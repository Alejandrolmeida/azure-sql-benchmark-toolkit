# 🚀 Quick Start Guide

Get started with Azure SQL Benchmark Toolkit in 5 minutes!

## Paso 1: Instalación de Prerrequisitos (5 min)

### Python 3.8+

```bash
# Verificar versión
python3 --version

# Si no tienes Python 3.8+, instalar:
# Ubuntu/Debian
sudo apt-get update && sudo apt-get install -y python3 python3-pip

# macOS
brew install python@3.9

# Windows
# Descargar desde https://www.python.org/downloads/
```

### ODBC Driver para SQL Server

**Ubuntu/Debian:**

```bash
# Añadir repositorio de Microsoft
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Instalar driver
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17
```

**Windows:**
- Descargar desde: https://docs.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server
- Ejecutar instalador MSI

**macOS:**

```bash
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew install msodbcsql17
```

### Dependencias Python

```bash
pip install pyodbc
```

## Paso 2: Clonar el Repositorio (1 min)

```bash
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit
```

## Paso 3: Crear Tu Primer Cliente (2 min)

```bash
# Crear estructura de cliente
./tools/utils/create_client.sh mi-empresa

# Navegar al directorio del cliente
cd customers/mi-empresa
```

Esto crea:
```
mi-empresa/
├── README.md                   # Documentación del cliente
├── QUICKSTART.md              # Guía rápida específica
├── config/
│   ├── client-config.env      # Configuración editable
│   └── servers-inventory.json # Inventario de servidores
├── benchmarks/                # Aquí se guardarán resultados
└── docs/                      # Documentación adicional
```

## Paso 4: Configurar Conexión SQL (3 min)

Edita `config/client-config.env`:

```bash
nano config/client-config.env
```

### Opción A: Windows Authentication (Recomendado)

```bash
SQL_SERVER="mi-servidor.domain.local"
SQL_DATABASE="master"
SQL_USE_TRUSTED_AUTH="true"
SQL_USERNAME=""
SQL_PASSWORD=""
```

### Opción B: SQL Authentication

```bash
SQL_SERVER="192.168.1.100"
SQL_DATABASE="master"
SQL_USE_TRUSTED_AUTH="false"
SQL_USERNAME="sqlmonitor"
SQL_PASSWORD="P@ssw0rd123!"
```

### Configuración de Benchmark

```bash
# Intervalo de muestreo (segundos)
BENCHMARK_INTERVAL="120"  # 2 minutos recomendado

# Duración total (segundos)
BENCHMARK_DURATION="86400"  # 24 horas recomendado

# Para pruebas rápidas:
# BENCHMARK_DURATION="600"  # 10 minutos
```

### Configuración Azure (Opcional)

```bash
AZURE_SUBSCRIPTION="12345678-1234-1234-1234-123456789012"
AZURE_RESOURCE_GROUP="rg-mi-empresa-sql"
AZURE_REGION="westeurope"
AZURE_VM_SIZE="Standard_E16ds_v5"
```

## Paso 5: Ejecutar Benchmark (Variable)

### Test Rápido (10 minutos)

```bash
# Volver al directorio raíz
cd ../..

# Ejecutar benchmark de prueba
./tools/utils/run_benchmark.sh mi-empresa SQLPROD01 --duration 600 --interval 30
```

### Benchmark de Producción (24 horas)

```bash
# Ejecutar benchmark completo
./tools/utils/run_benchmark.sh mi-empresa SQLPROD01

# O con parámetros explícitos
./tools/utils/run_benchmark.sh mi-empresa SQLPROD01 --duration 86400 --interval 120
```

**Salida esperada:**

```
========================================
  Azure SQL Benchmark Toolkit
  Run Benchmark
========================================

ℹ️  Client: mi-empresa
ℹ️  Benchmark: /path/to/customers/mi-empresa/benchmarks/2025-11-25_143530

🔍 SQL SERVER WORKLOAD MONITOR - EXTENDED EDITION
==================================================================
Server: mi-servidor.domain.local
Database: master
Interval: 120s
Duration: 86400s (24.0 hours)
Output: sql_workload_SQLPROD01_20251125_143530.json
==================================================================

📊 Sample #1 at 2025-11-25 14:35:30
  CPU: 45.2%
  RAM: 67.8% | Buffer Pool: 15234 MB
  IOPS: 1247
  TPS: 850
  ⏱️  Waiting 117.3s until next sample...
```

## Paso 6: Generar Informes (1 min)

Una vez completado el benchmark:

```bash
# Generar los 3 informes HTML
./tools/utils/generate_reports.sh mi-empresa 2025-11-25

# O especificar directorio completo con timestamp
./tools/utils/generate_reports.sh mi-empresa 2025-11-25_143530
```

**Salida esperada:**

```
========================================
  Azure SQL Benchmark Toolkit
  Generate Reports
========================================

ℹ️  Client: mi-empresa
ℹ️  Benchmark: /path/to/customers/mi-empresa/benchmarks/2025-11-25_143530
ℹ️  Data file: sql_workload_SQLPROD01_20251125_143530.json
ℹ️  Samples found: 720

✅ Reports generated:
  1. benchmark-performance-report.html
  2. cost-analysis-report.html
  3. migration-operations-guide.html

✅ Summary report created: REPORT_SUMMARY.md
```

## Paso 7: Ver Resultados (< 1 min)

### Opción A: Línea de Comandos

```bash
# Linux/WSL
xdg-open customers/mi-empresa/benchmarks/2025-11-25_143530/benchmark-performance-report.html

# Windows
start customers\mi-empresa\benchmarks\2025-11-25_143530\benchmark-performance-report.html

# macOS
open customers/mi-empresa/benchmarks/2025-11-25_143530/benchmark-performance-report.html
```

### Opción B: Explorador de Archivos

Navega a:
```
customers/mi-empresa/benchmarks/2025-11-25_143530/
```

Abre cualquiera de los 3 informes HTML con tu navegador preferido.

## 📊 Los 3 Informes Generados

### 1. benchmark-performance-report.html
- **Propósito**: Análisis técnico detallado
- **Audiencia**: DBAs, Arquitectos, Ingenieros
- **Contenido**:
  - Gráficos interactivos de CPU, RAM, IOPS
  - Análisis de transacciones y wait statistics
  - Identificación de bottlenecks
  - Recomendación de Azure VM

### 2. cost-analysis-report.html
- **Propósito**: Justificación financiera
- **Audiencia**: CIOs, CFOs, Management
- **Contenido**:
  - TCO on-premises vs Azure (3 años)
  - Desglose de costos mensual
  - ROI y break-even point
  - Estrategias de optimización

### 3. migration-operations-guide.html
- **Propósito**: Plan de ejecución
- **Audiencia**: Project Managers, Equipos de Operaciones
- **Contenido**:
  - Roadmap de migración paso a paso
  - Checklists pre/post migración
  - Procedimientos de cutover y rollback
  - Matriz de riesgos

## 🎯 Próximos Pasos

### 1. Revisar Informes
- Lee los 3 informes completamente
- Toma notas de métricas clave
- Identifica patrones de uso

### 2. Ajustar Configuración Azure
- Edita `config/client-config.env`
- Actualiza sizing si es necesario
- Añade costos on-premises reales

### 3. Compartir con Stakeholders
- Comparte informes HTML (Teams, OneDrive, SharePoint)
- Presenta en reuniones
- Documenta decisiones

### 4. Planificar Migración
- Usa Migration Operations Guide
- Define timeline
- Asigna recursos

### 5. Ejecutar Más Benchmarks
- Diferentes períodos (fin de mes, etc.)
- Otros servidores
- Comparar tendencias

## 🔧 Comandos Útiles

### Listar Clientes

```bash
ls -1 customers/
```

### Ver Benchmarks de un Cliente

```bash
ls -lh customers/mi-empresa/benchmarks/
```

### Ver Último Benchmark

```bash
ls -lt customers/mi-empresa/benchmarks/ | head -2
```

### Eliminar Cliente

```bash
rm -rf customers/mi-empresa
```

### Actualizar Toolkit

```bash
git pull origin main
```

## ❓ Preguntas Frecuentes

### ¿Cuánto espacio en disco necesito?

- **Por benchmark de 24h**: ~50-100 MB (JSON + informes)
- **Recomendado**: 1 GB libre por cliente

### ¿El benchmark afecta al rendimiento de SQL Server?

Impacto mínimo (<1% CPU). Las queries son de lectura y están optimizadas.

### ¿Puedo ejecutar varios benchmarks simultáneamente?

Sí, pero en servidores diferentes. No ejecutes 2 benchmarks en el mismo servidor.

### ¿Qué hago si el benchmark se interrumpe?

Los datos parciales se guardan automáticamente. Genera informes con lo capturado.

### ¿Puedo personalizar los informes HTML?

Sí, edita los templates en `templates/`. Los datos se incrustan desde el JSON.

## 📚 Más Información

- **[SETUP.md](SETUP.md)** - Instalación detallada
- **[USAGE.md](USAGE.md)** - Guía completa de uso
- **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)** - Resolución de problemas
- **[README.md](../README.md)** - Documentación principal

## 🆘 Soporte

¿Problemas? Consulta:
- [Troubleshooting Guide](TROUBLESHOOTING.md)
- [GitHub Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues)
- [GitHub Discussions](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)

---

**¡Feliz benchmarking!** 🚀
