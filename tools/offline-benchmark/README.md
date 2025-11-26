# SQL Server Workload Monitor - Offline Edition

**Versión 2.1.0** | Azure SQL Benchmark Toolkit

Herramienta standalone para monitorización de SQL Server en sistemas **sin conexión remota**. Recolecta métricas detalladas de performance durante 24-48 horas y exporta resultados compatibles con el toolkit principal.

---

## 📋 Características

- ✅ **100% Offline**: Funciona en servidores sin conexión remota
- ✅ **Query Externa**: SQL query en archivo separado para testing en SSMS
- ✅ **Checkpoint Recovery**: Recuperación automática ante interrupciones
- ✅ **Formato Compatible**: JSON exportable al toolkit principal
- ✅ **Logging Mejorado**: Tags [DEBUG], [OK], [FAIL] para troubleshooting
- ✅ **Timeout Protection**: Previene hangs con timeout de 30 segundos
- ✅ **Herramientas Completas**: Status checker, diagnóstico, generador de carga
- ✅ **Multi-plataforma**: Python 3.8+ (Linux/Windows compatible)

---

## 🚀 Quick Start

### ⭐ Para Servidores Windows SQL Server (RECOMENDADO)

**La mayoría de servidores SQL Server son Windows sin Python instalado.** Usa la **PowerShell Edition** (sin dependencias externas):

```powershell
# 1. Descargar y extraer en servidor SQL
cd C:\SQLBenchmark\offline-benchmark

# 2. Ejecutar instalador PowerShell (30 segundos)
.\INSTALL.ps1

# 3. Test rápido (15 minutos)
.\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -Interval 60

# 4. Transferir JSON a máquina Linux con toolkit completo
# Archivo generado: sql_workload_monitor.json
```

**📚 Documentación completa:** [README-PowerShell.md](README-PowerShell.md)

---

### 🐍 Para Servidores Linux con Python

Si tu SQL Server corre en Linux o tienes Python 3.8+ instalado:

```bash
# 1. Navegar al directorio offline-benchmark
cd tools/offline-benchmark

# 2. Ejecutar instalador (valida dependencias, conectividad, permisos)
python3 INSTALL.py

# 3. Test rápido (15 minutos)
python3 scripts/monitor_sql_workload.py --server localhost --duration 15 --interval 60

# 4. Monitorización producción (24 horas)
python3 scripts/monitor_sql_workload.py --server localhost --duration 1440 --interval 120
```

**Con SQL Authentication:**
```bash
python3 INSTALL.py --server MYSERVER --username sa --password YourPassword
```

---

## 📦 Contenido del Package

```
tools/offline-benchmark/
├── INSTALL.py                          # Instalador automatizado
├── README.md                           # Esta documentación
├── scripts/
│   ├── monitor_sql_workload.py         # Monitor principal
│   ├── workload-sample-query.sql       # Query SQL externa
│   ├── check_monitoring_status.py      # Checker de status
│   ├── diagnose_monitoring.py          # Herramienta diagnóstico
│   └── Generate-SQLWorkload.py         # Generador de carga sintética
├── samples/
│   └── (archivos de ejemplo)
├── docs/
│   ├── INSTALLATION.md                 # Instalación detallada
│   ├── USAGE.md                        # Guía de uso avanzado
│   ├── TROUBLESHOOTING.md              # Solución de problemas
│   └── INTEGRATION.md                  # Integración con toolkit
├── output/                             # Resultados JSON
├── checkpoints/                        # Checkpoints de recuperación
└── logs/                               # Logs de ejecución
```

---

## 📊 Uso Detallado

### Monitor Principal

**Opciones básicas:**
```bash
python scripts/monitor_sql_workload.py \
  --server .                    # SQL Server instance (. = localhost)
  --duration 1440               # Duración en minutos (1440 = 24 horas)
  --interval 120                # Intervalo entre muestras en segundos
  --output output/results.json  # Archivo JSON de salida
```

**SQL Authentication:**
```bash
python scripts/monitor_sql_workload.py \
  --server MYSERVER\SQL2022 \
  --username sa \
  --password YourPassword \
  --duration 1440
```

**Resumir desde checkpoint:**
```bash
python scripts/monitor_sql_workload.py \
  --resume-from checkpoints/checkpoint_20251126_120000.json
```

### Status Checker

**Check único:**
```bash
python scripts/check_monitoring_status.py sql_workload_monitor_checkpoint.json
```

**Watch mode (refresco continuo):**
```bash
python scripts/check_monitoring_status.py --watch checkpoint.json
```

Muestra:
- Timeline (inicio, último checkpoint, tiempo transcurrido)
- Estadísticas de muestras (total, errores, success rate)
- Últimas 5 muestras
- Métricas promedio (CPU, memoria, conexiones, I/O)
- Valores pico (peak CPU, memory, connections)

### Diagnóstico

```bash
python scripts/diagnose_monitoring.py --server .
```

Verifica:
1. ✅ ODBC drivers instalados
2. ✅ Conectividad a SQL Server
3. ✅ Permisos (VIEW SERVER STATE)
4. ✅ Archivo query SQL existe
5. ✅ Query ejecuta correctamente (< 2 segundos)

### Generador de Workload

**Carga ligera (testing):**
```bash
python scripts/Generate-SQLWorkload.py --server . --intensity light --duration 30
```

**Carga media con picos:**
```bash
python scripts/Generate-SQLWorkload.py \
  --server . \
  --intensity medium \
  --duration 60 \
  --pattern peaks
```

**Carga alta continua:**
```bash
python scripts/Generate-SQLWorkload.py \
  --server . \
  --intensity high \
  --duration 120 \
  --threads 8
```

Intensidades:
- **light**: 60 queries/min (1 query/segundo)
- **medium**: 120 queries/min (2 queries/segundo)
- **high**: 240 queries/min (4 queries/segundo)

---

## 📈 Métricas Recolectadas

Cada muestra incluye **18 métricas clave**:

### CPU
- `TotalCPUs`: Número total de CPUs lógicas
- `SQLServerCPUTimeMs`: Tiempo CPU usado por SQL Server (ms)

### Memoria
- `TotalMemoryMB`: Memoria total del sistema (MB)
- `CommittedMemoryMB`: Memoria committed por SQL Server (MB)
- `TargetMemoryMB`: Memoria target de SQL Server (MB)
- `BufferPoolMB`: Tamaño del buffer pool (MB)

### Actividad
- `BatchRequestsPerSec`: Batch requests por segundo
- `CompilationsPerSec`: Compilaciones por segundo
- `UserConnections`: Conexiones de usuario activas

### I/O
- `TotalReads`: Total de operaciones de lectura
- `TotalWrites`: Total de operaciones de escritura
- `TotalReadLatencyMs`: Latencia acumulada de lecturas (ms)
- `TotalWriteLatencyMs`: Latencia acumulada de escrituras (ms)
- `TotalBytesRead`: Bytes leídos totales
- `TotalBytesWritten`: Bytes escritos totales

### Wait Stats
- `TopWaitType`: Tipo de wait más frecuente
- `TopWaitTimeMs`: Tiempo acumulado del top wait (ms)

---

## 🔧 Requisitos

### Software
- **Python**: 3.8 o superior
- **pyodbc**: `pip install pyodbc`
- **ODBC Driver 17**: SQL Server Native Client

### Permisos SQL Server
- **VIEW SERVER STATE** permission (mínimo)
- O **sysadmin** role

### SQL Server
- SQL Server 2016 o superior
- SQL Server 2012/2014 (compatible con ajustes menores)

---

## 🛠️ Instalación Detallada

### Linux (Ubuntu/Debian)

```bash
# 1. Instalar Python 3.8+
sudo apt update
sudo apt install python3 python3-pip

# 2. Instalar ODBC Driver 17
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt update
sudo ACCEPT_EULA=Y apt install msodbcsql17 unixodbc-dev

# 3. Instalar pyodbc
pip3 install pyodbc

# 4. Ejecutar instalador
python3 INSTALL.py
```

### Windows

```powershell
# 1. Instalar Python 3.8+ (desde python.org)

# 2. Instalar ODBC Driver 17
# Descargar desde: https://go.microsoft.com/fwlink/?linkid=2249004

# 3. Instalar pyodbc
pip install pyodbc

# 4. Ejecutar instalador
python INSTALL.py
```

---

## 📤 Exportar Resultados al Toolkit Principal

### 1. Copiar JSON al servidor con toolkit

```bash
# Desde servidor offline a tu workstation
scp output/sql_workload_monitor.json user@workstation:/path/to/toolkit/
```

### 2. Importar al toolkit

```bash
cd /path/to/toolkit
./tools/utils/import_offline_benchmark.sh \
  --customer example-client \
  --benchmark-name offline-test-20251126 \
  --json-file sql_workload_monitor.json
```

### 3. Generar reportes

```bash
./tools/utils/generate_reports.sh example-client
```

Los reportes HTML incluirán datos del benchmark offline.

---

## 🐛 Troubleshooting

### Error: "No module named 'pyodbc'"

```bash
pip install pyodbc
```

### Error: "No SQL Server ODBC driver found"

**Linux:**
```bash
sudo ACCEPT_EULA=Y apt install msodbcsql17
```

**Windows:**
Descargar desde: https://docs.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server

### Error: "Login failed for user"

- Verificar username/password
- Verificar SQL Authentication habilitado en SQL Server
- Usar `--username` y `--password` si no es Windows Authentication

### Error: "User lacks VIEW SERVER STATE permission"

```sql
-- Ejecutar en SQL Server con cuenta sysadmin
USE master;
GO
GRANT VIEW SERVER STATE TO [DOMAIN\User];
GO
```

### Error: "Query timeout (> 30 seconds)"

La query está optimizada para ejecutar en < 1 segundo. Si timeout:
- Verificar performance del servidor
- Revisar blocking locks (sp_who2)
- Considerar reducir intervalo de muestras

### Checkpoint no se actualiza

- Verificar que proceso de monitorización esté corriendo
- Revisar logs en terminal
- Verificar permisos de escritura en directorio

---

## 📚 Casos de Uso

### 1. Test Rápido (15 minutos)

Validar conectividad, permisos, y query antes de monitorización completa.

```bash
python scripts/monitor_sql_workload.py --server . --duration 15 --interval 60
```

### 2. Workload Sintético (60 minutos)

Generar carga sintética para simular actividad en servidor de desarrollo.

```bash
# Terminal 1: Generar workload
python scripts/Generate-SQLWorkload.py --intensity medium --duration 60

# Terminal 2: Monitorizar workload
python scripts/monitor_sql_workload.py --duration 60 --interval 30

# Terminal 3: Watch status
python scripts/check_monitoring_status.py --watch checkpoint.json
```

### 3. Producción (48 horas)

Monitorización completa de servidor productivo incluyendo fines de semana.

```bash
# Iniciar monitorización en background (nohup)
nohup python scripts/monitor_sql_workload.py \
  --duration 2880 \
  --interval 120 \
  --output output/prod_48h.json \
  > logs/monitor_48h.log 2>&1 &

# Monitorizar status periodicamente
watch -n 60 'python scripts/check_monitoring_status.py checkpoint.json'
```

### 4. Troubleshooting

Diagnosticar problemas de conectividad o permisos.

```bash
python scripts/diagnose_monitoring.py --server . > diagnostics.txt
```

---

## 🔍 Formato JSON de Salida

```json
{
  "metadata": {
    "version": "2.1.0",
    "server": ".",
    "database": "master",
    "start_time": "2025-01-26T08:00:00",
    "end_time": "2025-01-27T08:00:00",
    "duration_minutes": 1440,
    "interval_seconds": 120,
    "total_samples": 720,
    "errors_count": 0
  },
  "samples": [
    {
      "timestamp": "2025-01-26T08:00:00",
      "cpu": {
        "total_cpus": 8,
        "sql_server_cpu_time_ms": 45000
      },
      "memory": {
        "total_mb": 16384,
        "committed_mb": 8192,
        "target_mb": 12288,
        "buffer_pool_mb": 7890
      },
      "activity": {
        "batch_requests_per_sec": 156.3,
        "compilations_per_sec": 12.5,
        "user_connections": 47
      },
      "io": {
        "total_reads": 1234567,
        "total_writes": 234567,
        "total_read_latency_ms": 45678,
        "total_write_latency_ms": 12345,
        "total_bytes_read": 10485760000,
        "total_bytes_written": 2097152000
      },
      "waits": {
        "top_wait_type": "PAGEIOLATCH_SH",
        "top_wait_time_ms": 123456
      }
    }
  ]
}
```

---

## 📖 Documentación Adicional

- **[INSTALLATION.md](docs/INSTALLATION.md)**: Instalación paso a paso para cada plataforma
- **[USAGE.md](docs/USAGE.md)**: Guía de uso avanzado con ejemplos
- **[TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)**: Solución detallada de problemas comunes
- **[INTEGRATION.md](docs/INTEGRATION.md)**: Integración con toolkit principal
- **[../../docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md)**: Arquitectura del toolkit completo

---

## 🤝 Contribuir

Este proyecto es parte del **Azure SQL Benchmark Toolkit**. Para contribuir:

1. Fork del repositorio principal
2. Crear feature branch (`git checkout -b feature/amazing-feature`)
3. Commit cambios (`git commit -m 'Add amazing feature'`)
4. Push a branch (`git push origin feature/amazing-feature`)
5. Abrir Pull Request

Ver [CONTRIBUTING.md](../../docs/CONTRIBUTING.md) para más detalles.

---

## 📄 Licencia

MIT License - Ver [LICENSE](../../LICENSE) en el repositorio principal.

---

## 🆘 Soporte

- **Issues**: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues
- **Email**: soporte@ejemplo.com
- **Documentación**: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/wiki

---

## 🎯 Roadmap

### v2.2.0 (Q2 2025)
- [ ] PowerShell version equivalente
- [ ] GUI para Windows (Tkinter)
- [ ] Integración con Azure Blob Storage
- [ ] Notificaciones email en completado

### v2.3.0 (Q3 2025)
- [ ] Análisis de trends en el propio tool
- [ ] Detección automática de anomalías
- [ ] Recomendaciones de optimización

---

**Última actualización**: 2025-01-26  
**Versión**: 2.1.0  
**Autor**: Alejandro Almeida
