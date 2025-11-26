<#
.SYNOPSIS
    SQL Server Workload Monitor - PowerShell Edition
    
.DESCRIPTION
    Herramienta standalone para monitorización de SQL Server en Windows sin dependencias externas.
    Basada en el proyecto funcional SQLMonitoring_OnPremises_v2 (100% probado).
    Compatible con SQL Server 2012-2025.
    
.PARAMETER ServerInstance
    Instancia de SQL Server (default: ".")
    
.PARAMETER Duration
    Duración en minutos (default: 1440 = 24 horas)
    
.PARAMETER Interval
    Intervalo entre muestras en segundos (default: 120 = 2 minutos)
    
.PARAMETER OutputFile
    Archivo JSON de salida (default: sql_workload_monitor.json)
    
.PARAMETER Username
    Usuario SQL (si se usa SQL Authentication)
    
.PARAMETER Password
    Password SQL (si se usa SQL Authentication)
    
.PARAMETER Background
    Ejecutar en background con Task Scheduler
    
.EXAMPLE
    .\Monitor-SQLWorkload.ps1 -ServerInstance "." -Duration 15 -Interval 60
    
.EXAMPLE
    .\Monitor-SQLWorkload.ps1 -ServerInstance "MYSERVER\SQL2022" -Username "sa" -Password "P@ssw0rd"
    
.EXAMPLE
    .\Monitor-SQLWorkload.ps1 -Background
    
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
    [int]$Duration = 1440,
    
    [Parameter(Mandatory=$false)]
    [int]$Interval = 120,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "sql_workload_monitor.json",
    
    [Parameter(Mandatory=$false)]
    [string]$Username,
    
    [Parameter(Mandatory=$false)]
    [string]$Password,
    
    [Parameter(Mandatory=$false)]
    [switch]$Background
)

$ErrorActionPreference = "Stop"
$Version = "2.1.0"

# Banner
$Banner = @"

====================================================================
  SQL SERVER WORKLOAD MONITOR - POWERSHELL EDITION v$Version
  Azure SQL Benchmark Toolkit
====================================================================

"@

Write-Host $Banner -ForegroundColor Cyan

# Función de logging mejorado (del proyecto funcional)
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

# Verificar/instalar módulo SqlServer
function Test-SqlServerModule {
    Write-LogMessage "Checking SqlServer module..." "DEBUG"
    
    $module = Get-Module -ListAvailable -Name SqlServer | Sort-Object Version -Descending | Select-Object -First 1
    
    if (-not $module) {
        Write-LogMessage "SqlServer module not found. Installing..." "WARN"
        try {
            Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
            Import-Module SqlServer
            Write-LogMessage "SqlServer module installed successfully" "OK"
        }
        catch {
            Write-LogMessage "Failed to install SqlServer module: $_" "FAIL"
            return $false
        }
    }
    else {
        Write-LogMessage "SqlServer module found: v$($module.Version)" "OK"
        Import-Module SqlServer
    }
    
    return $true
}

# Test conectividad SQL Server
function Test-SqlConnection {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass
    )
    
    Write-LogMessage "Testing SQL Server connectivity..." "DEBUG"
    
    try {
        $query = "SELECT @@SERVERNAME AS ServerName, @@VERSION AS Version"
        
        if ($User) {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $query -ConnectionTimeout 10 -QueryTimeout 10
        }
        else {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query -ConnectionTimeout 10 -QueryTimeout 10
        }
        
        Write-LogMessage "Connected to: $($result.ServerName)" "OK"
        Write-LogMessage "Version: $($result.Version.Split("`n")[0].Substring(0, [Math]::Min(80, $result.Version.Split("`n")[0].Length)))" "DEBUG"
        
        return $true
    }
    catch {
        Write-LogMessage "Connection failed: $_" "FAIL"
        return $false
    }
}

# Verificar permisos
function Test-SqlPermissions {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass
    )
    
    Write-LogMessage "Checking permissions..." "DEBUG"
    
    try {
        $query = @"
SELECT 
    SUSER_SNAME() AS CurrentUser,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasViewServerState,
    IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin
"@
        
        if ($User) {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $query
        }
        else {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query
        }
        
        Write-LogMessage "Current user: $($result.CurrentUser)" "INFO"
        
        if ($result.IsSysAdmin -eq 1) {
            Write-LogMessage "User is sysadmin" "OK"
            return $true
        }
        elseif ($result.HasViewServerState -eq 1) {
            Write-LogMessage "User has VIEW SERVER STATE permission" "OK"
            return $true
        }
        else {
            Write-LogMessage "User lacks VIEW SERVER STATE permission" "FAIL"
            Write-LogMessage "Grant with: GRANT VIEW SERVER STATE TO [$($result.CurrentUser)]" "INFO"
            return $false
        }
    }
    catch {
        Write-LogMessage "Failed to check permissions: $_" "FAIL"
        return $false
    }
}

# Cargar query desde archivo externo (mejora del proyecto funcional)
function Get-MonitoringQuery {
    $queryFile = Join-Path $PSScriptRoot "workload-sample-query.sql"
    
    if (-not (Test-Path $queryFile)) {
        Write-LogMessage "Query file not found: $queryFile" "FAIL"
        return $null
    }
    
    try {
        $query = Get-Content $queryFile -Raw -Encoding UTF8
        Write-LogMessage "Loaded query from: $queryFile" "OK"
        return $query
    }
    catch {
        Write-LogMessage "Failed to load query file: $_" "FAIL"
        return $null
    }
}

# Test query execution
function Test-MonitoringQuery {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass,
        [string]$Query
    )
    
    Write-LogMessage "Testing query execution..." "DEBUG"
    
    try {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        
        if ($User) {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $Query -QueryTimeout 30
        }
        else {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $Query -QueryTimeout 30
        }
        
        $sw.Stop()
        $duration = $sw.Elapsed.TotalSeconds
        
        Write-LogMessage "Query executed successfully" "OK"
        Write-LogMessage "Execution time: $([math]::Round($duration, 3)) seconds" "INFO"
        
        # Mostrar valores de ejemplo
        Write-LogMessage "Sample values:" "DEBUG"
        Write-LogMessage "  - CPUs: $($result.TotalCPUs)" "DEBUG"
        Write-LogMessage "  - Memory: $($result.TotalMemoryMB) MB" "DEBUG"
        Write-LogMessage "  - Buffer Pool: $($result.BufferPoolMB) MB" "DEBUG"
        Write-LogMessage "  - User Connections: $($result.UserConnections)" "DEBUG"
        
        if ($duration -gt 2.0) {
            Write-LogMessage "Query took > 2 seconds ($([math]::Round($duration, 3))s) - consider optimization" "WARN"
        }
        
        return $true
    }
    catch {
        Write-LogMessage "Query execution failed: $_" "FAIL"
        return $false
    }
}

# Recolectar muestra
function Get-WorkloadSample {
    param(
        [string]$Server,
        [string]$User,
        [string]$Pass,
        [string]$Query
    )
    
    try {
        if ($User) {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Username $User -Password $Pass -Query $Query -QueryTimeout 30
        }
        else {
            $result = Invoke-Sqlcmd -ServerInstance $Server -Query $Query -QueryTimeout 30
        }
        
        # Construir objeto con estructura v2.1
        $sample = [PSCustomObject]@{
            timestamp = $result.SampleTime.ToString("yyyy-MM-ddTHH:mm:ss")
            cpu = @{
                total_cpus = $result.TotalCPUs
                sql_server_cpu_time_ms = $result.SQLServerCPUTimeMs
            }
            memory = @{
                total_mb = $result.TotalMemoryMB
                committed_mb = $result.CommittedMemoryMB
                target_mb = $result.TargetMemoryMB
                buffer_pool_mb = $result.BufferPoolMB
            }
            activity = @{
                batch_requests_per_sec = $result.BatchRequestsPerSec
                compilations_per_sec = $result.CompilationsPerSec
                user_connections = $result.UserConnections
            }
            io = @{
                total_reads = $result.TotalReads
                total_writes = $result.TotalWrites
                total_read_latency_ms = $result.TotalReadLatencyMs
                total_write_latency_ms = $result.TotalWriteLatencyMs
                total_bytes_read = $result.TotalBytesRead
                total_bytes_written = $result.TotalBytesWritten
            }
            waits = @{
                top_wait_type = $result.TopWaitType
                top_wait_time_ms = $result.TopWaitTimeMs
            }
        }
        
        return $sample
    }
    catch {
        Write-LogMessage "Failed to collect sample: $_" "FAIL"
        return $null
    }
}

# Guardar checkpoint (del proyecto funcional)
function Save-Checkpoint {
    param(
        [array]$Samples,
        [datetime]$StartTime,
        [string]$CheckpointFile
    )
    
    try {
        $checkpoint = @{
            version = $Version
            server = $ServerInstance
            start_time = $StartTime.ToString("yyyy-MM-ddTHH:mm:ss")
            checkpoint_time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
            samples_collected = $Samples.Count
            samples = $Samples
        } | ConvertTo-Json -Depth 10 -Compress:$false
        
        $checkpoint | Out-File -FilePath $CheckpointFile -Encoding UTF8 -Force
        Write-LogMessage "Checkpoint saved: $CheckpointFile" "DEBUG"
    }
    catch {
        Write-LogMessage "Failed to save checkpoint: $_" "FAIL"
    }
}

# Cargar checkpoint
function Load-Checkpoint {
    param([string]$CheckpointFile)
    
    if (-not (Test-Path $CheckpointFile)) {
        return $null
    }
    
    try {
        $checkpoint = Get-Content $CheckpointFile -Raw | ConvertFrom-Json
        Write-LogMessage "Loaded checkpoint: $CheckpointFile" "OK"
        Write-LogMessage "Resuming from $($checkpoint.samples_collected) samples" "INFO"
        return $checkpoint
    }
    catch {
        Write-LogMessage "Failed to load checkpoint: $_" "FAIL"
        return $null
    }
}

# Función principal de monitorización
function Start-Monitoring {
    param(
        [string]$Server,
        [int]$DurationMin,
        [int]$IntervalSec,
        [string]$Output,
        [string]$User,
        [string]$Pass
    )
    
    # Configuración
    $totalSamples = [math]::Floor(($DurationMin * 60) / $IntervalSec)
    $endTime = (Get-Date).AddMinutes($DurationMin)
    $checkpointFile = $Output -replace '\.json$', '_checkpoint.json'
    $checkpointInterval = 60 # minutos
    
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor Yellow
    Write-Host "  Server:           $Server"
    Write-Host "  Duration:         $DurationMin minutes ($([math]::Round($DurationMin/60, 1)) hours)"
    Write-Host "  Sample Interval:  $IntervalSec seconds"
    Write-Host "  Total Samples:    $totalSamples"
    Write-Host "  Checkpoint Every: $checkpointInterval minutes"
    Write-Host "  Output File:      $Output"
    Write-Host ""
    
    # Cargar query
    $query = Get-MonitoringQuery
    if (-not $query) { return $false }
    
    # Test conectividad
    if (-not (Test-SqlConnection -Server $Server -User $User -Pass $Pass)) { return $false }
    
    # Test permisos
    if (-not (Test-SqlPermissions -Server $Server -User $User -Pass $Pass)) { return $false }
    
    # Test query
    if (-not (Test-MonitoringQuery -Server $Server -User $User -Pass $Pass -Query $query)) { return $false }
    
    Write-Host ""
    Write-Host "Timeline:" -ForegroundColor Yellow
    Write-Host "  Start:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Host "  Estimated: $($endTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Host ""
    
    # Inicializar o resumir
    $samples = @()
    $startSample = 0
    $startTime = Get-Date
    $errorsCount = 0
    
    if (Test-Path $checkpointFile) {
        $checkpoint = Load-Checkpoint -CheckpointFile $checkpointFile
        if ($checkpoint) {
            $samples = @($checkpoint.samples)
            $startSample = $checkpoint.samples_collected
            $startTime = [datetime]::ParseExact($checkpoint.start_time, "yyyy-MM-ddTHH:mm:ss", $null)
        }
    }
    
    Write-LogMessage "Starting monitoring..." "OK"
    Write-Host ""
    
    # Loop de monitorización
    $nextCheckpoint = (Get-Date).AddMinutes($checkpointInterval)
    
    try {
        for ($i = $startSample; $i -lt $totalSamples; $i++) {
            # Recolectar muestra
            $sample = Get-WorkloadSample -Server $Server -User $User -Pass $Pass -Query $query
            
            if ($sample) {
                $samples += $sample
                
                # Progress
                $progress = [math]::Round((($i + 1) / $totalSamples) * 100, 1)
                $elapsed = (Get-Date) - $startTime
                $remaining = $endTime - (Get-Date)
                
                $timeFormat = "{0:D2}:{1:D2}:{2:D2}"
                $elapsedStr = $timeFormat -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds
                $remainingStr = $timeFormat -f $remaining.Hours, $remaining.Minutes, $remaining.Seconds
                
                Write-Host ("[{0}] Sample #{1}/{2} ({3}%) | Elapsed: {4} | Remaining: {5}" -f `
                    (Get-Date -Format "HH:mm:ss"), ($i + 1), $totalSamples, $progress, $elapsedStr, $remainingStr)
            }
            else {
                $errorsCount++
            }
            
            # Checkpoint?
            if ((Get-Date) -ge $nextCheckpoint) {
                Save-Checkpoint -Samples $samples -StartTime $startTime -CheckpointFile $checkpointFile
                $nextCheckpoint = (Get-Date).AddMinutes($checkpointInterval)
            }
            
            # Esperar intervalo (excepto en última muestra)
            if ($i -lt ($totalSamples - 1)) {
                Start-Sleep -Seconds $IntervalSec
            }
        }
        
        # Guardar resultado final
        Write-Host ""
        Write-LogMessage "Monitoring completed successfully" "OK"
        Write-LogMessage "Total samples collected: $($samples.Count)" "INFO"
        Write-LogMessage "Total errors: $errorsCount" "INFO"
        
        # Guardar JSON final (formato v2.1)
        $result = @{
            metadata = @{
                version = $Version
                server = $Server
                database = "master"
                start_time = $startTime.ToString("yyyy-MM-ddTHH:mm:ss")
                end_time = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ss")
                duration_minutes = $DurationMin
                interval_seconds = $IntervalSec
                total_samples = $samples.Count
                errors_count = $errorsCount
            }
            samples = $samples
        } | ConvertTo-Json -Depth 10 -Compress:$false
        
        $result | Out-File -FilePath $Output -Encoding UTF8 -Force
        Write-LogMessage "Results saved to: $Output" "OK"
        
        # Limpiar checkpoint
        if (Test-Path $checkpointFile) {
            Remove-Item $checkpointFile -Force
            Write-LogMessage "Checkpoint file removed" "DEBUG"
        }
        
        return $true
    }
    catch {
        Write-Host ""
        Write-LogMessage "Monitoring interrupted: $_" "FAIL"
        Write-LogMessage "Saving partial results..." "INFO"
        
        # Guardar checkpoint parcial
        Save-Checkpoint -Samples $samples -StartTime $startTime -CheckpointFile $checkpointFile
        Write-LogMessage "Partial checkpoint saved: $checkpointFile" "OK"
        
        return $false
    }
}

# Main execution
if (-not (Test-SqlServerModule)) {
    exit 1
}

$success = Start-Monitoring `
    -Server $ServerInstance `
    -DurationMin $Duration `
    -IntervalSec $Interval `
    -Output $OutputFile `
    -User $Username `
    -Pass $Password

if ($success) {
    exit 0
}
else {
    exit 1
}
