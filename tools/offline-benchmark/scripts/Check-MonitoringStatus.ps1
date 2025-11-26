<#
.SYNOPSIS
    Verifica el estado de una monitorización en curso
    
.DESCRIPTION
    Lee el archivo JSON de salida y muestra estadísticas de progreso.
    Modo watch actualiza cada N segundos.
    
.PARAMETER OutputFile
    Archivo JSON a verificar (default: sql_workload_monitor.json)
    
.PARAMETER Watch
    Modo watch (actualización continua)
    
.PARAMETER RefreshSeconds
    Intervalo de actualización en modo watch (default: 10)
    
.EXAMPLE
    .\Check-MonitoringStatus.ps1
    
.EXAMPLE
    .\Check-MonitoringStatus.ps1 -OutputFile benchmark_20240115.json
    
.EXAMPLE
    .\Check-MonitoringStatus.ps1 -Watch -RefreshSeconds 5
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputFile = "sql_workload_monitor.json",
    
    [Parameter(Mandatory=$false)]
    [switch]$Watch,
    
    [Parameter(Mandatory=$false)]
    [int]$RefreshSeconds = 10
)

function Show-MonitoringStatus {
    param([string]$File)
    
    Clear-Host
    
    Write-Host ""
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host " MONITORING STATUS CHECK" -ForegroundColor Yellow
    Write-Host " File: $File" -ForegroundColor Yellow
    Write-Host ("=" * 70) -ForegroundColor DarkGray
    Write-Host ""
    
    # Verificar archivo existe
    if (-not (Test-Path $File)) {
        Write-Host "[FAIL] File not found: $File" -ForegroundColor Red
        Write-Host ""
        return $false
    }
    
    Write-Host "[OK] File found: $File" -ForegroundColor Green
    Write-Host ""
    
    # Leer JSON
    try {
        $data = Get-Content $File -Raw | ConvertFrom-Json
    }
    catch {
        Write-Host "[FAIL] Failed to parse JSON: $_" -ForegroundColor Red
        Write-Host ""
        return $false
    }
    
    # Metadata
    Write-Host "JSON Structure:" -ForegroundColor Cyan
    Write-Host "  Version:         $($data.metadata.version)"
    Write-Host "  Server:          $($data.metadata.server)"
    Write-Host "  Duration:        $($data.metadata.duration_minutes) minutes"
    Write-Host "  Interval:        $($data.metadata.interval_seconds) seconds"
    Write-Host "  Start Time:      $($data.metadata.start_time)"
    
    # Calcular progreso
    $samplesCollected = $data.samples.Count
    $totalSamples = [math]::Floor(($data.metadata.duration_minutes * 60) / $data.metadata.interval_seconds)
    $progressPct = [math]::Round(($samplesCollected / $totalSamples) * 100, 1)
    
    Write-Host "  Samples:         $samplesCollected / $totalSamples ($progressPct%)" -ForegroundColor Yellow
    Write-Host ""
    
    # Progress
    Write-Host "Progress:" -ForegroundColor Cyan
    
    $startTime = [datetime]::ParseExact($data.metadata.start_time, "yyyy-MM-ddTHH:mm:ss", $null)
    $elapsed = (Get-Date) - $startTime
    
    $timeFormat = "{0:D2}:{1:D2}:{2:D2}"
    $elapsedStr = $timeFormat -f $elapsed.Hours, $elapsed.Minutes, $elapsed.Seconds
    Write-Host "  Elapsed:         $elapsedStr"
    
    if ($samplesCollected -lt $totalSamples) {
        $avgIntervalSec = $elapsed.TotalSeconds / $samplesCollected
        $remainingSamples = $totalSamples - $samplesCollected
        $remainingSeconds = $remainingSamples * $avgIntervalSec
        $remaining = [TimeSpan]::FromSeconds($remainingSeconds)
        $remainingStr = $timeFormat -f $remaining.Hours, $remaining.Minutes, $remaining.Seconds
        $estimatedEnd = (Get-Date).AddSeconds($remainingSeconds)
        
        Write-Host "  Remaining:       $remainingStr (estimated)"
        Write-Host "  Completion:      ~$($estimatedEnd.ToString('yyyy-MM-dd HH:mm:ss'))"
    }
    else {
        Write-Host "  Status:          COMPLETED" -ForegroundColor Green
        Write-Host "  End Time:        $($data.metadata.end_time)"
    }
    
    Write-Host ""
    
    # Health
    Write-Host "Health:" -ForegroundColor Cyan
    $errorsCount = if ($data.metadata.errors_count) { $data.metadata.errors_count } else { 0 }
    Write-Host "  Errors:          $errorsCount"
    
    if ($errorsCount -eq 0) {
        Write-Host "  Status:          ✓ HEALTHY" -ForegroundColor Green
    }
    elseif ($errorsCount -le 5) {
        Write-Host "  Status:          ⚠ WARNING" -ForegroundColor Yellow
    }
    else {
        Write-Host "  Status:          ✗ UNHEALTHY" -ForegroundColor Red
    }
    
    Write-Host ""
    
    # Últimas muestras
    if ($samplesCollected -gt 0) {
        Write-Host "Recent Samples:" -ForegroundColor Cyan
        $recentSamples = $data.samples | Select-Object -Last 3
        
        foreach ($sample in $recentSamples) {
            Write-Host "  $($sample.timestamp)  CPU: $($sample.cpu.total_cpus) cores  Mem: $($sample.memory.buffer_pool_mb) MB  Conns: $($sample.activity.user_connections)"
        }
        
        Write-Host ""
    }
    
    return $true
}

# Main execution
if ($Watch) {
    Write-Host "Watch mode enabled (refresh every $RefreshSeconds seconds). Press Ctrl+C to exit." -ForegroundColor Yellow
    Write-Host ""
    
    while ($true) {
        Show-MonitoringStatus -File $OutputFile
        Start-Sleep -Seconds $RefreshSeconds
    }
}
else {
    $success = Show-MonitoringStatus -File $OutputFile
    
    if ($success) {
        exit 0
    }
    else {
        exit 1
    }
}
