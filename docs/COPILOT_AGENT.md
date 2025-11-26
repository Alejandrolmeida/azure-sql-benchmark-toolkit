# 🤖 GitHub Copilot Agent - Azure Architect

## 📋 Descripción General

Este proyecto incluye un **agente de IA especializado** llamado `azure-architect` que potencia GitHub Copilot con conocimiento experto en:

- 🏗️ **Arquitectura Azure Enterprise**
- 📊 **Análisis de benchmarks SQL Server**
- 💰 **Optimización de costos (FinOps)**
- 🔒 **Seguridad y compliance**
- 🚀 **Migraciones a Azure SQL**
- 📝 **Infraestructura como código (Bicep)**

El agente está configurado en `.github/copilot-instructions.md` y activo en **modo `azure-architect`**.

## 🎯 Casos de Uso

### 1. Análisis Automático de Benchmarks

Analiza resultados de benchmarks y recomienda Azure VMs óptimas:

```
@azure-architect analiza el benchmark del cliente contoso-manufacturing y recomienda el mejor Azure VM SKU
```

**Ejemplo de respuesta:**
- Análisis de CPU, RAM, IOPS capturados
- Recomendación de VM Family (Esv5, Dsv5, etc.)
- Justificación técnica del sizing
- Estimación de costos mensual

### 2. Generación de Infraestructura Bicep

Crea código Bicep para desplegar recursos Azure basándose en los requisitos del benchmark:

```
@azure-architect genera Bicep para desplegar SQL Server en Azure con los requisitos del último benchmark de fabrikam-retail
```

**Genera:**
- Virtual Machine con sizing correcto
- Managed Disks (Premium SSD v2)
- Virtual Network y subnets
- Network Security Groups
- Azure Backup configurado
- Monitoring (Log Analytics + Application Insights)

### 3. Optimización de Costos

Analiza costos y propone ahorros:

```
@azure-architect revisa el TCO del informe de adventureworks y sugiere optimizaciones de costo
```

**Propuestas:**
- Reserved Instances (ahorro 30-40%)
- Azure Hybrid Benefit (ahorro hasta 85%)
- Spot Instances para dev/test
- Auto-shutdown para entornos no-prod
- Right-sizing de recursos sobredimensionados

### 4. Estrategia de Migración

Genera planes de migración detallados:

```
@azure-architect crea un plan de migración paso a paso para el servidor SQLPROD01 del cliente contoso
```

**Incluye:**
- Pre-requisitos y checklist
- Estrategia de migración (Lift & Shift, PaaS, Hybrid)
- Timeline con fases
- Matriz de riesgos
- Procedimientos de rollback
- Validación post-migración

### 5. Troubleshooting y Diagnóstico

Ayuda con problemas durante benchmarks o migraciones:

```
@azure-architect el benchmark falló con error "Login failed for user" ¿qué debo revisar?
```

```
@azure-architect el informe muestra alta latencia de disco, ¿qué VM debería usar en Azure?
```

### 6. Documentación Técnica

Genera documentación profesional:

```
@azure-architect crea un Architecture Decision Record (ADR) documentando por qué elegimos Esv5 sobre Dsv5
```

```
@azure-architect genera un resumen ejecutivo del proyecto de migración para presentar al cliente
```

## 🔧 Configuración Avanzada

### Modo Azure Architect

El agente está configurado permanentemente en modo `azure-architect`. Esto significa que tiene:

- **Expertise en Azure**: Well-Architected Framework, pricing, servicios
- **Conocimiento del proyecto**: Estructura de carpetas, scripts, templates
- **Acceso a MCP Servers**: Azure, Bicep, GitHub, Filesystem, Brave Search, Memory

### Variables de Entorno Necesarias

Para funcionalidad completa del agente, configura estas variables:

```bash
# Azure (para acceso a recursos reales)
export AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"

# GitHub (para gestión de repos e issues)
export GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Brave Search (opcional, para búsqueda de documentación actualizada)
export BRAVE_API_KEY="BSA_xxxxxxxxxxxxxxxxxxxx"
```

Ver `.env.example` para template completo.

## 🧠 MCP Servers Integrados

El agente utiliza estos **Model Context Protocol (MCP)** servers:

### 1. azure-mcp (`@azure/mcp-server-azure`)
- **Función**: Acceso directo a recursos Azure
- **Capacidades**:
  - Consultar VMs, VNets, NSGs, Storage Accounts
  - Obtener métricas de rendimiento
  - Revisar configuraciones de seguridad
  - Validar compliance

### 2. bicep-mcp (`@modelcontextprotocol/server-bicep`)
- **Función**: Análisis y generación de Bicep
- **Capacidades**:
  - Validar sintaxis de templates
  - Generar módulos reutilizables
  - Sugerir best practices
  - Documentar recursos

### 3. github-mcp (`@modelcontextprotocol/server-github`)
- **Función**: Gestión de repositorio GitHub
- **Capacidades**:
  - Crear issues y PRs
  - Gestionar workflows
  - Revisar código
  - Actualizar documentación

### 4. filesystem-mcp (`@modelcontextprotocol/server-filesystem`)
- **Función**: Navegación del workspace
- **Capacidades**:
  - Leer archivos de configuración
  - Analizar resultados de benchmarks JSON
  - Revisar scripts y plantillas
  - Detectar patrones del proyecto

### 5. brave-search-mcp (`@modelcontextprotocol/server-brave-search`)
- **Función**: Búsqueda web inteligente
- **Capacidades**:
  - Documentación oficial Azure actualizada
  - Benchmarks de la comunidad
  - Nuevos servicios y features
  - Pricing actualizado

### 6. memory-mcp (`@modelcontextprotocol/server-memory`)
- **Función**: Contexto persistente
- **Capacidades**:
  - Recordar decisiones arquitectónicas previas
  - Tracking de convenciones del cliente
  - Historial de conversaciones relevantes
  - Preferencias de configuración

## 📚 Comandos Útiles

### Análisis de Benchmarks

```bash
# Analizar benchmark específico
@azure-architect analiza customers/contoso/benchmarks/2025-11-25/sql_workload_*.json

# Comparar múltiples benchmarks
@azure-architect compara los benchmarks de noviembre vs octubre para el cliente fabrikam

# Identificar bottlenecks
@azure-architect qué bottlenecks hay en el último benchmark de SQLPROD01
```

### Generación de Código

```bash
# Bicep completo
@azure-architect genera infraestructura completa en Bicep para el sizing recomendado

# Scripts de despliegue
@azure-architect crea script bash para desplegar la infraestructura con validaciones

# Workflows CI/CD
@azure-architect genera GitHub Actions workflow para deploy automático a Azure
```

### Optimización

```bash
# Costos
@azure-architect cómo puedo reducir 30% el costo estimado del proyecto X

# Performance
@azure-architect qué configuración de discos maximiza IOPS sin explotar el presupuesto

# Seguridad
@azure-architect revisa la configuración de NSGs y sugiere mejoras Zero Trust
```

## 🎓 Ejemplos Prácticos

### Ejemplo 1: Análisis Completo de Cliente

```
Usuario: @azure-architect analiza el cliente contoso-manufacturing y dame un resumen ejecutivo

Agente:
📊 RESUMEN EJECUTIVO - Contoso Manufacturing

INFRAESTRUCTURA ACTUAL:
- SQL Server: SQLPROD01 (Windows Server 2019)
- CPU: 16 cores, avg utilization 45%
- RAM: 128 GB, avg utilization 68%
- IOPS: Read 2.5K, Write 800 (avg)
- Latencia disco: 8ms avg, 35ms p95

RECOMENDACIÓN AZURE:
- VM SKU: Standard_E16s_v5 (16 vCPU, 128 GB RAM)
- Discos: Premium SSD v2 (2x P40 en RAID 0)
- Región: West Europe (proximidad oficinas)
- Availability: Zone-redundant (99.99% SLA)

COSTOS (3 años):
- On-premises actual: €156,000
- Azure PAYG: €178,200
- Azure Reserved (3yr): €115,800
- AHORRO con RI: €40,200 (26%)

PRÓXIMOS PASOS:
1. Validar conectividad ExpressRoute
2. Pilot en entorno DEV
3. Plan de cutover (ventana 4h)
```

### Ejemplo 2: Generación de Bicep

```
Usuario: @azure-architect genera Bicep para SQL VM con las especificaciones del benchmark

Agente:
// main.bicep - SQL Server en Azure VM

param location string = 'westeurope'
param vmSize string = 'Standard_E16s_v5'
param sqlAdminPassword string

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {
  name: 'sql-prod-01'
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: 'sql2022-ws2022'
        sku: 'enterprise'
        version: 'latest'
      }
      dataDisks: [
        {
          lun: 0
          name: 'data-disk-01'
          diskSizeGB: 2048
          caching: 'ReadOnly'
          createOption: 'Empty'
          managedDisk: {
            storageAccountType: 'PremiumV2_LRS'
          }
        }
        // ... más configuración
      ]
    }
    // ... resto del template
  }
}
```

### Ejemplo 3: Troubleshooting

```
Usuario: @azure-architect el benchmark muestra CPU al 90% constante, ¿qué está pasando?

Agente:
🔍 DIAGNÓSTICO: CPU al 90% constante

POSIBLES CAUSAS:
1. **Queries ineficientes**: Revisa dm_exec_query_stats
2. **Falta de índices**: Analiza missing indexes DMVs
3. **Bloqueos**: Verifica wait stats (LCK_M_*)
4. **CPU Pressure**: Memory grants excesivos

ACCIONES INMEDIATAS:
```sql
-- Top 10 queries por CPU
SELECT TOP 10 
    qs.total_worker_time/qs.execution_count AS avg_cpu_time,
    qt.text AS query_text
FROM sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
ORDER BY avg_cpu_time DESC;
```

RECOMENDACIÓN AZURE:
Si el problema es capacity, considera:
- VM actual → Upgrade a serie F (optimizada CPU)
- O escalar horizontalmente (read replicas)
- Implementar Query Store para análisis histórico
```

## 🛠️ Tips y Mejores Prácticas

### Para Consultores

✅ **Usa contexto específico**: Menciona nombres de clientes, fechas de benchmarks
✅ **Pide múltiples opciones**: "Dame 3 opciones de VM con pros/cons"
✅ **Solicita justificación**: "Explica por qué elegiste Esv5 sobre Dsv5"
✅ **Genera documentación**: El agente puede crear ADRs, informes ejecutivos

### Para Arquitectos

✅ **Valida decisiones**: "Revisa este Bicep y sugiere mejoras de seguridad"
✅ **Optimiza costos**: "Cómo reducir 20% sin sacrificar SLA"
✅ **Compliance**: "Valida que esta config cumple ISO 27001"
✅ **Disaster Recovery**: "Diseña estrategia DR con RPO 1h, RTO 4h"

### Para Operaciones

✅ **Automatización**: "Crea script para backup automático de todos los clientes"
✅ **Monitoring**: "Configura alerts críticos para esta infra"
✅ **Runbooks**: "Documenta procedimiento de rollback paso a paso"
✅ **Troubleshooting**: "Diagnostica por qué falló el despliegue"

## 🚨 Limitaciones y Consideraciones

### ⚠️ El Agente NO Puede

- ❌ Ejecutar comandos directamente en servidores de producción
- ❌ Acceder a datos sensibles no explícitamente compartidos
- ❌ Realizar cambios en Azure sin aprobación
- ❌ Garantizar 100% de precisión en estimaciones de costo (precios pueden variar)

### ✅ El Agente SÍ Puede

- ✅ Analizar archivos JSON de benchmarks automáticamente
- ✅ Generar código Bicep, scripts bash, workflows
- ✅ Consultar documentación oficial Azure en tiempo real
- ✅ Recordar contexto de conversaciones anteriores (memory-mcp)
- ✅ Acceder a recursos Azure (solo lectura) si se configuran credenciales

## 📖 Referencias

- **Configuración del agente**: `.github/copilot-instructions.md`
- **MCP Servers**: `mcp.json`
- **Variables de entorno**: `.env.example`
- **Ejemplos de uso**: `docs/examples/`

## 🤝 Contribuir

Si encuentras formas de mejorar el agente:

1. Documenta el caso de uso en un Issue
2. Propón mejoras al prompt en `.github/copilot-instructions.md`
3. Comparte ejemplos exitosos en `docs/examples/`

## 📞 Soporte

- **Issues GitHub**: Para bugs o mejoras del agente
- **Discussions**: Para compartir casos de uso exitosos
- **Security**: Para vulnerabilidades, ver `SECURITY.md`

---

**Última actualización**: 2025-11-26  
**Versión del agente**: 2.0.0  
**Modo activo**: `azure-architect`
