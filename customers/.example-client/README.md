# Cliente de Ejemplo: .example-client

## Información del Cliente

**Nombre**: Cliente de Ejemplo
**Fecha de creación**: 2025-11-20
**Propósito**: Demostración del Azure SQL Benchmark Toolkit

## Descripción

Este es un cliente de ejemplo que contiene un benchmark real de 22 horas de un SQL Server de producción. Los datos y resultados están incluidos para que puedas:

1. Ver cómo se estructuran los resultados
2. Entender el formato de los informes HTML
3. Usar como referencia para tus propios benchmarks
4. Aprender de los patrones identificados

## Servidor SQL Analizado

| Servidor | Entorno | Versión SQL | Cores | RAM | Storage | Estado |
|----------|---------|-------------|-------|-----|---------|--------|
| SQLPROD01 | Production | SQL Server 2019 Enterprise | 12 | 32 GB | 500 GB SSD | Activo |

### Características del Sistema
- **CPU**: Intel Xeon E5-2670 v3 @ 2.30GHz (12 cores)
- **RAM**: 32 GB DDR4
- **Storage**: 2x 250GB SSD en RAID 0
- **Red**: 1 Gbps
- **OS**: Windows Server 2019 Standard

## Benchmark Realizado

### Parámetros del Benchmark

| Parámetro | Valor |
|-----------|-------|
| Fecha de inicio | 2025-11-20 14:33:53 |
| Duración | 22 horas |
| Muestras capturadas | 660 |
| Intervalo de muestreo | 120 segundos (2 min) |
| Tamaño datos JSON | 2.1 MB |

### Hallazgos Clave

#### 🔴 CPU: Saturación Constante
- **Utilización promedio**: 100% (12 cores al máximo)
- **Diagnóstico**: Bottleneck crítico en procesamiento
- **Impacto**: Queries lentas, timeouts, contención de recursos

#### 🟡 Memoria: Uso Moderado
- **RAM utilizada**: 19 GB de 32 GB (59%)
- **Buffer Pool**: 15.4 GB estable
- **Page Life Expectancy**: 3,600 seg (saludable > 300s)
- **Estado**: Bien dimensionada, sin presión de memoria

#### 🟢 Disco I/O: Patrón Bimodal
- **IOPS promedio**: 547 (operacional normal)
- **IOPS pico**: 4,607 (spike a medianoche)
- **Latencia promedio**: 5-8 ms (aceptable)
- **Patrón**: Batch jobs nocturnos causan picos predecibles

#### ⚙️ Transacciones
- **TPS promedio**: 450-600
- **TPS pico**: 1,350 (durante batch)
- **Batch requests/sec**: 800-1,200
- **SQL compilations/sec**: Bajo (buena reutilización de planes)

### Patrones Temporales Identificados

1. **Horario laboral (8:00-18:00)**
   - CPU: 100% constante
   - TPS: 500-700
   - Usuarios concurrentes: Alto

2. **Batch nocturno (00:00-02:00)**
   - IOPS: Spike a 4,600+
   - TPS: Pico a 1,350
   - Procesamiento de reportes/cierres

3. **Madrugada (02:00-07:00)**
   - CPU: 100% (procesos aún activos)
   - IOPS: Normalizado a ~500
   - Mantenimiento de índices

## Recomendación Azure

### Azure VM Sugerida

**Standard_E16ds_v5**
- **vCPUs**: 16 (vs 12 actuales) - +33% capacidad
- **RAM**: 128 GB (vs 32 GB actuales) - 4x capacidad
- **Storage**: 400 GiB temp SSD + Premium SSD P20 disks
- **Network**: 12,500 Mbps (vs 1,000 Mbps)
- **Costo mensual**: ~€750 (Pay-as-you-go)

### Configuración de Discos Recomendada

| Disco | Tipo | Tamaño | IOPS | Throughput | Uso |
|-------|------|--------|------|------------|-----|
| OS Disk | P10 Premium SSD | 128 GB | 500 | 100 MB/s | Sistema Operativo |
| Data Disk 1 | P20 Premium SSD | 512 GB | 2,300 | 150 MB/s | Data Files |
| Data Disk 2 | P20 Premium SSD | 512 GB | 2,300 | 150 MB/s | Data Files (stripe) |
| Log Disk | P15 Premium SSD | 256 GB | 1,100 | 125 MB/s | Transaction Log |

**IOPS Total**: 6,200 (vs 4,607 pico actual)

## Análisis de Costos

### TCO Comparativo (3 años)

| Concepto | On-Premises | Azure PaaS | Azure IaaS |
|----------|-------------|------------|------------|
| **Hardware** | €35,000 | €0 | €0 |
| **Licencias SQL** | €72,000 | Incluido | €43,200 |
| **Compute** | €18,000 | €27,000 | €27,000 |
| **Mantenimiento** | €18,000 | €0 | €5,400 |
| **Personal IT** | €30,000 | €12,000 | €18,000 |
| **Energía/Espacio** | €9,600 | €0 | €0 |
| **Total 3 años** | **€182,600** | **€39,000** | **€93,600** |

### Ahorros con Azure

- **IaaS**: €89,000 (49% reducción)
- **PaaS**: €143,600 (79% reducción) - **Recomendado**

### Optimizaciones Adicionales

1. **Reserved Instances (1 año)**: -30% = €6,300/año ahorrados
2. **Azure Hybrid Benefit**: -55% licencias = €23,760 ahorrados
3. **Auto-shutdown dev/test**: -40% en no-prod = €4,500/año

**Ahorro total optimizado**: €157,560 (86%)

## Informes Disponibles

Los siguientes informes HTML están incluidos en `benchmarks/2025-11-20/`:

1. **[benchmark-performance-report.html](benchmarks/2025-11-20/benchmark-performance-report.html)**
   - Análisis técnico completo
   - Gráficos interactivos
   - Recomendaciones de sizing

2. **[cost-analysis-report.html](benchmarks/2025-11-20/cost-analysis-report.html)**
   - TCO comparativo
   - Proyecciones financieras
   - ROI analysis

3. **[migration-operations-guide.html](benchmarks/2025-11-20/migration-operations-guide.html)**
   - Plan de migración paso a paso
   - Checklists operativos
   - Matriz de riesgos

## Cómo Usar Este Ejemplo

### 1. Explorar la Estructura

```bash
cd customers/.example-client
tree -L 3
```

### 2. Ver el JSON de Datos Raw

```bash
# Ver primeras 100 líneas
head -n 100 benchmarks/2025-11-20/sql_workload_extended_20251120_143353.json

# Ver con formato
jq '.[0]' benchmarks/2025-11-20/sql_workload_extended_20251120_143353.json
```

### 3. Abrir Informes HTML

```bash
# Linux/WSL
xdg-open benchmarks/2025-11-20/benchmark-performance-report.html

# Windows
start benchmarks\2025-11-20\benchmark-performance-report.html

# macOS
open benchmarks/2025-11-20/benchmark-performance-report.html
```

### 4. Usar como Plantilla

Copia la estructura para tu propio cliente:

```bash
# Desde el directorio raíz del proyecto
./tools/utils/create_client.sh mi-nuevo-cliente
```

## Lecciones Aprendidas

### ✅ Qué Funcionó Bien

1. **Captura de 22 horas**: Suficiente para identificar patrones diarios completos
2. **Intervalo de 2 minutos**: Buen balance entre detalle y tamaño de datos
3. **Inclusión de noche/madrugada**: Reveló batch jobs críticos

### 📝 Recomendaciones para Tu Benchmark

1. **Duración mínima**: 24 horas para ciclo completo
2. **Incluir fin de semana**: Si hay procesamiento especial sábado/domingo
3. **Monitorear fin de mes**: Patrones de cierre contable
4. **Documentar eventos**: Anotar mantenimientos o incidentes durante captura

### 🔍 Métricas Críticas a Vigilar

- CPU al 100% sostenido = Necesitas más vCPUs
- IOPS > 2,000 sostenido = Considera Premium SSD o Ultra Disk
- Page Life Expectancy < 300s = Necesitas más RAM
- Wait type PAGEIOLATCH = Bottleneck de disco
- Wait type CXPACKET = Queries mal paralelizadas

## Contactos

| Rol | Nombre | Email |
|-----|--------|-------|
| Responsable Técnico | Juan García | juan.garcia@example.com |
| Contacto Principal | María López | maria.lopez@example.com |
| DBA Senior | Pedro Martínez | pedro.martinez@example.com |

## Próximos Pasos Sugeridos

1. ✅ Revisar los 3 informes HTML
2. ✅ Validar recomendaciones de sizing con equipo técnico
3. ⏳ Aprobar presupuesto para migración Azure
4. ⏳ Ejecutar PoC en entorno dev/test
5. ⏳ Planificar piloto con workload no-crítico
6. ⏳ Migración completa a producción

## Notas Adicionales

- Este benchmark reveló que el servidor está **severamente sub-dimensionado en CPU**
- La migración a Azure con E16ds_v5 resolvería el bottleneck inmediatamente
- Se recomienda **Azure SQL Managed Instance** sobre IaaS por:
  - Menor costo (79% ahorro)
  - Alta disponibilidad built-in (99.99% SLA)
  - Backups automáticos con PITR
  - Patching automático sin downtime
  - Escalado online sin reinicio

---

**Este ejemplo demuestra el valor completo del Azure SQL Benchmark Toolkit**

¿Preguntas? Consulta el [README principal](../../README.md)
