#!/bin/bash
#
# Create Client - Azure SQL Benchmark Toolkit
# Creates a new customer directory structure for benchmark management
#
# Usage: ./create_client.sh <client-name>
# Example: ./create_client.sh contoso-manufacturing
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

# Functions
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  Azure SQL Benchmark Toolkit${NC}"
    echo -e "${BLUE}  Create New Client${NC}"
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
    if [ $# -eq 0 ]; then
        print_error "Client name is required"
        echo ""
        echo "Usage: $0 <client-name>"
        echo ""
        echo "Examples:"
        echo "  $0 contoso-manufacturing"
        echo "  $0 fabrikam-retail"
        echo "  $0 adventureworks-online"
        echo ""
        exit 1
    fi
    
    CLIENT_NAME="$1"
    CLIENT_DIR="$CUSTOMERS_DIR/$CLIENT_NAME"
    
    # Validate client name
    if [[ ! "$CLIENT_NAME" =~ ^[a-z0-9-]+$ ]]; then
        print_error "Invalid client name. Use lowercase letters, numbers, and hyphens only."
        exit 1
    fi
    
    # Check if client already exists
    if [ -d "$CLIENT_DIR" ]; then
        print_error "Client '$CLIENT_NAME' already exists at: $CLIENT_DIR"
        exit 1
    fi
    
    print_info "Creating client: $CLIENT_NAME"
    print_info "Location: $CLIENT_DIR"
    echo ""
    
    # Create directory structure
    print_info "Creating directory structure..."
    mkdir -p "$CLIENT_DIR"/{benchmarks,docs,config}
    
    # Create client README
    cat > "$CLIENT_DIR/README.md" << EOF
# Cliente: $CLIENT_NAME

## Información del Cliente

**Nombre**: $CLIENT_NAME
**Fecha de creación**: $(date +%Y-%m-%d)

## Descripción

<!-- Añadir descripción del cliente aquí -->

## Servidores SQL Gestionados

| Servidor | Entorno | Versión SQL | Estado | Última Evaluación |
|----------|---------|-------------|--------|-------------------|
| <!-- Ejemplo: SQLPROD01 --> | <!-- prod --> | <!-- SQL Server 2019 --> | <!-- Activo --> | <!-- 2025-11-25 --> |

## Benchmarks Realizados

<!-- Los benchmarks se almacenan en el directorio benchmarks/ -->

| Fecha | Servidor | Duración | Informes | Notas |
|-------|----------|----------|----------|-------|
| <!-- 2025-11-25 --> | <!-- SQLPROD01 --> | <!-- 24h --> | <!-- [Ver informes](benchmarks/2025-11-25/) --> | <!-- Benchmark inicial --> |

## Contactos

| Rol | Nombre | Email | Teléfono |
|-----|--------|-------|----------|
| Responsable Técnico | | | |
| Contacto Principal | | | |

## Notas

<!-- Añadir notas relevantes del proyecto aquí -->

EOF
    
    print_success "Created README.md"
    
    # Create client configuration template
    cat > "$CLIENT_DIR/config/client-config.env" << EOF
# Client Configuration - $CLIENT_NAME
# Generated: $(date +%Y-%m-%d)

# Client Information
CLIENT_NAME="$CLIENT_NAME"
CLIENT_ID="$(echo $CLIENT_NAME | tr '-' '_' | tr '[:lower:]' '[:upper:]')"

# SQL Server Connection (Default - Update as needed)
SQL_SERVER="localhost"
SQL_DATABASE="master"
SQL_USERNAME=""
SQL_PASSWORD=""
SQL_USE_TRUSTED_AUTH="true"

# Benchmark Settings
BENCHMARK_INTERVAL="120"  # seconds
BENCHMARK_DURATION="86400"  # 24 hours

# Azure Target Configuration
AZURE_SUBSCRIPTION=""
AZURE_RESOURCE_GROUP="rg-$CLIENT_NAME-sql-migration"
AZURE_REGION="westeurope"
AZURE_VM_SIZE="Standard_E16ds_v5"

# Cost Analysis Settings
ONPREM_SERVER_COST_MONTHLY="5000"  # EUR
ONPREM_LICENSE_COST_MONTHLY="2000"  # EUR
ONPREM_MAINTENANCE_COST_MONTHLY="500"  # EUR

# Reporting
REPORT_LANGUAGE="es"  # en, es, fr, de
REPORT_CURRENCY="EUR"  # EUR, USD, GBP

# Email Notifications (Optional)
NOTIFICATION_EMAIL=""
SMTP_SERVER=""
SMTP_PORT="587"
SMTP_USERNAME=""
SMTP_PASSWORD=""

EOF
    
    print_success "Created config/client-config.env"
    
    # Create servers inventory
    cat > "$CLIENT_DIR/config/servers-inventory.json" << EOF
{
  "client": "$CLIENT_NAME",
  "created": "$(date -Iseconds)",
  "servers": [
    {
      "id": 1,
      "name": "SQLPROD01",
      "hostname": "sqlprod01.domain.local",
      "environment": "production",
      "sql_version": "SQL Server 2019",
      "edition": "Enterprise",
      "cores": 12,
      "ram_gb": 32,
      "storage_gb": 500,
      "status": "active",
      "notes": "Primary production server"
    }
  ]
}
EOF
    
    print_success "Created config/servers-inventory.json"
    
    # Create quick start guide
    cat > "$CLIENT_DIR/QUICKSTART.md" << EOF
# Quick Start Guide - $CLIENT_NAME

## Configuración Inicial

### 1. Configurar Conexión SQL Server

Edita el archivo de configuración:

\`\`\`bash
nano config/client-config.env
\`\`\`

Actualiza los siguientes parámetros:
- \`SQL_SERVER\`: Hostname o IP del servidor SQL
- \`SQL_DATABASE\`: Base de datos (generalmente 'master')
- \`SQL_USERNAME\` y \`SQL_PASSWORD\`: Si usas SQL authentication
- \`SQL_USE_TRUSTED_AUTH\`: "true" para Windows auth, "false" para SQL auth

### 2. Actualizar Inventario de Servidores

Edita el inventario:

\`\`\`bash
nano config/servers-inventory.json
\`\`\`

### 3. Ejecutar Benchmark

Desde el directorio raíz del proyecto:

\`\`\`bash
# Benchmark de 24 horas (recomendado)
./tools/utils/run_benchmark.sh $CLIENT_NAME SQLPROD01

# Benchmark de prueba (10 minutos)
./tools/utils/run_benchmark.sh $CLIENT_NAME SQLPROD01 --duration 600 --interval 30
\`\`\`

### 4. Generar Informes

Una vez completado el benchmark:

\`\`\`bash
./tools/utils/generate_reports.sh $CLIENT_NAME 2025-11-25
\`\`\`

Los informes HTML se generarán en:
\`benchmarks/<fecha>/\`

### 5. Ver Informes

Abre los informes en tu navegador:

\`\`\`bash
# Linux/WSL
xdg-open benchmarks/<fecha>/benchmark-performance-report.html

# Windows
start benchmarks/<fecha>/benchmark-performance-report.html

# macOS
open benchmarks/<fecha>/benchmark-performance-report.html
\`\`\`

## Estructura de Archivos

\`\`\`
$CLIENT_NAME/
├── README.md                    # Documentación del cliente
├── QUICKSTART.md               # Esta guía
├── config/
│   ├── client-config.env       # Configuración general
│   └── servers-inventory.json  # Inventario de servidores
├── benchmarks/
│   └── YYYY-MM-DD/            # Resultados por fecha
│       ├── sql_workload_*.json           # Datos raw del benchmark
│       ├── benchmark-performance-report.html
│       ├── cost-analysis-report.html
│       └── migration-operations-guide.html
└── docs/                       # Documentación adicional
\`\`\`

## Soporte

Para ayuda adicional, consulta la documentación del proyecto en:
\`../../docs/README.md\`

EOF
    
    print_success "Created QUICKSTART.md"
    
    # Create .gitkeep files
    touch "$CLIENT_DIR/benchmarks/.gitkeep"
    touch "$CLIENT_DIR/docs/.gitkeep"
    
    # Summary
    echo ""
    print_success "Client '$CLIENT_NAME' created successfully!"
    echo ""
    print_info "Next steps:"
    echo "  1. cd $CLIENT_DIR"
    echo "  2. Edit config/client-config.env with your SQL Server details"
    echo "  3. Update config/servers-inventory.json with server information"
    echo "  4. Run: ../../tools/utils/run_benchmark.sh $CLIENT_NAME <server-name>"
    echo ""
    print_info "Directory structure:"
    tree -L 2 "$CLIENT_DIR" 2>/dev/null || ls -la "$CLIENT_DIR"
    echo ""
}

# Run main function
main "$@"
