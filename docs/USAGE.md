# 📖 Usage Guide - Azure SQL Benchmark Toolkit

Guía completa de uso del toolkit con ejemplos avanzados.

## 📋 Tabla de Contenidos

- [Flujo de Trabajo Completo](#flujo-de-trabajo-completo)
- [Gestión de Clientes](#gestión-de-clientes)
- [Ejecución de Benchmarks](#ejecución-de-benchmarks)
- [Generación de Informes](#generación-de-informes)
- [Análisis Avanzado](#análisis-avanzado)
- [Integración con Azure](#integración-con-azure)
- [Automatización](#automatización)
- [Mejores Prácticas](#mejores-prácticas)

## 🔄 Flujo de Trabajo Completo

### Workflow Típico

```
1. Crear Cliente
   ↓
2. Configurar Conexión SQL
   ↓
3. Ejecutar Benchmark (6-24h)
   ↓
4. Generar Informes HTML
   ↓
5. Analizar Resultados
   ↓
6. Presentar a Stakeholders
   ↓
7. Planificar Migración
```

## 👥 Gestión de Clientes

### Crear Nuevo Cliente

```bash
./tools/utils/create_client.sh nombre-cliente
```

**Ejemplo real:**

```bash
./tools/utils/create_client.sh contoso-manufacturing
```

Esto crea:

```
customers/contoso-manufacturing/
├── README.md
├── QUICKSTART.md
├── config/
│   ├── client-config.env       # ← EDITAR AQUÍ
│   └── servers-inventory.json  # ← OPCIONAL
├── benchmarks/                 # Resultados aquí
└── docs/                       # Documentación adicional
```

### Configurar Cliente

Edita `customers/nombre-cliente/config/client-config.env`:

```bash
# Información del Cliente
CLIENT_NAME="Contoso Manufacturing"
CLIENT_INDUSTRY="Manufacturing"
CLIENT_CONTACT="john.doe@contoso.com"

# SQL Server
SQL_SERVER="sql-prod-01.contoso.local"
SQL_DATABASE="master"
SQL_USE_TRUSTED_AUTH="true"

# Azure Target
AZURE_SUBSCRIPTION="12345678-1234-1234-1234-123456789012"
AZURE_RESOURCE_GROUP="rg-contoso-sqlmigration"
AZURE_REGION="westeurope"
AZURE_VM_SIZE="Standard_E16ds_v5"

# Benchmark Configuration
BENCHMARK_INTERVAL="120"      # 2 minutos
BENCHMARK_DURATION="86400"    # 24 horas

# Cost Analysis
ON_PREM_HARDWARE_COST="50000"     # Costo hardware €
ON_PREM_SOFTWARE_LICENSES="25000" # Licencias SQL Server €
ON_PREM_POWER_COOLING="3000"      # Electricidad/AC €/año
ON_PREM_DATACENTER_RENT="12000"   # Colocation €/año
ON_PREM_MAINTENANCE="8000"        # Soporte €/año
```

### Inventario de Servidores

Opcionalmente, documenta todos los servidores en `servers-inventory.json`:

```json
{
  "servers": [
    {
      "hostname": "sql-prod-01.contoso.local",
      "role": "Production OLTP",
      "sql_version": "SQL Server 2019 Enterprise",
      "os": "Windows Server 2019",
      "cpu_cores": 16,
      "ram_gb": 128,
      "storage_tb": 2,
      "criticality": "High",
      "owner": "IT Operations"
    },
    {
      "hostname": "sql-dwh-01.contoso.local",
      "role": "Data Warehouse",
      "sql_version": "SQL Server 2022 Enterprise",
      "os": "Windows Server 2022",
      "cpu_cores": 32,
      "ram_gb": 256,
      "storage_tb": 10,
      "criticality": "Medium",
      "owner": "BI Team"
    }
  ]
}
```

### Listar Clientes

```bash
ls -1 customers/
```

### Eliminar Cliente

```bash
# ⚠️ Cuidado: elimina TODO el cliente y sus benchmarks
rm -rf customers/nombre-cliente
```

## 📊 Ejecución de Benchmarks

### Benchmark Básico (Usa config por defecto)

```bash
./tools/utils/run_benchmark.sh nombre-cliente nombre-servidor
```

**Ejemplo:**

```bash
./tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01
```

### Benchmark con Parámetros Personalizados

```bash
./tools/utils/run_benchmark.sh nombre-cliente nombre-servidor \
  --duration <segundos> \
  --interval <segundos>
```

**Ejemplos:**

```bash
# Test rápido de 10 minutos
./tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01 \
  --duration 600 \
  --interval 30

# Benchmark de 24 horas (recomendado)
./tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01 \
  --duration 86400 \
  --interval 120

# Benchmark de 1 semana (máximo detalle)
./tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01 \
  --duration 604800 \
  --interval 300
```

### Benchmark en Background (Sesión Persistente)

Para benchmarks largos, usa `screen` o `tmux`:

```bash
# Usando screen
screen -S benchmark-contoso
./tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01
# Presiona Ctrl+A, luego D para desconectar

# Reconectar más tarde
screen -r benchmark-contoso

# Listar sesiones activas
screen -ls
```

```bash
# Usando tmux
tmux new -s benchmark-contoso
./tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01
# Presiona Ctrl+B, luego D para desconectar

# Reconectar
tmux attach -t benchmark-contoso

# Listar sesiones
tmux ls
```

### Monitorizar Benchmark en Ejecución

```bash
# Ver salida en tiempo real
tail -f customers/contoso-manufacturing/benchmarks/*/benchmark.log

# Ver progreso del JSON
watch -n 60 'ls -lh customers/contoso-manufacturing/benchmarks/*/sql_workload_*.json'

# Contar samples capturados
jq '. | length' customers/contoso-manufacturing/benchmarks/*/sql_workload_*.json
```

### Detener Benchmark Manualmente

```bash
# Encuentra el proceso
ps aux | grep monitor_sql_workload

# Mata el proceso (los datos hasta el momento se guardan)
kill <PID>

# O con Ctrl+C si está en primer plano
```

## 📈 Generación de Informes

### Generar Informes Automáticamente

```bash
./tools/utils/generate_reports.sh nombre-cliente fecha
```

**Ejemplos:**

```bash
# Usando solo fecha (busca el directorio más reciente de ese día)
./tools/utils/generate_reports.sh contoso-manufacturing 2025-11-25

# Usando fecha + timestamp completo
./tools/utils/generate_reports.sh contoso-manufacturing 2025-11-25_143530
```

### Regenerar Informes (Sobrescribe existentes)

```bash
./tools/utils/generate_reports.sh contoso-manufacturing 2025-11-25 --force
```

### Personalizar Informes

Antes de generar, edita las plantillas:

```bash
# Editar plantilla de Performance
nano templates/benchmark-performance-report.html

# Editar plantilla de Costos
nano templates/cost-analysis-report.html

# Editar plantilla de Migración
nano templates/migration-operations-guide.html
```

Las plantillas usan **placeholders** que se reemplazan con datos del JSON:

- `{{CLIENT_NAME}}`
- `{{SERVER_NAME}}`
- `{{BENCHMARK_DATE}}`
- `{{CPU_AVG}}`, `{{RAM_AVG}}`, `{{IOPS_AVG}}`
- `{{AZURE_VM_SIZE}}`
- `{{COST_MONTHLY}}`
- etc.

### Exportar Informes a PDF

```bash
# Usando wkhtmltopdf (instalar primero)
sudo apt-get install -y wkhtmltopdf

# Convertir HTML a PDF
wkhtmltopdf \
  customers/contoso-manufacturing/benchmarks/2025-11-25/benchmark-performance-report.html \
  customers/contoso-manufacturing/benchmarks/2025-11-25/benchmark-performance-report.pdf
```

## 🔍 Análisis Avanzado

### Analizar JSON con jq

```bash
# Ver estructura del JSON
jq 'keys' sql_workload_*.json

# Extraer métricas específicas
jq '.[].cpu_percent' sql_workload_*.json | jq -s 'add/length'  # Promedio CPU

# Top 5 picos de CPU
jq '[.[] | {time: .timestamp, cpu: .cpu_percent}] | sort_by(.cpu) | reverse | .[0:5]' sql_workload_*.json

# Contar transacciones totales
jq '[.[].transactions_per_sec] | add' sql_workload_*.json
```

### Comparar Múltiples Benchmarks

```bash
# Crear script de comparación
cat > compare_benchmarks.sh << 'EOF'
#!/bin/bash

CLIENT=$1
DATE1=$2
DATE2=$3

echo "Comparando benchmarks de $CLIENT:"
echo ""

echo "Benchmark 1: $DATE1"
jq '[.[].cpu_percent] | add/length' \
  customers/$CLIENT/benchmarks/$DATE1/sql_workload_*.json

echo "Benchmark 2: $DATE2"
jq '[.[].cpu_percent] | add/length' \
  customers/$CLIENT/benchmarks/$DATE2/sql_workload_*.json
EOF

chmod +x compare_benchmarks.sh

./compare_benchmarks.sh contoso-manufacturing 2025-11-01 2025-11-25
```

### Exportar a CSV para Excel/PowerBI

```bash
# Convertir JSON a CSV
jq -r '
  ["timestamp","cpu_percent","ram_percent","iops","transactions_per_sec"],
  (.[] | [.timestamp, .cpu_percent, .ram_percent, .total_iops, .transactions_per_sec])
  | @csv
' sql_workload_*.json > benchmark_data.csv
```

## ☁️ Integración con Azure

### Sizing Automático con Azure CLI

```bash
# Listar VMs recomendadas para 16 vCPU, 128 GB RAM
az vm list-sizes --location westeurope \
  --query "[?numberOfCores==16 && memoryInMB>=131072]" \
  --output table

# Calcular costo estimado
az consumption usage list \
  --start-date 2025-11-01 \
  --end-date 2025-11-30 \
  --query "[].{Cost:pretaxCost}" \
  --output table
```

### Desplegar Infraestructura con Bicep

Usa el agente `@azure-architect` para generar Bicep:

```
@azure-architect genera Bicep para desplegar SQL Server VM con el sizing del benchmark de contoso-manufacturing
```

O usa templates existentes:

```bash
# Crear directorio de infraestructura
mkdir -p customers/contoso-manufacturing/infrastructure

# Copiar template base
cp templates/azure-vm-sql.bicep customers/contoso-manufacturing/infrastructure/

# Editar parámetros
nano customers/contoso-manufacturing/infrastructure/main.bicepparam

# Desplegar
az deployment group create \
  --resource-group rg-contoso-sqlmigration \
  --template-file customers/contoso-manufacturing/infrastructure/azure-vm-sql.bicep \
  --parameters @customers/contoso-manufacturing/infrastructure/main.bicepparam
```

## 🤖 Automatización

### Cron Job para Benchmarks Periódicos

```bash
# Editar crontab
crontab -e

# Benchmark semanal todos los lunes a las 2 AM
0 2 * * 1 /home/user/azure-sql-benchmark-toolkit/tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01 >> /var/log/benchmark-weekly.log 2>&1

# Benchmark mensual el día 1 de cada mes a las 3 AM
0 3 1 * * /home/user/azure-sql-benchmark-toolkit/tools/utils/run_benchmark.sh contoso-manufacturing SQLPROD01 --duration 172800 >> /var/log/benchmark-monthly.log 2>&1
```

### Script de Backup Automático

```bash
cat > backup_benchmarks.sh << 'EOF'
#!/bin/bash

BACKUP_DIR="/backup/benchmarks"
TOOLKIT_DIR="$HOME/azure-sql-benchmark-toolkit"

mkdir -p $BACKUP_DIR

tar -czf $BACKUP_DIR/benchmarks-$(date +%Y%m%d).tar.gz \
  $TOOLKIT_DIR/customers/*/benchmarks/

# Eliminar backups antiguos (> 90 días)
find $BACKUP_DIR -name "benchmarks-*.tar.gz" -mtime +90 -delete

echo "Backup completado: benchmarks-$(date +%Y%m%d).tar.gz"
EOF

chmod +x backup_benchmarks.sh

# Añadir a cron (diario a las 4 AM)
# 0 4 * * * /path/to/backup_benchmarks.sh
```

### Notificaciones por Email

```bash
# Instalar mailutils
sudo apt-get install -y mailutils

# Script de notificación
cat > notify_completion.sh << 'EOF'
#!/bin/bash

CLIENT=$1
BENCHMARK_DIR=$2

SUBJECT="Benchmark Completado - $CLIENT"
BODY="El benchmark de $CLIENT ha finalizado.

Directorio: $BENCHMARK_DIR

Genera informes con:
./tools/utils/generate_reports.sh $CLIENT <fecha>
"

echo "$BODY" | mail -s "$SUBJECT" admin@empresa.com
EOF

chmod +x notify_completion.sh
```

## 💡 Mejores Prácticas

### Duración Óptima del Benchmark

| Escenario | Duración Recomendada |
|-----------|---------------------|
| **Test rápido** | 30-60 minutos |
| **Análisis básico** | 6-12 horas |
| **Producción** | 24 horas |
| **Completo** | 7 días (incluye fin de semana) |

### Intervalo de Muestreo

| Detalle | Intervalo | Tamaño JSON (24h) |
|---------|-----------|-------------------|
| **Alto** | 30 segundos | ~200 MB |
| **Medio** | 60 segundos | ~100 MB |
| **Estándar** | 120 segundos | ~50 MB |
| **Bajo** | 300 segundos | ~20 MB |

**Recomendación**: 120 segundos (balance perfecto)

### Cuándo Ejecutar Benchmarks

✅ **Mejor momento:**
- Semana normal (no festivos, no cierres de mes)
- Incluir horario laboral completo
- Incluir procesos batch nocturnos
- Incluir picos de carga conocidos

❌ **Evitar:**
- Ventanas de mantenimiento
- Períodos de baja actividad (vacaciones)
- Durante migraciones o cambios mayores
- Inmediatamente después de reboot

### Organización de Clientes

```bash
# Estructura recomendada
customers/
├── cliente-a/
│   ├── benchmarks/
│   │   ├── 2025-01-baseline/          # Benchmark inicial
│   │   ├── 2025-02-optimization/      # Post-optimización
│   │   └── 2025-03-peak-month/        # Mes de alta carga
│   └── docs/
│       ├── decisions.md               # ADRs
│       └── meetings/
├── cliente-b/
└── cliente-c/
```

### Seguridad y Credenciales

✅ **Hacer:**
- Usar Windows Authentication siempre que sea posible
- Almacenar passwords en Azure Key Vault
- Rotar credenciales cada 90 días
- Usar cuentas de servicio dedicadas con permisos mínimos
- Nunca commitear `client-config.env` a git

❌ **No hacer:**
- Hardcodear passwords en scripts
- Usar cuenta `sa` para benchmarks
- Compartir credenciales de forma insegura
- Dejar passwords en logs

## 📞 Soporte y Recursos

- **[QUICKSTART.md](QUICKSTART.md)** - Inicio rápido
- **[SETUP.md](SETUP.md)** - Instalación
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Problemas comunes
- **[COPILOT_AGENT.md](COPILOT_AGENT.md)** - Uso del agente IA
- **[README.md](../README.md)** - Documentación principal

## 🤝 Contribuir

¿Tienes un caso de uso interesante? Comparte en:
- GitHub Discussions
- Crea un Issue con etiqueta "enhancement"
- Envía un Pull Request con tu script

---

**Última actualización**: 2025-11-26  
**Versión**: 2.0.0
