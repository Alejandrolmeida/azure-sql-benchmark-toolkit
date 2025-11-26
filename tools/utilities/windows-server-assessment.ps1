<#
.SYNOPSIS
    Windows Server & SQL Server Assessment Tool for Azure Migration
    
.DESCRIPTION
    Comprehensive assessment script that collects hardware, performance, and SQL Server
    inventory data from on-premises Windows Server to size Azure VM appropriately.
    
    Collects:
    - CPU specifications and utilization
    - Memory capacity and usage
    - Disk inventory with IOPS and latency benchmarks
    - SQL Server configuration and database sizes
    - Network configuration
    - Performance counters
    
.PARAMETER OutputPath
    Directory where results will be saved (default: C:\AzureMigration\Assessment)
    
.PARAMETER BenchmarkDuration
    Duration in seconds for disk performance tests (default: 60)
    
.PARAMETER IncludeSQLInventory
    Include SQL Server inventory (requires SQL Server installed)
    
.EXAMPLE
    .\windows-server-assessment.ps1
    
.EXAMPLE
    .\windows-server-assessment.ps1 -OutputPath "D:\Assessment" -BenchmarkDuration 120
    
.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 18, 2025
    Requires: PowerShell 5.1+, Administrator privileges
    Compatible: Windows Server 2016/2019/2022
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\AzureMigration\Assessment",
    
    [Parameter(Mandatory=$false)]
    [int]$BenchmarkDuration = 60,
    
    [Parameter(Mandatory=$false)]
    [switch]$IncludeSQLInventory = $true,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDiskBenchmark = $false
)

# Ensure script runs with admin privileges
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

# Create output directory
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$reportFile = Join-Path $OutputPath "assessment_$timestamp.html"
$jsonFile = Join-Path $OutputPath "assessment_$timestamp.json"
$csvFile = Join-Path $OutputPath "assessment_$timestamp.csv"

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Azure Migration Assessment Tool" -ForegroundColor Cyan
Write-Host "  Collecting server specifications and performance data..." -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Initialize results object
$assessmentResults = @{
    Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ServerName = $env:COMPUTERNAME
    Assessment = @{
        Computer = @{}
        CPU = @{}
        Memory = @{}
        Disks = @()
        Network = @{}
        OperatingSystem = @{}
        SQLServer = @{}
        Performance = @{}
        AzureRecommendation = @{}
    }
}

#region Helper Functions

function Write-Progress-Step {
    param(
        [string]$Step,
        [string]$Status = "Running"
    )
    Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
    Write-Host "$Step" -NoNewline -ForegroundColor White
    Write-Host " ... " -NoNewline -ForegroundColor Gray
    Write-Host "$Status" -ForegroundColor Yellow
}

function Test-SQLServerInstalled {
    try {
        $sqlServices = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "MSSQL*" -and $_.Status -eq "Running" }
        return ($null -ne $sqlServices -and $sqlServices.Count -gt 0)
    } catch {
        return $false
    }
}

function Get-DiskIOPS {
    param(
        [string]$DriveLetter,
        [int]$Duration = 30
    )
    
    Write-Host "    Testing IOPS for drive $DriveLetter (this may take $Duration seconds)..." -ForegroundColor Gray
    
    try {
        # Test file path
        $testFile = "${DriveLetter}:\azure_iops_test_$(Get-Random).tmp"
        $blockSize = 8KB
        $fileSize = 100MB
        
        # Sequential Write Test
        $writeStart = Get-Date
        $stream = [System.IO.File]::Create($testFile)
        $buffer = New-Object byte[] $blockSize
        $writeOps = 0
        
        $endTime = $writeStart.AddSeconds($Duration / 4)
        while ((Get-Date) -lt $endTime -and $stream.Position -lt $fileSize) {
            $stream.Write($buffer, 0, $buffer.Length)
            $writeOps++
        }
        $stream.Close()
        $writeDuration = ((Get-Date) - $writeStart).TotalSeconds
        $writeIOPS = [math]::Round($writeOps / $writeDuration, 2)
        
        # Sequential Read Test
        $readStart = Get-Date
        $stream = [System.IO.File]::OpenRead($testFile)
        $readOps = 0
        
        $endTime = $readStart.AddSeconds($Duration / 4)
        while ((Get-Date) -lt $endTime -and $stream.Position -lt $stream.Length) {
            $bytesRead = $stream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -eq 0) { break }
            $readOps++
        }
        $stream.Close()
        $readDuration = ((Get-Date) - $readStart).TotalSeconds
        $readIOPS = [math]::Round($readOps / $readDuration, 2)
        
        # Random I/O Test (simplified)
        $randomIOPS = [math]::Round(($readIOPS + $writeIOPS) / 2 * 0.7, 2)  # Estimate
        
        # Cleanup
        Remove-Item $testFile -Force -ErrorAction SilentlyContinue
        
        return @{
            SequentialReadIOPS = $readIOPS
            SequentialWriteIOPS = $writeIOPS
            RandomIOPS = $randomIOPS
            TestDuration = $Duration
        }
    } catch {
        Write-Warning "Failed to test IOPS for drive ${DriveLetter}: $_"
        return @{
            SequentialReadIOPS = 0
            SequentialWriteIOPS = 0
            RandomIOPS = 0
            TestDuration = 0
            Error = $_.Exception.Message
        }
    }
}

function Get-DiskLatency {
    param([string]$DriveLetter)
    
    try {
        $perfCounter = "\PhysicalDisk(*)\Avg. Disk sec/Read"
        $samples = (Get-Counter -Counter $perfCounter -SampleInterval 1 -MaxSamples 5 -ErrorAction SilentlyContinue).CounterSamples
        $diskSamples = $samples | Where-Object { $_.Path -like "*$DriveLetter*" }
        
        if ($diskSamples) {
            $avgLatency = ($diskSamples | Measure-Object -Property CookedValue -Average).Average * 1000
            return [math]::Round($avgLatency, 2)
        }
        return 0
    } catch {
        return 0
    }
}

#endregion

#region 1. Computer System Information

Write-Progress-Step "Collecting computer system information"

try {
    $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    
    $assessmentResults.Assessment.Computer = @{
        Name = $computerSystem.Name
        Manufacturer = $computerSystem.Manufacturer
        Model = $computerSystem.Model
        Domain = $computerSystem.Domain
        TotalPhysicalMemoryGB = [math]::Round($computerSystem.TotalPhysicalMemory / 1GB, 2)
        NumberOfProcessors = $computerSystem.NumberOfProcessors
        NumberOfLogicalProcessors = $computerSystem.NumberOfLogicalProcessors
        BIOSVersion = $bios.SMBIOSBIOSVersion
        SerialNumber = $bios.SerialNumber
    }
    
    Write-Host "    ✓ Computer: $($computerSystem.Name) ($($computerSystem.Manufacturer) $($computerSystem.Model))" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect computer system information: $_"
}

#endregion

#region 2. CPU Information

Write-Progress-Step "Collecting CPU information"

try {
    $processors = Get-CimInstance -ClassName Win32_Processor
    $cpuInfo = @()
    
    foreach ($cpu in $processors) {
        $cpuInfo += @{
            Name = $cpu.Name
            Manufacturer = $cpu.Manufacturer
            NumberOfCores = $cpu.NumberOfCores
            NumberOfLogicalProcessors = $cpu.NumberOfLogicalProcessors
            MaxClockSpeed = $cpu.MaxClockSpeed
            CurrentClockSpeed = $cpu.CurrentClockSpeed
            L2CacheSize = $cpu.L2CacheSize
            L3CacheSize = $cpu.L3CacheSize
        }
    }
    
    $assessmentResults.Assessment.CPU = @{
        Processors = $cpuInfo
        TotalCores = ($processors | Measure-Object -Property NumberOfCores -Sum).Sum
        TotalLogicalProcessors = ($processors | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
    }
    
    Write-Host "    ✓ CPU: $($processors[0].Name) - $($assessmentResults.Assessment.CPU.TotalCores) cores / $($assessmentResults.Assessment.CPU.TotalLogicalProcessors) vCPUs" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect CPU information: $_"
}

#endregion

#region 3. Memory Information

Write-Progress-Step "Collecting memory information"

try {
    $memory = Get-CimInstance -ClassName Win32_PhysicalMemory
    $memoryModules = @()
    
    foreach ($module in $memory) {
        $memoryModules += @{
            Capacity = [math]::Round($module.Capacity / 1GB, 2)
            Speed = $module.Speed
            Manufacturer = $module.Manufacturer
            PartNumber = $module.PartNumber
        }
    }
    
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $totalMemoryGB = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $freeMemoryGB = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    $usedMemoryGB = $totalMemoryGB - $freeMemoryGB
    
    $assessmentResults.Assessment.Memory = @{
        TotalMemoryGB = $totalMemoryGB
        UsedMemoryGB = [math]::Round($usedMemoryGB, 2)
        FreeMemoryGB = [math]::Round($freeMemoryGB, 2)
        UsagePercent = [math]::Round(($usedMemoryGB / $totalMemoryGB) * 100, 2)
        Modules = $memoryModules
        ModuleCount = $memory.Count
    }
    
    Write-Host "    ✓ Memory: $totalMemoryGB GB total ($($assessmentResults.Assessment.Memory.UsagePercent)% used)" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect memory information: $_"
}

#endregion

#region 4. Operating System Information

Write-Progress-Step "Collecting operating system information"

try {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    
    $assessmentResults.Assessment.OperatingSystem = @{
        Caption = $os.Caption
        Version = $os.Version
        BuildNumber = $os.BuildNumber
        OSArchitecture = $os.OSArchitecture
        ServicePackMajorVersion = $os.ServicePackMajorVersion
        InstallDate = $os.InstallDate.ToString("yyyy-MM-dd")
        LastBootUpTime = $os.LastBootUpTime.ToString("yyyy-MM-dd HH:mm:ss")
        Locale = $os.Locale
        TimeZone = (Get-TimeZone).DisplayName
    }
    
    Write-Host "    ✓ OS: $($os.Caption) ($($os.Version)) - Installed: $($assessmentResults.Assessment.OperatingSystem.InstallDate)" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect OS information: $_"
}

#endregion

#region 5. Disk Information and Benchmarks

Write-Progress-Step "Collecting disk information and running benchmarks"

try {
    $disks = Get-CimInstance -ClassName Win32_DiskDrive
    $volumes = Get-CimInstance -ClassName Win32_Volume | Where-Object { $_.DriveLetter -ne $null }
    
    $diskResults = @()
    
    foreach ($disk in $disks) {
        $diskPartitions = Get-CimAssociatedInstance -InputObject $disk -ResultClassName Win32_DiskPartition
        
        $diskInfo = @{
            Model = $disk.Model
            InterfaceType = $disk.InterfaceType
            MediaType = $disk.MediaType
            SizeGB = [math]::Round($disk.Size / 1GB, 2)
            Partitions = $disk.Partitions
            BytesPerSector = $disk.BytesPerSector
            Volumes = @()
        }
        
        foreach ($partition in $diskPartitions) {
            $logicalDisks = Get-CimAssociatedInstance -InputObject $partition -ResultClassName Win32_LogicalDisk
            
            foreach ($logicalDisk in $logicalDisks) {
                $volume = $volumes | Where-Object { $_.DriveLetter -eq "$($logicalDisk.DeviceID)" }
                
                if ($volume) {
                    $driveLetter = $volume.DriveLetter.TrimEnd(':')
                    
                    $volumeInfo = @{
                        DriveLetter = $driveLetter
                        Label = $volume.Label
                        FileSystem = $volume.FileSystem
                        CapacityGB = [math]::Round($volume.Capacity / 1GB, 2)
                        FreeSpaceGB = [math]::Round($volume.FreeSpace / 1GB, 2)
                        UsedSpaceGB = [math]::Round(($volume.Capacity - $volume.FreeSpace) / 1GB, 2)
                        UsagePercent = [math]::Round((($volume.Capacity - $volume.FreeSpace) / $volume.Capacity) * 100, 2)
                    }
                    
                    # Run IOPS benchmark if not skipped
                    if (-not $SkipDiskBenchmark) {
                        if ($driveLetter -eq "C") {
                            Write-Host "    Running benchmark on SYSTEM drive ${driveLetter}:\ (USE WITH CAUTION)" -ForegroundColor Yellow
                        } else {
                            Write-Host "    Running benchmark on drive ${driveLetter}:\" -ForegroundColor Cyan
                        }
                        
                        $iopsResults = Get-DiskIOPS -DriveLetter $driveLetter -Duration ([math]::Min($BenchmarkDuration / 2, 30))
                        $volumeInfo.IOPS = $iopsResults
                        
                        # Get latency
                        $latency = Get-DiskLatency -DriveLetter $driveLetter
                        $volumeInfo.AvgLatencyMs = $latency
                    }
                    
                    $diskInfo.Volumes += $volumeInfo
                }
            }
        }
        
        $diskResults += $diskInfo
    }
    
    $assessmentResults.Assessment.Disks = $diskResults
    
    Write-Host "    ✓ Disks: $($disks.Count) physical disks, $($volumes.Count) volumes" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect disk information: $_"
}

#endregion

#region 6. Network Information

Write-Progress-Step "Collecting network information"

try {
    $networkAdapters = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration | Where-Object { $_.IPEnabled -eq $true }
    $physicalAdapters = Get-CimInstance -ClassName Win32_NetworkAdapter | Where-Object { $_.PhysicalAdapter -eq $true -and $_.NetEnabled -eq $true }
    
    $networkInfo = @()
    
    foreach ($adapter in $physicalAdapters) {
        $config = $networkAdapters | Where-Object { $_.Index -eq $adapter.Index }
        
        if ($config) {
            $networkInfo += @{
                Name = $adapter.Name
                MACAddress = $adapter.MACAddress
                Speed = if ($adapter.Speed) { [math]::Round($adapter.Speed / 1MB, 2) } else { 0 }
                IPAddress = $config.IPAddress -join ", "
                SubnetMask = $config.IPSubnet -join ", "
                DefaultGateway = $config.DefaultIPGateway -join ", "
                DNSServers = $config.DNSServerSearchOrder -join ", "
                DHCPEnabled = $config.DHCPEnabled
            }
        }
    }
    
    $assessmentResults.Assessment.Network = @{
        Adapters = $networkInfo
        AdapterCount = $networkInfo.Count
    }
    
    Write-Host "    ✓ Network: $($networkInfo.Count) active network adapters" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect network information: $_"
}

#endregion

#region 7. SQL Server Information

if ($IncludeSQLInventory -and (Test-SQLServerInstalled)) {
    Write-Progress-Step "Collecting SQL Server information"
    
    try {
        # Find SQL Server instances
        $sqlInstances = Get-Service -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "MSSQL*" -and $_.Status -eq "Running" }
        
        $sqlInfo = @{
            Instances = @()
        }
        
        foreach ($instance in $sqlInstances) {
            $instanceName = if ($instance.Name -eq "MSSQLSERVER") { "localhost" } else { "localhost\$($instance.Name.Replace('MSSQL$',''))" }
            
            try {
                # Try to connect and get SQL Server info
                $query = @"
SELECT 
    SERVERPROPERTY('ProductVersion') AS Version,
    SERVERPROPERTY('ProductLevel') AS ServicePack,
    SERVERPROPERTY('Edition') AS Edition,
    SERVERPROPERTY('EngineEdition') AS EngineEdition,
    (SELECT COUNT(*) FROM sys.databases WHERE database_id > 4) AS UserDatabases
"@
                
                $sqlCmd = "sqlcmd -S $instanceName -Q `"$query`" -h -1 -W -s`",`""
                $result = Invoke-Expression $sqlCmd 2>$null
                
                if ($result) {
                    $sqlInstance = @{
                        InstanceName = $instanceName
                        ServiceName = $instance.Name
                        Status = $instance.Status
                        StartMode = $instance.StartType
                    }
                    
                    # Get database sizes
                    $dbQuery = @"
SELECT 
    DB_NAME(database_id) AS DatabaseName,
    (SUM(size) * 8 / 1024 / 1024.0) AS SizeGB
FROM sys.master_files
WHERE database_id > 4
GROUP BY database_id
ORDER BY SizeGB DESC
"@
                    
                    $dbCmd = "sqlcmd -S $instanceName -Q `"$dbQuery`" -h -1 -W -s`",`""
                    $dbResult = Invoke-Expression $dbCmd 2>$null
                    
                    if ($dbResult) {
                        $sqlInstance.Databases = @()
                        $dbLines = $dbResult -split "`n" | Where-Object { $_ -match "\S" }
                        foreach ($line in $dbLines) {
                            $parts = $line -split ","
                            if ($parts.Count -ge 2) {
                                $sqlInstance.Databases += @{
                                    Name = $parts[0].Trim()
                                    SizeGB = [math]::Round([decimal]$parts[1].Trim(), 2)
                                }
                            }
                        }
                    }
                    
                    $sqlInfo.Instances += $sqlInstance
                }
            } catch {
                Write-Warning "Failed to query SQL instance $instanceName : $_"
            }
        }
        
        $assessmentResults.Assessment.SQLServer = $sqlInfo
        
        Write-Host "    ✓ SQL Server: $($sqlInstances.Count) instance(s) found" -ForegroundColor Green
        
    } catch {
        Write-Warning "Failed to collect SQL Server information: $_"
    }
} else {
    Write-Host "    ⊘ SQL Server inventory skipped (not installed or disabled)" -ForegroundColor Gray
}

#endregion

#region 8. Performance Counters (Real-time sampling)

Write-Progress-Step "Collecting performance counters (sampling for 60 seconds)"

try {
    $counters = @(
        "\Processor(_Total)\% Processor Time",
        "\Memory\Available MBytes",
        "\PhysicalDisk(_Total)\Disk Reads/sec",
        "\PhysicalDisk(_Total)\Disk Writes/sec",
        "\PhysicalDisk(_Total)\Avg. Disk sec/Read",
        "\PhysicalDisk(_Total)\Avg. Disk sec/Write",
        "\Network Interface(*)\Bytes Total/sec"
    )
    
    Write-Host "    Sampling performance counters..." -ForegroundColor Gray
    $samples = Get-Counter -Counter $counters -SampleInterval 2 -MaxSamples 30 -ErrorAction SilentlyContinue
    
    $cpuSamples = $samples.CounterSamples | Where-Object { $_.Path -like "*Processor(_Total)*" }
    $avgCPU = ($cpuSamples | Measure-Object -Property CookedValue -Average).Average
    
    $memSamples = $samples.CounterSamples | Where-Object { $_.Path -like "*Memory\Available*" }
    $avgAvailMemMB = ($memSamples | Measure-Object -Property CookedValue -Average).Average
    
    $diskReadSamples = $samples.CounterSamples | Where-Object { $_.Path -like "*Disk Reads/sec*" }
    $avgDiskReads = ($diskReadSamples | Measure-Object -Property CookedValue -Average).Average
    
    $diskWriteSamples = $samples.CounterSamples | Where-Object { $_.Path -like "*Disk Writes/sec*" }
    $avgDiskWrites = ($diskWriteSamples | Measure-Object -Property CookedValue -Average).Average
    
    $assessmentResults.Assessment.Performance = @{
        AvgCPUPercent = [math]::Round($avgCPU, 2)
        AvgAvailableMemoryMB = [math]::Round($avgAvailMemMB, 2)
        AvgDiskReadsPerSec = [math]::Round($avgDiskReads, 2)
        AvgDiskWritesPerSec = [math]::Round($avgDiskWrites, 2)
        SamplingDuration = "60 seconds"
        SampleInterval = "2 seconds"
    }
    
    Write-Host "    ✓ Performance: Avg CPU $([math]::Round($avgCPU, 2))%, Avg Disk Reads $([math]::Round($avgDiskReads, 2))/s, Writes $([math]::Round($avgDiskWrites, 2))/s" -ForegroundColor Green
} catch {
    Write-Warning "Failed to collect performance counters: $_"
}

#endregion

#region 9. Azure VM Recommendation

Write-Progress-Step "Calculating Azure VM recommendation"

try {
    $cpuCores = $assessmentResults.Assessment.CPU.TotalCores
    $memoryGB = $assessmentResults.Assessment.Memory.TotalMemoryGB
    $totalDiskGB = ($assessmentResults.Assessment.Disks.Volumes | Measure-Object -Property CapacityGB -Sum).Sum
    
    # Azure VM sizing logic (simplified)
    $recommendedSKU = ""
    $recommendedCost = 0
    
    if ($cpuCores -le 2 -and $memoryGB -le 8) {
        $recommendedSKU = "Standard_D2s_v5"
        $recommendedCost = 96
    } elseif ($cpuCores -le 4 -and $memoryGB -le 16) {
        $recommendedSKU = "Standard_D4s_v5"
        $recommendedCost = 192
    } elseif ($cpuCores -le 4 -and $memoryGB -le 32) {
        $recommendedSKU = "Standard_E4ds_v5"
        $recommendedCost = 245
    } elseif ($cpuCores -le 8 -and $memoryGB -le 32) {
        $recommendedSKU = "Standard_D8s_v5"
        $recommendedCost = 384
    } elseif ($cpuCores -le 8 -and $memoryGB -le 64) {
        $recommendedSKU = "Standard_E8ds_v5"
        $recommendedCost = 490
    } elseif ($cpuCores -le 16 -and $memoryGB -le 64) {
        $recommendedSKU = "Standard_D16s_v5"
        $recommendedCost = 768
    } else {
        $recommendedSKU = "Standard_E16ds_v5"
        $recommendedCost = 980
    }
    
    # Azure Premium SSD specifications
    $azureDisks = @(
        @{Name="P6";  Size=64;   IOPS=240;   Throughput=50;  Cost=5},
        @{Name="P10"; Size=128;  IOPS=500;   Throughput=100; Cost=10},
        @{Name="P15"; Size=256;  IOPS=1100;  Throughput=125; Cost=35},
        @{Name="P20"; Size=512;  IOPS=2300;  Throughput=150; Cost=60},
        @{Name="P30"; Size=1024; IOPS=5000;  Throughput=200; Cost=120},
        @{Name="P40"; Size=2048; IOPS=7500;  Throughput=250; Cost=230},
        @{Name="P50"; Size=4096; IOPS=7500;  Throughput=250; Cost=450},
        @{Name="P60"; Size=8192; IOPS=16000; Throughput=500; Cost=900}
    )
    
    # Disk recommendation with performance matching
    $diskRecommendation = @()
    foreach ($disk in $assessmentResults.Assessment.Disks) {
        foreach ($volume in $disk.Volumes) {
            if ($volume.CapacityGB -gt 0) {
                $diskType = "Premium SSD"
                
                # Get measured IOPS if available
                $measuredIOPS = 0
                $measuredThroughput = 0
                if ($volume.IOPS -and $volume.IOPS.SequentialReadIOPS) {
                    $measuredIOPS = [math]::Max($volume.IOPS.SequentialReadIOPS, $volume.IOPS.SequentialWriteIOPS)
                    $measuredThroughput = $measuredIOPS * 8 / 1024  # Rough estimate in MB/s
                }
                
                # Find matching Azure disk by capacity
                $selectedDisk = $null
                foreach ($azureDisk in $azureDisks) {
                    if ($azureDisk.Size -ge $volume.CapacityGB) {
                        $selectedDisk = $azureDisk
                        break
                    }
                }
                
                # If measured IOPS available, check if selected disk meets performance
                $needsRAID = $false
                $raidConfig = $null
                
                if ($measuredIOPS -gt 0 -and $null -ne $selectedDisk) {
                    if ($selectedDisk.IOPS -lt $measuredIOPS -or $selectedDisk.Throughput -lt $measuredThroughput) {
                        # Single disk insufficient, calculate RAID
                        $needsRAID = $true
                        
                        # Try to find RAID configuration
                        foreach ($azureDisk in $azureDisks) {
                            if ($azureDisk.Size -ge $volume.CapacityGB) {
                                for ($count = 2; $count -le 8; $count++) {
                                    if (($azureDisk.IOPS * $count) -ge $measuredIOPS -and 
                                        ($azureDisk.Throughput * $count) -ge $measuredThroughput -and
                                        ($azureDisk.Size * $count) -ge $volume.CapacityGB) {
                                        $raidConfig = @{
                                            DiskSKU = $azureDisk.Name
                                            DiskCount = $count
                                            TotalIOPS = $azureDisk.IOPS * $count
                                            TotalThroughput = $azureDisk.Throughput * $count
                                            TotalSize = $azureDisk.Size * $count
                                            TotalCost = $azureDisk.Cost * $count
                                        }
                                        break
                                    }
                                }
                                if ($null -ne $raidConfig) { break }
                            }
                        }
                    }
                }
                
                if ($needsRAID -and $null -ne $raidConfig) {
                    # RAID configuration needed
                    $diskRecommendation += @{
                        SourceVolume = $volume.DriveLetter
                        SourceSizeGB = $volume.CapacityGB
                        SourceIOPS = $measuredIOPS
                        AzureDiskSKU = "$($raidConfig.DiskCount)x Premium SSD $($raidConfig.DiskSKU) (RAID-0)"
                        AzureDiskType = "Premium SSD RAID-0"
                        AzureIOPS = $raidConfig.TotalIOPS
                        AzureThroughput = $raidConfig.TotalThroughput
                        EstimatedCostEUR = $raidConfig.TotalCost
                        Configuration = "Storage Spaces - Simple (Stripe)"
                        PerformanceMatch = "Meets requirements"
                    }
                } else {
                    # Single disk sufficient or no IOPS data
                    if ($null -eq $selectedDisk) {
                        $selectedDisk = $azureDisks[-1]  # Largest disk
                    }
                    
                    $perfMatch = "Unknown"
                    if ($measuredIOPS -gt 0) {
                        if ($selectedDisk.IOPS -ge $measuredIOPS * 1.2) {
                            $perfMatch = "Exceeds requirements"
                        } elseif ($selectedDisk.IOPS -ge $measuredIOPS) {
                            $perfMatch = "Meets requirements"
                        } else {
                            $perfMatch = "Below requirements (consider RAID)"
                        }
                    }
                    
                    $diskRecommendation += @{
                        SourceVolume = $volume.DriveLetter
                        SourceSizeGB = $volume.CapacityGB
                        SourceIOPS = $measuredIOPS
                        AzureDiskSKU = "$($selectedDisk.Name) ($($selectedDisk.Size)GB)"
                        AzureDiskType = "Premium SSD"
                        AzureIOPS = $selectedDisk.IOPS
                        AzureThroughput = $selectedDisk.Throughput
                        EstimatedCostEUR = $selectedDisk.Cost
                        Configuration = "Single disk"
                        PerformanceMatch = $perfMatch
                    }
                }
            }
        }
    }
    
    $totalDiskCost = ($diskRecommendation | Measure-Object -Property EstimatedCostEUR -Sum).Sum
    
    $assessmentResults.Assessment.AzureRecommendation = @{
        RecommendedVMSKU = $recommendedSKU
        VMvCPUs = $cpuCores
        VMMemoryGB = $memoryGB
        EstimatedVMCostEUR = $recommendedCost
        Disks = $diskRecommendation
        EstimatedDiskCostEUR = $totalDiskCost
        TotalEstimatedMonthlyCostEUR = $recommendedCost + $totalDiskCost
        Notes = "Costs are estimates (EUR/month) without Azure Hybrid Benefit or Reserved Instances. Actual costs may vary."
        Region = "West Europe"
    }
    
    Write-Host "    ✓ Recommendation: $recommendedSKU (~€$($recommendedCost + $totalDiskCost)/month)" -ForegroundColor Green
} catch {
    Write-Warning "Failed to calculate Azure recommendation: $_"
}

#endregion

#region 10. Export Results

Write-Host ""
Write-Progress-Step "Exporting results"

# Export to JSON
try {
    $assessmentResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
    Write-Host "    ✓ JSON exported: $jsonFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to export JSON: $_"
}

# Export to CSV (flattened)
try {
    $csvData = @()
    
    # Add computer info
    $csvData += [PSCustomObject]@{
        Category = "Computer"
        Property = "Name"
        Value = $assessmentResults.Assessment.Computer.Name
    }
    
    $csvData += [PSCustomObject]@{
        Category = "Computer"
        Property = "Model"
        Value = "$($assessmentResults.Assessment.Computer.Manufacturer) $($assessmentResults.Assessment.Computer.Model)"
    }
    
    # Add CPU info
    $csvData += [PSCustomObject]@{
        Category = "CPU"
        Property = "Cores"
        Value = $assessmentResults.Assessment.CPU.TotalCores
    }
    
    $csvData += [PSCustomObject]@{
        Category = "CPU"
        Property = "vCPUs"
        Value = $assessmentResults.Assessment.CPU.TotalLogicalProcessors
    }
    
    # Add Memory info
    $csvData += [PSCustomObject]@{
        Category = "Memory"
        Property = "Total GB"
        Value = $assessmentResults.Assessment.Memory.TotalMemoryGB
    }
    
    $csvData += [PSCustomObject]@{
        Category = "Memory"
        Property = "Usage %"
        Value = $assessmentResults.Assessment.Memory.UsagePercent
    }
    
    # Add disk info
    foreach ($disk in $assessmentResults.Assessment.Disks) {
        foreach ($volume in $disk.Volumes) {
            $csvData += [PSCustomObject]@{
                Category = "Disk"
                Property = "Volume $($volume.DriveLetter)"
                Value = "$($volume.CapacityGB) GB ($($volume.UsagePercent)% used)"
            }
        }
    }
    
    # Add Azure recommendation
    $csvData += [PSCustomObject]@{
        Category = "Azure Recommendation"
        Property = "VM SKU"
        Value = $assessmentResults.Assessment.AzureRecommendation.RecommendedVMSKU
    }
    
    $csvData += [PSCustomObject]@{
        Category = "Azure Recommendation"
        Property = "Monthly Cost (EUR)"
        Value = $assessmentResults.Assessment.AzureRecommendation.TotalEstimatedMonthlyCostEUR
    }
    
    $csvData | Export-Csv -Path $csvFile -NoTypeInformation -Encoding UTF8
    Write-Host "    ✓ CSV exported: $csvFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to export CSV: $_"
}

# Generate HTML Report
try {
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Azure Migration Assessment Report - $($assessmentResults.ServerName)</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 30px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        h1 { color: #0078d4; border-bottom: 3px solid #0078d4; padding-bottom: 10px; }
        h2 { color: #106ebe; margin-top: 30px; border-left: 4px solid #0078d4; padding-left: 10px; }
        h3 { color: #005a9e; }
        .summary { background: #e3f2fd; padding: 20px; border-radius: 5px; margin: 20px 0; }
        .recommendation { background: #fff3cd; padding: 20px; border-radius: 5px; margin: 20px 0; border-left: 4px solid #ffc107; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th { background: #0078d4; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border: 1px solid #ddd; }
        tr:nth-child(even) { background: #f9f9f9; }
        .metric { display: inline-block; margin: 10px 20px 10px 0; }
        .metric-label { font-weight: bold; color: #666; }
        .metric-value { font-size: 24px; color: #0078d4; }
        .footer { margin-top: 40px; padding-top: 20px; border-top: 1px solid #ddd; color: #666; font-size: 12px; }
        .status-good { color: #28a745; font-weight: bold; }
        .status-warning { color: #ffc107; font-weight: bold; }
        .status-critical { color: #dc3545; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔍 Azure Migration Assessment Report</h1>
        
        <div class="summary">
            <h3>Assessment Summary</h3>
            <div class="metric">
                <div class="metric-label">Server Name</div>
                <div class="metric-value">$($assessmentResults.ServerName)</div>
            </div>
            <div class="metric">
                <div class="metric-label">Assessment Date</div>
                <div class="metric-value">$($assessmentResults.Timestamp)</div>
            </div>
        </div>
        
        <h2>💻 Computer System</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Name</td><td>$($assessmentResults.Assessment.Computer.Name)</td></tr>
            <tr><td>Manufacturer</td><td>$($assessmentResults.Assessment.Computer.Manufacturer)</td></tr>
            <tr><td>Model</td><td>$($assessmentResults.Assessment.Computer.Model)</td></tr>
            <tr><td>Domain</td><td>$($assessmentResults.Assessment.Computer.Domain)</td></tr>
            <tr><td>BIOS Version</td><td>$($assessmentResults.Assessment.Computer.BIOSVersion)</td></tr>
        </table>
        
        <h2>🖥️ CPU</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Processor</td><td>$($assessmentResults.Assessment.CPU.Processors[0].Name)</td></tr>
            <tr><td>Physical Cores</td><td>$($assessmentResults.Assessment.CPU.TotalCores)</td></tr>
            <tr><td>Logical Processors (vCPUs)</td><td>$($assessmentResults.Assessment.CPU.TotalLogicalProcessors)</td></tr>
            <tr><td>Max Clock Speed</td><td>$($assessmentResults.Assessment.CPU.Processors[0].MaxClockSpeed) MHz</td></tr>
        </table>
        
        <h2>💾 Memory</h2>
        <table>
            <tr><th>Property</th><th>Value</th></tr>
            <tr><td>Total Memory</td><td>$($assessmentResults.Assessment.Memory.TotalMemoryGB) GB</td></tr>
            <tr><td>Used Memory</td><td>$($assessmentResults.Assessment.Memory.UsedMemoryGB) GB</td></tr>
            <tr><td>Free Memory</td><td>$($assessmentResults.Assessment.Memory.FreeMemoryGB) GB</td></tr>
            <tr><td>Usage</td><td class="$(if($assessmentResults.Assessment.Memory.UsagePercent -gt 80){'status-warning'}else{'status-good'})">$($assessmentResults.Assessment.Memory.UsagePercent)%</td></tr>
        </table>
        
        <h2>💿 Disks</h2>
"@

    foreach ($disk in $assessmentResults.Assessment.Disks) {
        $html += "<h3>$($disk.Model)</h3>"
        $html += "<table>"
        $html += "<tr><th>Volume</th><th>Capacity</th><th>Used</th><th>File System</th><th>IOPS (Read/Write)</th></tr>"
        
        foreach ($volume in $disk.Volumes) {
            $iopsInfo = if ($volume.IOPS.SequentialReadIOPS) {
                "$($volume.IOPS.SequentialReadIOPS) / $($volume.IOPS.SequentialWriteIOPS)"
            } else {
                "Not tested"
            }
            
            $html += "<tr>"
            $html += "<td><strong>$($volume.DriveLetter):\</strong> $($volume.Label)</td>"
            $html += "<td>$($volume.CapacityGB) GB</td>"
            $html += "<td class='$(if($volume.UsagePercent -gt 80){'status-warning'}else{'status-good'})'>$($volume.UsedSpaceGB) GB ($($volume.UsagePercent)%)</td>"
            $html += "<td>$($volume.FileSystem)</td>"
            $html += "<td>$iopsInfo</td>"
            $html += "</tr>"
        }
        
        $html += "</table>"
    }

    $html += @"
        
        <h2>🌐 Network</h2>
        <table>
            <tr><th>Adapter</th><th>IP Address</th><th>MAC Address</th><th>Speed (Mbps)</th></tr>
"@

    foreach ($adapter in $assessmentResults.Assessment.Network.Adapters) {
        $html += "<tr>"
        $html += "<td>$($adapter.Name)</td>"
        $html += "<td>$($adapter.IPAddress)</td>"
        $html += "<td>$($adapter.MACAddress)</td>"
        $html += "<td>$($adapter.Speed)</td>"
        $html += "</tr>"
    }

    $html += @"
        </table>
        
        <h2>🗄️ SQL Server</h2>
"@

    if ($assessmentResults.Assessment.SQLServer -and 
        $assessmentResults.Assessment.SQLServer.Instances -and 
        $assessmentResults.Assessment.SQLServer.Instances.Count -gt 0) {
        foreach ($instance in $assessmentResults.Assessment.SQLServer.Instances) {
            $html += "<h3>Instance: $($instance.InstanceName)</h3>"
            $html += "<table>"
            $html += "<tr><th>Database</th><th>Size (GB)</th></tr>"
            
            foreach ($db in $instance.Databases) {
                $html += "<tr>"
                $html += "<td>$($db.Name)</td>"
                $html += "<td>$($db.SizeGB)</td>"
                $html += "</tr>"
            }
            
            $html += "</table>"
        }
    } else {
        $html += "<p>No SQL Server instances detected or inventory disabled.</p>"
    }

    $html += @"
        
        <h2>📊 Performance Metrics</h2>
        <table>
            <tr><th>Metric</th><th>Average Value</th></tr>
            <tr><td>CPU Utilization</td><td class="$(if($assessmentResults.Assessment.Performance.AvgCPUPercent -gt 80){'status-warning'}else{'status-good'})">$($assessmentResults.Assessment.Performance.AvgCPUPercent)%</td></tr>
            <tr><td>Available Memory</td><td>$($assessmentResults.Assessment.Performance.AvgAvailableMemoryMB) MB</td></tr>
            <tr><td>Disk Reads/sec</td><td>$($assessmentResults.Assessment.Performance.AvgDiskReadsPerSec)</td></tr>
            <tr><td>Disk Writes/sec</td><td>$($assessmentResults.Assessment.Performance.AvgDiskWritesPerSec)</td></tr>
        </table>
        <p><em>Metrics sampled over 60 seconds</em></p>
        
        <h2>☁️ Azure Migration Recommendation</h2>
        <div class="recommendation">
            <h3>Recommended Azure VM</h3>
            <div class="metric">
                <div class="metric-label">VM SKU</div>
                <div class="metric-value">$($assessmentResults.Assessment.AzureRecommendation.RecommendedVMSKU)</div>
            </div>
            <div class="metric">
                <div class="metric-label">vCPUs</div>
                <div class="metric-value">$($assessmentResults.Assessment.AzureRecommendation.VMvCPUs)</div>
            </div>
            <div class="metric">
                <div class="metric-label">Memory</div>
                <div class="metric-value">$($assessmentResults.Assessment.AzureRecommendation.VMMemoryGB) GB</div>
            </div>
            <div class="metric">
                <div class="metric-label">Estimated Cost</div>
                <div class="metric-value">€$($assessmentResults.Assessment.AzureRecommendation.TotalEstimatedMonthlyCostEUR)/month</div>
            </div>
        </div>
        
        <h3>Disk Configuration</h3>
        <table>
            <tr>
                <th>Source Volume</th>
                <th>Source Size</th>
                <th>Source IOPS</th>
                <th>Azure Disk SKU</th>
                <th>Azure IOPS</th>
                <th>Azure Throughput</th>
                <th>Performance Match</th>
                <th>Cost (EUR/month)</th>
            </tr>
"@

    foreach ($disk in $assessmentResults.Assessment.AzureRecommendation.Disks) {
        $perfMatchClass = if ($disk.PerformanceMatch -like "*Exceeds*") { 
            "status-good" 
        } elseif ($disk.PerformanceMatch -like "*Meets*") { 
            "status-good" 
        } elseif ($disk.PerformanceMatch -like "*Below*") { 
            "status-warning" 
        } else { 
            "" 
        }
        
        $html += "<tr>"
        $html += "<td><strong>$($disk.SourceVolume):\</strong></td>"
        $html += "<td>$($disk.SourceSizeGB) GB</td>"
        $html += "<td>$($disk.SourceIOPS)</td>"
        $html += "<td>$($disk.AzureDiskSKU)<br/><small>$($disk.Configuration)</small></td>"
        $html += "<td>$($disk.AzureIOPS)</td>"
        $html += "<td>$($disk.AzureThroughput) MB/s</td>"
        $html += "<td class='$perfMatchClass'>$($disk.PerformanceMatch)</td>"
        $html += "<td>€$($disk.EstimatedCostEUR)</td>"
        $html += "</tr>"
    }

    $html += @"
        </table>
        
        <p><strong>Note:</strong> $($assessmentResults.Assessment.AzureRecommendation.Notes)</p>
        
        <div class="footer">
            <p>Generated by Azure Migration Assessment Tool | Alejandro Almeida - Azure Architect Pro</p>
            <p>Assessment Date: $($assessmentResults.Timestamp)</p>
            <p>For questions or support, contact your Azure architect.</p>
        </div>
    </div>
</body>
</html>
"@

    $html | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "    ✓ HTML report exported: $reportFile" -ForegroundColor Green
} catch {
    Write-Warning "Failed to export HTML report: $_"
}

#endregion

Write-Host ""
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Assessment Complete!" -ForegroundColor Green
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📄 Results saved to:" -ForegroundColor White
Write-Host "   JSON: $jsonFile" -ForegroundColor Gray
Write-Host "   CSV:  $csvFile" -ForegroundColor Gray
Write-Host "   HTML: $reportFile" -ForegroundColor Gray
Write-Host ""
Write-Host "☁️  Azure Recommendation:" -ForegroundColor White
Write-Host "   VM SKU: $($assessmentResults.Assessment.AzureRecommendation.RecommendedVMSKU)" -ForegroundColor Cyan
Write-Host "   Est. Monthly Cost: €$($assessmentResults.Assessment.AzureRecommendation.TotalEstimatedMonthlyCostEUR)" -ForegroundColor Cyan
Write-Host ""
Write-Host "📧 Next Steps:" -ForegroundColor White
Write-Host "   1. Review the HTML report in your browser" -ForegroundColor Gray
Write-Host "   2. Share the JSON file with your Azure architect" -ForegroundColor Gray
Write-Host "   3. Proceed with Azure Migrate setup using recommended sizing" -ForegroundColor Gray
Write-Host ""

# Open HTML report
try {
    Start-Process $reportFile
} catch {
    Write-Host "Could not auto-open report. Please open manually: $reportFile" -ForegroundColor Yellow
}
