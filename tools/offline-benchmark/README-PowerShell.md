# Offline Benchmark Tool - PowerShell Edition

## 🎯 Quick Start (Windows SQL Server)

**Para servidores Windows SQL Server SIN Python instalado:**

```powershell
# 1. Descargar toolkit en el servidor SQL
Invoke-WebRequest -Uri "https://github.com/Alejandrolmeida/azure-sql-benchmark-toolkit/releases/latest/download/offline-benchmark.zip" -OutFile "offline-benchmark.zip"
Expand-Archive -Path offline-benchmark.zip -DestinationPath C:\SQLBenchmark

# 2. Navegar a la carpeta
cd C:\SQLBenchmark\offline-benchmark

# 3. Ejecutar instalador
.\INSTALL.ps1

# 4. Ejecutar monitor (ejemplo: 15 minutos, cada 60 segundos)
.\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -Interval 60

# 5. Transferir resultado a máquina Linux con toolkit completo
# Archivo generado: sql_workload_monitor.json
```

## 🔥 Versiones Disponibles

Este toolkit ofrece **DOS versiones** del offline benchmark:

### 1️⃣ PowerShell Edition (RECOMENDADO para Windows)

✅ **Ventajas:**
- ✅ **Sin dependencias externas** (solo PowerShell 5.1+, ya incluido en Windows Server)
- ✅ **Instalación en 30 segundos** (solo instalar módulo SqlServer si no está)
- ✅ **Nativo Windows** (no requiere WSL, Python, ni Bash)
- ✅ **Basado en código 100% probado** (SQLMonitoring_OnPremises_v2)
- ✅ **Compatible SQL Server 2012-2025**

**Ubicación:**
```
tools/offline-benchmark/
├── INSTALL.ps1                          # Instalador PowerShell
├── scripts/
│   ├── Monitor-SQLWorkload.ps1          # Monitor principal
│   ├── Check-MonitoringStatus.ps1       # Verificar estado
│   ├── Test-Diagnostics.ps1             # Diagnósticos
│   ├── Generate-SQLWorkload.ps1         # Generador carga sintética
│   └── workload-sample-query.sql        # Query optimizada (< 1 seg)
└── docs/
    ├── README-PowerShell.md             # Esta guía
    ├── INSTALLATION-PowerShell.md       # Instalación detallada
    └── USAGE-PowerShell.md              # Ejemplos de uso
```

### 2️⃣ Python Edition (para Linux o usuarios Python)

⚠️ **Requiere:**
- Python 3.8+
- pyodbc
- ODBC Driver 17 for SQL Server
- Bash (scripts auxiliares)

**Ubicación:** `tools/offline-benchmark/scripts/monitor_sql_workload.py`

**Documentación:** [README-Python.md](docs/README-Python.md)

---

## 📋 Requisitos (PowerShell Edition)

### Windows Server / Desktop
- **OS:** Windows Server 2012 R2+ / Windows 8.1+
- **PowerShell:** 5.1+ (incluido) o PowerShell 7+ (opcional)
- **Módulo:** SqlServer (se instala automáticamente)
- **Red:** Acceso local o remoto a instancia SQL Server

### SQL Server
- **Versión:** SQL Server 2012 SP4 - 2025
- **Edición:** Express, Standard, Enterprise, Developer
- **Permisos:** `VIEW SERVER STATE` o `sysadmin`
- **Protocolo:** TCP/IP habilitado (para conexiones remotas)

### Disk Space
- **Mínimo:** 100 MB libres
- **Recomendado:** 1 GB+ (para monitoreos largos)

**Estimación tamaño JSON:**
- 1 sample ≈ 2 KB
- 24h @ 2min interval = 720 samples ≈ 1.5 MB

---

## 🚀 Instalación Detallada

### Paso 1: Descargar Toolkit

**Opción A: Desde GitHub Release**
```powershell
# Descargar última versión
$url = "https://github.com/Alejandrolmeida/azure-sql-benchmark-toolkit/releases/latest/download/offline-benchmark.zip"
Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\offline-benchmark.zip"

# Extraer
Expand-Archive -Path "$env:TEMP\offline-benchmark.zip" -DestinationPath "C:\SQLBenchmark" -Force

cd C:\SQLBenchmark\offline-benchmark
```

**Opción B: Clonar repositorio**
```powershell
git clone https://github.com/Alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit\tools\offline-benchmark
```

### Paso 2: Ejecutar Instalador

```powershell
# Instalación básica (instancia local)
.\INSTALL.ps1

# Instalación con instancia remota
.\INSTALL.ps1 -ServerInstance "SERVIDOR\INSTANCIA"

# Instalación con SQL Authentication
.\INSTALL.ps1 -ServerInstance "." -Username "sa" -Password "Tu_Password"
```

**¿Qué hace el instalador?**

El instalador realiza **8 checks automáticos**:

1. ✅ **PowerShell Version**: Verifica PS 5.1+ o PS 7+
2. ✅ **SqlServer Module**: Instala módulo si no existe
3. ✅ **SQL Connectivity**: Prueba conexión a SQL Server
4. ✅ **Permissions**: Valida `VIEW SERVER STATE`
5. ✅ **Query File**: Verifica `workload-sample-query.sql`
6. ✅ **Query Execution**: Test de ejecución < 1 segundo
7. ✅ **Disk Space**: Verifica espacio disponible
8. ✅ **Monitor Script**: Valida `Monitor-SQLWorkload.ps1`

**Salida de ejemplo:**
```
====================================================================
  INSTALADOR - SQL SERVER WORKLOAD MONITOR (POWERSHELL)
  Azure SQL Benchmark Toolkit v2.1.0
====================================================================

======================================================================
 CHECK: PowerShell Version
======================================================================
[2024-01-15 10:30:00] [INFO] PowerShell Version: 5.1.19041.4046
[2024-01-15 10:30:00] [OK] PowerShell 5.1 detected (compatible)

======================================================================
 CHECK: SqlServer Module
======================================================================
[2024-01-15 10:30:02] [OK] SqlServer module found: v22.2.0
[2024-01-15 10:30:03] [OK] Module imported successfully

======================================================================
 CHECK: SQL Server Connectivity
======================================================================
[2024-01-15 10:30:04] [INFO] Target: .
[2024-01-15 10:30:05] [OK] Connection successful!

  Server Name:      SERVIDOR\SQLEXPRESS
  Product Version:  16.0.1000.6
  Product Level:    RTM
  Edition:          Express Edition (64-bit)

... (6 checks more)

======================================================================
 INSTALLATION SUMMARY
======================================================================

  Total Checks:    8
  Passed:          8
  Failed:          0
  Warnings:        0

✓ INSTALLATION SUCCESSFUL

Next steps:
  1. Run monitor:
     .\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -Interval 60
```

---

## 📊 Uso

### Monitor Principal

**Sintaxis básica:**
```powershell
.\scripts\Monitor-SQLWorkload.ps1 [parámetros]
```

**Parámetros:**

| Parámetro | Tipo | Default | Descripción |
|-----------|------|---------|-------------|
| `-ServerInstance` | string | `.` | Instancia SQL (`.` = local) |
| `-Duration` | int | `1440` | Duración en minutos (1440 = 24h) |
| `-Interval` | int | `120` | Intervalo muestras (seg) |
| `-OutputFile` | string | `sql_workload_monitor.json` | Archivo salida |
| `-Username` | string | - | Usuario SQL Auth |
| `-Password` | string | - | Password SQL Auth |

**Ejemplos:**

```powershell
# 1. Monitor básico: 15 minutos, cada 60 segundos
.\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -Interval 60

# 2. Monitor 24 horas, cada 2 minutos (para migración)
.\scripts\Monitor-SQLWorkload.ps1 -Duration 1440 -Interval 120

# 3. Monitor instancia remota
.\scripts\Monitor-SQLWorkload.ps1 -ServerInstance "SERVIDOR\SQL2022" -Duration 30 -Interval 60

# 4. Monitor con SQL Authentication
.\scripts\Monitor-SQLWorkload.ps1 -ServerInstance "." -Username "sa" -Password "P@ssw0rd" -Duration 60

# 5. Monitor custom output
.\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -OutputFile "benchmark_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
```

**Salida durante ejecución:**
```
====================================================================
  SQL SERVER WORKLOAD MONITOR - POWERSHELL EDITION v2.1.0
  Azure SQL Benchmark Toolkit
====================================================================

Configuration:
  Server:           .
  Duration:         15 minutes (0.3 hours)
  Sample Interval:  60 seconds
  Total Samples:    15
  Checkpoint Every: 60 minutes
  Output File:      sql_workload_monitor.json

[2024-01-15 11:00:00] [OK] Loaded query from: C:\SQLBenchmark\workload-sample-query.sql
[2024-01-15 11:00:01] [OK] Connected to: SERVIDOR\SQLEXPRESS
[2024-01-15 11:00:02] [OK] User has VIEW SERVER STATE permission
[2024-01-15 11:00:03] [OK] Query executed successfully

Timeline:
  Start:     2024-01-15 11:00:03
  Estimated: 2024-01-15 11:15:03

[2024-01-15 11:00:03] [OK] Starting monitoring...

[11:00:04] Sample #1/15 (6.7%) | Elapsed: 00:00:01 | Remaining: 00:14:59
[11:01:05] Sample #2/15 (13.3%) | Elapsed: 00:01:02 | Remaining: 00:13:58
[11:02:06] Sample #3/15 (20.0%) | Elapsed: 00:02:03 | Remaining: 00:12:57
...
[11:15:03] Sample #15/15 (100.0%) | Elapsed: 00:15:00 | Remaining: 00:00:00

[2024-01-15 11:15:03] [OK] Monitoring completed successfully
[2024-01-15 11:15:03] [INFO] Total samples collected: 15
[2024-01-15 11:15:03] [INFO] Total errors: 0
[2024-01-15 11:15:04] [OK] Results saved to: sql_workload_monitor.json
```

### Recuperación ante Interrupciones (Checkpoint Recovery)

Si el monitor se interrumpe (Ctrl+C, cierre sesión, reinicio), **automáticamente guarda un checkpoint** cada 60 minutos.

**Archivo checkpoint:** `sql_workload_monitor_checkpoint.json`

**Para resumir:**
```powershell
# Simplemente vuelve a ejecutar el mismo comando
.\scripts\Monitor-SQLWorkload.ps1 -Duration 1440 -Interval 120

# El script detecta el checkpoint y resume automáticamente
```

**Salida con checkpoint:**
```
[2024-01-15 12:30:15] [OK] Loaded checkpoint: sql_workload_monitor_checkpoint.json
[2024-01-15 12:30:15] [INFO] Resuming from 30 samples
```

---

## 🔍 Scripts Auxiliares

### 1. Check-MonitoringStatus.ps1

Verifica el estado de una monitorización en curso.

```powershell
# Verificar estado
.\scripts\Check-MonitoringStatus.ps1 -OutputFile sql_workload_monitor.json

# Watch mode (actualización cada 10 segundos)
.\scripts\Check-MonitoringStatus.ps1 -OutputFile sql_workload_monitor.json -Watch
```

**Salida:**
```
====================================================================
  MONITORING STATUS CHECK
  File: sql_workload_monitor.json
====================================================================

[2024-01-15 12:45:00] [OK] File found: sql_workload_monitor.json

JSON Structure:
  Version:         2.1.0
  Server:          SERVIDOR\SQLEXPRESS
  Duration:        1440 minutes
  Interval:        120 seconds
  Start Time:      2024-01-15 11:00:00
  Samples:         30 / 720 (4.2%)

Progress:
  Elapsed:         01:00:00
  Remaining:       23:00:00 (estimated)
  Completion:      ~2024-01-16 11:00:00

Health:
  Errors:          0
  Status:          ✓ HEALTHY
```

### 2. Test-Diagnostics.ps1

Ejecuta diagnósticos completos del sistema y SQL Server.

```powershell
# Diagnóstico completo
.\scripts\Test-Diagnostics.ps1 -ServerInstance "."

# Con SQL Authentication
.\scripts\Test-Diagnostics.ps1 -ServerInstance "." -Username "sa" -Password "P@ssw0rd"
```

**Checks realizados:**
1. PowerShell version
2. SqlServer module
3. SQL Server connectivity
4. SQL Server permissions
5. DMV access test (sys.dm_os_sys_info, sys.dm_os_performance_counters)

### 3. Generate-SQLWorkload.ps1

Genera carga sintética para pruebas.

```powershell
# Carga ligera: 10 minutos, 10 queries/seg
.\scripts\Generate-SQLWorkload.ps1 -Duration 10 -QueriesPerSecond 10

# Carga media: 30 minutos, 50 queries/seg
.\scripts\Generate-SQLWorkload.ps1 -Duration 30 -QueriesPerSecond 50

# Carga pesada: 60 minutos, 100 queries/seg
.\scripts\Generate-SQLWorkload.ps1 -Duration 60 -QueriesPerSecond 100 -Complexity High
```

**Ejemplo combinado (monitor + workload):**
```powershell
# Terminal 1: Generar carga
.\scripts\Generate-SQLWorkload.ps1 -Duration 30 -QueriesPerSecond 50

# Terminal 2: Monitorizar
.\scripts\Monitor-SQLWorkload.ps1 -Duration 30 -Interval 60
```

---

## 📦 Formato JSON Generado

El archivo JSON sigue el **formato v2.1** compatible con el toolkit principal:

```json
{
  "metadata": {
    "version": "2.1.0",
    "server": "SERVIDOR\\SQLEXPRESS",
    "database": "master",
    "start_time": "2024-01-15T11:00:00",
    "end_time": "2024-01-15T11:15:00",
    "duration_minutes": 15,
    "interval_seconds": 60,
    "total_samples": 15,
    "errors_count": 0
  },
  "samples": [
    {
      "timestamp": "2024-01-15T11:00:04",
      "cpu": {
        "total_cpus": 8,
        "sql_server_cpu_time_ms": 123456
      },
      "memory": {
        "total_mb": 16384,
        "committed_mb": 8192,
        "target_mb": 8192,
        "buffer_pool_mb": 6144
      },
      "activity": {
        "batch_requests_per_sec": 125.5,
        "compilations_per_sec": 3.2,
        "user_connections": 15
      },
      "io": {
        "total_reads": 1234567,
        "total_writes": 987654,
        "total_read_latency_ms": 45678,
        "total_write_latency_ms": 23456,
        "total_bytes_read": 12345678901,
        "total_bytes_written": 9876543210
      },
      "waits": {
        "top_wait_type": "CXPACKET",
        "top_wait_time_ms": 12345
      }
    }
  ]
}
```

**18 métricas por muestra:**
- **CPU:** Total CPUs, SQL Server CPU time
- **Memory:** Total, Committed, Target, Buffer Pool
- **Activity:** Batch Requests/sec, Compilations/sec, User Connections
- **I/O:** Reads, Writes, Latencies, Bytes Read/Written
- **Waits:** Top Wait Type, Wait Time

---

## 🔄 Importar Datos al Toolkit Principal

Una vez generado el JSON en el servidor SQL Server, **transfiérelo a la máquina Linux** con el toolkit completo:

```bash
# En máquina Linux con toolkit completo

# 1. Copiar JSON desde Windows (ejemplo: scp, sftp, pendrive, etc.)
scp usuario@servidor-sql:C:\SQLBenchmark\sql_workload_monitor.json ./

# 2. Importar con script dedicado
./tools/utils/import_offline_benchmark.sh sql_workload_monitor.json

# 3. Generar reportes
./tools/utils/generate_reports.sh <customer-id>
```

**El script `import_offline_benchmark.sh` automáticamente:**
- ✅ Valida JSON formato v2.1
- ✅ Crea cliente si no existe
- ✅ Genera benchmark_id único
- ✅ Guarda en `customers/<customer-id>/benchmarks/<benchmark-id>/`
- ✅ Calcula estadísticas agregadas
- ✅ Prepara datos para reportes

---

## 🛠️ Troubleshooting

### Error: "Module SqlServer not found"

```powershell
# Instalar manualmente
Install-Module -Name SqlServer -Scope CurrentUser -Force
```

### Error: "Login failed for user"

```powershell
# Opción 1: Usar Windows Authentication (sin -Username/-Password)
.\scripts\Monitor-SQLWorkload.ps1

# Opción 2: Verificar credenciales SQL Authentication
.\scripts\Monitor-SQLWorkload.ps1 -Username "sa" -Password "CorrectPassword"
```

### Error: "The user does not have permission to perform this action"

```sql
-- Desde SSMS como sysadmin:
GRANT VIEW SERVER STATE TO [DOMINIO\Usuario]
-- O
ALTER SERVER ROLE sysadmin ADD MEMBER [DOMINIO\Usuario]
```

### Error: "A network-related or instance-specific error occurred"

```powershell
# 1. Verificar SQL Server corriendo
Get-Service | Where-Object {$_.Name -like "*SQL*"}

# 2. Verificar firewall (puerto 1433)
Test-NetConnection -ComputerName localhost -Port 1433

# 3. Verificar protocolo TCP/IP habilitado
# SQL Server Configuration Manager > SQL Server Network Configuration > Protocols for [INSTANCE]
# Habilitar TCP/IP y reiniciar servicio
```

### Error: "Execution time > 2 seconds"

**Causa:** Query lenta (posible contención en DMVs)

**Soluciones:**
1. Ejecutar en horario de baja carga
2. Verificar estado general SQL Server: `sp_who2`, `sp_BlitzFirst`
3. Aumentar timeout en query: `-QueryTimeout 60`

### Monitor interrumpido, ¿cómo resumir?

```powershell
# Simplemente vuelve a ejecutar el mismo comando
.\scripts\Monitor-SQLWorkload.ps1 -Duration 1440 -Interval 120

# El checkpoint (_checkpoint.json) se carga automáticamente
```

---

## 📚 Documentación Adicional

- **[INSTALLATION-PowerShell.md](INSTALLATION-PowerShell.md)**: Guía detallada instalación Windows
- **[USAGE-PowerShell.md](USAGE-PowerShell.md)**: Ejemplos avanzados y casos de uso
- **[workload-sample-query.sql](../scripts/workload-sample-query.sql)**: Query SQL documentada

---

## 🔗 Integración con Toolkit Principal

### Arquitectura Multi-Plataforma

```
┌─────────────────────────────────────────────────────────────┐
│                 WINDOWS SQL SERVER                          │
│                                                             │
│  ┌───────────────────────────────────────────────┐          │
│  │ PowerShell Offline Monitor                    │          │
│  │ ✓ Sin Python                                  │          │
│  │ ✓ Solo PowerShell 5.1+ (nativo Windows)      │          │
│  │ ✓ Módulo SqlServer                            │          │
│  └───────────────────────────────────────────────┘          │
│                        │                                     │
│                        │ sql_workload_monitor.json           │
│                        ▼                                     │
└────────────────────────┼─────────────────────────────────────┘
                         │
                         │ Transfer (scp/sftp/pendrive)
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              LINUX MANAGEMENT SERVER                        │
│                                                             │
│  ┌───────────────────────────────────────────────┐          │
│  │ Azure SQL Benchmark Toolkit (completo)        │          │
│  │                                               │          │
│  │  tools/utils/import_offline_benchmark.sh     │          │
│  │  ├─ Validate JSON v2.1                       │          │
│  │  ├─ Create customer/benchmark dirs           │          │
│  │  ├─ Calculate aggregated stats               │          │
│  │  └─ Prepare for reports                      │          │
│  │                                               │          │
│  │  tools/analysis/ (Python analyzers)          │          │
│  │  templates/ (HTML reports)                   │          │
│  │  scripts/report-generation/                  │          │
│  └───────────────────────────────────────────────┘          │
│                        │                                     │
│                        ▼                                     │
│  ┌───────────────────────────────────────────────┐          │
│  │ Reports:                                      │          │
│  │ • Benchmark Performance Report (HTML)         │          │
│  │ • Cost Analysis Report (HTML)                 │          │
│  │ • Migration Operations Guide (HTML)           │          │
│  └───────────────────────────────────────────────┘          │
└─────────────────────────────────────────────────────────────┘
```

### Workflow Completo

```powershell
# 1. En servidor Windows SQL (offline, sin Python)
cd C:\SQLBenchmark\offline-benchmark
.\INSTALL.ps1
.\scripts\Monitor-SQLWorkload.ps1 -Duration 1440 -Interval 120

# 2. Transferir JSON a Linux
# (scp, sftp, pendrive, email attachment, etc.)

# 3. En servidor Linux (toolkit completo)
./tools/utils/import_offline_benchmark.sh sql_workload_monitor.json

# 4. Generar reportes
./tools/utils/generate_reports.sh customer-xyz

# 5. Ver reportes
firefox customers/customer-xyz/reports/benchmark-performance-report.html
```

---

## 🆚 Comparación: PowerShell vs Python

| Feature | PowerShell Edition | Python Edition |
|---------|-------------------|----------------|
| **OS Nativo** | ✅ Windows (PS 5.1+ incluido) | ❌ Linux / Requiere Python en Windows |
| **Instalación** | ⚡ 30 segundos (módulo SqlServer) | ⏱️ 5-10 minutos (Python + deps) |
| **Dependencias** | Módulo SqlServer (auto-install) | Python 3.8+, pyodbc, ODBC Driver 17 |
| **Tamaño Instalación** | ~50 MB (módulo SqlServer) | ~200 MB (Python + packages) |
| **Complejidad** | 🟢 Baja (1 comando install) | 🟡 Media (gestión entorno Python) |
| **Checkpoint Recovery** | ✅ Sí | ✅ Sí |
| **Formato JSON** | v2.1 (compatible) | v2.1 (compatible) |
| **Performance Query** | < 1 segundo | < 1 segundo |
| **Background Execution** | ✅ Task Scheduler | ❌ Requiere terminal activo |
| **Basado en Código Funcional** | ✅ SQLMonitoring_OnPremises_v2 (100%) | ⚠️ Implementación nueva |
| **Recomendado para** | 🎯 **Windows SQL Servers** | Linux boxes con Python |

**Conclusión:** Para servidores **Windows SQL Server** (el caso más común), **PowerShell Edition es la mejor opción** por:
- Sin instalación compleja
- Sin dependencias externas
- Nativo Windows
- Basado en código 100% probado

---

## 📞 Soporte

**Issues:** https://github.com/Alejandrolmeida/azure-sql-benchmark-toolkit/issues

**Documentación completa:** [README principal](../../README.md)

---

**Versión:** 2.1.0  
**Última actualización:** 2024-01-15  
**Autor:** Alejandro Almeida
