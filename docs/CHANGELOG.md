# 📜 Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.

El formato está basado en [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
y este proyecto adhiere a [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planeado para v2.1.0

- [ ] Soporte para Azure SQL Managed Instance
- [ ] Análisis de Query Store
- [ ] Comparación de múltiples benchmarks
- [ ] API REST (FastAPI)
- [ ] Dashboard web en tiempo real

## [2.0.0] - 2025-11-26

### 🎉 Initial Public Release

Primera versión pública del Azure SQL Benchmark Toolkit, completamente rediseñado desde cero.

### ✨ Added

#### Core Features
- **Multi-tenant Architecture**: Gestión de múltiples clientes con aislamiento de datos
- **SQL Server Monitoring**: Captura exhaustiva de métricas (CPU, RAM, IOPS, TPS, Wait Stats)
- **Benchmark Tool**: Script Python `monitor_sql_workload.py` para captura de series temporales
- **Report Generation**: 3 informes HTML profesionales con gráficos interactivos
  - Benchmark Performance Report
  - Cost Analysis Report (TCO on-premises vs Azure)
  - Migration Operations Guide
- **Template System**: Plantillas HTML reutilizables con placeholders dinámicos

#### Scripts & Utilities
- `create_client.sh`: Crear nuevos clientes con estructura completa
- `run_benchmark.sh`: Ejecutar benchmarks con parámetros personalizables
- `generate_reports.sh`: Generar informes HTML desde datos JSON

#### GitHub Copilot Agent Integration
- **Azure Architect Mode**: Agente IA especializado en arquitectura Azure
- **MCP Servers**: Integración con 6 Model Context Protocol servers
  - `azure-mcp`: Acceso a recursos Azure
  - `bicep-mcp`: Generación de infraestructura como código
  - `github-mcp`: Gestión de repositorio
  - `filesystem-mcp`: Navegación del workspace
  - `brave-search-mcp`: Búsqueda web de documentación
  - `memory-mcp`: Contexto persistente
- **AI-Powered Analysis**: Análisis automático de benchmarks y recomendaciones

#### Documentation
- `README.md`: Documentación principal completa (1,500+ líneas)
- `QUICKSTART.md`: Guía de inicio rápido en 5 minutos
- `SETUP.md`: Instalación detallada para Linux/Windows/macOS
- `USAGE.md`: Guía completa de uso con ejemplos avanzados
- `ARCHITECTURE.md`: Documentación técnica de arquitectura
- `CONTRIBUTING.md`: Guía para contribuidores
- `COPILOT_AGENT.md`: Documentación del agente IA
- `SECURITY.md`: Política de seguridad y mejores prácticas
- `.env.example`: Template de variables de entorno

#### Configuration
- **Global Settings**: `config/settings.env` con configuración por defecto
- **Client-Specific Config**: `customers/*/config/client-config.env` por cliente
- **Server Inventory**: JSON para documentar servidores del cliente
- **MCP Configuration**: `mcp.json` para GitHub Copilot Agent

#### Visual Identity
- **ASCII Logo**: Logo "AZURE SQL BT" en tipografía ANSI Shadow
- **Badges**: MIT License, Python 3.8+, Azure Ready, Version
- **Professional Styling**: Azure-themed colors en informes HTML

#### Example Client
- `.example-client/`: Cliente de ejemplo con datos reales de producción
- Benchmark de 24 horas con 720 samples
- Informes HTML generados y listos para visualizar
- Documentación específica del cliente

#### Security
- `.gitignore`: Protección de credenciales y datos sensibles
- `.env` exclusion: Variables de entorno nunca commiteadas
- Customer data protection: Benchmarks excluidos por defecto
- Key Vault integration: Soporte para Azure Key Vault (opcional)
- Windows Authentication: Preferred method para SQL Server

### 🔧 Technical Details

#### Technologies
- **Python**: 3.8+ (core monitoring logic)
- **pyodbc**: 4.0+ (SQL Server connectivity)
- **Bash**: 4.0+ (orchestration scripts)
- **Chart.js**: 3.9.1 (interactive charts)
- **Prism.js**: 1.29.0 (syntax highlighting)
- **jq**: 1.6+ (JSON processing)

#### Platform Support
- ✅ Ubuntu/Debian (tested on 20.04, 22.04)
- ✅ Windows 10+ (via WSL or Git Bash)
- ✅ macOS 10.15+ (via Homebrew)

#### SQL Server Support
- ✅ SQL Server 2016+
- ✅ SQL Server 2017
- ✅ SQL Server 2019
- ✅ SQL Server 2022
- ⏳ Azure SQL Managed Instance (coming in v2.1)

### 📊 Metrics Captured

#### System Metrics
- **CPU**: % utilization (from `sys.dm_os_ring_buffers`)
- **Memory**: Total, Used, Available, Buffer Pool, Page Life Expectancy
- **Disk I/O**: Read/Write IOPS, Latency (avg, p95, max), Throughput MB/s

#### SQL Server Metrics
- **Transactions**: TPS, Batch Requests/sec, Compilations/sec
- **Wait Statistics**: Top 10 wait types with accumulated times
- **Database Sizes**: Data files + Log files per database
- **Connection Pool**: Active connections, sessions

### 🎨 Report Features

#### Interactive Charts (Chart.js)
- CPU utilization over time
- RAM usage trends
- IOPS patterns
- Transaction rate
- Wait statistics distribution

#### Cost Analysis
- TCO calculation (3-year projection)
- On-premises vs Azure comparison
- Azure VM sizing recommendations
- Reserved Instances savings
- Azure Hybrid Benefit calculations

#### Migration Planning
- Pre-migration checklist
- Step-by-step migration plan
- Rollback procedures
- Risk matrix
- Post-migration validation

### 🔒 Security Enhancements

- Credential encryption in transit (TLS/SSL)
- No plaintext passwords in git
- Azure Key Vault integration support
- Audit logging of benchmark executions
- RBAC recommendations for SQL Server

### 🌐 Multi-Tenant Features

- Isolated customer directories
- Per-client configuration
- Independent benchmark storage
- Client-specific reports
- Bulk operations support

### 📦 Distribution

- **License**: MIT License
- **Repository**: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit
- **Language**: Spanish (primary), English (partial)
- **Release Tag**: v2.0.0

### 🙏 Acknowledgments

- Microsoft Azure Documentation
- SQL Server Performance Tuning Community
- Chart.js and Prism.js libraries
- GitHub Copilot for development assistance

### 📝 Breaking Changes

N/A - Primera versión pública

### 🐛 Known Issues

- Windows native support limited (requires WSL for bash scripts)
- Large benchmarks (>7 days) generate JSONs >500 MB
- No real-time monitoring dashboard (planned for v2.1)
- No multi-benchmark comparison tool yet (planned for v2.2)

### 🔗 Links

- [Documentation](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/tree/main/docs)
- [Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues)
- [Discussions](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)

---

## Version History

### Version Numbering

Este proyecto usa [Semantic Versioning](https://semver.org/):

- **MAJOR**: Cambios incompatibles en la API
- **MINOR**: Nuevas funcionalidades compatibles hacia atrás
- **PATCH**: Bug fixes compatibles hacia atrás

### Future Releases

#### v2.1.0 (Q1 2026) - Planned
- Azure SQL Managed Instance support
- Query Store analysis
- Multi-benchmark comparison
- PowerBI export

#### v2.2.0 (Q2 2026) - Planned
- API REST (FastAPI)
- Real-time dashboard (React)
- PostgreSQL storage option
- Docker containerization

#### v3.0.0 (Q3 2026) - Vision
- Multi-cloud support (AWS RDS, Google Cloud SQL)
- Kubernetes deployment
- Advanced ML-based recommendations
- SaaS offering

---

## How to Contribute

¿Encontraste un bug? ¿Tienes una idea para un feature?

1. **Issues**: [Report a bug or request a feature](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues)
2. **Discussions**: [Ask questions or share ideas](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)
3. **Pull Requests**: [Contribute code](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/pulls)

Ver [CONTRIBUTING.md](CONTRIBUTING.md) para más detalles.

---

## Support

- **GitHub Issues**: Bug reports y feature requests
- **GitHub Discussions**: Preguntas y comunidad
- **Email**: alejandro.almeida@example.com
- **Documentation**: [docs/](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/tree/main/docs)

---

**Última actualización**: 2025-11-26  
**Versión actual**: 2.0.0  
**Formato**: [Keep a Changelog](https://keepachangelog.com/)
