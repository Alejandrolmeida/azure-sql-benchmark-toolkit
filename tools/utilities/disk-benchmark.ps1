<#
.SYNOPSIS
    Disk IOPS and Latency Benchmark Tool
    
.DESCRIPTION
    Lightweight script focused ONLY on disk performance testing.
    Use this for quick IOPS and latency measurements without full system assessment.
    
.PARAMETER DriveLetter
    Drive letter to test (e.g., "C", "D", "E")
    
.PARAMETER Duration
    Duration of test in seconds (default: 30)
    
.PARAMETER TestFileSize
    Size of test file in MB (default: 500)
    
.EXAMPLE
    .\disk-benchmark.ps1 -DriveLetter "C" -Duration 60
    
.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 18, 2025
    WARNING: Running on system drive (C:) may impact performance during test
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$DriveLetter,
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 30,
    
    [Parameter(Mandatory=$false)]
    [int]$TestFileSizeMB = 500
)

# Ensure admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges"
    exit 1
}

$DriveLetter = $DriveLetter.TrimEnd(':')

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Disk Performance Benchmark Tool" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Target Drive: ${DriveLetter}:\" -ForegroundColor White
Write-Host "Test Duration: $Duration seconds" -ForegroundColor White
Write-Host "Test File Size: $TestFileSizeMB MB" -ForegroundColor White
Write-Host ""

# Check if drive exists
if (-not (Test-Path "${DriveLetter}:\")) {
    Write-Error "Drive ${DriveLetter}:\ does not exist"
    exit 1
}

# Check free space
$drive = Get-PSDrive $DriveLetter
$freeSpaceGB = [math]::Round($drive.Free / 1GB, 2)

Write-Host "Free Space: $freeSpaceGB GB" -ForegroundColor Gray

if ($freeSpaceGB -lt ($TestFileSizeMB / 1024 * 2)) {
    Write-Warning "Low disk space! Need at least $([math]::Round($TestFileSizeMB / 1024 * 2, 2)) GB free"
    $continue = Read-Host "Continue anyway? (yes/no)"
    if ($continue -ne "yes") {
        exit 1
    }
}

# Test file path
$testFile = "${DriveLetter}:\azure_disk_benchmark_$(Get-Random).tmp"
$blockSize = 8KB
$fileSize = $TestFileSizeMB * 1MB

Write-Host ""
Write-Host "Starting benchmark..." -ForegroundColor Yellow
Write-Host ""

# ================================================================
# Sequential Write Test
# ================================================================
Write-Host "[1/4] Sequential Write Test..." -ForegroundColor Cyan

$writeStart = Get-Date
$stream = [System.IO.File]::Create($testFile)
$buffer = New-Object byte[] $blockSize
$writeOps = 0

try {
    $endTime = $writeStart.AddSeconds($Duration / 4)
    while ((Get-Date) -lt $endTime -and $stream.Position -lt $fileSize) {
        $stream.Write($buffer, 0, $buffer.Length)
        $writeOps++
        
        # Progress indicator
        if ($writeOps % 1000 -eq 0) {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
} finally {
    $stream.Close()
}

$writeDuration = ((Get-Date) - $writeStart).TotalSeconds
$writeIOPS = [math]::Round($writeOps / $writeDuration, 2)
$writeMBps = [math]::Round(($writeOps * $blockSize / 1MB) / $writeDuration, 2)

Write-Host ""
Write-Host "  ✓ Sequential Write: $writeIOPS IOPS | $writeMBps MB/s" -ForegroundColor Green

# ================================================================
# Sequential Read Test
# ================================================================
Write-Host ""
Write-Host "[2/4] Sequential Read Test..." -ForegroundColor Cyan

$readStart = Get-Date
$stream = [System.IO.File]::OpenRead($testFile)
$readOps = 0

try {
    $endTime = $readStart.AddSeconds($Duration / 4)
    while ((Get-Date) -lt $endTime -and $stream.Position -lt $stream.Length) {
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -eq 0) { break }
        $readOps++
        
        # Progress indicator
        if ($readOps % 1000 -eq 0) {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
} finally {
    $stream.Close()
}

$readDuration = ((Get-Date) - $readStart).TotalSeconds
$readIOPS = [math]::Round($readOps / $readDuration, 2)
$readMBps = [math]::Round(($readOps * $blockSize / 1MB) / $readDuration, 2)

Write-Host ""
Write-Host "  ✓ Sequential Read: $readIOPS IOPS | $readMBps MB/s" -ForegroundColor Green

# ================================================================
# Random Write Test (Simplified)
# ================================================================
Write-Host ""
Write-Host "[3/4] Random Write Test..." -ForegroundColor Cyan

$randomWriteStart = Get-Date
$stream = [System.IO.File]::Open($testFile, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Write)
$randomWriteOps = 0
$random = New-Object System.Random

try {
    $endTime = $randomWriteStart.AddSeconds($Duration / 4)
    while ((Get-Date) -lt $endTime) {
        $randomPosition = $random.Next(0, [int]($stream.Length - $blockSize))
        $stream.Seek($randomPosition, [System.IO.SeekOrigin]::Begin) | Out-Null
        $stream.Write($buffer, 0, $buffer.Length)
        $randomWriteOps++
        
        # Progress indicator
        if ($randomWriteOps % 500 -eq 0) {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
} finally {
    $stream.Close()
}

$randomWriteDuration = ((Get-Date) - $randomWriteStart).TotalSeconds
$randomWriteIOPS = [math]::Round($randomWriteOps / $randomWriteDuration, 2)

Write-Host ""
Write-Host "  ✓ Random Write: $randomWriteIOPS IOPS" -ForegroundColor Green

# ================================================================
# Random Read Test (Simplified)
# ================================================================
Write-Host ""
Write-Host "[4/4] Random Read Test..." -ForegroundColor Cyan

$randomReadStart = Get-Date
$stream = [System.IO.File]::OpenRead($testFile)
$randomReadOps = 0

try {
    $endTime = $randomReadStart.AddSeconds($Duration / 4)
    while ((Get-Date) -lt $endTime) {
        $randomPosition = $random.Next(0, [int]($stream.Length - $blockSize))
        $stream.Seek($randomPosition, [System.IO.SeekOrigin]::Begin) | Out-Null
        $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
        if ($bytesRead -eq 0) { break }
        $randomReadOps++
        
        # Progress indicator
        if ($randomReadOps % 500 -eq 0) {
            Write-Host "." -NoNewline -ForegroundColor Gray
        }
    }
} finally {
    $stream.Close()
}

$randomReadDuration = ((Get-Date) - $randomReadStart).TotalSeconds
$randomReadIOPS = [math]::Round($randomReadOps / $randomReadDuration, 2)

Write-Host ""
Write-Host "  ✓ Random Read: $randomReadIOPS IOPS" -ForegroundColor Green

# ================================================================
# Latency Test (using Performance Counters)
# ================================================================
Write-Host ""
Write-Host "[Bonus] Disk Latency Measurement..." -ForegroundColor Cyan

try {
    $perfCounter = "\PhysicalDisk(*)\Avg. Disk sec/Read"
    $samples = (Get-Counter -Counter $perfCounter -SampleInterval 1 -MaxSamples 5 -ErrorAction SilentlyContinue).CounterSamples
    $diskSamples = $samples | Where-Object { $_.Path -like "*${DriveLetter}*" -or $_.Path -like "*_Total*" }
    
    if ($diskSamples) {
        $avgLatency = ($diskSamples | Measure-Object -Property CookedValue -Average).Average * 1000
        $latencyMs = [math]::Round($avgLatency, 2)
        Write-Host "  ✓ Average Read Latency: $latencyMs ms" -ForegroundColor Green
    } else {
        Write-Host "  ⚠ Could not measure latency" -ForegroundColor Yellow
        $latencyMs = 0
    }
} catch {
    Write-Host "  ⚠ Could not measure latency: $_" -ForegroundColor Yellow
    $latencyMs = 0
}

# ================================================================
# Cleanup
# ================================================================
Write-Host ""
Write-Host "Cleaning up test file..." -ForegroundColor Gray
Remove-Item $testFile -Force -ErrorAction SilentlyContinue

# ================================================================
# Summary Report
# ================================================================
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  BENCHMARK RESULTS SUMMARY" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Drive: ${DriveLetter}:\" -ForegroundColor White
Write-Host ""

$results = @"
+------------------------+------------------+------------------+
| Test Type              | IOPS             | Throughput       |
+------------------------+------------------+------------------+
| Sequential Write       | $($writeIOPS.ToString().PadLeft(16)) | $($writeMBps.ToString().PadLeft(12)) MB/s |
| Sequential Read        | $($readIOPS.ToString().PadLeft(16)) | $($readMBps.ToString().PadLeft(12)) MB/s |
| Random Write (4K)      | $($randomWriteIOPS.ToString().PadLeft(16)) | N/A              |
| Random Read (4K)       | $($randomReadIOPS.ToString().PadLeft(16)) | N/A              |
+------------------------+------------------+------------------+
"@

Write-Host $results

if ($latencyMs -gt 0) {
    Write-Host ""
    Write-Host "Average Read Latency: $latencyMs ms" -ForegroundColor White
}

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  AZURE DISK RECOMMENDATION" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Calculate average and peak IOPS
$avgIOPS = [math]::Round(($readIOPS + $writeIOPS + $randomReadIOPS + $randomWriteIOPS) / 4, 0)
$peakIOPS = [math]::Max([math]::Max($readIOPS, $writeIOPS), [math]::Max($randomReadIOPS, $randomWriteIOPS))
$avgThroughput = [math]::Round(($readMBps + $writeMBps) / 2, 2)

Write-Host "📊 On-Premises Performance Measured:" -ForegroundColor White
Write-Host "  • Average IOPS: $avgIOPS" -ForegroundColor Gray
Write-Host "  • Peak IOPS: $peakIOPS" -ForegroundColor Gray
Write-Host "  • Average Throughput: $avgThroughput MB/s" -ForegroundColor Gray
if ($latencyMs -gt 0) {
    Write-Host "  • Average Latency: $latencyMs ms" -ForegroundColor Gray
}
Write-Host ""

# Azure Premium SSD specifications
$azureDisks = @(
    @{Name="P6";  Size=64;   IOPS=240;   Throughput=50;  Latency=2; Cost=5},
    @{Name="P10"; Size=128;  IOPS=500;   Throughput=100; Latency=2; Cost=10},
    @{Name="P15"; Size=256;  IOPS=1100;  Throughput=125; Latency=2; Cost=35},
    @{Name="P20"; Size=512;  IOPS=2300;  Throughput=150; Latency=2; Cost=60},
    @{Name="P30"; Size=1024; IOPS=5000;  Throughput=200; Latency=2; Cost=120},
    @{Name="P40"; Size=2048; IOPS=7500;  Throughput=250; Latency=2; Cost=230},
    @{Name="P50"; Size=4096; IOPS=7500;  Throughput=250; Latency=2; Cost=450},
    @{Name="P60"; Size=8192; IOPS=16000; Throughput=500; Latency=2; Cost=900},
    @{Name="P70"; Size=16384;IOPS=18000; Throughput=750; Latency=2; Cost=1800},
    @{Name="P80"; Size=32768;IOPS=20000; Throughput=900; Latency=2; Cost=3600}
)

# Find appropriate single disk
$singleDisk = $null
$needsRAID = $false

foreach ($disk in $azureDisks) {
    if ($disk.IOPS -ge $peakIOPS -and $disk.Throughput -ge $avgThroughput) {
        $singleDisk = $disk
        break
    }
}

# If no single disk is sufficient, calculate RAID configuration
if ($null -eq $singleDisk) {
    $needsRAID = $true
    Write-Host "⚠️  SINGLE DISK INSUFFICIENT - RAID CONFIGURATION REQUIRED" -ForegroundColor Yellow
    Write-Host ""
    
    # Find smallest disk that can meet requirements in RAID-0
    $raidDisk = $null
    $raidDiskCount = 0
    
    foreach ($disk in $azureDisks) {
        for ($count = 2; $count -le 8; $count++) {
            $raidIOPS = $disk.IOPS * $count
            $raidThroughput = $disk.Throughput * $count
            
            if ($raidIOPS -ge $peakIOPS -and $raidThroughput -ge $avgThroughput) {
                $raidDisk = $disk
                $raidDiskCount = $count
                break
            }
        }
        if ($null -ne $raidDisk) { break }
    }
    
    if ($null -ne $raidDisk) {
        Write-Host "💡 RECOMMENDED CONFIGURATION: RAID-0 (Striping)" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "  Disk Model: Premium SSD $($raidDisk.Name) ($($raidDisk.Size) GB)" -ForegroundColor White
        Write-Host "  Number of Disks: $raidDiskCount" -ForegroundColor White
        Write-Host "  RAID Level: RAID-0 (Stripe)" -ForegroundColor White
        Write-Host "  Total Capacity: $($raidDisk.Size * $raidDiskCount) GB" -ForegroundColor White
        Write-Host ""
        
        $raidTotalIOPS = $raidDisk.IOPS * $raidDiskCount
        $raidTotalThroughput = $raidDisk.Throughput * $raidDiskCount
        $raidTotalCost = $raidDisk.Cost * $raidDiskCount
        
        Write-Host "📈 RAID-0 Performance:" -ForegroundColor Cyan
        Write-Host "  • Total IOPS: $raidTotalIOPS (vs $peakIOPS on-prem)" -ForegroundColor White
        Write-Host "  • Total Throughput: $raidTotalThroughput MB/s (vs $avgThroughput MB/s on-prem)" -ForegroundColor White
        Write-Host "  • Latency: ~$($raidDisk.Latency) ms (vs $latencyMs ms on-prem)" -ForegroundColor White
        Write-Host ""
        
        # Calculate performance gain/loss
        $iopsGain = [math]::Round((($raidTotalIOPS - $peakIOPS) / $peakIOPS) * 100, 1)
        $throughputGain = [math]::Round((($raidTotalThroughput - $avgThroughput) / $avgThroughput) * 100, 1)
        
        Write-Host "📊 Performance Comparison:" -ForegroundColor Cyan
        if ($iopsGain -gt 0) {
            Write-Host "  • IOPS: +$iopsGain% improvement ✓" -ForegroundColor Green
        } else {
            Write-Host "  • IOPS: $iopsGain% (matches requirement)" -ForegroundColor Yellow
        }
        
        if ($throughputGain -gt 0) {
            Write-Host "  • Throughput: +$throughputGain% improvement ✓" -ForegroundColor Green
        } else {
            Write-Host "  • Throughput: $throughputGain% (matches requirement)" -ForegroundColor Yellow
        }
        
        if ($latencyMs -gt 0 -and $raidDisk.Latency -lt $latencyMs) {
            $latencyImprovement = [math]::Round((($latencyMs - $raidDisk.Latency) / $latencyMs) * 100, 1)
            Write-Host "  • Latency: -$latencyImprovement% (faster) ✓" -ForegroundColor Green
        }
        
        Write-Host ""
        Write-Host "💰 Cost:" -ForegroundColor Cyan
        Write-Host "  • Monthly Cost: €$raidTotalCost/month ($raidDiskCount x €$($raidDisk.Cost))" -ForegroundColor White
        Write-Host ""
        
        Write-Host "⚙️  Windows Storage Spaces Configuration:" -ForegroundColor Cyan
        Write-Host "  1. Create Storage Pool with $raidDiskCount Premium SSD disks" -ForegroundColor Gray
        Write-Host "  2. Create Virtual Disk with Simple (Stripe) layout" -ForegroundColor Gray
        Write-Host "  3. Set interleave (stripe size) to 64KB for SQL Server workloads" -ForegroundColor Gray
        Write-Host "  4. Format with NTFS and 64KB allocation unit size" -ForegroundColor Gray
        Write-Host ""
        Write-Host "  PowerShell Command Example:" -ForegroundColor Gray
        Write-Host "  New-StoragePool -FriendlyName 'SQLDataPool' -StorageSubSystemId (Get-StorageSubSystem).UniqueId -PhysicalDisks (Get-PhysicalDisk -CanPool `$true)" -ForegroundColor DarkGray
        Write-Host "  New-VirtualDisk -FriendlyName 'SQLDataDisk' -StoragePoolFriendlyName 'SQLDataPool' -ResiliencySettingName Simple -Size $($raidDisk.Size * $raidDiskCount)GB -ProvisioningType Fixed -Interleave 64KB" -ForegroundColor DarkGray
        Write-Host ""
        
    } else {
        Write-Host "⚠️  Requirements exceed even maximum RAID configuration" -ForegroundColor Red
        Write-Host "  Consider Azure Ultra Disk with custom IOPS/throughput provisioning" -ForegroundColor Yellow
        Write-Host ""
    }
    
} else {
    # Single disk is sufficient
    Write-Host "✅ RECOMMENDED CONFIGURATION: Single Disk" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Disk Model: Premium SSD $($singleDisk.Name) ($($singleDisk.Size) GB)" -ForegroundColor White
    Write-Host ""
    
    Write-Host "📈 Azure Disk Performance:" -ForegroundColor Cyan
    Write-Host "  • IOPS: $($singleDisk.IOPS) (vs $peakIOPS on-prem)" -ForegroundColor White
    Write-Host "  • Throughput: $($singleDisk.Throughput) MB/s (vs $avgThroughput MB/s on-prem)" -ForegroundColor White
    Write-Host "  • Latency: ~$($singleDisk.Latency) ms (vs $latencyMs ms on-prem)" -ForegroundColor White
    Write-Host ""
    
    # Calculate performance gain/loss
    $iopsGain = [math]::Round((($singleDisk.IOPS - $peakIOPS) / $peakIOPS) * 100, 1)
    $throughputGain = [math]::Round((($singleDisk.Throughput - $avgThroughput) / $avgThroughput) * 100, 1)
    
    Write-Host "📊 Performance Comparison:" -ForegroundColor Cyan
    
    if ($iopsGain -gt 10) {
        Write-Host "  • IOPS: +$iopsGain% improvement ✓✓" -ForegroundColor Green
        Write-Host "    (More than sufficient - consider smaller disk to save cost)" -ForegroundColor Gray
    } elseif ($iopsGain -gt 0) {
        Write-Host "  • IOPS: +$iopsGain% improvement ✓" -ForegroundColor Green
    } else {
        Write-Host "  • IOPS: $iopsGain% (adequate)" -ForegroundColor Yellow
    }
    
    if ($throughputGain -gt 10) {
        Write-Host "  • Throughput: +$throughputGain% improvement ✓✓" -ForegroundColor Green
    } elseif ($throughputGain -gt 0) {
        Write-Host "  • Throughput: +$throughputGain% improvement ✓" -ForegroundColor Green
    } else {
        Write-Host "  • Throughput: $throughputGain% (adequate)" -ForegroundColor Yellow
    }
    
    if ($latencyMs -gt 0) {
        if ($singleDisk.Latency -lt $latencyMs) {
            $latencyImprovement = [math]::Round((($latencyMs - $singleDisk.Latency) / $latencyMs) * 100, 1)
            Write-Host "  • Latency: -$latencyImprovement% (faster) ✓" -ForegroundColor Green
        } elseif ($singleDisk.Latency -eq $latencyMs) {
            Write-Host "  • Latency: Same performance" -ForegroundColor White
        } else {
            Write-Host "  • Latency: +$([math]::Round((($singleDisk.Latency - $latencyMs) / $latencyMs) * 100, 1))% (slower)" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "💰 Cost:" -ForegroundColor Cyan
    Write-Host "  • Monthly Cost: €$($singleDisk.Cost)/month" -ForegroundColor White
    Write-Host ""
    
    # Check if we can downgrade to save cost
    $previousDisk = $null
    foreach ($disk in $azureDisks) {
        if ($disk.Name -eq $singleDisk.Name) { break }
        $previousDisk = $disk
    }
    
    if ($null -ne $previousDisk) {
        if ($previousDisk.IOPS -ge ($peakIOPS * 0.8) -and $previousDisk.Throughput -ge ($avgThroughput * 0.8)) {
            $savings = $singleDisk.Cost - $previousDisk.Cost
            Write-Host "💡 Cost Optimization Opportunity:" -ForegroundColor Yellow
            Write-Host "  Consider Premium SSD $($previousDisk.Name) ($($previousDisk.Size) GB) to save €$savings/month" -ForegroundColor Gray
            Write-Host "  Performance: $($previousDisk.IOPS) IOPS, $($previousDisk.Throughput) MB/s" -ForegroundColor Gray
            Write-Host ""
        }
    }
}

# Latency interpretation
if ($latencyMs -gt 0) {
    Write-Host "Latency Analysis:" -ForegroundColor White
    if ($latencyMs -lt 10) {
        Write-Host "  ✓ Excellent latency (<10ms) - Premium SSD will maintain performance" -ForegroundColor Green
    } elseif ($latencyMs -lt 20) {
        Write-Host "  ✓ Good latency (10-20ms) - Premium SSD recommended" -ForegroundColor Green
    } elseif ($latencyMs -lt 50) {
        Write-Host "  ⚠ Medium latency (20-50ms) - Premium SSD highly recommended" -ForegroundColor Yellow
    } else {
        Write-Host "  ⚠ High latency (>50ms) - Upgrade to Premium SSD REQUIRED" -ForegroundColor Red
    }
    Write-Host ""
}

Write-Host "Note: Azure Premium SSDs provide consistent low-latency performance" -ForegroundColor Gray
Write-Host "      Typical latency: 1-5ms for Premium SSD, <1ms for Ultra Disk" -ForegroundColor Gray
Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Benchmark Complete!" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
