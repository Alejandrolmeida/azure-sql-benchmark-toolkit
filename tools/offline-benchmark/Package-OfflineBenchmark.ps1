<#
.SYNOPSIS
    SQL Server Workload Monitor - Package Script (PowerShell Edition)
    
.DESCRIPTION
    Crea un paquete ZIP portable con todos los archivos necesarios para
    el offline benchmark en Windows.
    
.PARAMETER Version
    Versión del paquete (default: 2.2.0)
    
.PARAMETER OutputDir
    Directorio de salida para el ZIP (default: releases)
    
.PARAMETER IncludePython
    Incluir también scripts Python en el paquete (default: false)
    
.EXAMPLE
    .\Package-OfflineBenchmark.ps1
    
.EXAMPLE
    .\Package-OfflineBenchmark.ps1 -Version "2.2.0" -OutputDir "C:\Releases"
    
.EXAMPLE
    .\Package-OfflineBenchmark.ps1 -IncludePython
    
.NOTES
    Autor: Alejandro Almeida
    Versión: 2.2.0
    Compatible con: PowerShell 5.1+
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$Version = "2.2.0",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputDir = "releases",
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludePython
)

$ErrorActionPreference = "Stop"

$PackageName = "sql-workload-monitor-offline-powershell-v$Version"
if ($IncludePython) {
    $PackageName = "sql-workload-monitor-offline-full-v$Version"
}

# Banner
Write-Host ""
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host "  SQL SERVER WORKLOAD MONITOR - PACKAGING (POWERSHELL)" -ForegroundColor Cyan
Write-Host ("=" * 70) -ForegroundColor Cyan
Write-Host ""
Write-Host "Version:     $Version" -ForegroundColor White
Write-Host "Output:      $OutputDir\$PackageName.zip" -ForegroundColor White
Write-Host "Include:     $(if($IncludePython){'PowerShell + Python'}else{'PowerShell only'})" -ForegroundColor White
Write-Host ""

# Crear directorio temporal
$TempDir = Join-Path $env:TEMP "sql-monitor-package-$(Get-Random)"
$PackageDir = Join-Path $TempDir $PackageName

New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

# Función helper para logging
function Write-Step {
    param([string]$Message)
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host $Message -ForegroundColor Green
}

# Función para copiar archivo con validación
function Copy-PackageFile {
    param(
        [string]$Source,
        [string]$Destination
    )
    
    if (Test-Path $Source) {
        Copy-Item -Path $Source -Destination $Destination -Force
        Write-Host "  ✓ $(Split-Path $Source -Leaf)" -ForegroundColor Gray
    }
    else {
        Write-Host "  ✗ SKIP: $(Split-Path $Source -Leaf) not found" -ForegroundColor Yellow
    }
}

try {
    # [1/8] Estructura de directorios
    Write-Step "[1/8] Creating package structure..."
    @('scripts', 'docs', 'output', 'checkpoints', 'logs') | ForEach-Object {
        New-Item -ItemType Directory -Path (Join-Path $PackageDir $_) -Force | Out-Null
    }
    Write-Host "  ✓ Directory structure created" -ForegroundColor Gray
    Write-Host ""

    # [2/8] Scripts PowerShell
    Write-Step "[2/8] Copying PowerShell scripts..."
    Copy-PackageFile "scripts\Monitor-SQLWorkload.ps1" "$PackageDir\scripts\"
    Copy-PackageFile "scripts\Check-MonitoringStatus.ps1" "$PackageDir\scripts\"
    Copy-PackageFile "scripts\workload-sample-query.sql" "$PackageDir\scripts\"
    Write-Host ""

    # [2b/8] Scripts Python (opcional)
    if ($IncludePython) {
        Write-Step "[2b/8] Copying Python scripts..."
        Copy-PackageFile "scripts\monitor_sql_workload.py" "$PackageDir\scripts\"
        Copy-PackageFile "scripts\check_monitoring_status.py" "$PackageDir\scripts\"
        Copy-PackageFile "scripts\diagnose_monitoring.py" "$PackageDir\scripts\"
        Copy-PackageFile "scripts\Generate-SQLWorkload.py" "$PackageDir\scripts\"
        Copy-PackageFile "INSTALL.py" "$PackageDir\"
        Write-Host ""
    }

    # [3/8] Instalador PowerShell
    Write-Step "[3/8] Copying installer..."
    Copy-PackageFile "INSTALL.ps1" "$PackageDir\"
    Write-Host ""

    # [4/8] Documentación
    Write-Step "[4/8] Copying documentation..."
    Copy-PackageFile "README-PowerShell.md" "$PackageDir\README.md"
    Copy-PackageFile "docs\INSTALLATION-PowerShell.md" "$PackageDir\docs\"
    Copy-PackageFile "docs\USAGE-PowerShell.md" "$PackageDir\docs\"
    
    if ($IncludePython) {
        Copy-PackageFile "README.md" "$PackageDir\README-Python.md"
        Copy-PackageFile "docs\INSTALLATION.md" "$PackageDir\docs\INSTALLATION-Python.md"
        Copy-PackageFile "docs\USAGE.md" "$PackageDir\docs\USAGE-Python.md"
    }
    Write-Host ""

    # [5/8] VERSION file
    Write-Step "[5/8] Creating VERSION file..."
    $Version | Out-File -FilePath (Join-Path $PackageDir "VERSION") -Encoding UTF8
    Write-Host "  ✓ VERSION" -ForegroundColor Gray
    Write-Host ""

    # [6/8] PACKAGE_INFO.txt
    Write-Step "[6/8] Creating package info..."
    $PackageInfo = @"
===================================================================
SQL Server Workload Monitor - Offline Edition (PowerShell)
===================================================================

Version:     $Version
Package:     $PackageName.zip
Created:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Platform:    Windows Server 2016+ / Windows 10+
PowerShell:  5.1+ (included in Windows Server 2016+)

Contents:
  - Monitor-SQLWorkload.ps1       : Main monitoring script (PowerShell)
  - Check-MonitoringStatus.ps1    : Status checker (PowerShell)
  - workload-sample-query.sql     : External SQL query
  - INSTALL.ps1                   : Automated installer (PowerShell)
  - README.md                     : Complete documentation (PowerShell)
  - docs/                         : Additional guides
$(if($IncludePython){@"
  
  Python Edition (also included):
  - monitor_sql_workload.py       : Main monitoring script (Python)
  - check_monitoring_status.py    : Status checker (Python)
  - diagnose_monitoring.py        : Diagnostic tool (Python)
  - Generate-SQLWorkload.py       : Workload generator (Python)
  - INSTALL.py                    : Automated installer (Python)
  - README-Python.md              : Python documentation
"@}else{""})

Installation (PowerShell - RECOMMENDED):
  1. Unzip package on Windows Server with SQL Server
  2. Open PowerShell (no admin required)
  3. cd sql-workload-monitor-offline-powershell-v$Version
  4. .\INSTALL.ps1

Quick Start:
  .\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -Interval 60

$(if($IncludePython){@"
Installation (Python - ALTERNATIVE):
  1. Unzip package
  2. Install Python 3.8+ and ODBC Driver 17
  3. pip install -r requirements.txt
  4. python INSTALL.py

Quick Start (Python):
  python scripts\monitor_sql_workload.py --server . --duration 15 --interval 60

"@}else{""})
Requirements:
  - Windows Server 2012 R2+ / Windows 10+
  - PowerShell 5.1+ (included in Windows Server 2016+)
  - SQL Server 2012+ (local or remote)
  - Network access to SQL Server instance
  - Permissions: VIEW SERVER STATE or sysadmin

Dependencies (auto-installed):
  - SqlServer PowerShell module (installed by INSTALL.ps1)

No Python, Bash, or WSL required!

For full documentation, see README.md

License: MIT
Project: Azure SQL Benchmark Toolkit
Repository: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit

===================================================================
"@

    $PackageInfo | Out-File -FilePath (Join-Path $PackageDir "PACKAGE_INFO.txt") -Encoding UTF8
    Write-Host "  ✓ PACKAGE_INFO.txt" -ForegroundColor Gray
    Write-Host ""

    # [6b/8] requirements.txt (si incluye Python)
    if ($IncludePython) {
        Write-Step "[6b/8] Creating requirements.txt (Python)..."
        @"
pyodbc>=5.0.0
"@ | Out-File -FilePath (Join-Path $PackageDir "requirements.txt") -Encoding UTF8
        Write-Host "  ✓ requirements.txt" -ForegroundColor Gray
        Write-Host ""
    }

    # [7/8] Crear ZIP
    Write-Step "[7/8] Creating ZIP package..."
    
    # Crear directorio de salida si no existe
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }
    
    $ZipPath = Join-Path (Resolve-Path $OutputDir).Path "$PackageName.zip"
    
    # Eliminar ZIP existente si existe
    if (Test-Path $ZipPath) {
        Remove-Item $ZipPath -Force
    }
    
    # Comprimir (PowerShell 5.0+)
    Add-Type -Assembly System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($PackageDir, $ZipPath)
    
    Write-Host "  ✓ ZIP created" -ForegroundColor Gray
    Write-Host ""

    # [8/8] Calcular hash
    Write-Step "[8/8] Calculating integrity hash..."
    $Hash = Get-FileHash -Path $ZipPath -Algorithm SHA256
    Write-Host "  ✓ SHA256 calculated" -ForegroundColor Gray
    Write-Host ""

    # Información final
    $FileSize = (Get-Item $ZipPath).Length
    $FileSizeMB = [math]::Round($FileSize / 1MB, 2)

    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host "  PACKAGING COMPLETE" -ForegroundColor Green
    Write-Host ("=" * 70) -ForegroundColor Green
    Write-Host ""
    Write-Host "Package:     " -NoNewline -ForegroundColor White
    Write-Host "$PackageName.zip" -ForegroundColor Cyan
    Write-Host "Location:    " -NoNewline -ForegroundColor White
    Write-Host "$OutputDir\" -ForegroundColor Cyan
    Write-Host "Size:        " -NoNewline -ForegroundColor White
    Write-Host "$FileSizeMB MB ($FileSize bytes)" -ForegroundColor Cyan
    Write-Host ""
    
    Write-Host "Contents:" -ForegroundColor Yellow
    Add-Type -Assembly System.IO.Compression.FileSystem
    $Zip = [System.IO.Compression.ZipFile]::OpenRead($ZipPath)
    $Zip.Entries | Select-Object -First 15 | ForEach-Object {
        $SizeKB = [math]::Round($_.Length / 1KB, 1)
        Write-Host "  $($_.FullName) ($SizeKB KB)" -ForegroundColor Gray
    }
    if ($Zip.Entries.Count -gt 15) {
        Write-Host "  ... and $($Zip.Entries.Count - 15) more files" -ForegroundColor Gray
    }
    $Zip.Dispose()
    Write-Host ""
    
    Write-Host "Distribution Options:" -ForegroundColor Yellow
    Write-Host "  ✓ Upload to GitHub Releases" -ForegroundColor White
    Write-Host "  ✓ Copy to file share (SMB/CIFS)" -ForegroundColor White
    Write-Host "  ✓ Email to DBAs (if < 25 MB)" -ForegroundColor White
    Write-Host "  ✓ Transfer via USB/pendrive" -ForegroundColor White
    Write-Host "  ✓ Internal package repository" -ForegroundColor White
    Write-Host ""
    
    Write-Host "Integrity Check:" -ForegroundColor Yellow
    Write-Host "  Algorithm: SHA256" -ForegroundColor White
    Write-Host "  Hash:      $($Hash.Hash)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  PowerShell verification:" -ForegroundColor Gray
    Write-Host "  `$hash = Get-FileHash '$ZipPath' -Algorithm SHA256" -ForegroundColor DarkGray
    Write-Host "  `$hash.Hash -eq '$($Hash.Hash)'" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "Next Steps:" -ForegroundColor Yellow
    Write-Host "  1. Test package on clean Windows Server" -ForegroundColor White
    Write-Host "  2. Verify INSTALL.ps1 runs successfully" -ForegroundColor White
    Write-Host "  3. Run Monitor-SQLWorkload.ps1 test (5 min)" -ForegroundColor White
    Write-Host "  4. Distribute to target SQL Servers" -ForegroundColor White
    Write-Host ""
}
catch {
    Write-Host ""
    Write-Host "ERROR: Packaging failed" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ""
    exit 1
}
finally {
    # Limpiar directorio temporal
    if (Test-Path $TempDir) {
        Remove-Item -Path $TempDir -Recurse -Force
    }
}

Write-Host "✓ Package ready for distribution!" -ForegroundColor Green
Write-Host ""
