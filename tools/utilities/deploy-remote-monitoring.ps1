<#
.SYNOPSIS
    Deploys and launches SQL Server Workload Monitor on a remote Windows server.

.DESCRIPTION
    This script uses PowerShell Remoting to:
    1. Copy monitoring scripts to remote server
    2. Launch 48-hour monitoring via Task Scheduler
    3. Verify execution
    4. Optionally retrieve results when completed

.PARAMETER RemoteComputer
    Remote server hostname or IP (e.g., EBSBI, 192.168.1.100)

.PARAMETER Credential
    PSCredential object for authentication. If not provided, will prompt.

.PARAMETER ServerInstance
    SQL Server instance name on remote server (default: RemoteComputer value)

.PARAMETER Duration
    Monitoring duration in minutes (default: 2880 = 48 hours)

.PARAMETER SampleInterval
    Sampling interval in seconds (default: 120 = 2 minutes)

.PARAMETER LocalScriptsPath
    Path to local scripts directory (default: current directory)

.PARAMETER RemoteScriptsPath
    Path on remote server where scripts will be copied (default: C:\Temp)

.PARAMETER RetrieveResults
    Switch to retrieve results after monitoring completes

.EXAMPLE
    .\deploy-remote-monitoring.ps1 -RemoteComputer "EBSBI"
    Deploy and launch monitoring on EBSBI server with defaults

.EXAMPLE
    .\deploy-remote-monitoring.ps1 -RemoteComputer "EBSBI" -Duration 1440 -SampleInterval 60
    Deploy 24-hour monitoring with 1-minute samples

.EXAMPLE
    .\deploy-remote-monitoring.ps1 -RemoteComputer "EBSBI" -RetrieveResults
    Retrieve completed results from EBSBI

.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 19, 2025
    Requires: PowerShell Remoting enabled on remote server
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RemoteComputer,
    
    [Parameter(Mandatory=$false)]
    [PSCredential]$Credential,
    
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance,
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 2880,
    
    [Parameter(Mandatory=$false)]
    [int]$SampleInterval = 120,
    
    [Parameter(Mandatory=$false)]
    [string]$LocalScriptsPath = $PSScriptRoot,
    
    [Parameter(Mandatory=$false)]
    [string]$RemoteScriptsPath = "C:\Temp",
    
    [Parameter(Mandatory=$false)]
    [switch]$RetrieveResults
)

# If ServerInstance not specified, use RemoteComputer name
if (-not $ServerInstance) {
    $ServerInstance = $RemoteComputer
}

# If Credential not provided, prompt
if (-not $Credential) {
    $Credential = Get-Credential -Message "Enter credentials for $RemoteComputer"
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  Remote SQL Server Workload Monitor Deployment" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Configuration:" -ForegroundColor Yellow
Write-Host "  Remote Server:    $RemoteComputer" -ForegroundColor White
Write-Host "  SQL Instance:     $ServerInstance" -ForegroundColor White
Write-Host "  Duration:         $Duration minutes ($([math]::Round($Duration/60, 1)) hours)" -ForegroundColor White
Write-Host "  Sample Interval:  $SampleInterval seconds" -ForegroundColor White
Write-Host "  Local Scripts:    $LocalScriptsPath" -ForegroundColor White
Write-Host "  Remote Path:      $RemoteScriptsPath" -ForegroundColor White
Write-Host ""

# Test connectivity
Write-Host "🔍 Testing connectivity to $RemoteComputer..." -ForegroundColor Yellow

try {
    $testConnection = Test-NetConnection -ComputerName $RemoteComputer -Port 5985 -WarningAction SilentlyContinue
    
    if (-not $testConnection.TcpTestSucceeded) {
        Write-Host "❌ ERROR: Cannot connect to $RemoteComputer on port 5985 (WinRM)" -ForegroundColor Red
        Write-Host ""
        Write-Host "💡 To enable PowerShell Remoting on the remote server:" -ForegroundColor Yellow
        Write-Host "   1. RDP to $RemoteComputer" -ForegroundColor White
        Write-Host "   2. Open PowerShell as Administrator" -ForegroundColor White
        Write-Host "   3. Run: Enable-PSRemoting -Force" -ForegroundColor Cyan
        Write-Host "   4. Run: Set-Item WSMan:\localhost\Client\TrustedHosts -Value '*' -Force" -ForegroundColor Cyan
        Write-Host ""
        exit 1
    }
    
    Write-Host "✅ Connectivity OK" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "⚠️  Warning: Connectivity test failed, but will attempt connection anyway" -ForegroundColor Yellow
    Write-Host ""
}

# Create PS Session
Write-Host "🔗 Creating PowerShell session to $RemoteComputer..." -ForegroundColor Yellow

try {
    $session = New-PSSession -ComputerName $RemoteComputer -Credential $Credential -ErrorAction Stop
    Write-Host "✅ Session created successfully" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "❌ ERROR: Failed to create PowerShell session" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "💡 Common issues:" -ForegroundColor Yellow
    Write-Host "   - PowerShell Remoting not enabled on remote server" -ForegroundColor White
    Write-Host "   - Firewall blocking WinRM (port 5985/5986)" -ForegroundColor White
    Write-Host "   - Incorrect credentials" -ForegroundColor White
    Write-Host "   - Remote computer not in TrustedHosts" -ForegroundColor White
    Write-Host ""
    exit 1
}

if (-not $RetrieveResults) {
    # Deploy and launch monitoring
    
    # 1. Verify local scripts exist
    Write-Host "📂 Verifying local scripts..." -ForegroundColor Yellow
    
    $requiredScripts = @(
        "sql-workload-monitor-extended.ps1",
        "launch-workload-monitor-task.ps1"
    )
    
    $missingScripts = @()
    foreach ($script in $requiredScripts) {
        $scriptPath = Join-Path $LocalScriptsPath $script
        if (-not (Test-Path $scriptPath)) {
            $missingScripts += $script
        }
    }
    
    if ($missingScripts.Count -gt 0) {
        Write-Host "❌ ERROR: Missing scripts:" -ForegroundColor Red
        foreach ($script in $missingScripts) {
            Write-Host "   - $script" -ForegroundColor Yellow
        }
        Write-Host ""
        Write-Host "Expected location: $LocalScriptsPath" -ForegroundColor White
        Remove-PSSession $session
        exit 1
    }
    
    Write-Host "✅ All scripts found" -ForegroundColor Green
    Write-Host ""
    
    # 2. Create remote directory
    Write-Host "📁 Creating remote directory: $RemoteScriptsPath..." -ForegroundColor Yellow
    
    Invoke-Command -Session $session -ScriptBlock {
        param($Path)
        if (-not (Test-Path $Path)) {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
        }
    } -ArgumentList $RemoteScriptsPath
    
    Write-Host "✅ Remote directory ready" -ForegroundColor Green
    Write-Host ""
    
    # 3. Copy scripts to remote server
    Write-Host "📤 Copying scripts to remote server..." -ForegroundColor Yellow
    
    foreach ($script in $requiredScripts) {
        $localPath = Join-Path $LocalScriptsPath $script
        $remotePath = Join-Path $RemoteScriptsPath $script
        
        Write-Host "   Copying $script..." -ForegroundColor Gray
        Copy-Item -Path $localPath -Destination $remotePath -ToSession $session -Force
    }
    
    Write-Host "✅ Scripts copied successfully" -ForegroundColor Green
    Write-Host ""
    
    # 4. Launch monitoring task
    Write-Host "🚀 Launching monitoring task on remote server..." -ForegroundColor Yellow
    Write-Host ""
    
    $launchResult = Invoke-Command -Session $session -ScriptBlock {
        param($ScriptsPath, $Instance, $Dur, $Interval)
        
        cd $ScriptsPath
        
        # Execute launcher script
        & ".\launch-workload-monitor-task.ps1" `
            -ServerInstance $Instance `
            -Duration $Dur `
            -SampleInterval $Interval
            
    } -ArgumentList $RemoteScriptsPath, $ServerInstance, $Duration, $SampleInterval
    
    # Display output from remote execution
    $launchResult | ForEach-Object { Write-Host $_ }
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  ✅ DEPLOYMENT COMPLETED SUCCESSFULLY" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    # 5. Verify task is running
    Write-Host "🔍 Verifying task status..." -ForegroundColor Yellow
    
    $taskStatus = Invoke-Command -Session $session -ScriptBlock {
        Get-ScheduledTask | Where-Object {$_.TaskName -like "SQLWorkloadMonitor*"} | Select-Object TaskName, State, @{Name="LastRunTime";Expression={(Get-ScheduledTaskInfo -TaskName $_.TaskName).LastRunTime}}
    }
    
    if ($taskStatus) {
        Write-Host ""
        $taskStatus | Format-Table -AutoSize | Out-String | Write-Host
        Write-Host "✅ Task is active on remote server" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Warning: No active monitoring task found" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Write-Host "📋 Next Steps:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  1. Wait for monitoring to complete (~$([math]::Round($Duration/60)) hours)" -ForegroundColor White
    Write-Host "     Estimated completion: $((Get-Date).AddMinutes($Duration).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  2. Check progress remotely:" -ForegroundColor White
    Write-Host "     .\deploy-remote-monitoring.ps1 -RemoteComputer '$RemoteComputer' -RetrieveResults" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  3. Or manually verify:" -ForegroundColor White
    Write-Host "     `$session = New-PSSession -ComputerName '$RemoteComputer' -Credential (Get-Credential)" -ForegroundColor Cyan
    Write-Host "     Invoke-Command -Session `$session -ScriptBlock { Get-Content C:\AzureMigration\Assessment\task_log_*.txt -Tail 20 }" -ForegroundColor Cyan
    Write-Host ""
    
} else {
    # Retrieve results mode
    
    Write-Host "📥 Retrieving monitoring results from $RemoteComputer..." -ForegroundColor Yellow
    Write-Host ""
    
    # Check if results exist
    $resultsExist = Invoke-Command -Session $session -ScriptBlock {
        $htmlFiles = Get-ChildItem -Path "C:\AzureMigration\Assessment" -Filter "sql_workload_extended_*.html" -ErrorAction SilentlyContinue
        $jsonFiles = Get-ChildItem -Path "C:\AzureMigration\Assessment" -Filter "sql_workload_extended_*.json" -ErrorAction SilentlyContinue
        
        return @{
            HTML = $htmlFiles
            JSON = $jsonFiles
        }
    }
    
    if (-not $resultsExist.HTML -and -not $resultsExist.JSON) {
        Write-Host "⚠️  No results found yet" -ForegroundColor Yellow
        Write-Host ""
        
        # Check if task is still running
        $taskStatus = Invoke-Command -Session $session -ScriptBlock {
            Get-ScheduledTask | Where-Object {$_.TaskName -like "SQLWorkloadMonitor*"}
        }
        
        if ($taskStatus) {
            Write-Host "ℹ️  Monitoring task is still running:" -ForegroundColor Cyan
            $taskInfo = Invoke-Command -Session $session -ScriptBlock {
                param($TaskName)
                Get-ScheduledTaskInfo -TaskName $TaskName
            } -ArgumentList $taskStatus[0].TaskName
            
            Write-Host "   Task: $($taskStatus[0].TaskName)" -ForegroundColor White
            Write-Host "   Started: $($taskInfo.LastRunTime)" -ForegroundColor White
            
            if ($taskInfo.LastRunTime) {
                $elapsed = (Get-Date) - $taskInfo.LastRunTime
                $remaining = [TimeSpan]::FromMinutes($Duration) - $elapsed
                Write-Host "   Elapsed: $([math]::Round($elapsed.TotalHours, 1)) hours" -ForegroundColor White
                Write-Host "   Remaining: ~$([math]::Round($remaining.TotalHours, 1)) hours" -ForegroundColor Yellow
            }
        } else {
            Write-Host "⚠️  No active monitoring task found" -ForegroundColor Yellow
        }
        
    } else {
        # Create local results directory
        $localResultsDir = Join-Path (Get-Location) "Results_$RemoteComputer"
        if (-not (Test-Path $localResultsDir)) {
            New-Item -ItemType Directory -Path $localResultsDir -Force | Out-Null
        }
        
        Write-Host "📂 Local results directory: $localResultsDir" -ForegroundColor Cyan
        Write-Host ""
        
        # Copy HTML files
        if ($resultsExist.HTML) {
            Write-Host "📊 Copying HTML reports..." -ForegroundColor Yellow
            foreach ($file in $resultsExist.HTML) {
                $remotePath = $file.FullName
                $localPath = Join-Path $localResultsDir $file.Name
                
                Write-Host "   $($file.Name)" -ForegroundColor Gray
                Copy-Item -Path $remotePath -Destination $localPath -FromSession $session -Force
            }
            Write-Host "✅ HTML reports copied" -ForegroundColor Green
            Write-Host ""
        }
        
        # Copy JSON files
        if ($resultsExist.JSON) {
            Write-Host "📊 Copying JSON data..." -ForegroundColor Yellow
            foreach ($file in $resultsExist.JSON) {
                $remotePath = $file.FullName
                $localPath = Join-Path $localResultsDir $file.Name
                
                Write-Host "   $($file.Name)" -ForegroundColor Gray
                Copy-Item -Path $remotePath -Destination $localPath -FromSession $session -Force
            }
            Write-Host "✅ JSON data copied" -ForegroundColor Green
            Write-Host ""
        }
        
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host "  ✅ RESULTS RETRIEVED SUCCESSFULLY" -ForegroundColor Green
        Write-Host "=====================================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "📂 Results saved to: $localResultsDir" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "📊 Open HTML report:" -ForegroundColor Yellow
        
        if ($resultsExist.HTML) {
            $htmlPath = Join-Path $localResultsDir $resultsExist.HTML[0].Name
            Write-Host "   $htmlPath" -ForegroundColor Cyan
            
            # Try to open in default browser
            if ($IsWindows -or $PSVersionTable.PSVersion.Major -le 5) {
                Write-Host ""
                Write-Host "Opening in browser..." -ForegroundColor Gray
                Start-Process $htmlPath
            }
        }
        Write-Host ""
    }
}

# Close session
Write-Host "🔌 Closing remote session..." -ForegroundColor Gray
Remove-PSSession $session
Write-Host "✅ Session closed" -ForegroundColor Green
Write-Host ""
