<#
.SYNOPSIS
    Empaqueta los scripts de monitorización para despliegue manual en servidor on-premises.

.DESCRIPTION
    Crea un paquete ZIP autocontenido con:
    - Scripts de monitorización
    - Script de instalación automatizado
    - Documentación paso a paso
    - Verificación de requisitos
    
    Ideal para servidores sin conexión a Azure o internet.

.PARAMETER OutputPath
    Ruta donde se creará el paquete ZIP (default: escritorio del usuario)

.PARAMETER IncludeDocumentation
    Incluir documentación completa en el paquete

.EXAMPLE
    .\package-monitoring-deployment.ps1
    Crea paquete en el escritorio con configuración por defecto

.EXAMPLE
    .\package-monitoring-deployment.ps1 -OutputPath "C:\Packages" -IncludeDocumentation
    Crea paquete con documentación en ruta específica

.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 19, 2025
    Uso: Para despliegue en entornos on-premises sin conectividad Azure
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeDocumentation
)

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "║   📦 SQL Server Monitoring - Package for On-Premises Deployment             ║" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Determine output path
if (-not $OutputPath) {
    if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
        $OutputPath = [Environment]::GetFolderPath("Desktop")
    } else {
        $OutputPath = $HOME
    }
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$packageName = "SQLMonitoring_OnPremises_$timestamp"

# Use temp directory compatible with the current OS
if ($IsWindows -or ($PSVersionTable.PSVersion.Major -le 5)) {
    $tempDir = Join-Path $env:TEMP $packageName
} else {
    # Linux/macOS: use /tmp with proper path
    $tempDir = "/tmp/$packageName"
}

$zipPath = Join-Path $OutputPath "$packageName.zip"

Write-Host "📂 Configuración del paquete:" -ForegroundColor Yellow
Write-Host "   Directorio temporal: $tempDir" -ForegroundColor Gray
Write-Host "   Paquete final:       $zipPath" -ForegroundColor Gray
Write-Host ""

# Create temp directory
Write-Host "📁 Creando estructura de directorios..." -ForegroundColor Yellow
if (Test-Path $tempDir) {
    Remove-Item $tempDir -Recurse -Force
}
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir "scripts") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $tempDir "docs") -Force | Out-Null
Write-Host "✅ Estructura creada" -ForegroundColor Green
Write-Host ""

# Copy monitoring scripts
Write-Host "📄 Copiando scripts de monitorización..." -ForegroundColor Yellow

$scriptsDir = $PSScriptRoot
$requiredScripts = @(
    "sql-workload-monitor-extended.ps1",
    "launch-workload-monitor-task.ps1",
    "check-monitoring-status.ps1",
    "diagnose-monitoring.ps1"
)

$copiedScripts = 0
foreach ($script in $requiredScripts) {
    $sourcePath = Join-Path $scriptsDir $script
    if (Test-Path $sourcePath) {
        Copy-Item $sourcePath -Destination (Join-Path $tempDir "scripts" $script) -Force
        Write-Host "   ✅ $script" -ForegroundColor Gray
        $copiedScripts++
    } else {
        Write-Host "   ⚠️  $script (no encontrado)" -ForegroundColor Yellow
    }
}
Write-Host "✅ $copiedScripts scripts copiados" -ForegroundColor Green
Write-Host ""

# Copy documentation if requested
if ($IncludeDocumentation) {
    Write-Host "📖 Copiando documentación..." -ForegroundColor Yellow
    
    $docsToInclude = @(
        "MONITORING_GUIDE.md",
        "EXAMPLE_OUTPUT.md",
        "README.md"
    )
    
    foreach ($doc in $docsToInclude) {
        $sourcePath = Join-Path $scriptsDir $doc
        if (Test-Path $sourcePath) {
            Copy-Item $sourcePath -Destination (Join-Path $tempDir "docs" $doc) -Force
            Write-Host "   ✅ $doc" -ForegroundColor Gray
        }
    }
    Write-Host "✅ Documentación incluida" -ForegroundColor Green
    Write-Host ""
}

# Create automated installer script
Write-Host "🔧 Generando script de instalación automatizado..." -ForegroundColor Yellow

$installerContent = @'
<#
.SYNOPSIS
    Instalador automatizado para SQL Server Workload Monitoring (On-Premises)

.DESCRIPTION
    Este script:
    1. Verifica requisitos del sistema
    2. Crea estructura de directorios
    3. Instala scripts de monitorización
    4. Lanza monitoreo de 48 horas
    5. Configura Task Scheduler para persistencia

.PARAMETER ServerInstance
    Nombre de la instancia SQL Server (default: nombre del servidor)

.PARAMETER Duration
    Duración del monitoreo en minutos (default: 2880 = 48 horas)

.PARAMETER SampleInterval
    Intervalo entre muestras en segundos (default: 120 = 2 minutos)

.PARAMETER InstallOnly
    Solo instala scripts sin ejecutar monitoreo

.EXAMPLE
    .\INSTALL.ps1
    Instala y ejecuta monitoreo con valores por defecto

.EXAMPLE
    .\INSTALL.ps1 -ServerInstance "SQLSERVER01" -Duration 1440
    Monitoreo de 24 horas en instancia específica

.EXAMPLE
    .\INSTALL.ps1 -InstallOnly
    Solo instala scripts sin ejecutar
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = $env:COMPUTERNAME,
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 2880,
    
    [Parameter(Mandatory=$false)]
    [int]$SampleInterval = 120,
    
    [Parameter(Mandatory=$false)]
    [switch]$InstallOnly
)

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "║   🚀 SQL Server Workload Monitor - Instalación On-Premises                  ║" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar privilegios de administrador
Write-Host "🔍 Verificando privilegios de administrador..." -ForegroundColor Yellow
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ERROR: Se requieren privilegios de Administrador" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Solución:" -ForegroundColor Yellow
    Write-Host "   1. Cierra esta ventana de PowerShell" -ForegroundColor White
    Write-Host "   2. Haz clic derecho en PowerShell → 'Ejecutar como administrador'" -ForegroundColor White
    Write-Host "   3. Ejecuta este script nuevamente" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-Host "✅ Privilegios correctos" -ForegroundColor Green
Write-Host ""

# 2. Verificar versión de PowerShell
Write-Host "🔍 Verificando versión de PowerShell..." -ForegroundColor Yellow
$psVersion = $PSVersionTable.PSVersion
Write-Host "   Versión detectada: $($psVersion.Major).$($psVersion.Minor)" -ForegroundColor Gray

if ($psVersion.Major -lt 5) {
    Write-Host "⚠️  WARNING: PowerShell version < 5.0 puede tener problemas" -ForegroundColor Yellow
    Write-Host "   Recomendado: PowerShell 5.1 o superior" -ForegroundColor Gray
    $continue = Read-Host "¿Continuar de todos modos? (S/N)"
    if ($continue -ne "S") {
        exit 1
    }
}
Write-Host "✅ Versión compatible" -ForegroundColor Green
Write-Host ""

# 3. Verificar conectividad SQL Server
Write-Host "🔍 Verificando conectividad a SQL Server..." -ForegroundColor Yellow
Write-Host "   Instancia: $ServerInstance" -ForegroundColor Gray

try {
    $sqlTest = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT @@VERSION AS Version" -ErrorAction Stop
    Write-Host "✅ Conectividad SQL OK" -ForegroundColor Green
    Write-Host "   $($sqlTest.Version.Split("`n")[0])" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "❌ ERROR: No se puede conectar a SQL Server" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Posibles causas:" -ForegroundColor Yellow
    Write-Host "   - Instancia incorrecta (actual: $ServerInstance)" -ForegroundColor White
    Write-Host "   - Servicio SQL Server no está corriendo" -ForegroundColor White
    Write-Host "   - Permisos insuficientes (requiere VIEW SERVER STATE)" -ForegroundColor White
    Write-Host ""
    exit 1
}

# 4. Crear estructura de directorios
Write-Host "📁 Creando estructura de directorios..." -ForegroundColor Yellow

$baseDir = "C:\AzureMigration"
$assessmentDir = Join-Path $baseDir "Assessment"
$scriptsDir = Join-Path $baseDir "Scripts"

@($baseDir, $assessmentDir, $scriptsDir) | ForEach-Object {
    if (-not (Test-Path $_)) {
        New-Item -ItemType Directory -Path $_ -Force | Out-Null
        Write-Host "   ✅ $_" -ForegroundColor Gray
    } else {
        Write-Host "   ℹ️  $_ (ya existe)" -ForegroundColor Gray
    }
}
Write-Host "✅ Directorios listos" -ForegroundColor Green
Write-Host ""

# 5. Copiar scripts
Write-Host "📄 Instalando scripts de monitorización..." -ForegroundColor Yellow

$currentDir = $PSScriptRoot
$scriptsToCopy = Get-ChildItem (Join-Path $currentDir "scripts") -Filter "*.ps1"

foreach ($script in $scriptsToCopy) {
    $destPath = Join-Path $scriptsDir $script.Name
    Copy-Item $script.FullName -Destination $destPath -Force
    Write-Host "   ✅ $($script.Name)" -ForegroundColor Gray
}
Write-Host "✅ Scripts instalados en: $scriptsDir" -ForegroundColor Green
Write-Host ""

# 6. Copiar documentación (si existe)
$docsDir = Join-Path $currentDir "docs"
if (Test-Path $docsDir) {
    Write-Host "📖 Instalando documentación..." -ForegroundColor Yellow
    $docsDestDir = Join-Path $baseDir "Documentation"
    if (-not (Test-Path $docsDestDir)) {
        New-Item -ItemType Directory -Path $docsDestDir -Force | Out-Null
    }
    
    Get-ChildItem $docsDir -Filter "*.md" | ForEach-Object {
        Copy-Item $_.FullName -Destination (Join-Path $docsDestDir $_.Name) -Force
        Write-Host "   ✅ $($_.Name)" -ForegroundColor Gray
    }
    Write-Host "✅ Documentación instalada en: $docsDestDir" -ForegroundColor Green
    Write-Host ""
}

Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "║   ✅ INSTALACIÓN COMPLETADA EXITOSAMENTE                                     ║" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

if ($InstallOnly) {
    Write-Host "ℹ️  Modo solo instalación (-InstallOnly). Scripts listos para uso manual." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📋 Para ejecutar monitoreo:" -ForegroundColor Yellow
    Write-Host "   cd $scriptsDir" -ForegroundColor Cyan
    Write-Host "   .\launch-workload-monitor-task.ps1 -ServerInstance '$ServerInstance' -Duration $Duration" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

# 7. Lanzar monitoreo automáticamente
Write-Host "🚀 Iniciando monitoreo de 48 horas..." -ForegroundColor Yellow
Write-Host ""
Write-Host "   Instancia SQL:    $ServerInstance" -ForegroundColor White
Write-Host "   Duración:         $Duration minutos ($([math]::Round($Duration/60, 1)) horas)" -ForegroundColor White
Write-Host "   Intervalo:        $SampleInterval segundos" -ForegroundColor White
Write-Host "   Directorio salida: $assessmentDir" -ForegroundColor White
Write-Host ""

$launcherScript = Join-Path $scriptsDir "launch-workload-monitor-task.ps1"

if (-not (Test-Path $launcherScript)) {
    Write-Host "❌ ERROR: Script launcher no encontrado" -ForegroundColor Red
    Write-Host "   Ruta esperada: $launcherScript" -ForegroundColor Yellow
    exit 1
}

try {
    & $launcherScript -ServerInstance $ServerInstance -Duration $Duration -SampleInterval $SampleInterval -OutputPath $assessmentDir
    
    Write-Host ""
    Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║                                                                              ║" -ForegroundColor Green
    Write-Host "║   ✅ MONITOREO INICIADO CORRECTAMENTE                                        ║" -ForegroundColor Green
    Write-Host "║                                                                              ║" -ForegroundColor Green
    Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "📊 El monitoreo se ejecutará durante las próximas $([math]::Round($Duration/60)) horas" -ForegroundColor Cyan
    Write-Host "   Finalización estimada: $((Get-Date).AddMinutes($Duration).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host ""
    
    Write-Host "📋 Comandos útiles:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   # Verificar estado del monitoreo" -ForegroundColor White
    Write-Host "   Get-ScheduledTask | Where-Object {{`$_.TaskName -like 'SQLWorkloadMonitor*'}}" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # Ver log en tiempo real" -ForegroundColor White
    Write-Host "   Get-Content $assessmentDir\task_log_*.txt -Wait -Tail 20" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   # Verificar progreso con script de diagnóstico" -ForegroundColor White
    Write-Host "   cd $scriptsDir" -ForegroundColor Cyan
    Write-Host "   .\check-monitoring-status.ps1" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "🎯 Resultados se generarán en: $assessmentDir" -ForegroundColor Yellow
    Write-Host "   - sql_workload_extended_*.html (reporte visual)" -ForegroundColor Gray
    Write-Host "   - sql_workload_extended_*.json (datos completos)" -ForegroundColor Gray
    Write-Host ""
}
catch {
    Write-Host "❌ ERROR al lanzar monitoreo" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
'@

$installerPath = Join-Path $tempDir "INSTALL.ps1"
Set-Content -Path $installerPath -Value $installerContent -Encoding UTF8
Write-Host "✅ Script de instalación generado" -ForegroundColor Green
Write-Host ""

# Create README with instructions
Write-Host "📝 Generando instrucciones de despliegue..." -ForegroundColor Yellow

$readmeContent = @"
# SQL Server Workload Monitor - Despliegue On-Premises

📅 Paquete generado: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## 🎯 Propósito

Este paquete contiene todo lo necesario para ejecutar una monitorización extendida (24-48 horas) de SQL Server en un entorno **on-premises sin conexión a Azure**.

## 📦 Contenido del Paquete

```
SQLMonitoring_OnPremises_$timestamp/
├── INSTALL.ps1                           # Script de instalación automatizado ⭐
├── LEEME.txt                             # Este archivo
├── scripts/
│   ├── sql-workload-monitor-extended.ps1 # Monitor principal
│   ├── launch-workload-monitor-task.ps1  # Launcher con Task Scheduler
│   ├── check-monitoring-status.ps1       # Verificación de progreso
│   └── diagnose-monitoring.ps1           # Diagnóstico de problemas
└── docs/                                  # Documentación completa
    ├── MONITORING_GUIDE.md
    ├── EXAMPLE_OUTPUT.md
    └── README.md
```

## 🚀 Instalación Rápida (Recomendado)

### 1. Copiar paquete al servidor

Transfiere este archivo ZIP al servidor SQL Server on-premises usando:
- 🔹 Unidad USB
- 🔹 Carpeta compartida de red
- 🔹 RDP (copiar/pegar)
- 🔹 Herramienta de transferencia corporativa

### 2. Extraer contenido

```powershell
# En el servidor SQL Server
Expand-Archive -Path "C:\Temp\$packageName.zip" -DestinationPath "C:\Temp\SQLMonitoring"
cd C:\Temp\SQLMonitoring
```

### 3. Ejecutar instalador automatizado

```powershell
# Abrir PowerShell como ADMINISTRADOR
# Ejecutar:
.\INSTALL.ps1
```

El instalador hará **TODO automáticamente**:
✅ Verifica requisitos (PowerShell, SQL Server, permisos)
✅ Crea estructura de directorios (C:\AzureMigration\)
✅ Instala scripts de monitorización
✅ Lanza monitoreo de 48 horas con Task Scheduler
✅ Configura persistencia (sobrevive a reinicios)

**Tiempo de instalación**: ~2 minutos

## ⚙️ Opciones de Instalación

### Monitoreo personalizado

```powershell
# 24 horas en lugar de 48
.\INSTALL.ps1 -Duration 1440

# Instancia SQL específica
.\INSTALL.ps1 -ServerInstance "SERVIDOR01\INSTANCIA02"

# Solo instalar scripts (sin ejecutar monitoreo)
.\INSTALL.ps1 -InstallOnly
```

### Ejecución manual (sin instalador)

```powershell
# Extraer scripts
cd C:\Temp\SQLMonitoring\scripts

# Ejecutar directamente
.\launch-workload-monitor-task.ps1 -ServerInstance "MISERVIDOR" -Duration 2880
```

## 📊 Durante el Monitoreo (48 horas)

### Verificar estado

```powershell
# Ver tarea programada
Get-ScheduledTask | Where-Object {`$_.TaskName -like "SQLWorkloadMonitor*"}

# Ver log en tiempo real
Get-Content C:\AzureMigration\Assessment\task_log_*.txt -Wait -Tail 20

# Script de diagnóstico completo
cd C:\AzureMigration\Scripts
.\check-monitoring-status.ps1
```

### El monitoreo:
- ✅ Se ejecuta en **background** (no bloquea terminal)
- ✅ Sobrevive a **cierres de sesión RDP**
- ✅ Sobrevive a **reinicios del servidor** (se reanuda automáticamente)
- ✅ Genera **checkpoints cada hora** para recuperación
- ✅ No afecta al rendimiento de SQL Server (impacto <1%)

## 📈 Resultados

### Ubicación de archivos

```
C:\AzureMigration\Assessment\
├── sql_workload_extended_YYYYMMDD_HHMMSS.html   # Reporte visual ⭐
├── sql_workload_extended_YYYYMMDD_HHMMSS.json   # Datos completos
├── checkpoint_*.json                             # Checkpoints de progreso
└── task_log_*.txt                                # Log de ejecución
```

### Reporte HTML incluye:

📊 **Estadísticas Globales**
- CPU: Average, Peak, P95
- Memoria: Average, Peak, P95
- Disk IOPS: Average, Peak, P95
- User Activity: Conexiones, transacciones

📈 **Análisis por Hora**
- 24-48 tablas (una por hora)
- Identificación automática de horas pico

☁️ **Recomendaciones Azure**
- VM SKU optimizado (E-series memory-optimized)
- Disk configuration (Premium SSD/Ultra Disk)
- Estimación de costos mensuales (€)
- Comparación vs sizing por hardware

💰 **Ahorro de Costos**
- Comparativa hardware vs workload sizing
- Porcentaje de ahorro (típicamente 30-50%)
- ROI de la migración

### Transferir resultados de vuelta

Una vez completado el monitoreo:

1. **Comprimir resultados**:
   ```powershell
   Compress-Archive -Path "C:\AzureMigration\Assessment\*" -DestinationPath "C:\Temp\ResultadosMonitoreo.zip"
   ```

2. **Transferir ZIP** usando mismo método que para el paquete inicial:
   - USB
   - Carpeta compartida
   - RDP
   - Email (si tamaño lo permite, típicamente <5 MB)

3. **Abrir HTML** en cualquier navegador

## 🔧 Requisitos del Sistema

### Servidor SQL Server

| Requisito | Valor Mínimo | Recomendado |
|-----------|--------------|-------------|
| **Windows** | Server 2012 R2 | Server 2016+ |
| **PowerShell** | 5.1 | 7.x |
| **SQL Server** | 2012 | 2016+ |
| **Permisos SQL** | VIEW SERVER STATE | sysadmin |
| **Espacio disco** | 50 MB | 100 MB |
| **RAM disponible** | 100 MB | 256 MB |

### Usuario que ejecuta

- ✅ **Administrador local** del servidor Windows
- ✅ Permisos **VIEW SERVER STATE** en SQL Server (o sysadmin)
- ✅ Acceso a crear **Tareas Programadas** (Task Scheduler)

## ❓ Troubleshooting

### Error: "No se puede conectar a SQL Server"

**Causa**: Instancia incorrecta o servicio SQL Server detenido

**Solución**:
```powershell
# Verificar instancias SQL disponibles
Get-Service | Where-Object {`$_.Name -like "MSSQL*"}

# Verificar conectividad
Invoke-Sqlcmd -ServerInstance "MISERVIDOR" -Query "SELECT @@VERSION"
```

### Error: "Se requieren privilegios de Administrador"

**Solución**: Cerrar PowerShell y abrir como **Administrador**
- Clic derecho en PowerShell → "Ejecutar como administrador"

### Monitoreo no genera archivos

**Diagnóstico**:
```powershell
cd C:\AzureMigration\Scripts
.\diagnose-monitoring.ps1
```

Este script:
- ✅ Busca procesos activos
- ✅ Verifica tareas programadas
- ✅ Localiza archivos de log
- ✅ Identifica errores comunes

## 📞 Soporte

Para consultas o problemas:
1. Revisar **docs/MONITORING_GUIDE.md** (guía completa)
2. Revisar **docs/EXAMPLE_OUTPUT.md** (ejemplos de salidas esperadas)
3. Ejecutar **diagnose-monitoring.ps1** y enviar output
4. Contactar con el equipo de Azure Architect Pro

---

## 📚 Documentación Adicional

Si se incluyó documentación completa en el paquete (carpeta `docs/`):

- **MONITORING_GUIDE.md**: Guía paso a paso completa (450+ líneas)
- **EXAMPLE_OUTPUT.md**: Ejemplos reales de outputs (550+ líneas)
- **README.md**: Referencia rápida de scripts

---

## ✅ Checklist de Despliegue

- [ ] Paquete transferido al servidor SQL Server
- [ ] ZIP extraído en C:\Temp\SQLMonitoring
- [ ] PowerShell abierto como Administrador
- [ ] Ejecutado INSTALL.ps1
- [ ] Verificado que Task está corriendo (Get-ScheduledTask)
- [ ] Confirmado que task_log se está escribiendo
- [ ] Anotada fecha/hora de finalización estimada
- [ ] Configurado recordatorio para recoger resultados

---

**¡Listo para ejecutar monitoreo extendido en tu SQL Server on-premises! 🚀**

Generated by: Azure Architect Pro - Alejandro Almeida
Package Date: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

$readmePath = Join-Path $tempDir "LEEME.txt"
Set-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
Write-Host "✅ Instrucciones generadas" -ForegroundColor Green
Write-Host ""

# Create ZIP package
Write-Host "📦 Creando paquete ZIP..." -ForegroundColor Yellow

try {
    Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -Force
    Write-Host "✅ Paquete creado exitosamente" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "❌ ERROR al crear ZIP" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

# Clean up temp directory
try {
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force -ErrorAction Stop
    }
}
catch {
    # Silently ignore cleanup errors - package already created
    Write-Verbose "Temp directory cleanup skipped: $($_.Exception.Message)"
}

# Get package size
$packageSize = (Get-Item $zipPath).Length
$packageSizeMB = [math]::Round($packageSize / 1MB, 2)

Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "║   ✅ PAQUETE CREADO EXITOSAMENTE                                             ║" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📦 Información del paquete:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   Ubicación:  $zipPath" -ForegroundColor Cyan
Write-Host "   Tamaño:     $packageSizeMB MB" -ForegroundColor Cyan
Write-Host "   Scripts:    $copiedScripts archivos" -ForegroundColor Cyan
if ($IncludeDocumentation) {
    Write-Host "   Docs:       Incluidas" -ForegroundColor Cyan
}
Write-Host ""
Write-Host "📋 Próximos pasos:" -ForegroundColor Yellow
Write-Host ""
Write-Host "   1. Transferir ZIP al servidor on-premises:" -ForegroundColor White
Write-Host "      - Usar USB, carpeta compartida, RDP, o email" -ForegroundColor Gray
Write-Host ""
Write-Host "   2. En el servidor SQL Server:" -ForegroundColor White
Write-Host "      Expand-Archive -Path 'C:\Temp\$packageName.zip' -DestinationPath 'C:\Temp\SQLMonitoring'" -ForegroundColor Cyan
Write-Host "      cd C:\Temp\SQLMonitoring" -ForegroundColor Cyan
Write-Host "      .\INSTALL.ps1" -ForegroundColor Cyan
Write-Host ""
Write-Host "   3. El instalador hará TODO automáticamente:" -ForegroundColor White
Write-Host "      ✅ Verificar requisitos" -ForegroundColor Gray
Write-Host "      ✅ Instalar scripts en C:\AzureMigration\" -ForegroundColor Gray
Write-Host "      ✅ Lanzar monitoreo 48 horas" -ForegroundColor Gray
Write-Host "      ✅ Configurar Task Scheduler" -ForegroundColor Gray
Write-Host ""
Write-Host "   4. Esperar 48 horas y recoger resultados de:" -ForegroundColor White
Write-Host "      C:\AzureMigration\Assessment\sql_workload_extended_*.html" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Consejo:" -ForegroundColor Yellow
Write-Host "   El archivo LEEME.txt en el ZIP contiene instrucciones completas" -ForegroundColor Gray
Write-Host ""
