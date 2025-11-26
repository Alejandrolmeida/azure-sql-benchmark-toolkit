#!/bin/bash
#
# Generate Reports - Azure SQL Benchmark Toolkit
# Generates HTML reports from benchmark data
#
# Usage: ./generate_reports.sh <client-name> <benchmark-date>
# Example: ./generate_reports.sh contoso-manufacturing 2025-11-25
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
TEMPLATES_DIR="$PROJECT_ROOT/templates"

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Azure SQL Benchmark Toolkit${NC}"
    echo -e "${BLUE}  Generate Reports${NC}"
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

# Main script
main() {
    print_header
    
    # Check arguments
    if [ $# -lt 2 ]; then
        print_error "Client name and benchmark date are required"
        echo ""
        echo "Usage: $0 <client-name> <benchmark-date>"
        echo ""
        echo "Examples:"
        echo "  $0 contoso-manufacturing 2025-11-25"
        echo "  $0 fabrikam-retail 2025-11-20_143353"
        echo ""
        exit 1
    fi
    
    CLIENT_NAME="$1"
    BENCHMARK_DATE="$2"
    
    CLIENT_DIR="$CUSTOMERS_DIR/$CLIENT_NAME"
    
    # Check if client exists
    if [ ! -d "$CLIENT_DIR" ]; then
        print_error "Client '$CLIENT_NAME' not found at: $CLIENT_DIR"
        exit 1
    fi
    
    # Find benchmark directory (support both date and date_time formats)
    BENCHMARK_DIR=""
    if [ -d "$CLIENT_DIR/benchmarks/$BENCHMARK_DATE" ]; then
        BENCHMARK_DIR="$CLIENT_DIR/benchmarks/$BENCHMARK_DATE"
    else
        # Try to find directory starting with the date
        MATCHING_DIRS=$(find "$CLIENT_DIR/benchmarks" -maxdepth 1 -type d -name "${BENCHMARK_DATE}*" | head -1)
        if [ -n "$MATCHING_DIRS" ]; then
            BENCHMARK_DIR="$MATCHING_DIRS"
        fi
    fi
    
    if [ -z "$BENCHMARK_DIR" ] || [ ! -d "$BENCHMARK_DIR" ]; then
        print_error "Benchmark directory not found for date: $BENCHMARK_DATE"
        print_info "Available benchmarks:"
        ls -1 "$CLIENT_DIR/benchmarks" 2>/dev/null || echo "  (none)"
        exit 1
    fi
    
    print_info "Client: $CLIENT_NAME"
    print_info "Benchmark: $BENCHMARK_DIR"
    echo ""
    
    # Find JSON data file
    JSON_FILE=$(find "$BENCHMARK_DIR" -name "sql_workload_*.json" -type f | head -1)
    
    if [ -z "$JSON_FILE" ] || [ ! -f "$JSON_FILE" ]; then
        print_error "No benchmark JSON file found in: $BENCHMARK_DIR"
        exit 1
    fi
    
    print_info "Data file: $(basename $JSON_FILE)"
    
    # Check if JSON is valid
    if ! jq empty "$JSON_FILE" 2>/dev/null; then
        print_error "Invalid JSON file: $JSON_FILE"
        exit 1
    fi
    
    # Get number of samples
    SAMPLE_COUNT=$(jq '. | length' "$JSON_FILE")
    print_info "Samples found: $SAMPLE_COUNT"
    echo ""
    
    # Copy templates to benchmark directory
    print_info "Generating reports from templates..."
    
    # Check if templates exist
    if [ ! -f "$TEMPLATES_DIR/benchmark-performance-report.html" ]; then
        print_error "Templates not found in: $TEMPLATES_DIR"
        exit 1
    fi
    
    # Copy templates
    cp "$TEMPLATES_DIR/benchmark-performance-report.html" "$BENCHMARK_DIR/"
    cp "$TEMPLATES_DIR/cost-analysis-report.html" "$BENCHMARK_DIR/"
    cp "$TEMPLATES_DIR/migration-operations-guide.html" "$BENCHMARK_DIR/"
    
    print_success "Reports generated:"
    echo "  1. benchmark-performance-report.html - Technical performance analysis"
    echo "  2. cost-analysis-report.html - Cost comparison Azure vs On-premises"
    echo "  3. migration-operations-guide.html - Migration planning and operations"
    echo ""
    
    # Update metadata
    if [ -f "$BENCHMARK_DIR/benchmark-metadata.json" ]; then
        jq '.reports_generated = "'$(date -Iseconds)'" | .reports = ["benchmark-performance-report.html", "cost-analysis-report.html", "migration-operations-guide.html"]' \
            "$BENCHMARK_DIR/benchmark-metadata.json" > "$BENCHMARK_DIR/benchmark-metadata.json.tmp" \
            && mv "$BENCHMARK_DIR/benchmark-metadata.json.tmp" "$BENCHMARK_DIR/benchmark-metadata.json"
    fi
    
    # Generate summary report
    cat > "$BENCHMARK_DIR/REPORT_SUMMARY.md" << EOF
# Benchmark Report Summary

**Client**: $CLIENT_NAME
**Date**: $BENCHMARK_DATE
**Generated**: $(date +"%Y-%m-%d %H:%M:%S")

## Data Collection

- **Samples**: $SAMPLE_COUNT
- **Data File**: $(basename $JSON_FILE)
- **File Size**: $(du -h "$JSON_FILE" | cut -f1)

## Available Reports

1. **[Benchmark Performance Report](benchmark-performance-report.html)**
   - CPU utilization analysis
   - Memory usage patterns
   - Disk I/O metrics (IOPS, latency)
   - Transaction statistics
   - Temporal patterns and bottleneck detection
   - Azure VM sizing recommendations

2. **[Cost Analysis Report](cost-analysis-report.html)**
   - Total Cost of Ownership (TCO) comparison
   - Azure vs On-premises cost breakdown
   - 3-year cost projection
   - ROI analysis
   - Cost optimization recommendations

3. **[Migration Operations Guide](migration-operations-guide.html)**
   - Step-by-step migration plan
   - Pre-migration checklist
   - Cutover procedures
   - Rollback strategies
   - Post-migration validation
   - Risk mitigation

## Quick Access

Open reports in your browser:

\`\`\`bash
# Linux/WSL
xdg-open benchmark-performance-report.html

# Windows
start benchmark-performance-report.html

# macOS
open benchmark-performance-report.html
\`\`\`

## Next Steps

1. Review all three reports thoroughly
2. Share reports with stakeholders
3. Schedule migration planning meeting
4. Update client documentation with findings

## Files in This Directory

\`\`\`
$(ls -lh "$BENCHMARK_DIR" | tail -n +2)
\`\`\`

---
Generated by Azure SQL Benchmark Toolkit
EOF
    
    print_success "Summary report created: REPORT_SUMMARY.md"
    echo ""
    
    # Display file list
    print_info "Files in benchmark directory:"
    ls -lh "$BENCHMARK_DIR"
    echo ""
    
    # Offer to open report
    print_info "Open performance report now? (requires browser)"
    read -p "Open report? (yes/no): " -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        REPORT_FILE="$BENCHMARK_DIR/benchmark-performance-report.html"
        
        # Try different commands based on OS
        if command -v xdg-open &> /dev/null; then
            xdg-open "$REPORT_FILE" &
        elif command -v open &> /dev/null; then
            open "$REPORT_FILE" &
        elif command -v start &> /dev/null; then
            start "$REPORT_FILE" &
        else
            print_warning "Could not detect browser. Open manually:"
            echo "  $REPORT_FILE"
        fi
        
        print_success "Report opened in browser"
    fi
    
    echo ""
    print_success "Report generation completed!"
    echo ""
}

# Run main function
main "$@"
