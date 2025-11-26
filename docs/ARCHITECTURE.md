# 🏗️ Architecture - Azure SQL Benchmark Toolkit

Documentación técnica de la arquitectura del toolkit.

## 📋 Tabla de Contenidos

- [Visión General](#visión-general)
- [Componentes del Sistema](#componentes-del-sistema)
- [Flujo de Datos](#flujo-de-datos)
- [Estructura de Directorios](#estructura-de-directorios)
- [Tecnologías Utilizadas](#tecnologías-utilizadas)
- [Decisiones Arquitectónicas](#decisiones-arquitectónicas)
- [Seguridad](#seguridad)
- [Escalabilidad](#escalabilidad)

## 🎯 Visión General

Azure SQL Benchmark Toolkit es una suite modular diseñada con los siguientes principios:

### Principios de Diseño

1. **Simplicidad**: Scripts bash + Python, sin frameworks complejos
2. **Portabilidad**: Compatible con Linux, Windows, macOS
3. **Modularidad**: Componentes independientes y reutilizables
4. **Extensibilidad**: Fácil añadir nuevos tipos de análisis
5. **IA-Powered**: Integración con GitHub Copilot Agent y MCP servers

### Arquitectura High-Level

```
┌─────────────────────────────────────────────────────────────┐
│                    USUARIO / CONSULTOR                       │
└────────────────┬────────────────────────────────────────────┘
                 │
                 │ CLI Commands
                 │
┌────────────────▼────────────────────────────────────────────┐
│                   CAPA DE SCRIPTS                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ create_      │  │ run_         │  │ generate_    │      │
│  │ client.sh    │  │ benchmark.sh │  │ reports.sh   │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼─────────────┘
          │                  │                  │
          │                  │                  │
┌─────────▼──────────────────▼──────────────────▼─────────────┐
│                  CAPA DE HERRAMIENTAS                         │
│  ┌──────────────────────────────────────────────────────┐   │
│  │     monitor_sql_workload.py (Python)                 │   │
│  │     - Captura métricas de SQL Server                 │   │
│  │     - Genera JSON con series temporales              │   │
│  └──────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │     Template Engine (jinja2 / sed)                   │   │
│  │     - Procesa templates HTML                         │   │
│  │     - Inyecta datos del JSON                         │   │
│  └──────────────────────────────────────────────────────┘   │
└────────────┬──────────────────────────────┬──────────────────┘
             │                              │
             │ pyodbc                       │ Templates
             │                              │
┌────────────▼──────────────────┐  ┌────────▼───────────────────┐
│      SQL SERVER               │  │    ARCHIVOS ESTÁTICOS      │
│  - DMVs (sys.dm_*)           │  │  - benchmark-report.html   │
│  - Performance Counters       │  │  - cost-analysis.html      │
│  - Wait Statistics           │  │  - migration-guide.html    │
│  - Database Sizes            │  │  - Chart.js, Prism.js      │
└───────────────────────────────┘  └────────────────────────────┘
```

### Flujo de Ejecución

```
1. create_client.sh
   └─> Crea estructura de directorios
   └─> Genera config templates

2. run_benchmark.sh
   ├─> Lee config/client-config.env
   ├─> Valida conexión SQL Server
   ├─> Ejecuta monitor_sql_workload.py
   │   ├─> Loop cada N segundos
   │   ├─> Query DMVs
   │   ├─> Append a JSON
   │   └─> Ctrl+C o timeout
   └─> Guarda sql_workload_*.json

3. generate_reports.sh
   ├─> Lee sql_workload_*.json
   ├─> Calcula agregados (avg, p95, max)
   ├─> Lee templates/*.html
   ├─> Reemplaza {{PLACEHOLDERS}}
   └─> Genera 3 informes HTML
```

## 🧩 Componentes del Sistema

### 1. Scripts de Gestión (Bash)

**Ubicación**: `tools/utils/`

#### create_client.sh
- **Propósito**: Bootstrapping de nuevo cliente
- **Entrada**: Nombre del cliente
- **Salida**: Estructura de directorios + configs template
- **Dependencias**: Ninguna

#### run_benchmark.sh
- **Propósito**: Orquestar ejecución de benchmark
- **Entrada**: Nombre cliente, nombre servidor, parámetros opcionales
- **Salida**: JSON con series temporales
- **Dependencias**: Python 3.8+, pyodbc, monitor_sql_workload.py

#### generate_reports.sh
- **Propósito**: Generar informes HTML desde JSON
- **Entrada**: Nombre cliente, fecha benchmark
- **Salida**: 3 archivos HTML
- **Dependencias**: jq, templates/*.html

### 2. Herramientas de Monitorización (Python)

**Ubicación**: `tools/monitoring/`

#### monitor_sql_workload.py

**Arquitectura interna:**

```python
class SQLServerMonitor:
    def __init__(self, server, database, username, password):
        self.conn = pyodbc.connect(...)
        
    def collect_metrics(self):
        """Recolecta métricas de SQL Server"""
        return {
            'timestamp': datetime.now().isoformat(),
            'cpu_percent': self.get_cpu_usage(),
            'ram_percent': self.get_memory_usage(),
            'iops': self.get_disk_iops(),
            'transactions': self.get_transactions(),
            'wait_stats': self.get_wait_statistics(),
            'database_sizes': self.get_database_sizes()
        }
    
    def get_cpu_usage(self):
        """Query: sys.dm_os_ring_buffers"""
        query = """
        SELECT TOP 1 
            SQLProcessUtilization AS cpu_percent
        FROM (
            SELECT 
                record.value('(./Record/@id)[1]', 'int') AS record_id,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/
                    SystemIdle)[1]', 'int') AS system_idle,
                record.value('(./Record/SchedulerMonitorEvent/SystemHealth/
                    ProcessUtilization)[1]', 'int') AS SQLProcessUtilization,
                TIMESTAMP
            FROM (
                SELECT TIMESTAMP, 
                    CONVERT(XML, record) AS record
                FROM sys.dm_os_ring_buffers
                WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR'
                    AND record LIKE '%<SystemHealth>%'
            ) AS x
        ) AS y
        ORDER BY record_id DESC
        """
        return cursor.fetchone()[0]
    
    # ... métodos similares para RAM, IOPS, TPS, etc.
```

**DMVs Utilizadas:**

| DMV | Métrica Capturada |
|-----|-------------------|
| `sys.dm_os_ring_buffers` | CPU % |
| `sys.dm_os_sys_memory` | RAM total/disponible |
| `sys.dm_io_virtual_file_stats` | IOPS, latencia |
| `sys.dm_os_performance_counters` | TPS, batch requests |
| `sys.dm_os_wait_stats` | Wait types |
| `sys.databases` | Tamaño de DBs |

### 3. Plantillas de Informes (HTML)

**Ubicación**: `templates/`

#### Estructura de Template

```html
<!DOCTYPE html>
<html>
<head>
    <title>{{REPORT_TITLE}}</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@3.9.1"></script>
    <style>
        /* Estilos Azure-themed */
    </style>
</head>
<body>
    <h1>{{CLIENT_NAME}} - Benchmark Report</h1>
    
    <section id="executive-summary">
        <h2>Resumen Ejecutivo</h2>
        <div class="metric-card">
            <h3>CPU Promedio</h3>
            <span class="value">{{CPU_AVG}}%</span>
        </div>
        <!-- ... más métricas -->
    </section>
    
    <section id="charts">
        <canvas id="cpuChart"></canvas>
        <script>
            const ctx = document.getElementById('cpuChart').getContext('2d');
            new Chart(ctx, {
                type: 'line',
                data: {
                    labels: [{{TIMESTAMPS}}],
                    datasets: [{
                        label: 'CPU %',
                        data: [{{CPU_VALUES}}],
                        borderColor: 'rgb(0, 120, 212)'
                    }]
                }
            });
        </script>
    </section>
    
    <section id="recommendations">
        <h2>Recomendaciones Azure</h2>
        <p>Basado en las métricas capturadas:</p>
        <ul>
            <li>VM Size: <strong>{{AZURE_VM_SIZE}}</strong></li>
            <li>Disks: <strong>{{DISK_CONFIG}}</strong></li>
            <li>Costo mensual: <strong>{{COST_MONTHLY}}</strong></li>
        </ul>
    </section>
</body>
</html>
```

### 4. Configuración Multi-Tenant

**Ubicación**: `config/` + `customers/*/config/`

#### Jerarquía de Configuración

```
config/settings.env (Global)
    ↓ (inherited by)
customers/cliente-a/config/client-config.env (Override)
    ↓ (used by)
run_benchmark.sh
```

**Precedencia:**
1. Parámetros CLI (`--duration`, `--interval`)
2. `client-config.env` (cliente específico)
3. `settings.env` (defaults globales)

### 5. GitHub Copilot Agent Integration

**Ubicación**: `.github/copilot-instructions.md`, `mcp.json`

#### MCP Servers Architecture

```
┌─────────────────────────────────────────────────────────┐
│           GitHub Copilot (Claude Sonnet 4.5)           │
│                                                         │
│  Modo: azure-architect                                 │
│  Prompt: copilot-instructions.md (18,000 líneas)       │
└─────────────┬───────────────────────────────────────────┘
              │
              │ Model Context Protocol (MCP)
              │
┌─────────────▼───────────────────────────────────────────┐
│                    MCP SERVERS                          │
├─────────────────────────────────────────────────────────┤
│  azure-mcp          → Azure resources (VMs, VNets)     │
│  bicep-mcp          → Bicep templates                   │
│  github-mcp         → GitHub repos, issues, PRs         │
│  filesystem-mcp     → Workspace navigation              │
│  brave-search-mcp   → Web search (docs)                 │
│  memory-mcp         → Persistent context                │
└─────────────────────────────────────────────────────────┘
```

**Capabilities:**

- Analizar benchmarks JSON automáticamente
- Recomendar Azure VM sizing
- Generar código Bicep
- Crear scripts de automatización
- Documentar decisiones (ADRs)

## 📂 Estructura de Directorios

```
azure-sql-benchmark-toolkit/
│
├── .github/                          # GitHub-specific configs
│   └── copilot-instructions.md       # Agente IA (18k líneas)
│
├── mcp.json                          # MCP servers config
│
├── config/                           # Configuración global
│   └── settings.env                  # Defaults del toolkit
│
├── tools/                            # Herramientas principales
│   ├── monitoring/
│   │   └── monitor_sql_workload.py   # Captura de métricas
│   ├── analysis/                     # (Futuro: análisis avanzado)
│   └── utils/                        # Scripts de utilidad
│       ├── create_client.sh
│       ├── run_benchmark.sh
│       └── generate_reports.sh
│
├── templates/                        # Plantillas HTML
│   ├── benchmark-performance-report.html
│   ├── cost-analysis-report.html
│   └── migration-operations-guide.html
│
├── customers/                        # Multi-tenant data
│   ├── .example-client/             # Cliente de ejemplo
│   │   ├── README.md
│   │   ├── QUICKSTART.md
│   │   ├── config/
│   │   │   ├── client-config.env
│   │   │   └── servers-inventory.json
│   │   ├── benchmarks/
│   │   │   └── 2025-11-25_143530/
│   │   │       ├── sql_workload_*.json
│   │   │       ├── benchmark-performance-report.html
│   │   │       ├── cost-analysis-report.html
│   │   │       └── migration-operations-guide.html
│   │   └── docs/
│   │
│   ├── cliente-a/                    # Cliente real
│   └── cliente-b/                    # Cliente real
│
├── docs/                             # Documentación
│   ├── QUICKSTART.md
│   ├── SETUP.md
│   ├── USAGE.md
│   ├── ARCHITECTURE.md               # Este documento
│   ├── CONTRIBUTING.md
│   ├── CHANGELOG.md
│   ├── COPILOT_AGENT.md
│   ├── api/                          # API reference (futuro)
│   ├── examples/                     # Ejemplos de código
│   └── guides/                       # Guías específicas
│
├── scripts/                          # Scripts de operación
│   ├── setup/                        # Instalación
│   ├── customer-management/          # Gestión clientes
│   └── report-generation/            # Generación informes
│
├── .gitignore                        # Excluir datos sensibles
├── .env.example                      # Template de variables
├── SECURITY.md                       # Política de seguridad
├── LICENSE                           # MIT License
└── README.md                         # Documentación principal
```

## 🔧 Tecnologías Utilizadas

### Backend

| Tecnología | Versión | Uso |
|------------|---------|-----|
| **Python** | 3.8+ | Core monitoring logic |
| **pyodbc** | 4.0+ | SQL Server connectivity |
| **Bash** | 4.0+ | Orchestration scripts |
| **jq** | 1.6+ | JSON processing |

### Frontend (Informes)

| Tecnología | Versión | Uso |
|------------|---------|-----|
| **HTML5** | - | Estructura de informes |
| **CSS3** | - | Estilos Azure-themed |
| **Chart.js** | 3.9.1 | Gráficos interactivos |
| **Prism.js** | 1.29.0 | Syntax highlighting |

### AI & MCP

| Servidor MCP | Versión | Uso |
|--------------|---------|-----|
| **azure-mcp** | latest | Azure resource queries |
| **bicep-mcp** | latest | Bicep generation |
| **github-mcp** | latest | GitHub integration |
| **filesystem-mcp** | latest | Workspace navigation |
| **brave-search-mcp** | latest | Web search |
| **memory-mcp** | latest | Persistent context |

### Infrastructure

| Herramienta | Uso |
|-------------|-----|
| **Git** | Version control |
| **GitHub Actions** | CI/CD (futuro) |
| **Docker** | Containerización (opcional) |
| **Azure Bicep** | IaC para despliegues |

## 🧠 Decisiones Arquitectónicas

### ADR-001: ¿Por qué Bash en lugar de Python puro?

**Contexto**: Necesitamos orchestrar múltiples herramientas.

**Decisión**: Scripts bash para orquestación, Python solo para lógica compleja.

**Razones:**
- ✅ Bash es universal en Linux/macOS
- ✅ Fácil ejecutar comandos del sistema
- ✅ Python requiere más boilerplate para subprocess
- ✅ Separation of concerns (orchestration vs logic)

**Consecuencias:**
- Windows requiere WSL o Git Bash
- Scripts más legibles para sysadmins

### ADR-002: ¿JSON en lugar de SQL Database?

**Contexto**: Necesitamos almacenar series temporales de métricas.

**Decisión**: Un archivo JSON por benchmark, no base de datos.

**Razones:**
- ✅ Simplicidad (no setup de DB)
- ✅ Portabilidad (copiar/compartir fácilmente)
- ✅ Versionable con Git (archivos pequeños)
- ✅ Fácil parsear con jq/Python
- ✅ No requiere servidor adicional

**Consecuencias:**
- Benchmarks largos generan JSONs grandes (100 MB+)
- No hay queries complejas sin procesar primero

### ADR-003: ¿HTML estático en lugar de Web App?

**Contexto**: Necesitamos informes visuales profesionales.

**Decisión**: Informes HTML autónomos con CDN para librerías.

**Razones:**
- ✅ No requiere servidor web
- ✅ Abrir directamente en navegador
- ✅ Compartir fácilmente (Teams, OneDrive, SharePoint)
- ✅ Offline-friendly (CDN con fallback)
- ✅ Impresión/PDF nativa del navegador

**Consecuencias:**
- No hay interactividad server-side
- Filtros/drill-down limitados a JavaScript

### ADR-004: Multi-tenant con Filesystem

**Contexto**: Múltiples clientes con datos aislados.

**Decisión**: Directorio `customers/` con subdirectorios por cliente.

**Razones:**
- ✅ Aislamiento natural de datos
- ✅ Permisos del filesystem
- ✅ Backup granular por cliente
- ✅ No requiere base de datos multi-tenant
- ✅ Fácil eliminar cliente completo

**Consecuencias:**
- No hay búsqueda cross-cliente nativa
- Requiere scripts para agregar métricas globales

## 🔒 Seguridad

### Modelo de Amenazas

| Amenaza | Mitigación |
|---------|------------|
| **Credenciales en plaintext** | `.gitignore`, Azure Key Vault opcional |
| **Inyección SQL** | pyodbc con parámetros preparados |
| **Acceso no autorizado a benchmarks** | Permisos filesystem (chmod 700) |
| **Exposición de datos sensibles** | JSON excluido de git por defecto |
| **MITM en conexión SQL** | TLS/SSL obligatorio en pyodbc |

### Buenas Prácticas

```bash
# Permisos recomendados
chmod 700 customers/                    # Solo owner
chmod 600 customers/*/config/*.env      # Solo owner lectura/escritura
chmod 400 .env                          # Solo lectura para secrets globales
```

### Auditoría

```bash
# Log de accesos
ls -la customers/*/benchmarks/ > access_audit.txt

# Detectar credenciales expuestas
git grep -E '(password|secret|key).*=.*["\047][^$\{]' || echo "✅ Clean"
```

## 📈 Escalabilidad

### Límites Actuales

| Recurso | Límite | Workaround |
|---------|--------|------------|
| **Clientes** | Ilimitado | Filesystem limits |
| **Benchmarks por cliente** | Ilimitado | Archivar viejos |
| **Tamaño JSON** | ~500 MB | Comprimir con gzip |
| **Samples por benchmark** | ~100,000 | Reducir frecuencia |
| **Conexiones SQL simultáneas** | 1 por benchmark | Multiplexar |

### Optimizaciones Futuras

1. **Compresión automática**: Gzip JSONs antiguos
2. **Base de datos opcional**: PostgreSQL/SQLite para queries avanzados
3. **Streaming JSON**: No cargar todo en memoria
4. **Caché de cálculos**: Pre-calcular agregados
5. **Paralelización**: Ejecutar benchmarks en paralelo (servidores diferentes)

## 🔮 Roadmap Arquitectónico

### v2.1 - Q1 2026
- [ ] API REST (FastAPI)
- [ ] Dashboard web en tiempo real (React)
- [ ] Base de datos opcional (PostgreSQL)

### v2.2 - Q2 2026
- [ ] Soporte Azure SQL Managed Instance
- [ ] Análisis de Query Store
- [ ] Comparación de múltiples benchmarks

### v3.0 - Q3 2026
- [ ] Containerización (Docker)
- [ ] Kubernetes deployment
- [ ] Multi-cloud support (AWS RDS, Google Cloud SQL)

## 📚 Referencias

- **[SETUP.md](SETUP.md)** - Instalación
- **[USAGE.md](USAGE.md)** - Guía de uso
- **[CONTRIBUTING.md](CONTRIBUTING.md)** - Contribuir
- **[COPILOT_AGENT.md](COPILOT_AGENT.md)** - Agente IA

---

**Última actualización**: 2025-11-26  
**Versión**: 2.0.0  
**Arquitecto**: Alejandro Almeida
