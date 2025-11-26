#!/bin/bash
#
# Setup Script - Azure SQL Benchmark Toolkit
# Initial setup and dependency check for the toolkit
#
# Usage: ./setup.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Azure SQL Benchmark Toolkit${NC}"
    echo -e "${BLUE}  Setup & Dependency Check${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

check_python() {
    print_info "Checking Python installation..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_VERSION=$(python3 --version | cut -d ' ' -f 2)
        PYTHON_MAJOR=$(echo "$PYTHON_VERSION" | cut -d '.' -f 1)
        PYTHON_MINOR=$(echo "$PYTHON_VERSION" | cut -d '.' -f 2)
        
        if [ "$PYTHON_MAJOR" -ge 3 ] && [ "$PYTHON_MINOR" -ge 8 ]; then
            print_success "Python $PYTHON_VERSION (>=3.8 required)"
        else
            print_error "Python $PYTHON_VERSION found, but 3.8+ required"
            return 1
        fi
    else
        print_error "Python 3 not found"
        echo "  Install from: https://www.python.org/downloads/"
        return 1
    fi
}

check_pyodbc() {
    print_info "Checking Python pyodbc package..."
    
    if python3 -c "import pyodbc" 2>/dev/null; then
        PYODBC_VERSION=$(python3 -c "import pyodbc; print(pyodbc.version)" 2>/dev/null || echo "unknown")
        print_success "pyodbc installed (version $PYODBC_VERSION)"
    else
        print_warning "pyodbc not installed"
        echo "  Install with: pip install pyodbc"
        
        read -p "Install pyodbc now? (yes/no): " -r
        if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
            pip install pyodbc
            if [ $? -eq 0 ]; then
                print_success "pyodbc installed successfully"
            else
                print_error "Failed to install pyodbc"
                return 1
            fi
        fi
    fi
}

check_odbc_driver() {
    print_info "Checking ODBC Driver for SQL Server..."
    
    if command -v odbcinst &> /dev/null; then
        if odbcinst -q -d | grep -q "ODBC Driver 17 for SQL Server\|ODBC Driver 18 for SQL Server"; then
            DRIVER=$(odbcinst -q -d | grep "ODBC Driver" | head -1)
            print_success "ODBC Driver found: $DRIVER"
        else
            print_warning "ODBC Driver for SQL Server not found"
            echo ""
            echo "  Install instructions:"
            echo "  Ubuntu/Debian:"
            echo "    curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -"
            echo "    curl https://packages.microsoft.com/config/ubuntu/\$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list"
            echo "    sudo apt-get update && sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17"
            echo ""
            echo "  Windows: https://docs.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server"
            echo "  macOS: brew install msodbcsql17"
            return 1
        fi
    else
        print_warning "odbcinst not found - cannot verify ODBC driver"
    fi
}

check_git() {
    print_info "Checking Git installation..."
    
    if command -v git &> /dev/null; then
        GIT_VERSION=$(git --version | cut -d ' ' -f 3)
        print_success "Git $GIT_VERSION"
    else
        print_warning "Git not installed (optional for toolkit usage)"
    fi
}

check_jq() {
    print_info "Checking jq (JSON processor)..."
    
    if command -v jq &> /dev/null; then
        JQ_VERSION=$(jq --version | cut -d '-' -f 2)
        print_success "jq $JQ_VERSION"
    else
        print_warning "jq not installed (used by report generation)"
        echo "  Install: sudo apt-get install jq (Linux) or brew install jq (macOS)"
    fi
}

check_structure() {
    print_info "Checking project structure..."
    
    ERRORS=0
    
    for dir in tools customers templates docs config .github; do
        if [ -d "$dir" ]; then
            print_success "Directory exists: $dir"
        else
            print_error "Missing directory: $dir"
            ERRORS=$((ERRORS + 1))
        fi
    done
    
    if [ $ERRORS -gt 0 ]; then
        print_error "Project structure incomplete"
        return 1
    fi
}

check_permissions() {
    print_info "Checking script permissions..."
    
    for script in tools/utils/*.sh tools/monitoring/*.py; do
        if [ -f "$script" ]; then
            if [ -x "$script" ]; then
                # Already executable
                :
            else
                print_warning "Setting executable: $script"
                chmod +x "$script"
            fi
        fi
    done
    
    print_success "All scripts have correct permissions"
}

create_example_client() {
    if [ ! -d "customers/.example-client/benchmarks/2025-11-20" ]; then
        print_info "Example client benchmark data missing"
        print_info "This is expected in a fresh clone"
    else
        print_success "Example client data present"
    fi
}

main() {
    print_header
    
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    cd "$SCRIPT_DIR"
    
    print_info "Running setup from: $SCRIPT_DIR"
    echo ""
    
    CHECKS_PASSED=0
    CHECKS_FAILED=0
    
    # Run checks
    check_python && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    check_pyodbc && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    check_odbc_driver && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    check_git && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    check_jq && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    check_structure && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    check_permissions && CHECKS_PASSED=$((CHECKS_PASSED + 1)) || CHECKS_FAILED=$((CHECKS_FAILED + 1))
    create_example_client
    
    # Summary
    echo ""
    echo "========================================"
    echo "Setup Summary"
    echo "========================================"
    echo "Checks passed: $CHECKS_PASSED"
    echo "Checks failed: $CHECKS_FAILED"
    echo ""
    
    if [ $CHECKS_FAILED -eq 0 ]; then
        print_success "All checks passed! You're ready to go."
        echo ""
        print_info "Next steps:"
        echo "  1. Create your first client: ./tools/utils/create_client.sh my-client"
        echo "  2. Configure SQL connection: edit customers/my-client/config/client-config.env"
        echo "  3. Run benchmark: ./tools/utils/run_benchmark.sh my-client SERVER01"
        echo ""
        print_info "For more help, see: docs/QUICKSTART.md"
    else
        print_warning "Some checks failed. Please fix the issues above."
        echo ""
        print_info "For detailed setup instructions, see: docs/SETUP.md"
        exit 1
    fi
}

main "$@"
