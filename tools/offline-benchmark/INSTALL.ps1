<#
.SYNOPSIS
    Instalador de SQL Server Workload Monitor (PowerShell Edition)
    
.DESCRIPTION
    Verifica e instala dependencias necesarias para el monitor de SQL Server.
    Basado en el proyecto funcional SQLMonitoring_OnPremises_v2.
    
    Checks realizados:
    1. PowerShell 5.1+ o PowerShell 7+
    2. Módulo SqlServer instalado
    3. Conectividad con SQL Server
    4. Permisos VIEW SERVER STATE
    5. Archivo workload-sample-query.sql
    6. Test de ejecución de query
    7. Espacio en disco
    8. Configuración Task Scheduler (opcional)
    
.PARAMETER ServerInstance
    Instancia SQL Server para probar (default: ".")
    
.PARAMETER Username
    Usuario SQL (si se usa SQL Authentication)
    
.PARAMETER Password
    Password SQL (si se usa SQL Authentication)
    
.EXAMPLE
    .\INSTALL.ps1
    
.EXAMPLE
    .\INSTALL.ps1 -ServerInstance "MYSERVER\SQL2022"
    
.EXAMPLE
    .\INSTALL.ps1 -ServerInstance "." -Username "sa" -Password "P@ssw0rd"
    
.NOTES
    Autor: Alejandro Almeida
    Versión: 2.1.0
    Basado en: SQLMonitoring_OnPremises_v2 (funcional 100%)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Password
)

$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"

# Banner
$Banner = @"

====================================================================
  INSTALADOR - SQL SERVER WORKLOAD MONITOR (POWERSHELL)
  Azure SQL Benchmark Toolkit v2.1.0
====================================================================

"@

Write-Host $Banner -ForegroundColor Cyan

# Variables globales
$script:ChecksPassed = 0
$script:ChecksFailed = 0
$script:ChecksWarning = 0

# Logging mejorado
function Write-LogMessage {
    param(
        [string]$Message,
        [ValidateSet("INFO", "OK", "FAIL", "DEBUG", "WARN")]
        [string]$Level = "INFO"
    )
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch($Level) {
        "OK"    { "Green" }
        "FAIL"  { "Red" }
        "WARN"  { "Yellow" }
        "DEBUG" { "Gray" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

function Write-CheckHeader {
    param([string]$CheckName)
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host " CHECK: $CheckName" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor DarkGray
}

function Update-CheckCounter {
    param([ValidateSet("PASS", "FAIL", "WARN")][string]$Result)
    
    switch ($Result) {
        "PASS" { $script:ChecksPassed++ }
        "FAIL" { $script:ChecksFailed++ }
        "WARN" { $script:ChecksWarning++ }
    }
}

# ================================================================================
# CHECK 1: PowerShell Version
# ================================================================================
function Test-PowerShellVersion {
    Write-CheckHeader "PowerShell Version"
    
    try {
        $psVersion = $PSVersionTable.PSVersion
        Write-LogMessage "PowerShell Version: $psVersion" "INFO"
        
        if ($psVersion.Major -ge 7) {
            Write-LogMessage "PowerShell 7+ detected" "OK"
            Update-CheckCounter "PASS"
            return $true
        }
        elseif ($psVersion.Major -eq 5 -and $psVersion.Minor -ge 1) {
            Write-LogMessage "PowerShell 5.1 detected (compatible)" "OK"
            Update-CheckCounter "PASS"
            return $true
        }
        else {
            Write-LogMessage "PowerShell $psVersion is too old (required: 5.1+)" "FAIL"
            Write-LogMessage "Upgrade to PowerShell 7: https://aka.ms/powershell" "INFO"
            Update-CheckCounter "FAIL"
            return $false
        }
    }
    catch {
        Write-LogMessage "Failed to check PowerShell version: $_" "FAIL"
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# CHECK 2: SqlServer Module
# ================================================================================
function Test-SqlServerModule {
    Write-CheckHeader "SqlServer Module"
    
    try {
        $module = Get-Module -ListAvailable -Name SqlServer | Sort-Object Version -Descending | Select-Object -First 1
        
        if ($module) {
            Write-LogMessage "SqlServer module found: v$($module.Version)" "OK"
            Import-Module SqlServer -ErrorAction Stop
            Write-LogMessage "Module imported successfully" "OK"
            Update-CheckCounter "PASS"
            return $true
        }
        else {
            Write-LogMessage "SqlServer module not found" "WARN"
            Write-LogMessage "Attempting installation..." "INFO"
            
            try {
                Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                Import-Module SqlServer -ErrorAction Stop
                Write-LogMessage "SqlServer module installed successfully" "OK"
                Update-CheckCounter "PASS"
                return $true
            }
            catch {
                Write-LogMessage "Failed to install SqlServer module: $_" "FAIL"
                Write-LogMessage "Manual install: Install-Module -Name SqlServer -Scope CurrentUser" "INFO"
                Update-CheckCounter "FAIL"
                return $false
            }
        }
    }
    catch {
        Write-LogMessage "Error checking SqlServer module: $_" "FAIL"
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# CHECK 3: SQL Server Connectivity
# ================================================================================
function Test-SqlServerConnectivity {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass
    )
    
    Write-CheckHeader "SQL Server Connectivity"
    
    Write-LogMessage "Target: $Server" "INFO"
    
    try {
        $query = @"
SELECT 
    @@SERVERNAME AS ServerName,
    SERVERPROPERTY('ProductVersion') AS ProductVersion,
    SERVERPROPERTY('ProductLevel') AS ProductLevel,
    SERVERPROPERTY('Edition') AS Edition,
    @@VERSION AS FullVersion
"@
        
        if ($User) {
            Write-LogMessage "Using SQL Authentication: $User" "INFO"
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $query -ConnectionTimeout 10 -QueryTimeout 10 -ErrorAction Stop
        }
        else {
            Write-LogMessage "Using Windows Authentication" "INFO"
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query -ConnectionTimeout 10 -QueryTimeout 10 -ErrorAction Stop
        }
        
        Write-LogMessage "Connection successful!" "OK"
        Write-Host ""
        Write-Host "  Server Name:      $($result.ServerName)" -ForegroundColor Cyan
        Write-Host "  Product Version:  $($result.ProductVersion)" -ForegroundColor Cyan
        Write-Host "  Product Level:    $($result.ProductLevel)" -ForegroundColor Cyan
        Write-Host "  Edition:          $($result.Edition)" -ForegroundColor Cyan
        
        Update-CheckCounter "PASS"
        return $true
    }
    catch {
        Write-LogMessage "Connection failed: $_" "FAIL"
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Verify SQL Server is running: services.msc" -ForegroundColor Yellow
        Write-Host "  2. Check SQL Browser service (for named instances)" -ForegroundColor Yellow
        Write-Host "  3. Verify firewall rules: Test-NetConnection $Server -Port 1433" -ForegroundColor Yellow
        Write-Host "  4. Check SQL Server Configuration Manager (protocols enabled)" -ForegroundColor Yellow
        
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# CHECK 4: SQL Server Permissions
# ================================================================================
function Test-SqlServerPermissions {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass
    )
    
    Write-CheckHeader "SQL Server Permissions"
    
    try {
        $query = @"
SELECT 
    SUSER_SNAME() AS CurrentUser,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasViewServerState,
    IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin
"@
        
        if ($User) {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $query -ErrorAction Stop
        }
        else {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query -ErrorAction Stop
        }
        
        Write-LogMessage "Current user: $($result.CurrentUser)" "INFO"
        
        if ($result.IsSysAdmin -eq 1) {
            Write-LogMessage "User is member of sysadmin role" "OK"
            Update-CheckCounter "PASS"
            return $true
        }
        elseif ($result.HasViewServerState -eq 1) {
            Write-LogMessage "User has VIEW SERVER STATE permission" "OK"
            Update-CheckCounter "PASS"
            return $true
        }
        else {
            Write-LogMessage "User lacks VIEW SERVER STATE permission" "FAIL"
            Write-Host ""
            Write-Host "Grant permission with:" -ForegroundColor Yellow
            Write-Host "  GRANT VIEW SERVER STATE TO [$($result.CurrentUser)]" -ForegroundColor Cyan
            Write-Host ""
            
            Update-CheckCounter "FAIL"
            return $false
        }
    }
    catch {
        Write-LogMessage "Failed to check permissions: $_" "FAIL"
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# CHECK 5: Query File
# ================================================================================
function Test-QueryFile {
    Write-CheckHeader "Query File"
    
    $queryFile = Join-Path $PSScriptRoot "scripts\workload-sample-query.sql"
    
    Write-LogMessage "Looking for: $queryFile" "INFO"
    
    if (Test-Path $queryFile) {
        $fileSize = (Get-Item $queryFile).Length
        $lineCount = (Get-Content $queryFile).Count
        
        Write-LogMessage "Query file found" "OK"
        Write-Host ""
        Write-Host "  Path:       $queryFile" -ForegroundColor Cyan
        Write-Host "  Size:       $fileSize bytes" -ForegroundColor Cyan
        Write-Host "  Lines:      $lineCount" -ForegroundColor Cyan
        
        Update-CheckCounter "PASS"
        return $true
    }
    else {
        Write-LogMessage "Query file not found" "FAIL"
        Write-LogMessage "Expected location: $queryFile" "INFO"
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# CHECK 6: Query Execution Test
# ================================================================================
function Test-QueryExecution {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass
    )
    
    Write-CheckHeader "Query Execution Test"
    
    $queryFile = Join-Path $PSScriptRoot "scripts\workload-sample-query.sql"
    
    if (-not (Test-Path $queryFile)) {
        Write-LogMessage "Query file not found, skipping test" "WARN"
        Update-CheckCounter "WARN"
        return $false
    }
    
    try {
        $query = Get-Content $queryFile -Raw -Encoding UTF8
        
        Write-LogMessage "Executing test query..." "INFO"
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        if ($User) {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $query -QueryTimeout 30 -ErrorAction Stop
        }
        else {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query -QueryTimeout 30 -ErrorAction Stop
        }
        
        $sw.Stop()
        $duration = $sw.Elapsed.TotalSeconds
        
        Write-LogMessage "Query executed successfully" "OK"
        Write-LogMessage "Execution time: $([math]::Round($duration, 3)) seconds" "INFO"
        
        Write-Host ""
        Write-Host "  Sample values:" -ForegroundColor Cyan
        Write-Host "    - CPUs:            $($result.TotalCPUs)" -ForegroundColor Cyan
        Write-Host "    - Memory:          $($result.TotalMemoryMB) MB" -ForegroundColor Cyan
        Write-Host "    - Buffer Pool:     $($result.BufferPoolMB) MB" -ForegroundColor Cyan
        Write-Host "    - User Connections: $($result.UserConnections)" -ForegroundColor Cyan
        Write-Host "    - Batch Req/Sec:   $($result.BatchRequestsPerSec)" -ForegroundColor Cyan
        
        if ($duration -gt 2.0) {
            Write-LogMessage "Query took > 2 seconds ($([math]::Round($duration, 3))s)" "WARN"
            Write-LogMessage "This is acceptable but slower than ideal (<1 sec)" "WARN"
            Update-CheckCounter "WARN"
        }
        else {
            Update-CheckCounter "PASS"
        }
        
        return $true
    }
    catch {
        Write-LogMessage "Query execution failed: $_" "FAIL"
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# CHECK 7: Disk Space
# ================================================================================
function Test-DiskSpace {
    Write-CheckHeader "Disk Space"
    
    try {
        $scriptDrive = (Get-Item $PSScriptRoot).PSDrive.Name
        $drive = Get-PSDrive -Name $scriptDrive -PSProvider FileSystem
        
        $freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)
        $usedSpaceGB = [math]::Round($drive.Used / 1GB, 2)
        $totalSpaceGB = [math]::Round(($drive.Free + $drive.Used) / 1GB, 2)
        $freePercent = [math]::Round(($drive.Free / ($drive.Free + $drive.Used)) * 100, 1)
        
        Write-Host ""
        Write-Host "  Drive:         ${scriptDrive}:" -ForegroundColor Cyan
        Write-Host "  Total Space:   $totalSpaceGB GB" -ForegroundColor Cyan
        Write-Host "  Used Space:    $usedSpaceGB GB" -ForegroundColor Cyan
        Write-Host "  Free Space:    $freeSpaceGB GB ($freePercent%)" -ForegroundColor Cyan
        
        if ($freeSpaceGB -lt 0.1) {
            Write-LogMessage "Less than 100 MB free space available" "FAIL"
            Update-CheckCounter "FAIL"
            return $false
        }
        elseif ($freeSpaceGB -lt 1.0) {
            Write-LogMessage "Less than 1 GB free space available" "WARN"
            Write-LogMessage "Monitoring data can consume several MB per day" "WARN"
            Update-CheckCounter "WARN"
            return $true
        }
        else {
            Write-LogMessage "Sufficient disk space available" "OK"
            Update-CheckCounter "PASS"
            return $true
        }
    }
    catch {
        Write-LogMessage "Failed to check disk space: $_" "WARN"
        Update-CheckCounter "WARN"
        return $true
    }
}

# ================================================================================
# CHECK 8: Monitor Script
# ================================================================================
function Test-MonitorScript {
    Write-CheckHeader "Monitor Script"
    
    $monitorScript = Join-Path $PSScriptRoot "scripts\Monitor-SQLWorkload.ps1"
    
    Write-LogMessage "Looking for: $monitorScript" "INFO"
    
    if (Test-Path $monitorScript) {
        $fileSize = (Get-Item $monitorScript).Length
        $lineCount = (Get-Content $monitorScript).Count
        
        Write-LogMessage "Monitor script found" "OK"
        Write-Host ""
        Write-Host "  Path:       $monitorScript" -ForegroundColor Cyan
        Write-Host "  Size:       $fileSize bytes" -ForegroundColor Cyan
        Write-Host "  Lines:      $lineCount" -ForegroundColor Cyan
        
        Update-CheckCounter "PASS"
        return $true
    }
    else {
        Write-LogMessage "Monitor script not found" "FAIL"
        Write-LogMessage "Expected location: $monitorScript" "INFO"
        Update-CheckCounter "FAIL"
        return $false
    }
}

# ================================================================================
# Summary Report
# ================================================================================
function Write-SummaryReport {
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host " INSTALLATION SUMMARY" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host ""
    
    $total = $script:ChecksPassed + $script:ChecksFailed + $script:ChecksWarning
    
    Write-Host "  Total Checks:    $total" -ForegroundColor Cyan
    Write-Host "  Passed:          $script:ChecksPassed" -ForegroundColor Green
    Write-Host "  Failed:          $script:ChecksFailed" -ForegroundColor Red
    Write-Host "  Warnings:        $script:ChecksWarning" -ForegroundColor Yellow
    Write-Host ""
    
    if ($script:ChecksFailed -eq 0) {
        Write-Host "✓ INSTALLATION SUCCESSFUL" -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Run monitor:" -ForegroundColor White
        Write-Host "     .\scripts\Monitor-SQLWorkload.ps1 -Duration 15 -Interval 60" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  2. Check results:" -ForegroundColor White
        Write-Host "     Get-Content sql_workload_monitor.json | ConvertFrom-Json" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  3. Import to main toolkit (Linux):" -ForegroundColor White
        Write-Host "     ./tools/utils/import_offline_benchmark.sh sql_workload_monitor.json" -ForegroundColor Cyan
        Write-Host ""
        
        return $true
    }
    elseif ($script:ChecksFailed -le 2 -and $script:ChecksWarning -gt 0) {
        Write-Host "⚠ INSTALLATION COMPLETED WITH WARNINGS" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Review warnings above and proceed with caution." -ForegroundColor Yellow
        Write-Host ""
        
        return $true
    }
    else {
        Write-Host "✗ INSTALLATION FAILED" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please fix the errors above before proceeding." -ForegroundColor Red
        Write-Host ""
        
        return $false
    }
}

# ================================================================================
# MAIN EXECUTION
# ================================================================================

Write-LogMessage "Starting installation checks..." "INFO"

# Run all checks
$null = Test-PowerShellVersion
$null = Test-SqlServerModule
$null = Test-SqlServerConnectivity -Server $ServerInstance -User $Username -Pass $Password
$null = Test-SqlServerPermissions -Server $ServerInstance -User $Username -Pass $Password
$null = Test-QueryFile
$null = Test-QueryExecution -Server $ServerInstance -User $Username -Pass $Password
$null = Test-DiskSpace
$null = Test-MonitorScript

# Summary
$success = Write-SummaryReport

# Exit code
if ($success) {
    exit 0
}
else {
    exit 1
}
