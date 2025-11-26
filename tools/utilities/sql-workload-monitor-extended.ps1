<#
.SYNOPSIS
    SQL Server Extended Workload Monitoring for 24-48 hour periods
    
.DESCRIPTION
    Monitors SQL Server REAL workload over extended periods (24-48 hours) to capture
    complete daily patterns including peak hours, night maintenance, and weekend patterns.
    
    Features for extended monitoring:
    - Background execution (no terminal blocking)
    - Checkpoint files every hour (recovery from interruptions)
    - Hourly statistics to identify peak patterns
    - Automatic peak detection
    - Consolidated reports with trend analysis
    - Resume capability from checkpoints
    
    This captures TRUE workload patterns over business cycles, not just a snapshot.
    
.PARAMETER ServerInstance
    SQL Server instance name (default: localhost)
    
.PARAMETER Duration
    Monitoring duration in minutes
    Examples:
      -Duration 1440   # 24 hours
      -Duration 2880   # 48 hours
      -Duration 120    # 2 hours (testing)
    
.PARAMETER SampleInterval
    Sampling interval in seconds (default: 60)
    Recommended: 60-120 seconds for extended monitoring
    
.PARAMETER OutputPath
    Directory where results will be saved
    
.PARAMETER BackgroundMode
    Run as PowerShell background job (recommended for 24-48h monitoring)
    
.PARAMETER CheckpointInterval
    Interval in minutes to save checkpoints (default: 60)
    Allows recovery if monitoring is interrupted
    
.PARAMETER ResumeFrom
    Resume monitoring from a checkpoint file
    
.EXAMPLE
    # 24-hour monitoring in background
    .\sql-workload-monitor-extended.ps1 -Duration 1440 -BackgroundMode
    
.EXAMPLE
    # 48-hour monitoring with 2-minute samples
    .\sql-workload-monitor-extended.ps1 -Duration 2880 -SampleInterval 120 -BackgroundMode
    
.EXAMPLE
    # Check progress of background job
    Get-Job | Where-Object {$_.Name -like "SQLWorkloadMonitor*"} | Receive-Job -Keep
    
.EXAMPLE
    # Resume from checkpoint after interruption
    .\sql-workload-monitor-extended.ps1 -ResumeFrom "C:\AzureMigration\Assessment\checkpoint_20250119_100000.json"
    
.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 19, 2025
    Requires: SQL Server running, VIEW SERVER STATE permission
    
    BEST PRACTICE: 
    - Run for 24-48 hours to capture complete business cycle
    - Use BackgroundMode for unattended operation
    - Checkpoints saved every hour for safety
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 1440,  # Default: 24 hours
    
    [Parameter(Mandatory=$false)]
    [int]$SampleInterval = 60,  # Default: 1 minute
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\AzureMigration\Assessment",
    
    [Parameter(Mandatory=$false)]
    [switch]$BackgroundMode,
    
    [Parameter(Mandatory=$false)]
    [int]$CheckpointInterval = 60,  # Default: checkpoint every hour
    
    [Parameter(Mandatory=$false)]
    [string]$ResumeFrom = ""
)

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

# If BackgroundMode, start as job and exit
if ($BackgroundMode) {
    $jobName = "SQLWorkloadMonitor_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $scriptPath = $MyInvocation.MyCommand.Path
    
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  SQL Server Extended Workload Monitor - BACKGROUND MODE" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "" 
    Write-Host "Starting background monitoring job..." -ForegroundColor Green
    Write-Host ""
    Write-Host "  Job Name:    $jobName" -ForegroundColor White
    Write-Host "  Server:      $ServerInstance" -ForegroundColor White
    Write-Host "  Duration:    $Duration minutes ($([math]::Round($Duration/60, 1)) hours)" -ForegroundColor White
    Write-Host "  Interval:    $SampleInterval seconds" -ForegroundColor White
    Write-Host "  Samples:     $([math]::Floor($Duration * 60 / $SampleInterval))" -ForegroundColor White
    Write-Host "  Checkpoints: Every $CheckpointInterval minutes" -ForegroundColor White
    Write-Host "  Output:      $OutputPath" -ForegroundColor White
    Write-Host "  Start:       $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "  Estimated:   $((Get-Date).AddMinutes($Duration).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
    Write-Host ""
    
    # Start background job
    $job = Start-Job -Name $jobName -ScriptBlock {
        param($ScriptPath, $ServerInstance, $Duration, $SampleInterval, $OutputPath, $CheckpointInterval)
        
        # Execute script without -BackgroundMode flag
        & $ScriptPath -ServerInstance $ServerInstance -Duration $Duration `
            -SampleInterval $SampleInterval -OutputPath $OutputPath `
            -CheckpointInterval $CheckpointInterval
            
    } -ArgumentList $scriptPath, $ServerInstance, $Duration, $SampleInterval, $OutputPath, $CheckpointInterval
    
    Write-Host "Background job started successfully!" -ForegroundColor Green
    Write-Host "   Job ID: $($job.Id)" -ForegroundColor White
    Write-Host ""
    Write-Host "Useful commands:" -ForegroundColor Yellow
    Write-Host "   # Check job status" -ForegroundColor Gray
    Write-Host "   Get-Job -Id $($job.Id)" -ForegroundColor White
    Write-Host ""
    Write-Host "   # View live progress" -ForegroundColor Gray
    Write-Host "   Get-Job -Id $($job.Id) | Receive-Job -Keep" -ForegroundColor White
    Write-Host ""
    Write-Host "   # View all monitoring jobs" -ForegroundColor Gray
    Write-Host "   Get-Job | Where-Object {`$_.Name -like 'SQLWorkloadMonitor*'}" -ForegroundColor White
    Write-Host ""
    Write-Host "   # Stop job if needed" -ForegroundColor Gray
    Write-Host "   Stop-Job -Id $($job.Id)" -ForegroundColor White
    Write-Host ""
    Write-Host "   # Remove completed job" -ForegroundColor Gray
    Write-Host "   Remove-Job -Id $($job.Id)" -ForegroundColor White
    Write-Host ""
    Write-Host " Results will be saved to:" -ForegroundColor Yellow
    Write-Host "   $OutputPath\sql_workload_extended_*.json" -ForegroundColor White
    Write-Host "   $OutputPath\sql_workload_extended_*.html" -ForegroundColor White
    Write-Host ""
    
    return
}

# Main monitoring logic (foreground execution)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$checkpointFile = Join-Path $OutputPath "checkpoint_$timestamp.json"
$resultsFile = Join-Path $OutputPath "sql_workload_extended_$timestamp.json"
$reportFile = Join-Path $OutputPath "sql_workload_extended_$timestamp.html"

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  SQL Server Extended Workload Monitor" -ForegroundColor Cyan
Write-Host "   Capturing Real Workload Patterns for Azure Sizing" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Server:           $ServerInstance" -ForegroundColor White
Write-Host "  Duration:         $Duration minutes ($([math]::Round($Duration/60, 1)) hours)" -ForegroundColor White
Write-Host "  Sample Interval:  $SampleInterval seconds" -ForegroundColor White
Write-Host "  Total Samples:    $([math]::Floor($Duration * 60 / $SampleInterval))" -ForegroundColor White
Write-Host "  Checkpoint Every: $CheckpointInterval minutes" -ForegroundColor White
Write-Host "  Output Path:      $OutputPath" -ForegroundColor White
Write-Host ""
Write-Host "Timeline:" -ForegroundColor Yellow
Write-Host "  Start:     $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
Write-Host "  Estimated: $((Get-Date).AddMinutes($Duration).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
Write-Host ""

# Initialize or resume from checkpoint
$samples = [System.Collections.ArrayList]::new()
$startSample = 0
$startTime = Get-Date

if ($ResumeFrom -and (Test-Path $ResumeFrom)) {
    Write-Host "  Resuming from checkpoint: $ResumeFrom" -ForegroundColor Yellow
    try {
        $checkpoint = Get-Content $ResumeFrom | ConvertFrom-Json
        $startTime = [datetime]$checkpoint.StartTime
        $startSample = $checkpoint.SamplesCollected
        
        foreach ($sample in $checkpoint.Samples) {
            [void]$samples.Add($sample)
        }
        
        Write-Host " Resumed: $($samples.Count) samples already collected" -ForegroundColor Green
        Write-Host ""
    }
    catch {
        Write-Host "  Could not resume from checkpoint: $_" -ForegroundColor Yellow
        Write-Host "   Starting fresh monitoring..." -ForegroundColor Yellow
        Write-Host ""
    }
}

$sampleCount = [math]::Floor($Duration * 60 / $SampleInterval)
$checkpointSamples = [math]::Floor($CheckpointInterval * 60 / $SampleInterval)

Write-Host " Starting data collection..." -ForegroundColor Green
Write-Host "   Checkpoint will be saved every $checkpointSamples samples" -ForegroundColor Gray
Write-Host ""

# Collection loop
for ($i = $startSample; $i -lt $sampleCount; $i++) {
    $currentTime = Get-Date
    $elapsed = $currentTime - $startTime
    $remaining = [TimeSpan]::FromMinutes($Duration) - $elapsed
    $progress = [math]::Round(($i / $sampleCount) * 100, 1)
    
    # Progress indicator
    $progressBar = "=" * [math]::Floor($progress / 2)
    $progressBar = $progressBar.PadRight(50, " ")
    
    Write-Host "[$($currentTime.ToString('HH:mm:ss'))] " -NoNewline -ForegroundColor Gray
    Write-Host "[$progressBar] " -NoNewline -ForegroundColor Cyan
    Write-Host "$progress% " -NoNewline -ForegroundColor White
    Write-Host "($($i+1)/$sampleCount) " -NoNewline -ForegroundColor White
    Write-Host "  $($remaining.ToString('hh\:mm\:ss')) remaining" -ForegroundColor Yellow
    
    # Collect workload metrics from SQL Server
    try {
        Write-Host "   [DEBUG] Starting SQL query..." -ForegroundColor Gray
        
        # Load query from external SQL file (easier to maintain and test)
        $queryFile = Join-Path $PSScriptRoot "workload-sample-query.sql"
        
        if (-not (Test-Path $queryFile)) {
            # Fallback to inline query if file not found
            Write-Host "   [WARN] Query file not found: $queryFile" -ForegroundColor Yellow
            Write-Host "   [WARN] Using inline query as fallback..." -ForegroundColor Yellow
            
            $query = @"
-- Fallback inline query
SELECT 
    GETDATE() AS SampleTime,
    si.cpu_count AS TotalCPUs,
    CAST(@@CPU_BUSY * CAST(si.cpu_ticks AS FLOAT) / (si.cpu_ticks / si.ms_ticks) / 1000 AS INT) AS SQLServerCPUTimeMs,
    CAST(si.physical_memory_kb / 1024 AS INT) AS TotalMemoryMB,
    CAST(si.committed_kb / 1024 AS INT) AS CommittedMemoryMB,
    (SELECT COUNT(*) * 8 / 1024 FROM sys.dm_os_buffer_descriptors) AS BufferPoolMB,
    ISNULL((SELECT TOP 1 cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'Batch Requests/sec'), 0) AS BatchRequestsPerSec,
    ISNULL((SELECT TOP 1 cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'SQL Compilations/sec'), 0) AS CompilationsPerSec,
    ISNULL((SELECT TOP 1 cntr_value FROM sys.dm_os_performance_counters WHERE counter_name = 'User Connections'), 0) AS UserConnections,
    ISNULL((SELECT SUM(num_of_reads) FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalReads,
    ISNULL((SELECT SUM(num_of_writes) FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalWrites,
    ISNULL((SELECT SUM(io_stall_read_ms) FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalReadLatencyMs,
    ISNULL((SELECT SUM(io_stall_write_ms) FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalWriteLatencyMs,
    'N/A' AS TopWaitType, 0 AS TopWaitTimeMs
FROM sys.dm_os_sys_info si
"@
        } else {
            Write-Host "   [DEBUG] Loading query from: $queryFile" -ForegroundColor Gray
            $query = Get-Content $queryFile -Raw -Encoding UTF8
        }

        # Use TrustServerCertificate parameter if supported (SqlServer module 22.0+)
        $invokeSqlcmdParams = @{
            ServerInstance = $ServerInstance
            Query = $query
            ErrorAction = 'Stop'
            QueryTimeout = 30  # 30 second timeout
        }
        
        # Check if TrustServerCertificate parameter is available
        $sqlModuleVersion = (Get-Module SqlServer -ListAvailable | Select-Object -First 1).Version
        if ($sqlModuleVersion -and $sqlModuleVersion.Major -ge 22) {
            $invokeSqlcmdParams['TrustServerCertificate'] = $true
        }
        
        Write-Host "   [DEBUG] Executing Invoke-Sqlcmd..." -ForegroundColor Gray
        $result = Invoke-Sqlcmd @invokeSqlcmdParams
        Write-Host "   [DEBUG] Query completed successfully" -ForegroundColor Gray
        
        # Calculate derived metrics
        $cpuPercent = 0
        if ($result.TotalCPUs -gt 0) {
            $cpuPercent = [math]::Min(100, [math]::Round(($result.SQLServerCPUTimeMs / ($SampleInterval * 10)) / $result.TotalCPUs, 2))
        }
        
        $usedCPUCores = [math]::Round(($cpuPercent / 100) * $result.TotalCPUs, 2)
        
        $sample = [PSCustomObject]@{
            SampleTime = $result.SampleTime
            TotalCPUs = $result.TotalCPUs
            CPUPercent = $cpuPercent
            UsedCPUCores = $usedCPUCores
            TotalMemoryMB = $result.TotalMemoryMB
            CommittedMemoryMB = $result.CommittedMemoryMB
            BufferPoolMB = $result.BufferPoolMB
            BatchRequestsPerSec = $result.BatchRequestsPerSec
            CompilationsPerSec = $result.CompilationsPerSec
            UserConnections = $result.UserConnections
            TotalReads = $result.TotalReads
            TotalWrites = $result.TotalWrites
            TotalReadLatencyMs = $result.TotalReadLatencyMs
            TotalWriteLatencyMs = $result.TotalWriteLatencyMs
            TopWaitType = $result.TopWaitType
            TopWaitTimeMs = $result.TopWaitTimeMs
        }
        
        [void]$samples.Add($sample)
        Write-Host "     [OK] Sample $($i+1) collected successfully" -ForegroundColor Green
        [Console]::Out.Flush()  # Force output flush
        
    }
    catch {
        Write-Host "     [FAIL] Sample failed: $_" -ForegroundColor Red
        Write-Host "     Error details: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     Stack: $($_.ScriptStackTrace)" -ForegroundColor Gray
        Write-Host "     Continuing to next sample..." -ForegroundColor Yellow
        [Console]::Out.Flush()  # Force output flush
    }
    
    # Save checkpoint periodically
    if (($i -gt 0) -and (($i % $checkpointSamples) -eq 0)) {
        try {
            $checkpointData = @{
                ServerInstance = $ServerInstance
                StartTime = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
                CurrentTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                SamplesCollected = $samples.Count
                TotalSamples = $sampleCount
                ProgressPercent = $progress
                Samples = $samples
            }
            
            $checkpointData | ConvertTo-Json -Depth 10 -Compress | Out-File -FilePath $checkpointFile -Encoding UTF8 -Force
            Write-Host "    Checkpoint saved: $($samples.Count) samples" -ForegroundColor Green
        }
        catch {
            Write-Host "     Checkpoint save failed: $_" -ForegroundColor Yellow
        }
    }
    
    # Sleep until next sample
    if ($i -lt $sampleCount - 1) {
        Start-Sleep -Seconds $SampleInterval
    }
}

Write-Host ""
Write-Host " Data collection completed!" -ForegroundColor Green
Write-Host ""
Write-Host " Analyzing workload patterns..." -ForegroundColor Yellow

# Hourly analysis
$hourlyStats = @{}

foreach ($sample in $samples) {
    $hour = ([datetime]$sample.SampleTime).ToString("yyyy-MM-dd HH:00")
    
    if (-not $hourlyStats.ContainsKey($hour)) {
        $hourlyStats[$hour] = [System.Collections.ArrayList]::new()
    }
    
    [void]$hourlyStats[$hour].Add($sample)
}

# Calculate statistics per hour
$hourlyAnalysis = @()

foreach ($hour in ($hourlyStats.Keys | Sort-Object)) {
    $hourSamples = $hourlyStats[$hour]
    
    if ($hourSamples.Count -eq 0) { continue }
    
    $avgCPU = ($hourSamples | Measure-Object -Property UsedCPUCores -Average).Average
    $maxCPU = ($hourSamples | Measure-Object -Property UsedCPUCores -Maximum).Maximum
    $avgMemory = ($hourSamples | Measure-Object -Property CommittedMemoryMB -Average).Average
    $maxMemory = ($hourSamples | Measure-Object -Property CommittedMemoryMB -Maximum).Maximum
    $avgBatch = ($hourSamples | Measure-Object -Property BatchRequestsPerSec -Average).Average
    $maxBatch = ($hourSamples | Measure-Object -Property BatchRequestsPerSec -Maximum).Maximum
    $avgConnections = ($hourSamples | Measure-Object -Property UserConnections -Average).Average
    $maxConnections = ($hourSamples | Measure-Object -Property UserConnections -Maximum).Maximum
    
    # Calculate IOPS for this hour
    $firstSample = $hourSamples[0]
    $lastSample = $hourSamples[-1]
    $hourDurationSec = (([datetime]$lastSample.SampleTime) - ([datetime]$firstSample.SampleTime)).TotalSeconds
    
    $hourReadIOPS = 0
    $hourWriteIOPS = 0
    if ($hourDurationSec -gt 0) {
        $hourReadIOPS = [math]::Round(($lastSample.TotalReads - $firstSample.TotalReads) / $hourDurationSec, 2)
        $hourWriteIOPS = [math]::Round(($lastSample.TotalWrites - $firstSample.TotalWrites) / $hourDurationSec, 2)
    }
    
    $hourlyAnalysis += [PSCustomObject]@{
        Hour = $hour
        SampleCount = $hourSamples.Count
        AvgCPUCores = [math]::Round($avgCPU, 2)
        MaxCPUCores = [math]::Round($maxCPU, 2)
        AvgMemoryMB = [math]::Round($avgMemory, 0)
        MaxMemoryMB = [math]::Round($maxMemory, 0)
        AvgBatchRequestsPerSec = [math]::Round($avgBatch, 0)
        MaxBatchRequestsPerSec = [math]::Round($maxBatch, 0)
        AvgUserConnections = [math]::Round($avgConnections, 0)
        MaxUserConnections = [math]::Round($maxConnections, 0)
        AvgReadIOPS = $hourReadIOPS
        AvgWriteIOPS = $hourWriteIOPS
        TotalIOPS = $hourReadIOPS + $hourWriteIOPS
    }
}

# Identify peak hours
$peakHourCPU = $hourlyAnalysis | Sort-Object -Property MaxCPUCores -Descending | Select-Object -First 1
$peakHourMemory = $hourlyAnalysis | Sort-Object -Property MaxMemoryMB -Descending | Select-Object -First 1
$peakHourActivity = $hourlyAnalysis | Sort-Object -Property MaxBatchRequestsPerSec -Descending | Select-Object -First 1
$peakHourIOPS = $hourlyAnalysis | Sort-Object -Property TotalIOPS -Descending | Select-Object -First 1

# Overall statistics
$avgCPUCores = [math]::Round(($samples | Measure-Object -Property UsedCPUCores -Average).Average, 2)
$maxCPUCores = [math]::Round(($samples | Measure-Object -Property UsedCPUCores -Maximum).Maximum, 2)
$p95CPUCores = [math]::Round(($samples | Sort-Object -Property UsedCPUCores | Select-Object -Skip ([math]::Floor($samples.Count * 0.95)) -First 1).UsedCPUCores, 2)

$avgMemoryMB = [math]::Round(($samples | Measure-Object -Property CommittedMemoryMB -Average).Average, 0)
$maxMemoryMB = [math]::Round(($samples | Measure-Object -Property CommittedMemoryMB -Maximum).Maximum, 0)
$p95MemoryMB = [math]::Round(($samples | Sort-Object -Property CommittedMemoryMB | Select-Object -Skip ([math]::Floor($samples.Count * 0.95)) -First 1).CommittedMemoryMB, 0)

# Calculate IOPS
$firstSample = $samples[0]
$lastSample = $samples[-1]
$totalDurationSec = (([datetime]$lastSample.SampleTime) - ([datetime]$firstSample.SampleTime)).TotalSeconds

$avgReadIOPS = 0
$avgWriteIOPS = 0
if ($totalDurationSec -gt 0) {
    $avgReadIOPS = [math]::Round(($lastSample.TotalReads - $firstSample.TotalReads) / $totalDurationSec, 2)
    $avgWriteIOPS = [math]::Round(($lastSample.TotalWrites - $firstSample.TotalWrites) / $totalDurationSec, 2)
}

$totalIOPS = $avgReadIOPS + $avgWriteIOPS

# Azure VM sizing recommendation (based on PEAK + 20% headroom)
$recommendedCPUs = [math]::Max(4, [math]::Ceiling($maxCPUCores * 1.2))
$recommendedMemoryGB = [math]::Max(8, [math]::Ceiling(($maxMemoryMB / 1024) * 1.2))

# Match to Azure E-series (memory-optimized for SQL)
$vmSKUs = @(
    @{Name="Standard_E2ds_v5"; vCPUs=2; MemoryGB=16; Cost=75},
    @{Name="Standard_E4ds_v5"; vCPUs=4; MemoryGB=32; Cost=150},
    @{Name="Standard_E8ds_v5"; vCPUs=8; MemoryGB=64; Cost=300},
    @{Name="Standard_E16ds_v5"; vCPUs=16; MemoryGB=128; Cost=600},
    @{Name="Standard_E20ds_v5"; vCPUs=20; MemoryGB=160; Cost=750},
    @{Name="Standard_E32ds_v5"; vCPUs=32; MemoryGB=256; Cost=1200},
    @{Name="Standard_E48ds_v5"; vCPUs=48; MemoryGB=384; Cost=1800},
    @{Name="Standard_E64ds_v5"; vCPUs=64; MemoryGB=512; Cost=2400}
)

$recommendedVM = $vmSKUs | Where-Object { $_.vCPUs -ge $recommendedCPUs -and $_.MemoryGB -ge $recommendedMemoryGB } | Select-Object -First 1

if (-not $recommendedVM) {
    $recommendedVM = $vmSKUs[-1]  # Largest if requirements exceed
}

# Disk recommendation based on IOPS
$diskRecommendation = 'Premium SSD P15 (256GB - 1100 IOPS)'
$diskCost = 35

if ($totalIOPS -gt 15000) {
    $diskRecommendation = "Ultra Disk (custom IOPS: $totalIOPS)"
    $diskCost = 500
}
elseif ($totalIOPS -gt 10000) {
    $diskRecommendation = 'RAID-0: 2x Premium SSD P40 (4TB - 15000 IOPS)'
    $diskCost = 460
}
elseif ($totalIOPS -gt 5000) {
    $diskRecommendation = 'RAID-0: 2x Premium SSD P30 (2TB - 10000 IOPS)'
    $diskCost = 240
}
elseif ($totalIOPS -gt 2300) {
    $diskRecommendation = 'Premium SSD P30 (1TB - 5000 IOPS)'
    $diskCost = 120
}
elseif ($totalIOPS -gt 500) {
    $diskRecommendation = 'Premium SSD P20 (512GB - 2300 IOPS)'
    $diskCost = 60
}

$totalMonthlyCost = $recommendedVM.Cost + $diskCost

# Create results object
$results = @{
    MonitoringInfo = @{
        ServerInstance = $ServerInstance
        StartTime = $startTime.ToString("yyyy-MM-dd HH:mm:ss")
        EndTime = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        DurationMinutes = $Duration
        DurationHours = [math]::Round($Duration / 60, 2)
        SampleInterval = $SampleInterval
        TotalSamples = $samples.Count
        CheckpointFile = $checkpointFile
    }
    OverallStatistics = @{
        CPU = @{
            Average = $avgCPUCores
            Maximum = $maxCPUCores
            P95 = $p95CPUCores
        }
        Memory = @{
            AverageMB = $avgMemoryMB
            MaximumMB = $maxMemoryMB
            P95MB = $p95MemoryMB
            AverageGB = [math]::Round($avgMemoryMB / 1024, 2)
            MaximumGB = [math]::Round($maxMemoryMB / 1024, 2)
            P95GB = [math]::Round($p95MemoryMB / 1024, 2)
        }
        IOPS = @{
            AvgReadIOPS = $avgReadIOPS
            AvgWriteIOPS = $avgWriteIOPS
            TotalIOPS = $totalIOPS
        }
    }
    HourlyAnalysis = $hourlyAnalysis
    PeakHours = @{
        CPU = @{
            Hour = $peakHourCPU.Hour
            MaxCPUCores = $peakHourCPU.MaxCPUCores
            AvgCPUCores = $peakHourCPU.AvgCPUCores
        }
        Memory = @{
            Hour = $peakHourMemory.Hour
            MaxMemoryMB = $peakHourMemory.MaxMemoryMB
            AvgMemoryMB = $peakHourMemory.AvgMemoryMB
        }
        Activity = @{
            Hour = $peakHourActivity.Hour
            MaxBatchRequestsPerSec = $peakHourActivity.MaxBatchRequestsPerSec
            AvgBatchRequestsPerSec = $peakHourActivity.AvgBatchRequestsPerSec
        }
        IOPS = @{
            Hour = $peakHourIOPS.Hour
            ReadIOPS = $peakHourIOPS.AvgReadIOPS
            WriteIOPS = $peakHourIOPS.AvgWriteIOPS
            TotalIOPS = $peakHourIOPS.TotalIOPS
        }
    }
    AzureRecommendation = @{
        VM = @{
            SKU = $recommendedVM.Name
            vCPUs = $recommendedVM.vCPUs
            MemoryGB = $recommendedVM.MemoryGB
            MonthlyCostEUR = $recommendedVM.Cost
        }
        Disk = @{
            Configuration = $diskRecommendation
            MonthlyCostEUR = $diskCost
        }
        TotalMonthlyCostEUR = $totalMonthlyCost
        SizingBasis = "Based on PEAK workload + 20% headroom over $([math]::Round($Duration/60,1)) hours"
    }
    RawSamples = $samples
}

# Save JSON
Write-Host " Saving results..." -ForegroundColor Yellow
$results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8 -Force
Write-Host "    JSON: $resultsFile" -ForegroundColor Green

# Generate HTML report
Write-Host " Generating HTML report..." -ForegroundColor Yellow

$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>SQL Server Extended Workload Analysis</title>
    <style>
        body { font-family: 'Segoe UI', Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; background: white; padding: 30px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #106ebe; margin-top: 30px; border-bottom: 2px solid #106ebe; padding-bottom: 5px; }
        h3 { color: #005a9e; margin-top: 20px; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ddd; }
        tr:hover { background: #f0f0f0; }
        .metric-box { display: inline-block; background: #e8f4fd; border-left: 4px solid #0078d4; padding: 15px 20px; margin: 10px 10px 10px 0; min-width: 200px; }
        .metric-label { font-size: 12px; color: #666; text-transform: uppercase; }
        .metric-value { font-size: 24px; font-weight: bold; color: #0078d4; margin-top: 5px; }
        .warning { background: #fff4e5; border-left: 4px solid #ff8c00; padding: 15px; margin: 20px 0; }
        .success { background: #e8f5e9; border-left: 4px solid #4caf50; padding: 15px; margin: 20px 0; }
        .peak-indicator { background: #ffeb3b; padding: 2px 6px; border-radius: 3px; font-weight: bold; }
        .chart-placeholder { background: #f9f9f9; border: 2px dashed #ddd; padding: 40px; text-align: center; color: #999; margin: 20px 0; }
    </style>
</head>
<body>
    <div class="container">
        <h1> SQL Server Extended Workload Analysis</h1>
        <p style="font-size: 18px; color: #666;">Analysis of REAL workload patterns over $([math]::Round($Duration/60,1)) hours for accurate Azure sizing</p>
        
        <h2> Monitoring Information</h2>
        <table>
            <tr><th>Parameter</th><th>Value</th></tr>
            <tr><td>Server Instance</td><td><strong>$($results.MonitoringInfo.ServerInstance)</strong></td></tr>
            <tr><td>Start Time</td><td>$($results.MonitoringInfo.StartTime)</td></tr>
            <tr><td>End Time</td><td>$($results.MonitoringInfo.EndTime)</td></tr>
            <tr><td>Duration</td><td><strong>$($results.MonitoringInfo.DurationHours) hours</strong> ($($results.MonitoringInfo.DurationMinutes) minutes)</td></tr>
            <tr><td>Sample Interval</td><td>$($results.MonitoringInfo.SampleInterval) seconds</td></tr>
            <tr><td>Total Samples</td><td><strong>$($results.MonitoringInfo.TotalSamples)</strong></td></tr>
        </table>
        
        <h2> Peak Hours Detected</h2>
        <div class="warning">
            <h3> Critical Peak Periods</h3>
            <table>
                <tr>
                    <th>Metric</th>
                    <th>Peak Hour</th>
                    <th>Maximum Value</th>
                    <th>Hour Average</th>
                </tr>
                <tr>
                    <td><strong>CPU Usage</strong></td>
                    <td><span class="peak-indicator">$($results.PeakHours.CPU.Hour)</span></td>
                    <td><strong>$($results.PeakHours.CPU.MaxCPUCores) cores</strong></td>
                    <td>$($results.PeakHours.CPU.AvgCPUCores) cores</td>
                </tr>
                <tr>
                    <td><strong>Memory Usage</strong></td>
                    <td><span class="peak-indicator">$($results.PeakHours.Memory.Hour)</span></td>
                    <td><strong>$([math]::Round($results.PeakHours.Memory.MaxMemoryMB / 1024, 2)) GB</strong></td>
                    <td>$([math]::Round($results.PeakHours.Memory.AvgMemoryMB / 1024, 2)) GB</td>
                </tr>
                <tr>
                    <td><strong>Activity (Batch Req/Sec)</strong></td>
                    <td><span class="peak-indicator">$($results.PeakHours.Activity.Hour)</span></td>
                    <td><strong>$($results.PeakHours.Activity.MaxBatchRequestsPerSec)</strong></td>
                    <td>$($results.PeakHours.Activity.AvgBatchRequestsPerSec)</td>
                </tr>
                <tr>
                    <td><strong>IOPS</strong></td>
                    <td><span class="peak-indicator">$($results.PeakHours.IOPS.Hour)</span></td>
                    <td><strong>$($results.PeakHours.IOPS.TotalIOPS) IOPS</strong></td>
                    <td>Read: $($results.PeakHours.IOPS.ReadIOPS) / Write: $($results.PeakHours.IOPS.WriteIOPS)</td>
                </tr>
            </table>
        </div>
        
        <h2> Overall Statistics (Full Period)</h2>
        <div style="margin: 20px 0;">
            <div class="metric-box">
                <div class="metric-label">Average CPU</div>
                <div class="metric-value">$($results.OverallStatistics.CPU.Average) cores</div>
            </div>
            <div class="metric-box">
                <div class="metric-label">Peak CPU</div>
                <div class="metric-value">$($results.OverallStatistics.CPU.Maximum) cores</div>
            </div>
            <div class="metric-box">
                <div class="metric-label">P95 CPU</div>
                <div class="metric-value">$($results.OverallStatistics.CPU.P95) cores</div>
            </div>
        </div>
        <div style="margin: 20px 0;">
            <div class="metric-box">
                <div class="metric-label">Average Memory</div>
                <div class="metric-value">$($results.OverallStatistics.Memory.AverageGB) GB</div>
            </div>
            <div class="metric-box">
                <div class="metric-label">Peak Memory</div>
                <div class="metric-value">$($results.OverallStatistics.Memory.MaximumGB) GB</div>
            </div>
            <div class="metric-box">
                <div class="metric-label">P95 Memory</div>
                <div class="metric-value">$($results.OverallStatistics.Memory.P95GB) GB</div>
            </div>
        </div>
        <div style="margin: 20px 0;">
            <div class="metric-box">
                <div class="metric-label">Avg Read IOPS</div>
                <div class="metric-value">$($results.OverallStatistics.IOPS.AvgReadIOPS)</div>
            </div>
            <div class="metric-box">
                <div class="metric-label">Avg Write IOPS</div>
                <div class="metric-value">$($results.OverallStatistics.IOPS.AvgWriteIOPS)</div>
            </div>
            <div class="metric-box">
                <div class="metric-label">Total IOPS</div>
                <div class="metric-value">$($results.OverallStatistics.IOPS.TotalIOPS)</div>
            </div>
        </div>
        
        <h2> Hourly Pattern Analysis</h2>
        <table>
            <tr>
                <th>Hour</th>
                <th>Samples</th>
                <th>Avg CPU</th>
                <th>Max CPU</th>
                <th>Avg Memory</th>
                <th>Max Memory</th>
                <th>Batch Req/Sec</th>
                <th>Connections</th>
                <th>Total IOPS</th>
            </tr>
"@

foreach ($hourStat in $hourlyAnalysis) {
    $isPeakCPU = if ($hourStat.Hour -eq $peakHourCPU.Hour) { " class='peak-indicator'" } else { "" }
    $isPeakMemory = if ($hourStat.Hour -eq $peakHourMemory.Hour) { " class='peak-indicator'" } else { "" }
    $isPeakActivity = if ($hourStat.Hour -eq $peakHourActivity.Hour) { " class='peak-indicator'" } else { "" }
    
    $html += @"
            <tr>
                <td$isPeakCPU>$($hourStat.Hour)</td>
                <td>$($hourStat.SampleCount)</td>
                <td>$($hourStat.AvgCPUCores) cores</td>
                <td><strong>$($hourStat.MaxCPUCores) cores</strong></td>
                <td>$([math]::Round($hourStat.AvgMemoryMB / 1024, 2)) GB</td>
                <td><strong>$([math]::Round($hourStat.MaxMemoryMB / 1024, 2)) GB</strong></td>
                <td$isPeakActivity>$($hourStat.AvgBatchRequestsPerSec)</td>
                <td>$($hourStat.AvgUserConnections)</td>
                <td>$($hourStat.TotalIOPS)</td>
            </tr>
"@
}

$html += @"
        </table>
        
        <h2>Azure VM Recommendation</h2>
        <div class="success">
            <h3>Recommended Configuration (Based on PEAK + 20% headroom)</h3>
            <table>
                <tr>
                    <th>Component</th>
                    <th>Recommendation</th>
                    <th>Specifications</th>
                    <th>Monthly Cost (EUR)</th>
                </tr>
                <tr>
                    <td><strong>Virtual Machine</strong></td>
                    <td><strong style="font-size: 18px;">$($results.AzureRecommendation.VM.SKU)</strong></td>
                    <td>$($results.AzureRecommendation.VM.vCPUs) vCPUs, $($results.AzureRecommendation.VM.MemoryGB) GB RAM</td>
                    <td><strong>€$($results.AzureRecommendation.VM.MonthlyCostEUR)</strong></td>
                </tr>
                <tr>
                    <td><strong>Disk Configuration</strong></td>
                    <td><strong>$($results.AzureRecommendation.Disk.Configuration)</strong></td>
                    <td>Based on $($results.OverallStatistics.IOPS.TotalIOPS) IOPS measured</td>
                    <td><strong>€$($results.AzureRecommendation.Disk.MonthlyCostEUR)</strong></td>
                </tr>
                <tr style="background: #e8f5e9;">
                    <td colspan="3"><strong>TOTAL ESTIMATED MONTHLY COST</strong></td>
                    <td><strong style="font-size: 20px; color: #4caf50;">€$($results.AzureRecommendation.TotalMonthlyCostEUR)</strong></td>
                </tr>
            </table>
            <p><em>$($results.AzureRecommendation.SizingBasis)</em></p>
        </div>
        
        <h2> Sizing Methodology</h2>
        <div class="warning">
            <h3> Workload-Based Sizing (Used Here)</h3>
            <p>This recommendation is based on <strong>REAL workload measurements</strong> over $([math]::Round($Duration/60,1)) hours:</p>
            <ul>
                <li> Captures actual CPU usage during peak hours</li>
                <li> Measures real memory commitment (not total RAM installed)</li>
                <li> Records actual IOPS under load (not disk capacity)</li>
                <li> Identifies peak patterns to size for worst-case scenarios</li>
                <li> Adds 20% headroom for growth and seasonal peaks</li>
            </ul>
            <p><strong>Result:</strong> Right-sized Azure VM that meets performance requirements without over-provisioning. Typical savings: 30-50% vs hardware-based sizing.</p>
        </div>
        
        <div style="margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px;">
            <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Azure Architect Pro | Workload-Based Sizing for SQL Server Migration</p>
        </div>
    </div>
</body>
</html>
"@

$html | Out-File -FilePath $reportFile -Encoding UTF8 -Force
Write-Host "    HTML: $reportFile" -ForegroundColor Green
Write-Host ""

# Summary output
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "   MONITORING COMPLETED SUCCESSFULLY" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host " Summary:" -ForegroundColor Yellow
Write-Host "   Duration:        $([math]::Round($Duration/60,1)) hours" -ForegroundColor White
Write-Host "   Samples:         $($samples.Count)" -ForegroundColor White
Write-Host "   Avg CPU:         $($results.OverallStatistics.CPU.Average) cores" -ForegroundColor White
Write-Host "   Peak CPU:        $($results.OverallStatistics.CPU.Maximum) cores" -ForegroundColor White
Write-Host "   Avg Memory:      $($results.OverallStatistics.Memory.AverageGB) GB" -ForegroundColor White
Write-Host "   Peak Memory:     $($results.OverallStatistics.Memory.MaximumGB) GB" -ForegroundColor White
Write-Host "   Total IOPS:      $($results.OverallStatistics.IOPS.TotalIOPS)" -ForegroundColor White
Write-Host ""
Write-Host " Peak Hours:" -ForegroundColor Yellow
Write-Host "   CPU Peak:        $($results.PeakHours.CPU.Hour) - $($results.PeakHours.CPU.MaxCPUCores) cores" -ForegroundColor White
Write-Host "   Memory Peak:     $($results.PeakHours.Memory.Hour) - $([math]::Round($results.PeakHours.Memory.MaxMemoryMB / 1024, 2)) GB" -ForegroundColor White
Write-Host "   Activity Peak:   $($results.PeakHours.Activity.Hour) - $($results.PeakHours.Activity.MaxBatchRequestsPerSec) batch req/sec" -ForegroundColor White
Write-Host "   IOPS Peak:       $($results.PeakHours.IOPS.Hour) - $($results.PeakHours.IOPS.TotalIOPS) IOPS" -ForegroundColor White
Write-Host ""
Write-Host "  Azure Recommendation:" -ForegroundColor Yellow
Write-Host "   VM SKU:          $($results.AzureRecommendation.VM.SKU)" -ForegroundColor White
Write-Host "   vCPUs:           $($results.AzureRecommendation.VM.vCPUs)" -ForegroundColor White
Write-Host "   Memory:          $($results.AzureRecommendation.VM.MemoryGB) GB" -ForegroundColor White
Write-Host "   Disk:            $($results.AzureRecommendation.Disk.Configuration)" -ForegroundColor White
Write-Host "   Monthly Cost:    €$($results.AzureRecommendation.TotalMonthlyCostEUR)" -ForegroundColor Green
Write-Host ""
Write-Host " Files Generated:" -ForegroundColor Yellow
Write-Host "   JSON:       $resultsFile" -ForegroundColor White
Write-Host "   HTML:       $reportFile" -ForegroundColor White
Write-Host "   Checkpoint: $checkpointFile" -ForegroundColor White
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
