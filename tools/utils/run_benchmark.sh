#!/bin/bash
#
# Run Benchmark - Azure SQL Benchmark Toolkit
# Executes SQL Server workload monitoring for a specific client
#
# Usage: ./run_benchmark.sh <client-name> <server-name> [options]
# Example: ./run_benchmark.sh contoso-manufacturing SQLPROD01
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CUSTOMERS_DIR="$PROJECT_ROOT/customers"
TOOLS_DIR="$PROJECT_ROOT/tools"

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Azure SQL Benchmark Toolkit${NC}"
    echo -e "${BLUE}  Run Benchmark${NC}"
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

# Parse arguments
parse_arguments() {
    CLIENT_NAME=""
    SERVER_NAME=""
    DURATION="86400"  # Default: 24 hours
    INTERVAL="120"    # Default: 2 minutes
    
    # Parse positional arguments
    if [ $# -ge 1 ]; then
        CLIENT_NAME="$1"
        shift
    fi
    
    if [ $# -ge 1 ]; then
        SERVER_NAME="$1"
        shift
    fi
    
    # Parse optional arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --duration)
                DURATION="$2"
                shift 2
                ;;
            --interval)
                INTERVAL="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Usage: $0 <client-name> <server-name> [options]

Arguments:
  client-name     Client directory name (e.g., contoso-manufacturing)
  server-name     SQL Server name from inventory (e.g., SQLPROD01)

Options:
  --duration N    Monitoring duration in seconds (default: 86400 = 24h)
  --interval N    Sampling interval in seconds (default: 120 = 2min)
  --help, -h      Show this help message

Examples:
  # Full 24-hour benchmark
  $0 contoso-manufacturing SQLPROD01

  # 1-hour test benchmark
  $0 contoso-manufacturing SQLPROD01 --duration 3600 --interval 60

  # Quick 10-minute test
  $0 contoso-manufacturing SQLPROD01 --duration 600 --interval 30

Duration presets:
  10 minutes  : 600
  1 hour      : 3600
  6 hours     : 21600
  12 hours    : 43200
  24 hours    : 86400 (recommended)
  48 hours    : 172800

EOF
}

# Main script
main() {
    print_header
    
    # Parse arguments
    parse_arguments "$@"
    
    # Validate required arguments
    if [ -z "$CLIENT_NAME" ] || [ -z "$SERVER_NAME" ]; then
        print_error "Client name and server name are required"
        echo ""
        show_help
        exit 1
    fi
    
    CLIENT_DIR="$CUSTOMERS_DIR/$CLIENT_NAME"
    CONFIG_FILE="$CLIENT_DIR/config/client-config.env"
    INVENTORY_FILE="$CLIENT_DIR/config/servers-inventory.json"
    
    # Check if client exists
    if [ ! -d "$CLIENT_DIR" ]; then
        print_error "Client '$CLIENT_NAME' not found at: $CLIENT_DIR"
        print_info "Create client first: ./tools/utils/create_client.sh $CLIENT_NAME"
        exit 1
    fi
    
    # Check if config exists
    if [ ! -f "$CONFIG_FILE" ]; then
        print_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi
    
    # Load configuration
    print_info "Loading client configuration..."
    source "$CONFIG_FILE"
    
    # Override with client config if set
    DURATION="${BENCHMARK_DURATION:-$DURATION}"
    INTERVAL="${BENCHMARK_INTERVAL:-$INTERVAL}"
    
    # Display benchmark parameters
    echo ""
    print_info "Benchmark Configuration:"
    echo "  Client: $CLIENT_NAME"
    echo "  Server: $SERVER_NAME"
    echo "  SQL Server: ${SQL_SERVER}"
    echo "  Database: ${SQL_DATABASE}"
    echo "  Auth Mode: $([ "$SQL_USE_TRUSTED_AUTH" = "true" ] && echo "Windows" || echo "SQL")"
    echo "  Duration: $DURATION seconds ($(($DURATION / 3600)) hours)"
    echo "  Interval: $INTERVAL seconds"
    echo ""
    
    # Create benchmark directory
    BENCHMARK_DATE=$(date +%Y-%m-%d)
    BENCHMARK_TIME=$(date +%H%M%S)
    BENCHMARK_DIR="$CLIENT_DIR/benchmarks/${BENCHMARK_DATE}_${BENCHMARK_TIME}"
    mkdir -p "$BENCHMARK_DIR"
    
    print_info "Output directory: $BENCHMARK_DIR"
    echo ""
    
    # Prepare output filename
    OUTPUT_FILE="$BENCHMARK_DIR/sql_workload_${SERVER_NAME}_$(date +%Y%m%d_%H%M%S).json"
    
    # Check Python dependencies
    print_info "Checking Python dependencies..."
    if ! python3 -c "import pyodbc" 2>/dev/null; then
        print_error "Python package 'pyodbc' not found"
        print_info "Install with: pip install pyodbc"
        exit 1
    fi
    print_success "Python dependencies OK"
    echo ""
    
    # Confirm before starting
    print_warning "This benchmark will run for $(($DURATION / 3600)) hours"
    read -p "Do you want to continue? (yes/no): " -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        print_info "Benchmark cancelled by user"
        exit 0
    fi
    
    # Build Python command
    PYTHON_CMD="python3 $TOOLS_DIR/monitoring/monitor_sql_workload.py"
    PYTHON_CMD="$PYTHON_CMD --server $SQL_SERVER"
    PYTHON_CMD="$PYTHON_CMD --database $SQL_DATABASE"
    PYTHON_CMD="$PYTHON_CMD --interval $INTERVAL"
    PYTHON_CMD="$PYTHON_CMD --duration $DURATION"
    PYTHON_CMD="$PYTHON_CMD --output $OUTPUT_FILE"
    
    # Add authentication
    if [ "$SQL_USE_TRUSTED_AUTH" = "true" ]; then
        PYTHON_CMD="$PYTHON_CMD --trusted"
    else
        if [ -n "${SQL_USERNAME:-}" ] && [ -n "${SQL_PASSWORD:-}" ]; then
            PYTHON_CMD="$PYTHON_CMD --username $SQL_USERNAME --password $SQL_PASSWORD"
        else
            print_error "SQL authentication selected but credentials not provided"
            exit 1
        fi
    fi
    
    # Save benchmark metadata
    cat > "$BENCHMARK_DIR/benchmark-metadata.json" << EOF
{
  "client": "$CLIENT_NAME",
  "server": "$SERVER_NAME",
  "sql_server": "$SQL_SERVER",
  "database": "$SQL_DATABASE",
  "start_time": "$(date -Iseconds)",
  "duration_seconds": $DURATION,
  "interval_seconds": $INTERVAL,
  "output_file": "$(basename $OUTPUT_FILE)",
  "status": "running"
}
EOF
    
    # Run benchmark
    print_success "Starting benchmark..."
    echo ""
    print_info "Benchmark is running in the foreground."
    print_info "Progress will be displayed below."
    print_info "Press Ctrl+C to stop (partial results will be saved)"
    echo ""
    
    # Execute monitoring
    if $PYTHON_CMD; then
        # Update metadata
        jq '.status = "completed" | .end_time = "'$(date -Iseconds)'"' \
            "$BENCHMARK_DIR/benchmark-metadata.json" > "$BENCHMARK_DIR/benchmark-metadata.json.tmp" \
            && mv "$BENCHMARK_DIR/benchmark-metadata.json.tmp" "$BENCHMARK_DIR/benchmark-metadata.json"
        
        print_success "Benchmark completed successfully!"
    else
        # Update metadata
        jq '.status = "failed" | .end_time = "'$(date -Iseconds)'"' \
            "$BENCHMARK_DIR/benchmark-metadata.json" > "$BENCHMARK_DIR/benchmark-metadata.json.tmp" \
            && mv "$BENCHMARK_DIR/benchmark-metadata.json.tmp" "$BENCHMARK_DIR/benchmark-metadata.json"
        
        print_error "Benchmark failed or was interrupted"
    fi
    
    echo ""
    print_info "Results saved to: $BENCHMARK_DIR"
    echo ""
    print_info "Next steps:"
    echo "  1. Generate reports: ./tools/utils/generate_reports.sh $CLIENT_NAME $BENCHMARK_DATE"
    echo "  2. View results: ls -lh $BENCHMARK_DIR"
    echo ""
}

# Run main function
main "$@"
