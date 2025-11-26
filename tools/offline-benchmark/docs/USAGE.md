# Usage Guide - Offline Benchmark Tool

Guía completa de uso del SQL Server Workload Monitor - Offline Edition.

---

## Escenarios de Uso

### 1. Quick Test (15 minutos)

Validación rápida antes de monitorización completa:

```bash
python scripts/monitor_sql_workload.py --server . --duration 15 --interval 60
```

### 2. Monitorización Producción (24 horas)

```bash
python scripts/monitor_sql_workload.py --server . --duration 1440 --interval 120 --output output/prod_24h.json
```

### 3. Background Monitoring (nohup)

```bash
nohup python scripts/monitor_sql_workload.py --duration 2880 --interval 120 > logs/monitor.log 2>&1 &

# Ver proceso
ps aux | grep monitor_sql_workload

# Monitorizar status
python scripts/check_monitoring_status.py --watch sql_workload_monitor_checkpoint.json
```

### 4. Resume desde checkpoint

```bash
python scripts/monitor_sql_workload.py --resume-from checkpoints/checkpoint_20251126_120000.json
```

### 5. Generar workload sintético

```bash
# Terminal 1: Workload
python scripts/Generate-SQLWorkload.py --intensity medium --duration 60

# Terminal 2: Monitor
python scripts/monitor_sql_workload.py --duration 60 --interval 30
```

---

## Comandos Detallados

### monitor_sql_workload.py

```bash
python scripts/monitor_sql_workload.py \
  --server .                                    # SQL Server instance
  --database master                             # Database (default: master)
  --username sa                                 # SQL user (optional)
  --password P@ssw0rd                           # SQL password (optional)
  --duration 1440                               # Minutos (1440 = 24h)
  --interval 120                                # Segundos entre muestras
  --output output/results.json                  # Archivo salida
  --query-file workload-sample-query.sql        # Query SQL externa
  --checkpoint-interval 60                      # Checkpoint cada 60 min
  --resume-from checkpoints/checkpoint.json     # Resumir
```

### check_monitoring_status.py

```bash
# Check único
python scripts/check_monitoring_status.py checkpoint.json

# Watch mode (refresco cada 30s)
python scripts/check_monitoring_status.py --watch checkpoint.json

# Watch con intervalo custom
python scripts/check_monitoring_status.py --watch --interval 60 checkpoint.json
```

### diagnose_monitoring.py

```bash
# Windows Authentication
python scripts/diagnose_monitoring.py --server .

# SQL Authentication
python scripts/diagnose_monitoring.py --server MYSERVER\SQL2022 --username sa --password P@ssw0rd

# Query file custom
python scripts/diagnose_monitoring.py --server . --query-file custom-query.sql
```

### Generate-SQLWorkload.py

```bash
# Light (60 queries/min)
python scripts/Generate-SQLWorkload.py --server . --intensity light --duration 30

# Medium (120 queries/min)
python scripts/Generate-SQLWorkload.py --server . --intensity medium --duration 60

# High (240 queries/min)
python scripts/Generate-SQLWorkload.py --server . --intensity high --duration 120 --threads 8

# Con picos
python scripts/Generate-SQLWorkload.py --server . --intensity medium --pattern peaks --duration 60
```

---

## Análisis de Resultados

### Inspeccionar JSON con jq

```bash
# Metadata
jq '.metadata' output/results.json

# Primera muestra
jq '.samples[0]' output/results.json

# CPU promedio
jq '[.samples[].cpu.sql_server_cpu_time_ms] | add / length' output/results.json

# Memoria promedio
jq '[.samples[].memory.buffer_pool_mb] | add / length' output/results.json

# Top 5 muestras por CPU
jq '.samples | sort_by(.cpu.sql_server_cpu_time_ms) | reverse | .[0:5]' output/results.json
```

### Exportar a CSV

```bash
# Script Python para conversión
python3 << 'EOF'
import json
import csv

with open('output/results.json') as f:
    data = json.load(f)

with open('output/results.csv', 'w', newline='') as csvfile:
    fieldnames = ['timestamp', 'cpu_pct', 'memory_mb', 'connections', 'batch_req_sec']
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()
    
    for sample in data['samples']:
        cpu_pct = (sample['cpu']['sql_server_cpu_time_ms'] / (sample['cpu']['total_cpus'] * 1000)) * 100
        writer.writerow({
            'timestamp': sample['timestamp'],
            'cpu_pct': round(cpu_pct, 2),
            'memory_mb': sample['memory']['buffer_pool_mb'],
            'connections': sample['activity']['user_connections'],
            'batch_req_sec': sample['activity']['batch_requests_per_sec']
        })
EOF
```

---

Ver [TROUBLESHOOTING.md](TROUBLESHOOTING.md) para solución de problemas.
