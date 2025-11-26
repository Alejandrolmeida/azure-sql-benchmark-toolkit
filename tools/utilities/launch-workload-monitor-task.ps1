<#
.SYNOPSIS
    Creates a Windows Scheduled Task to run SQL Server Extended Workload Monitor
    
.DESCRIPTION
    This script creates a scheduled task that runs the workload monitor in the background.
    The task survives PowerShell session closures and server restarts.
    
.PARAMETER ServerInstance
    SQL Server instance name (default: localhost)
    
.PARAMETER Duration
    Monitoring duration in minutes (default: 1440 = 24 hours)
    
.PARAMETER SampleInterval
    Sampling interval in seconds (default: 60)
    
.PARAMETER OutputPath
    Directory where results will be saved
    
.PARAMETER TaskName
    Name for the scheduled task (default: SQLWorkloadMonitor)
    
.EXAMPLE
    .\launch-workload-monitor-task.ps1 -Duration 2880
    Creates a task that runs 48-hour monitoring
    
.EXAMPLE
    .\launch-workload-monitor-task.ps1 -ServerInstance "EBSBI" -Duration 2880 -SampleInterval 120
    Creates a task for EBSBI server with 48h monitoring and 2-minute samples
    
.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 19, 2025
    Requires: Administrator privileges
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 1440,
    
    [Parameter(Mandatory=$false)]
    [int]$SampleInterval = 60,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "C:\AzureMigration\Assessment",
    
    [Parameter(Mandatory=$false)]
    [string]$TaskName = "SQLWorkloadMonitor_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
)

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "❌ ERROR: This script requires Administrator privileges" -ForegroundColor Red
    Write-Host "   Please run PowerShell as Administrator and try again" -ForegroundColor Yellow
    exit 1
}

Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host "  SQL Server Workload Monitor - Task Scheduler Launcher" -ForegroundColor Cyan
Write-Host "=====================================================================" -ForegroundColor Cyan
Write-Host ""

# Create output directory if it doesn't exist
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    Write-Host "✅ Created output directory: $OutputPath" -ForegroundColor Green
}

# Get the script path
$scriptPath = Join-Path $PSScriptRoot "sql-workload-monitor-extended.ps1"

if (-not (Test-Path $scriptPath)) {
    Write-Host "❌ ERROR: sql-workload-monitor-extended.ps1 not found" -ForegroundColor Red
    Write-Host "   Expected location: $scriptPath" -ForegroundColor Yellow
    exit 1
}

# Build the PowerShell command
$arguments = "-ServerInstance `"$ServerInstance`" -Duration $Duration -SampleInterval $SampleInterval -OutputPath `"$OutputPath`""

# Create log file path
$logFile = Join-Path $OutputPath "task_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Create a wrapper script that handles logging
# NOTE: We DON'T use -BackgroundMode flag when running via Task Scheduler
# because the Task itself already runs in background
$wrapperScript = @'
Start-Transcript -Path '{0}' -Append -Force
try {{
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  SQL Server Workload Monitor - Task Execution Started" -ForegroundColor Cyan
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Start Time: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
    Write-Host "Server: {1}" -ForegroundColor White
    Write-Host "Duration: {2} minutes" -ForegroundColor White
    Write-Host "Sample Interval: {3} seconds" -ForegroundColor White
    Write-Host "Output Path: {4}" -ForegroundColor White
    Write-Host ""
    
    & '{5}' {6}
    
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Cyan
    Write-Host "  Task execution completed successfully" -ForegroundColor Green
    Write-Host "=====================================================================" -ForegroundColor Cyan
}}
catch {{
    Write-Host ""
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host "  ERROR during task execution" -ForegroundColor Red
    Write-Host "=====================================================================" -ForegroundColor Red
    Write-Host "$_" -ForegroundColor Yellow
}}
finally {{
    Stop-Transcript
}}
'@ -f $logFile, $ServerInstance, $Duration, $SampleInterval, $OutputPath, $scriptPath, $arguments

# Save wrapper script temporarily
$wrapperPath = Join-Path $OutputPath "task_wrapper_$(Get-Date -Format 'yyyyMMdd_HHmmss').ps1"
$wrapperScript | Out-File -FilePath $wrapperPath -Encoding UTF8 -Force

# Create the scheduled task action
$action = New-ScheduledTaskAction -Execute "PowerShell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$wrapperPath`""

# Create the task trigger (run immediately)
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date)

# Create task settings
$settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable:$false `
    -DontStopOnIdleEnd

# Create the task principal (run as current user with highest privileges)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

# Register the task
try {
    Register-ScheduledTask -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Settings $settings `
        -Principal $principal `
        -Description "SQL Server Workload Monitor - $Duration minutes" `
        -Force | Out-Null
    
    Write-Host "✅ Scheduled task created successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Yellow
    Write-Host "  Task Name:       $TaskName" -ForegroundColor White
    Write-Host "  Server:          $ServerInstance" -ForegroundColor White
    Write-Host "  Duration:        $Duration minutes ($([math]::Round($Duration/60, 1)) hours)" -ForegroundColor White
    Write-Host "  Sample Interval: $SampleInterval seconds" -ForegroundColor White
    Write-Host "  Output Path:     $OutputPath" -ForegroundColor White
    Write-Host "  Log File:        $logFile" -ForegroundColor White
    Write-Host "  Start Time:      $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor White
    Write-Host "  Estimated End:   $((Get-Date).AddMinutes($Duration).ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Yellow
    Write-Host ""
    
    # Start the task
    Start-ScheduledTask -TaskName $TaskName
    Write-Host "✅ Task started successfully!" -ForegroundColor Green
    Write-Host ""
    
    Write-Host "💡 Useful commands:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  # Check task status" -ForegroundColor Gray
    Write-Host "  Get-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # View task details" -ForegroundColor Gray
    Write-Host "  Get-ScheduledTask -TaskName '$TaskName' | Get-ScheduledTaskInfo" -ForegroundColor White
    Write-Host ""
    Write-Host "  # View live log output" -ForegroundColor Gray
    Write-Host "  Get-Content '$logFile' -Wait" -ForegroundColor White
    Write-Host ""
    Write-Host "  # View last 20 lines of log" -ForegroundColor Gray
    Write-Host "  Get-Content '$logFile' -Tail 20" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Stop task if needed" -ForegroundColor Gray
    Write-Host "  Stop-ScheduledTask -TaskName '$TaskName'" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Remove task when completed" -ForegroundColor Gray
    Write-Host "  Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false" -ForegroundColor White
    Write-Host ""
    Write-Host "  # List all workload monitor tasks" -ForegroundColor Gray
    Write-Host "  Get-ScheduledTask | Where-Object {`$_.TaskName -like 'SQLWorkloadMonitor*'}" -ForegroundColor White
    Write-Host ""
    
    Write-Host "✅ The task will continue running even if you:" -ForegroundColor Green
    Write-Host "   - Close PowerShell windows" -ForegroundColor White
    Write-Host "   - Log out from RDP" -ForegroundColor White
    Write-Host "   - Restart the server (task will resume)" -ForegroundColor White
    Write-Host ""
    Write-Host "📁 Results will be saved to:" -ForegroundColor Yellow
    Write-Host "   $OutputPath\sql_workload_extended_*.json" -ForegroundColor White
    Write-Host "   $OutputPath\sql_workload_extended_*.html" -ForegroundColor White
    Write-Host ""
    
}
catch {
    Write-Host "❌ ERROR: Failed to create scheduled task" -ForegroundColor Red
    Write-Host "   $($_.Exception.Message)" -ForegroundColor Yellow
    exit 1
}

Write-Host "=====================================================================" -ForegroundColor Cyan
