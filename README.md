```
    ___   _____ ____  ______
   /   | / ___// __ )/_  __/
  / /| | \__ \/ __  | / /   
 / ___ |___/ / /_/ / / /    
/_/  |_/____/_____/ /_/     
                            
 Azure SQL Benchmark Toolkit
    Performance Analysis
  & Migration Assessment
```

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![Azure](https://img.shields.io/badge/Azure-Ready-0078D4.svg)](https://azure.microsoft.com/)
[![Version](https://img.shields.io/badge/version-2.0.0-green.svg)](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/releases)

## 📋 Descripción

Azure SQL Benchmark Toolkit es una suite profesional de herramientas para realizar análisis de rendimiento exhaustivos de SQL Server y generar estudios de migración a Azure. Diseñado para consultores, arquitectos de soluciones y equipos de operaciones que necesitan:

- ✅ **Monitorización detallada** de SQL Server (CPU, RAM, IOPS, transacciones)
- ✅ **Informes profesionales** en HTML con gráficos interactivos
- ✅ **Análisis de costos** TCO comparando on-premises vs Azure
- ✅ **Guías de migración** paso a paso con checklists
- ✅ **Gestión multi-cliente** con estructura organizada
- ✅ **Asistente IA** con agente Azure Architect integrado

## 🎯 Casos de Uso

### Para Consultores y Partners
- Realizar evaluaciones de rendimiento en clientes
- Generar propuestas de migración con datos reales
- Gestionar múltiples proyectos de modernización
- Documentar decisiones arquitectónicas

### Para Arquitectos de Soluciones
- Dimensionar correctamente VMs en Azure
- Identificar bottlenecks y patrones de uso
- Planificar migraciones con métricas precisas
- Optimizar costos antes de migrar

### Para Equipos de Operaciones
- Establecer baseline de rendimiento actual
- Monitorizar tendencias de carga
- Preparar estrategias de DR/BC
- Validar sizing post-migración

## 🏗️ Estructura del Proyecto

```
azure-sql-benchmark-toolkit/
├── .github/                    # GitHub Copilot Agent (azure-architect)
│   └── copilot-instructions.md
├── mcp.json                    # Configuración MCP Servers
├── config/                     # Configuración global del toolkit
│   └── settings.env
├── tools/                      # Herramientas del toolkit
│   ├── monitoring/
│   │   └── monitor_sql_workload.py    # Script Python de monitorización
│   ├── analysis/
│   │   └── (futuras herramientas de análisis)
│   └── utils/
│       ├── create_client.sh           # Crear nuevo cliente
│       ├── run_benchmark.sh           # Ejecutar benchmark
│       └── generate_reports.sh        # Generar informes HTML
├── templates/                  # Plantillas de informes HTML
│   ├── benchmark-performance-report.html
│   ├── cost-analysis-report.html
│   └── migration-operations-guide.html
├── customers/                  # Directorio de clientes
│   └── .example-client/       # Cliente de ejemplo con datos reales
│       ├── README.md
│       ├── QUICKSTART.md
│       ├── config/
│       │   ├── client-config.env
│       │   └── servers-inventory.json
│       ├── benchmarks/
│       │   └── 2025-11-20/    # Resultados del benchmark
│       │       ├── sql_workload_*.json
│       │       ├── benchmark-performance-report.html
│       │       ├── cost-analysis-report.html
│       │       └── migration-operations-guide.html
│       └── docs/
└── docs/                       # Documentación del proyecto
    ├── QUICKSTART.md
    ├── SETUP.md
    ├── USAGE.md
    └── TROUBLESHOOTING.md
```

## 🚀 Quick Start (5 minutos)

### 1. Prerrequisitos

```bash
# Python 3.8+
python3 --version

# Instalar dependencias Python
pip install pyodbc

# ODBC Driver para SQL Server
# Ubuntu/Debian:
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
curl https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17

# Windows: Descargar desde https://docs.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server
# macOS: brew install msodbcsql17
```

### 2. Clonar el Repositorio

```bash
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit
```

### 3. Crear Tu Primer Cliente

```bash
./tools/utils/create_client.sh mi-cliente-ejemplo
cd customers/mi-cliente-ejemplo
```

### 4. Configurar Conexión SQL Server

Edita `config/client-config.env`:

```bash
SQL_SERVER="mi-servidor-sql.domain.local"
SQL_DATABASE="master"
SQL_USE_TRUSTED_AUTH="true"  # Windows Auth
# O para SQL Auth:
# SQL_USERNAME="sa"
# SQL_PASSWORD="P@ssw0rd"
# SQL_USE_TRUSTED_AUTH="false"
```

### 5. Ejecutar Benchmark

```bash
# Desde el directorio raíz del proyecto
./tools/utils/run_benchmark.sh mi-cliente-ejemplo SQLPROD01

# Para un test rápido de 10 minutos:
./tools/utils/run_benchmark.sh mi-cliente-ejemplo SQLPROD01 --duration 600 --interval 30
```

### 6. Generar Informes

```bash
./tools/utils/generate_reports.sh mi-cliente-ejemplo 2025-11-25
```

### 7. Ver Resultados

```bash
# Abrir informe en navegador
xdg-open customers/mi-cliente-ejemplo/benchmarks/2025-11-25/benchmark-performance-report.html
```

## 📊 Informes Generados

El toolkit genera **3 informes HTML profesionales**:

### 1. 🔍 Benchmark Performance Report
- Análisis detallado de CPU, RAM, IOPS
- Gráficos interactivos (Chart.js)
- Identificación de bottlenecks
- Patrones temporales de carga
- Recomendación de Azure VM sizing
- **Duración típica de lectura**: 15-20 minutos

### 2. 💰 Cost Analysis Report
- TCO comparativo (3 años)
- Desglose de costos on-premises vs Azure
- ROI y break-even point
- Optimizaciones de costo (Reserved Instances, Savings Plans)
- Proyecciones con diferentes escenarios
- **Duración típica de lectura**: 10-15 minutos

### 3. 📋 Migration Operations Guide
- Plan de migración paso a paso
- Checklists de pre-migración
- Procedimientos de cutover
- Estrategias de rollback
- Validación post-migración
- Matriz de riesgos
- **Duración típica de lectura**: 20-30 minutos

## 🤖 GitHub Copilot Agent (Azure Architect)

Este proyecto incluye un **agente de IA especializado** en arquitectura Azure (`azure-architect`) que puede:

- Analizar resultados de benchmarks automáticamente
- Sugerir configuraciones Azure óptimas
- Generar código Bicep para infraestructura
- Responder preguntas sobre migración
- Crear documentación técnica

### Activar el Agente

En GitHub Copilot Chat (VS Code):

```
@azure-architect analiza el benchmark del cliente contoso-manufacturing y sugiere el mejor Azure VM
```

```
@azure-architect genera Bicep para desplegar SQL Server con los requisitos del benchmark
```

Ver [docs/COPILOT_AGENT.md](docs/COPILOT_AGENT.md) para más detalles.

## 🔧 MCP Servers Configurados

El proyecto incluye configuración de **Model Context Protocol (MCP)** servers:

- **azure-mcp**: Acceso a recursos Azure, subscriptions, VMs
- **bicep-mcp**: Análisis y generación de templates Bicep
- **github-mcp**: Gestión de repos, issues, workflows
- **filesystem-mcp**: Navegación del workspace
- **brave-search-mcp**: Búsqueda de documentación actualizada

Ver [mcp.json](mcp.json) para configuración completa.

## 📚 Documentación Completa

- **[QUICKSTART.md](docs/QUICKSTART.md)** - Inicio rápido en 5 pasos
- **[SETUP.md](docs/SETUP.md)** - Instalación detallada y troubleshooting
- **[USAGE.md](docs/USAGE.md)** - Guía completa de uso
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Arquitectura del toolkit
- **[CONTRIBUTING.md](docs/CONTRIBUTING.md)** - Contribuir al proyecto
- **[CHANGELOG.md](docs/CHANGELOG.md)** - Historial de versiones

## 🎓 Ejemplos de Uso

### Benchmark de 24 horas (Producción)

```bash
./tools/utils/run_benchmark.sh contoso-mfg SQLPROD01 \
  --duration 86400 \
  --interval 120
```

### Benchmark de 1 hora (Prueba)

```bash
./tools/utils/run_benchmark.sh fabrikam-retail SQLDEV02 \
  --duration 3600 \
  --interval 60
```

### Benchmark de fin de semana (72 horas)

```bash
./tools/utils/run_benchmark.sh adventureworks-online SQLPROD03 \
  --duration 259200 \
  --interval 300
```

## 🔍 Métricas Capturadas

| Categoría | Métricas |
|-----------|----------|
| **CPU** | % Utilización, SQL CPU Time, Signal Wait Time |
| **Memoria** | RAM Total/Usado/Disponible, Buffer Pool, Page Life Expectancy |
| **Disco I/O** | IOPS (read/write), Latencia (avg/max), Throughput MB/s |
| **Transacciones** | TPS, Batch Requests/sec, Compilaciones SQL/sec |
| **Wait Stats** | Top 10 wait types con tiempos acumulados |
| **Bases de Datos** | Tamaño data/log files por DB |

## 💡 Tips y Mejores Prácticas

### ✅ Duración Recomendada del Benchmark

- **Mínimo**: 6 horas (captura jornada laboral completa)
- **Recomendado**: 24 horas (captura ciclo diario completo)
- **Ideal**: 7 días (captura patrones semanales)

### ✅ Intervalo de Muestreo

- **Alto detalle**: 30-60 segundos (aumenta tamaño JSON)
- **Equilibrado**: 120 segundos (2 minutos) - **recomendado**
- **Bajo detalle**: 300 segundos (5 minutos)

### ✅ Cuándo Ejecutar

- ✅ Durante horario laboral normal
- ✅ Incluir períodos de carga pico (fin de mes, cierres)
- ✅ Incluir procesos batch nocturnos
- ❌ Evitar ventanas de mantenimiento
- ❌ Evitar períodos de baja actividad (festivos)

### ✅ Conexión a SQL Server

- ✅ Usar cuenta con permisos VIEW SERVER STATE
- ✅ Preferir Windows Authentication (más segura)
- ✅ Ejecutar desde servidor cercano (baja latencia)
- ❌ No usar cuenta 'sa' en producción
- ❌ No guardar passwords en plaintext

## 🛠️ Troubleshooting

### Error: "pyodbc module not found"

```bash
pip install pyodbc
```

### Error: "ODBC Driver 17 for SQL Server not found"

Ver sección de prerrequisitos para instalar el driver ODBC.

### Error: "Connection failed: Login failed for user"

Verifica credenciales en `config/client-config.env` y permisos en SQL Server.

### El benchmark se interrumpió

Los resultados parciales se guardan automáticamente. Genera informes con los datos capturados:

```bash
./tools/utils/generate_reports.sh mi-cliente 2025-11-25
```

Ver [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) para más ayuda.

## 🤝 Contribuir

Las contribuciones son bienvenidas! Ver [CONTRIBUTING.md](CONTRIBUTING.md) para:

- Reportar bugs
- Sugerir nuevas features
- Enviar pull requests
- Mejorar documentación

## 📄 Licencia

Este proyecto está bajo licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

## 👥 Autores

- **Alejandro Almeida** - Arquitecto Azure & DevOps - [@alejandrolmeida](https://github.com/alejandrolmeida)

## 🙏 Agradecimientos

- Microsoft Azure Documentation
- SQL Server Performance Tuning Community
- Chart.js y Prism.js por las librerías
- GitHub Copilot por asistencia en desarrollo

## 📞 Soporte

- **Issues**: [GitHub Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues)
- **Discussions**: [GitHub Discussions](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)
- **Email**: alejandro.almeida@example.com

## 🗺️ Roadmap

- [ ] v2.1: Soporte para Azure SQL Database Managed Instance
- [ ] v2.2: Análisis de queries más lentas (Query Store)
- [ ] v2.3: Comparación de múltiples benchmarks
- [ ] v2.4: Exportación a PowerBI
- [ ] v2.5: API REST para integración
- [ ] v3.0: Dashboard web en tiempo real

## ⭐ Star History

Si este proyecto te resulta útil, ¡dale una estrella! ⭐

---

**Hecho con ❤️ para la comunidad Azure**

[⬆ Volver arriba](#-azure-sql-benchmark-toolkit)
