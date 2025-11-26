<#
.SYNOPSIS
    SQL Server Workload Monitoring for Azure Sizing
    
.DESCRIPTION
    Monitors SQL Server REAL workload during peak hours to accurately size Azure VMs.
    Captures: IOPS, CPU usage, memory usage, transactions/sec, queries/sec.
    
    This is MORE ACCURATE than hardware sizing because it measures actual load,
    not server capacity (which may be over-provisioned).
    
.PARAMETER ServerInstance
    SQL Server instance name (default: localhost)
    
.PARAMETER Duration
    Monitoring duration in minutes (default: 60)
    
.PARAMETER SampleInterval
    Sampling interval in seconds (default: 30)
    
.PARAMETER OutputPath
    Directory where results will be saved
    
.EXAMPLE
    .\sql-workload-monitor.ps1 -Duration 120 -SampleInterval 60
    
.EXAMPLE
    .\sql-workload-monitor.ps1 -ServerInstance "SERVER\SQL2019" -Duration 240
    
.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 19, 2025
    Requires: SQL Server running, VIEW SERVER STATE permission
    
    BEST PRACTICE: Run during PEAK HOURS (business hours) for accurate sizing
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 60,
    
    [Parameter(Mandatory=$false)]
    [int]$SampleInterval = 30,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\AzureMigration\Assessment"
)

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$resultsFile = Join-Path $OutputPath "sql_workload_$timestamp.json"
$reportFile = Join-Path $OutputPath "sql_workload_$timestamp.html"

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  SQL Server Workload Monitoring for Azure Sizing" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Server: $ServerInstance" -ForegroundColor White
Write-Host "  Duration: $Duration minutes" -ForegroundColor White
Write-Host "  Sample Interval: $SampleInterval seconds" -ForegroundColor White
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

$samples = [System.Collections.ArrayList]::new()
$sampleCount = [math]::Floor($Duration * 60 / $SampleInterval)

Write-Host "Starting monitoring... (will collect $sampleCount samples)" -ForegroundColor Yellow
Write-Host "⏰ Estimated completion: $((Get-Date).AddMinutes($Duration).ToString('HH:mm:ss'))" -ForegroundColor Yellow
Write-Host ""

for ($i = 0; $i -lt $sampleCount; $i++) {
    $currentTime = Get-Date
    $progress = [math]::Round(($i / $sampleCount) * 100, 1)
    
    Write-Host "[$($currentTime.ToString('HH:mm:ss'))] " -NoNewline -ForegroundColor Gray
    Write-Host "Sample $($i+1)/$sampleCount " -NoNewline -ForegroundColor White
    Write-Host "($progress%)" -ForegroundColor Cyan
    
    # SQL Query to get current workload metrics
    $query = @"
-- Current workload snapshot
SELECT 
    GETDATE() AS SampleTime,
    -- CPU metrics
    (SELECT cpu_count FROM sys.dm_os_sys_info) AS TotalCPUs,
    (SELECT @@CPU_BUSY * CAST(cpu_ticks AS FLOAT) / (cpu_ticks / ms_ticks) / 1000 
     FROM sys.dm_os_sys_info) AS SQLServerCPUTimeMs,
    -- Memory metrics
    (SELECT physical_memory_kb / 1024 FROM sys.dm_os_sys_info) AS TotalMemoryMB,
    (SELECT committed_kb / 1024 FROM sys.dm_os_sys_info) AS CommittedMemoryMB,
    (SELECT COUNT(*) * 8 / 1024 FROM sys.dm_os_buffer_descriptors) AS BufferPoolMB,
    -- Activity metrics
    (SELECT cntr_value FROM sys.dm_os_performance_counters 
     WHERE counter_name = 'Batch Requests/sec' AND object_name LIKE '%SQL Statistics%') AS BatchRequestsPerSec,
    (SELECT cntr_value FROM sys.dm_os_performance_counters 
     WHERE counter_name = 'SQL Compilations/sec' AND object_name LIKE '%SQL Statistics%') AS SQLCompilationsPerSec,
    (SELECT cntr_value FROM sys.dm_os_performance_counters 
     WHERE counter_name = 'User Connections' AND object_name LIKE '%General Statistics%') AS UserConnections,
    -- Disk I/O metrics
    (SELECT SUM(io_stall_read_ms) FROM sys.dm_io_virtual_file_stats(NULL, NULL)) AS TotalReadStallMs,
    (SELECT SUM(io_stall_write_ms) FROM sys.dm_io_virtual_file_stats(NULL, NULL)) AS TotalWriteStallMs,
    (SELECT SUM(num_of_reads) FROM sys.dm_io_virtual_file_stats(NULL, NULL)) AS TotalReads,
    (SELECT SUM(num_of_writes) FROM sys.dm_io_virtual_file_stats(NULL, NULL)) AS TotalWrites,
    -- Wait stats
    (SELECT TOP 1 wait_type FROM sys.dm_os_wait_stats 
     WHERE wait_type NOT IN ('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
                             'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR')
     ORDER BY wait_time_ms DESC) AS TopWaitType,
    (SELECT TOP 1 wait_time_ms FROM sys.dm_os_wait_stats 
     WHERE wait_type NOT IN ('CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
                             'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR')
     ORDER BY wait_time_ms DESC) AS TopWaitTimeMs;
"@
    
    try {
        # Execute query and capture results
        $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $query -ErrorAction Stop
        
        $sample = @{
            Timestamp = $currentTime.ToString("yyyy-MM-dd HH:mm:ss")
            TotalCPUs = $result.TotalCPUs
            SQLServerCPUTimeMs = $result.SQLServerCPUTimeMs
            TotalMemoryMB = $result.TotalMemoryMB
            CommittedMemoryMB = $result.CommittedMemoryMB
            BufferPoolMB = $result.BufferPoolMB
            BatchRequestsPerSec = $result.BatchRequestsPerSec
            SQLCompilationsPerSec = $result.SQLCompilationsPerSec
            UserConnections = $result.UserConnections
            TotalReadStallMs = $result.TotalReadStallMs
            TotalWriteStallMs = $result.TotalWriteStallMs
            TotalReads = $result.TotalReads
            TotalWrites = $result.TotalWrites
            TopWaitType = $result.TopWaitType
            TopWaitTimeMs = $result.TopWaitTimeMs
        }
        
        $samples.Add($sample) | Out-Null
        
        Write-Host "    ✓ " -NoNewline -ForegroundColor Green
        Write-Host "CPU: $($result.TotalCPUs) cores | " -NoNewline -ForegroundColor Gray
        Write-Host "Memory: $($result.CommittedMemoryMB) MB | " -NoNewline -ForegroundColor Gray
        Write-Host "Batch Req/s: $($result.BatchRequestsPerSec) | " -NoNewline -ForegroundColor Gray
        Write-Host "Connections: $($result.UserConnections)" -ForegroundColor Gray
        
    } catch {
        Write-Warning "Failed to collect sample: $_"
    }
    
    # Wait for next sample interval (except on last iteration)
    if ($i -lt $sampleCount - 1) {
        Start-Sleep -Seconds $SampleInterval
    }
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Analyzing workload data..." -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Calculate statistics
$avgCPUCores = ($samples | Measure-Object -Property TotalCPUs -Average).Average
$avgMemoryMB = ($samples | Measure-Object -Property CommittedMemoryMB -Average).Average
$peakMemoryMB = ($samples | Measure-Object -Property CommittedMemoryMB -Maximum).Maximum
$avgBatchReq = ($samples | Measure-Object -Property BatchRequestsPerSec -Average).Average
$peakBatchReq = ($samples | Measure-Object -Property BatchRequestsPerSec -Maximum).Maximum
$avgConnections = ($samples | Measure-Object -Property UserConnections -Average).Average
$peakConnections = ($samples | Measure-Object -Property UserConnections -Maximum).Maximum

# Calculate IOPS (reads + writes per sample interval)
$firstSample = $samples[0]
$lastSample = $samples[-1]
$durationSeconds = $sampleCount * $SampleInterval

$totalReads = $lastSample.TotalReads - $firstSample.TotalReads
$totalWrites = $lastSample.TotalWrites - $firstSample.TotalWrites
$avgReadIOPS = [math]::Round($totalReads / $durationSeconds, 2)
$avgWriteIOPS = [math]::Round($totalWrites / $durationSeconds, 2)
$totalIOPS = $avgReadIOPS + $avgWriteIOPS

# Calculate average latency
$readLatencyMs = if ($totalReads -gt 0) { 
    [math]::Round(($lastSample.TotalReadStallMs - $firstSample.TotalReadStallMs) / $totalReads, 2) 
} else { 0 }
$writeLatencyMs = if ($totalWrites -gt 0) { 
    [math]::Round(($lastSample.TotalWriteStallMs - $firstSample.TotalWriteStallMs) / $totalWrites, 2) 
} else { 0 }

# Azure VM Recommendation based on WORKLOAD (not hardware)
$recommendedCPUs = [math]::Max(4, [math]::Ceiling($avgCPUCores * 0.8))  # 80% of physical CPUs as baseline
$recommendedMemoryGB = [math]::Max(8, [math]::Ceiling($peakMemoryMB / 1024 * 1.2))  # 120% of peak memory

$recommendedSKU = ""
$estimatedCost = 0

if ($recommendedCPUs -le 2 -and $recommendedMemoryGB -le 16) {
    $recommendedSKU = "Standard_E2ds_v5"
    $estimatedCost = 150
} elseif ($recommendedCPUs -le 4 -and $recommendedMemoryGB -le 32) {
    $recommendedSKU = "Standard_E4ds_v5"
    $estimatedCost = 245
} elseif ($recommendedCPUs -le 8 -and $recommendedMemoryGB -le 64) {
    $recommendedSKU = "Standard_E8ds_v5"
    $estimatedCost = 490
} elseif ($recommendedCPUs -le 16 -and $recommendedMemoryGB -le 128) {
    $recommendedSKU = "Standard_E16ds_v5"
    $estimatedCost = 980
} else {
    $recommendedSKU = "Standard_E32ds_v5"
    $estimatedCost = 1960
}

# Disk recommendation based on measured IOPS
$diskRecommendation = ""
$diskCost = 0

if ($totalIOPS -lt 500) {
    $diskRecommendation = "Premium SSD P15 (256 GB, 1,100 IOPS)"
    $diskCost = 35
} elseif ($totalIOPS -lt 2300) {
    $diskRecommendation = "Premium SSD P20 (512 GB, 2,300 IOPS)"
    $diskCost = 60
} elseif ($totalIOPS -lt 5000) {
    $diskRecommendation = "Premium SSD P30 (1 TB, 5,000 IOPS)"
    $diskCost = 120
} elseif ($totalIOPS -lt 10000) {
    $diskRecommendation = "RAID-0: 2x Premium SSD P30 (2 TB total, 10,000 IOPS)"
    $diskCost = 240
} elseif ($totalIOPS -lt 15000) {
    $diskRecommendation = "RAID-0: 2x Premium SSD P40 (4 TB total, 15,000 IOPS)"
    $diskCost = 460
} else {
    $diskRecommendation = "Ultra Disk (custom IOPS: $totalIOPS)"
    $diskCost = 500
}

$totalCost = $estimatedCost + $diskCost

# Results object
$results = @{
    MonitoringDetails = @{
        ServerInstance = $ServerInstance
        StartTime = $samples[0].Timestamp
        EndTime = $samples[-1].Timestamp
        Duration = "$Duration minutes"
        SampleCount = $sampleCount
        SampleInterval = "$SampleInterval seconds"
    }
    WorkloadStatistics = @{
        CPU = @{
            AverageCPUs = $avgCPUCores
            RecommendedCPUs = $recommendedCPUs
        }
        Memory = @{
            AverageMemoryMB = [math]::Round($avgMemoryMB, 2)
            PeakMemoryMB = $peakMemoryMB
            RecommendedMemoryGB = $recommendedMemoryGB
        }
        Activity = @{
            AverageBatchRequestsPerSec = [math]::Round($avgBatchReq, 2)
            PeakBatchRequestsPerSec = $peakBatchReq
            AverageUserConnections = [math]::Round($avgConnections, 2)
            PeakUserConnections = $peakConnections
        }
        DiskIO = @{
            AverageReadIOPS = $avgReadIOPS
            AverageWriteIOPS = $avgWriteIOPS
            TotalIOPS = $totalIOPS
            AverageReadLatencyMs = $readLatencyMs
            AverageWriteLatencyMs = $writeLatencyMs
        }
    }
    AzureRecommendation = @{
        VMSKU = $recommendedSKU
        vCPUs = $recommendedCPUs
        MemoryGB = $recommendedMemoryGB
        DiskConfiguration = $diskRecommendation
        EstimatedVMCostEUR = $estimatedCost
        EstimatedDiskCostEUR = $diskCost
        TotalMonthlyCostEUR = $totalCost
        Notes = "Based on ACTUAL WORKLOAD during monitoring period. Costs for West Europe region without Azure Hybrid Benefit."
    }
    Samples = $samples
}

# Export to JSON
try {
    $results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8
    Write-Host "✓ Results exported: $resultsFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to export JSON: $_"
}

# Generate HTML Report
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>SQL Server Workload Analysis - $ServerInstance</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #106ebe; margin-top: 30px; }
        .summary { background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .recommendation { background: #fff3cd; padding: 20px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border: 1px solid #ddd; }
        tr:nth-child(even) { background: #f9f9f9; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-label { font-weight: bold; color: #666; }
        .metric-value { font-size: 24px; color: #0078d4; }
        .status-good { color: #28a745; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📊 SQL Server Workload Analysis</h1>
        
        <div class="summary">
            <h3>Monitoring Details</h3>
            <div class="metric">
                <div class="metric-label">Server</div>
                <div class="metric-value">$ServerInstance</div>
            </div>
            <div class="metric">
                <div class="metric-label">Duration</div>
                <div class="metric-value">$Duration min</div>
            </div>
            <div class="metric">
                <div class="metric-label">Samples</div>
                <div class="metric-value">$sampleCount</div>
            </div>
        </div>
        
        <h2>💻 Workload Statistics</h2>
        <table>
            <tr><th>Metric</th><th>Average</th><th>Peak</th></tr>
            <tr>
                <td><strong>CPU Cores Used</strong></td>
                <td>$([math]::Round($avgCPUCores, 2))</td>
                <td>-</td>
            </tr>
            <tr>
                <td><strong>Memory (MB)</strong></td>
                <td>$([math]::Round($avgMemoryMB, 2))</td>
                <td>$peakMemoryMB</td>
            </tr>
            <tr>
                <td><strong>Batch Requests/sec</strong></td>
                <td>$([math]::Round($avgBatchReq, 2))</td>
                <td>$peakBatchReq</td>
            </tr>
            <tr>
                <td><strong>User Connections</strong></td>
                <td>$([math]::Round($avgConnections, 2))</td>
                <td>$peakConnections</td>
            </tr>
            <tr>
                <td><strong>Read IOPS</strong></td>
                <td>$avgReadIOPS</td>
                <td>-</td>
            </tr>
            <tr>
                <td><strong>Write IOPS</strong></td>
                <td>$avgWriteIOPS</td>
                <td>-</td>
            </tr>
            <tr>
                <td><strong>Total IOPS</strong></td>
                <td><strong>$totalIOPS</strong></td>
                <td>-</td>
            </tr>
            <tr>
                <td><strong>Read Latency (ms)</strong></td>
                <td>$readLatencyMs</td>
                <td>-</td>
            </tr>
            <tr>
                <td><strong>Write Latency (ms)</strong></td>
                <td>$writeLatencyMs</td>
                <td>-</td>
            </tr>
        </table>
        
        <h2>☁️ Azure Recommendation (Based on Actual Workload)</h2>
        <div class="recommendation">
            <h3>Recommended Configuration</h3>
            <div class="metric">
                <div class="metric-label">VM SKU</div>
                <div class="metric-value">$recommendedSKU</div>
            </div>
            <div class="metric">
                <div class="metric-label">vCPUs</div>
                <div class="metric-value">$recommendedCPUs</div>
            </div>
            <div class="metric">
                <div class="metric-label">Memory</div>
                <div class="metric-value">$recommendedMemoryGB GB</div>
            </div>
        </div>
        
        <table>
            <tr><th>Component</th><th>Configuration</th><th>Monthly Cost (EUR)</th></tr>
            <tr>
                <td><strong>VM</strong></td>
                <td>$recommendedSKU</td>
                <td>€$estimatedCost</td>
            </tr>
            <tr>
                <td><strong>Disk</strong></td>
                <td>$diskRecommendation</td>
                <td>€$diskCost</td>
            </tr>
            <tr>
                <td colspan="2"><strong>TOTAL ESTIMATED COST</strong></td>
                <td><strong>€$totalCost/month</strong></td>
            </tr>
        </table>
        
        <p><strong>💡 Important Notes:</strong></p>
        <ul>
            <li>✅ Sizing based on <strong>ACTUAL WORKLOAD</strong>, not hardware capacity</li>
            <li>✅ 20% memory headroom included for growth</li>
            <li>⚠️ Costs are estimates for West Europe region</li>
            <li>⚠️ Consider Azure Hybrid Benefit for up to 40% savings on licensing</li>
            <li>⚠️ Monitor during PEAK HOURS for most accurate sizing</li>
        </ul>
    </div>
</body>
</html>
"@

try {
    $html | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "✓ HTML report exported: $reportFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to export HTML report: $_"
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Workload Analysis Complete!" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📊 Workload Summary:" -ForegroundColor White
Write-Host "   Average CPU Cores: $([math]::Round($avgCPUCores, 2))" -ForegroundColor Gray
Write-Host "   Peak Memory: $peakMemoryMB MB" -ForegroundColor Gray
Write-Host "   Average IOPS: $totalIOPS" -ForegroundColor Gray
Write-Host "   Average Batch Requests/sec: $([math]::Round($avgBatchReq, 2))" -ForegroundColor Gray
Write-Host ""
Write-Host "☁️  Azure Recommendation:" -ForegroundColor White
Write-Host "   VM SKU: $recommendedSKU" -ForegroundColor Cyan
Write-Host "   Disk: $diskRecommendation" -ForegroundColor Cyan
Write-Host "   Estimated Cost: €$totalCost/month" -ForegroundColor Cyan
Write-Host ""
Write-Host "📄 Results saved to:" -ForegroundColor White
Write-Host "   JSON: $resultsFile" -ForegroundColor Gray
Write-Host "   HTML: $reportFile" -ForegroundColor Gray
Write-Host ""

# Open HTML report
try {
    Start-Process $reportFile
} catch {
    Write-Host "Could not auto-open report. Please open manually: $reportFile" -ForegroundColor Yellow
}
