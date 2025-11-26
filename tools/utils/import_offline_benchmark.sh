#!/bin/bash
#
# Import Offline Benchmark
# ========================
#
# Script para importar benchmarks ejecutados offline en servidores sin acceso remoto.
# Integra el JSON generado por monitor_sql_workload_offline.py en la estructura del proyecto.
#
# Uso:
#   ./tools/utils/import_offline_benchmark.sh <cliente> <archivo_json> [nombre_servidor]
#
# Ejemplo:
#   ./tools/utils/import_offline_benchmark.sh contoso-manufacturing sql_workload_prod01_20251126.json SQLPROD01
#
# Autor: Alejandro Almeida
# Versión: 2.1.0
# Licencia: MIT

set -euo pipefail

# Colores
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Directorio raíz del proyecto
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TOOLKIT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Banner
print_banner() {
    echo -e "${BLUE}"
    echo "========================================"
    echo "  Azure SQL Benchmark Toolkit"
    echo "  Import Offline Benchmark"
    echo "========================================"
    echo -e "${NC}"
}

# Función de ayuda
show_help() {
    cat << EOF
Uso: $0 <cliente> <archivo_json> [nombre_servidor]

Importa un benchmark ejecutado offline al proyecto.

Argumentos:
  cliente          Nombre del cliente (debe existir en customers/)
  archivo_json     Ruta al archivo JSON generado offline
  nombre_servidor  Nombre del servidor (opcional, se extrae del JSON si no se proporciona)

Opciones:
  -h, --help       Muestra esta ayuda
  -v, --version    Muestra la versión

Ejemplos:
  # Importar con nombre de servidor explícito
  $0 contoso-manufacturing sql_workload_prod01.json SQLPROD01

  # Importar sin nombre de servidor (se extrae del nombre del archivo)
  $0 fabrikam-retail sql_workload_192_168_1_100_20251126.json

  # Desde un USB o directorio externo
  $0 adventureworks /mnt/usb/benchmark_results.json SQLPROD03

Notas:
  - El archivo JSON debe estar en el formato generado por monitor_sql_workload_offline.py
  - Se creará automáticamente el directorio de benchmark con timestamp
  - Después de importar, puedes generar informes con:
      ./tools/utils/generate_reports.sh <cliente> <fecha>

Para más información:
  https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/blob/main/docs/USAGE.md
EOF
}

# Validar argumentos
if [[ $# -lt 2 ]]; then
    echo -e "${RED}❌ Error: Argumentos insuficientes${NC}"
    echo ""
    show_help
    exit 1
fi

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

if [[ "$1" == "-v" ]] || [[ "$1" == "--version" ]]; then
    echo "import_offline_benchmark.sh v2.1.0"
    exit 0
fi

readonly CLIENT_NAME="$1"
readonly JSON_FILE="$2"
readonly SERVER_NAME="${3:-}"

print_banner

echo -e "${BLUE}ℹ️  Cliente:${NC} $CLIENT_NAME"
echo -e "${BLUE}ℹ️  Archivo JSON:${NC} $JSON_FILE"
if [[ -n "$SERVER_NAME" ]]; then
    echo -e "${BLUE}ℹ️  Servidor:${NC} $SERVER_NAME"
fi
echo ""

# Validar que el cliente existe
readonly CLIENT_DIR="$TOOLKIT_DIR/customers/$CLIENT_NAME"
if [[ ! -d "$CLIENT_DIR" ]]; then
    echo -e "${RED}❌ Error: El cliente '$CLIENT_NAME' no existe${NC}"
    echo ""
    echo "Clientes disponibles:"
    ls -1 "$TOOLKIT_DIR/customers/" | grep -v "^\.example-client$"
    echo ""
    echo "Para crear un nuevo cliente:"
    echo "  ./tools/utils/create_client.sh $CLIENT_NAME"
    exit 1
fi

# Validar que el archivo JSON existe
if [[ ! -f "$JSON_FILE" ]]; then
    echo -e "${RED}❌ Error: El archivo JSON '$JSON_FILE' no existe${NC}"
    exit 1
fi

# Validar que es un JSON válido
if ! jq empty "$JSON_FILE" 2>/dev/null; then
    echo -e "${RED}❌ Error: El archivo no es un JSON válido${NC}"
    exit 1
fi

# Validar estructura del JSON
echo -e "${YELLOW}🔍 Validando estructura del JSON...${NC}"

# Detectar formato del JSON (array directo vs objeto con metadata)
if jq -e '.metadata and .samples' "$JSON_FILE" > /dev/null 2>&1; then
    # Formato con metadata (monitor offline v2.1)
    echo -e "${BLUE}ℹ️  Formato detectado: Offline Monitor v2.1 (con metadata)${NC}"
    SAMPLE_COUNT=$(jq '.samples | length' "$JSON_FILE")
    FIRST_TIMESTAMP=$(jq -r '.samples[0].timestamp' "$JSON_FILE")
    LAST_TIMESTAMP=$(jq -r '.samples[-1].timestamp' "$JSON_FILE")
    SERVER_FROM_JSON=$(jq -r '.metadata.server // "unknown"' "$JSON_FILE")
elif jq -e 'type == "array"' "$JSON_FILE" > /dev/null 2>&1; then
    # Formato array directo (legacy)
    echo -e "${BLUE}ℹ️  Formato detectado: Array directo (legacy)${NC}"
    SAMPLE_COUNT=$(jq 'length' "$JSON_FILE")
    FIRST_TIMESTAMP=$(jq -r '.[0].timestamp' "$JSON_FILE")
    LAST_TIMESTAMP=$(jq -r '.[-1].timestamp' "$JSON_FILE")
    SERVER_FROM_JSON="unknown"
else
    echo -e "${RED}❌ Error: Formato JSON no reconocido${NC}"
    echo "Se espera: {metadata: {...}, samples: [...]} o simplemente [...]"
    exit 1
fi

# Verificar que tiene muestras
if [[ $SAMPLE_COUNT -eq 0 ]]; then
    echo -e "${RED}❌ Error: El JSON no contiene muestras${NC}"
    exit 1
fi

echo -e "${GREEN}✅ JSON válido con $SAMPLE_COUNT muestras${NC}"

# Calcular fechas
BENCHMARK_DATE=$(date -d "$FIRST_TIMESTAMP" +%Y-%m-%d 2>/dev/null || date +%Y-%m-%d)
BENCHMARK_DATETIME=$(date -d "$FIRST_TIMESTAMP" +%Y-%m-%d_%H%M%S 2>/dev/null || date +%Y-%m-%d_%H%M%S)

# Si no se proporcionó nombre de servidor, intentar extraerlo del nombre del archivo
if [[ -z "$SERVER_NAME" ]]; then
    # Extraer nombre del servidor del nombre del archivo (formato: sql_workload_<server>_<timestamp>.json)
    BASENAME=$(basename "$JSON_FILE" .json)
    if [[ $BASENAME =~ sql_workload_(.+)_[0-9]{8}_[0-9]{6} ]]; then
        EXTRACTED_SERVER="${BASH_REMATCH[1]}"
        EXTRACTED_SERVER=$(echo "$EXTRACTED_SERVER" | tr '_' '.' | tr '[:lower:]' '[:upper:]')
        
        echo ""
        echo -e "${YELLOW}📝 Nombre de servidor extraído del archivo:${NC} $EXTRACTED_SERVER"
        read -p "¿Usar este nombre? (Y/n): " -n 1 -r
        echo ""
        
        if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
            SERVER_NAME_FINAL="$EXTRACTED_SERVER"
        else
            read -p "Ingresa el nombre del servidor: " SERVER_NAME_FINAL
        fi
    else
        read -p "Ingresa el nombre del servidor: " SERVER_NAME_FINAL
    fi
else
    SERVER_NAME_FINAL="$SERVER_NAME"
fi

# Crear directorio de benchmark
readonly BENCHMARK_DIR="$CLIENT_DIR/benchmarks/$BENCHMARK_DATETIME"
mkdir -p "$BENCHMARK_DIR"

# Generar nombre final del archivo JSON
readonly JSON_FILENAME="sql_workload_${SERVER_NAME_FINAL}_${BENCHMARK_DATETIME//-/}.json"
readonly DEST_JSON="$BENCHMARK_DIR/$JSON_FILENAME"

# Copiar archivo JSON
echo ""
echo -e "${YELLOW}📦 Copiando archivo JSON...${NC}"
cp "$JSON_FILE" "$DEST_JSON"

# Verificar copia
if [[ ! -f "$DEST_JSON" ]]; then
    echo -e "${RED}❌ Error: No se pudo copiar el archivo${NC}"
    exit 1
fi

FILE_SIZE=$(du -h "$DEST_JSON" | cut -f1)
echo -e "${GREEN}✅ Archivo copiado: $FILE_SIZE${NC}"

# Crear archivo de metadatos
echo ""
echo -e "${YELLOW}📝 Creando metadatos...${NC}"

LAST_TIMESTAMP=$(jq -r '.[-1].timestamp' "$DEST_JSON")
DURATION_SECONDS=$(( $(date -d "$LAST_TIMESTAMP" +%s) - $(date -d "$FIRST_TIMESTAMP" +%s) ))
DURATION_HOURS=$(echo "scale=2; $DURATION_SECONDS / 3600" | bc)

cat > "$BENCHMARK_DIR/benchmark_metadata.json" << EOF
{
  "benchmark_info": {
    "client": "$CLIENT_NAME",
    "server": "$SERVER_NAME_FINAL",
    "start_time": "$FIRST_TIMESTAMP",
    "end_time": "$LAST_TIMESTAMP",
    "duration_seconds": $DURATION_SECONDS,
    "duration_hours": $DURATION_HOURS,
    "sample_count": $SAMPLE_COUNT,
    "import_method": "offline",
    "imported_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "imported_by": "$(whoami)",
    "original_file": "$(basename "$JSON_FILE")"
  }
}
EOF

echo -e "${GREEN}✅ Metadatos creados${NC}"

# Extraer estadísticas básicas
echo ""
echo -e "${YELLOW}📊 Calculando estadísticas...${NC}"

# Detectar formato y calcular estadísticas
if jq -e '.samples' "$DEST_JSON" > /dev/null 2>&1; then
    # Formato v2.1 con metadata
    CPU_AVG=$(jq '[.samples[].cpu.sql_server_cpu_time_ms / (.samples[].cpu.total_cpus * 1000) * 100] | add / length' "$DEST_JSON")
    CPU_MAX=$(jq '[.samples[].cpu.sql_server_cpu_time_ms / (.samples[].cpu.total_cpus * 1000) * 100] | max' "$DEST_JSON")
    
    RAM_AVG=$(jq '[.samples[].memory.buffer_pool_mb] | add / length' "$DEST_JSON")
    RAM_MAX=$(jq '[.samples[].memory.buffer_pool_mb] | max' "$DEST_JSON")
    
    IOPS_AVG=$(jq '[.samples[] | (.io.total_reads + .io.total_writes)] | add / length' "$DEST_JSON")
    IOPS_MAX=$(jq '[.samples[] | (.io.total_reads + .io.total_writes)] | max' "$DEST_JSON")
    
    TPS_AVG=$(jq '[.samples[].activity.batch_requests_per_sec] | add / length' "$DEST_JSON")
    TPS_MAX=$(jq '[.samples[].activity.batch_requests_per_sec] | max' "$DEST_JSON")
else
    # Formato legacy array
    CPU_AVG=$(jq '[.[].cpu_percent] | add / length' "$DEST_JSON")
    CPU_MAX=$(jq '[.[].cpu_percent] | max' "$DEST_JSON")
    
    RAM_AVG=$(jq '[.[].memory.memory_percent] | add / length' "$DEST_JSON")
    RAM_MAX=$(jq '[.[].memory.memory_percent] | max' "$DEST_JSON")
    
    IOPS_AVG=$(jq '[.[].disk_io.total_iops] | add / length' "$DEST_JSON")
    IOPS_MAX=$(jq '[.[].disk_io.total_iops] | max' "$DEST_JSON")
    
    TPS_AVG=$(jq '[.[].transactions.transactions_per_sec] | add / length' "$DEST_JSON")
    TPS_MAX=$(jq '[.[].transactions.transactions_per_sec] | max' "$DEST_JSON")
fi

# Crear resumen
cat > "$BENCHMARK_DIR/SUMMARY.md" << EOF
# Benchmark Summary - $SERVER_NAME_FINAL

**Cliente**: $CLIENT_NAME  
**Servidor**: $SERVER_NAME_FINAL  
**Fecha**: $BENCHMARK_DATE  
**Duración**: ${DURATION_HOURS}h ($SAMPLE_COUNT muestras)

## Métricas Principales

| Métrica | Promedio | Máximo |
|---------|----------|--------|
| **CPU %** | ${CPU_AVG}% | ${CPU_MAX}% |
| **RAM %** | ${RAM_AVG}% | ${RAM_MAX}% |
| **IOPS** | ${IOPS_AVG} | ${IOPS_MAX} |
| **TPS** | ${TPS_AVG} | ${TPS_MAX} |

## Archivos Generados

- \`$JSON_FILENAME\` - Datos crudos JSON
- \`benchmark_metadata.json\` - Metadatos del benchmark
- \`SUMMARY.md\` - Este resumen

## Próximos Pasos

### 1. Generar Informes HTML

\`\`\`bash
./tools/utils/generate_reports.sh $CLIENT_NAME $BENCHMARK_DATETIME
\`\`\`

### 2. Analizar con Agente IA

\`\`\`
@azure-architect analiza el benchmark de $CLIENT_NAME ejecutado el $BENCHMARK_DATE
\`\`\`

### 3. Ver Resultados

\`\`\`bash
xdg-open customers/$CLIENT_NAME/benchmarks/$BENCHMARK_DATETIME/benchmark-performance-report.html
\`\`\`

---

**Importado el**: $(date)  
**Método**: Benchmark offline  
**Archivo original**: $(basename "$JSON_FILE")
EOF

echo -e "${GREEN}✅ Resumen creado${NC}"

# Resumen final
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          ✅ BENCHMARK IMPORTADO EXITOSAMENTE                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}📊 Estadísticas:${NC}"
echo "  • Muestras: $SAMPLE_COUNT"
echo "  • Duración: ${DURATION_HOURS}h"
echo "  • CPU promedio: ${CPU_AVG}%"
echo "  • RAM promedio: ${RAM_AVG}%"
echo "  • IOPS promedio: ${IOPS_AVG}"
echo ""
echo -e "${BLUE}📁 Ubicación:${NC}"
echo "  $BENCHMARK_DIR"
echo ""
echo -e "${BLUE}📄 Archivos generados:${NC}"
echo "  • $JSON_FILENAME ($FILE_SIZE)"
echo "  • benchmark_metadata.json"
echo "  • SUMMARY.md"
echo ""
echo -e "${YELLOW}🚀 Próximos pasos:${NC}"
echo ""
echo "1️⃣  Generar informes HTML:"
echo -e "   ${GREEN}./tools/utils/generate_reports.sh $CLIENT_NAME $BENCHMARK_DATETIME${NC}"
echo ""
echo "2️⃣  O usar el agente IA para análisis:"
echo -e "   ${GREEN}@azure-architect analiza el benchmark de $CLIENT_NAME del $BENCHMARK_DATE${NC}"
echo ""
echo "3️⃣  Ver resumen rápido:"
echo -e "   ${GREEN}cat $BENCHMARK_DIR/SUMMARY.md${NC}"
echo ""
echo "═════════════════════════════════════════════════════════════════"
