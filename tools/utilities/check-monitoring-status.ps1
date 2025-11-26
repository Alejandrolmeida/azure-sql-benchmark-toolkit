<#
.SYNOPSIS
    Verifica el estado del monitoreo SQL Server en ejecución.

.DESCRIPTION
    Script para validar que el Task Scheduler o PowerShell Job está funcionando correctamente.
    Muestra progreso, tiempo transcurrido, y estado de archivos generados.
#>

param(
    [string]$OutputPath = "C:\AzureMigration\Assessment"
)

Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   🔍 VERIFICACIÓN DE MONITOREO SQL SERVER" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar Task Scheduler
Write-Host "1️⃣  TASK SCHEDULER:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

$tasks = Get-ScheduledTask | Where-Object {$_.TaskName -like "SQLWorkloadMonitor*"}

if ($tasks) {
    foreach ($task in $tasks) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName
        $status = $task.State
        
        $statusColor = switch ($status) {
            "Running" { "Green" }
            "Ready" { "Yellow" }
            default { "Red" }
        }
        
        Write-Host "  ✅ Task: " -NoNewline
        Write-Host $task.TaskName -ForegroundColor Cyan
        Write-Host "     Estado: " -NoNewline
        Write-Host $status -ForegroundColor $statusColor
        Write-Host "     Última Ejecución: $($taskInfo.LastRunTime)" -ForegroundColor Gray
        Write-Host "     Próxima Ejecución: $($taskInfo.NextRunTime)" -ForegroundColor Gray
        Write-Host ""
    }
} else {
    Write-Host "  ❌ No hay tasks de monitoreo activos" -ForegroundColor Red
}

# 2. Verificar PowerShell Jobs (si existen)
Write-Host "2️⃣  POWERSHELL JOBS:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

$jobs = Get-Job | Where-Object {$_.Name -like "SQLWorkloadMonitor*"}

if ($jobs) {
    foreach ($job in $jobs) {
        $statusColor = switch ($job.State) {
            "Running" { "Green" }
            "Completed" { "Cyan" }
            default { "Red" }
        }
        
        Write-Host "  ✅ Job: " -NoNewline
        Write-Host $job.Name -ForegroundColor Cyan
        Write-Host "     Estado: " -NoNewline
        Write-Host $job.State -ForegroundColor $statusColor
        Write-Host "     Inicio: $($job.PSBeginTime)" -ForegroundColor Gray
        
        if ($job.State -eq "Running") {
            $elapsed = (Get-Date) - $job.PSBeginTime
            Write-Host "     Tiempo Transcurrido: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Green
        }
        Write-Host ""
    }
} else {
    Write-Host "  ⚠️  No hay PowerShell jobs activos (normal si usas Task Scheduler)" -ForegroundColor Yellow
}

# 3. Verificar Log File
Write-Host "3️⃣  LOG FILES:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

if (Test-Path $OutputPath) {
    $logFiles = Get-ChildItem -Path $OutputPath -Filter "task_log_*.txt" -ErrorAction SilentlyContinue
    
    if ($logFiles) {
        $latestLog = $logFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        Write-Host "  📄 Log más reciente: " -NoNewline
        Write-Host $latestLog.Name -ForegroundColor Cyan
        Write-Host "     Tamaño: $([math]::Round($latestLog.Length/1KB, 2)) KB" -ForegroundColor Gray
        Write-Host "     Última modificación: $($latestLog.LastWriteTime)" -ForegroundColor Gray
        Write-Host ""
        
        # Mostrar últimas 10 líneas
        Write-Host "  📋 Últimas 10 líneas del log:" -ForegroundColor White
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        $lastLines = Get-Content $latestLog.FullName -Tail 10 -ErrorAction SilentlyContinue
        foreach ($line in $lastLines) {
            Write-Host "  " -NoNewline
            if ($line -match "ERROR|Failed|Exception") {
                Write-Host $line -ForegroundColor Red
            } elseif ($line -match "Success|Completed|✅") {
                Write-Host $line -ForegroundColor Green
            } elseif ($line -match "Sample|Progress|%") {
                Write-Host $line -ForegroundColor Cyan
            } else {
                Write-Host $line -ForegroundColor Gray
            }
        }
        Write-Host ""
    } else {
        Write-Host "  ⚠️  No se encontraron logs (puede que aún no haya empezado)" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ Directorio no existe: $OutputPath" -ForegroundColor Red
}

# 4. Verificar Checkpoints
Write-Host "4️⃣  CHECKPOINTS:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

if (Test-Path $OutputPath) {
    $checkpoints = Get-ChildItem -Path $OutputPath -Filter "checkpoint_*.json" -ErrorAction SilentlyContinue
    
    if ($checkpoints) {
        $latestCheckpoint = $checkpoints | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        
        Write-Host "  💾 Checkpoint más reciente: " -NoNewline
        Write-Host $latestCheckpoint.Name -ForegroundColor Cyan
        Write-Host "     Creado: $($latestCheckpoint.CreationTime)" -ForegroundColor Gray
        Write-Host "     Última actualización: $($latestCheckpoint.LastWriteTime)" -ForegroundColor Gray
        Write-Host "     Tamaño: $([math]::Round($latestCheckpoint.Length/1MB, 2)) MB" -ForegroundColor Gray
        Write-Host ""
        
        # Leer progreso del checkpoint
        try {
            $checkpointData = Get-Content $latestCheckpoint.FullName | ConvertFrom-Json
            
            Write-Host "  📊 Progreso del monitoreo:" -ForegroundColor White
            Write-Host "     Muestras recolectadas: " -NoNewline
            Write-Host "$($checkpointData.SamplesCollected) / $($checkpointData.TotalSamples)" -ForegroundColor Green
            Write-Host "     Progreso: " -NoNewline
            Write-Host "$($checkpointData.ProgressPercent)%" -ForegroundColor Green
            Write-Host "     Inicio: $($checkpointData.StartTime)" -ForegroundColor Gray
            Write-Host "     Última muestra: $($checkpointData.LastSampleTime)" -ForegroundColor Gray
            
            # Calcular tiempo estimado restante
            if ($checkpointData.SamplesCollected -gt 0 -and $checkpointData.TotalSamples -gt 0) {
                $startTime = [DateTime]::Parse($checkpointData.StartTime)
                $elapsed = (Get-Date) - $startTime
                $samplesPerHour = $checkpointData.SamplesCollected / $elapsed.TotalHours
                $remainingSamples = $checkpointData.TotalSamples - $checkpointData.SamplesCollected
                $hoursRemaining = $remainingSamples / $samplesPerHour
                
                Write-Host "     Tiempo transcurrido: " -NoNewline
                Write-Host "$([math]::Round($elapsed.TotalHours, 1)) horas" -ForegroundColor Cyan
                Write-Host "     Tiempo estimado restante: " -NoNewline
                Write-Host "$([math]::Round($hoursRemaining, 1)) horas" -ForegroundColor Cyan
            }
        } catch {
            Write-Host "  ⚠️  No se pudo leer el checkpoint (puede estar en uso)" -ForegroundColor Yellow
        }
        Write-Host ""
    } else {
        Write-Host "  ⚠️  No hay checkpoints todavía" -ForegroundColor Yellow
        Write-Host "     ℹ️  El primer checkpoint se genera después de ~60 minutos" -ForegroundColor Gray
        Write-Host ""
    }
}

# 5. Verificar Reportes Finales
Write-Host "5️⃣  REPORTES FINALES:" -ForegroundColor Yellow
Write-Host "────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

if (Test-Path $OutputPath) {
    $htmlReports = Get-ChildItem -Path $OutputPath -Filter "sql_workload_extended_*.html" -ErrorAction SilentlyContinue
    $jsonReports = Get-ChildItem -Path $OutputPath -Filter "sql_workload_extended_*.json" -ErrorAction SilentlyContinue
    
    if ($htmlReports -or $jsonReports) {
        Write-Host "  📊 Reportes encontrados:" -ForegroundColor Green
        
        foreach ($report in $htmlReports) {
            Write-Host "     HTML: " -NoNewline
            Write-Host $report.Name -ForegroundColor Cyan
            Write-Host "           Tamaño: $([math]::Round($report.Length/1MB, 2)) MB" -ForegroundColor Gray
        }
        
        foreach ($report in $jsonReports) {
            Write-Host "     JSON: " -NoNewline
            Write-Host $report.Name -ForegroundColor Cyan
            Write-Host "           Tamaño: $([math]::Round($report.Length/1MB, 2)) MB" -ForegroundColor Gray
        }
        Write-Host ""
    } else {
        Write-Host "  ⏳ No hay reportes finales todavía" -ForegroundColor Yellow
        Write-Host "     ℹ️  Los reportes se generan cuando completa las 48 horas" -ForegroundColor Gray
        Write-Host ""
    }
}

# 6. Resumen y Recomendaciones
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   📋 RESUMEN Y RECOMENDACIONES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($tasks -and $tasks[0].State -eq "Running") {
    Write-Host "✅ " -NoNewline -ForegroundColor Green
    Write-Host "El monitoreo está ACTIVO y funcionando correctamente" -ForegroundColor White
    Write-Host ""
    Write-Host "📌 Puedes:" -ForegroundColor Yellow
    Write-Host "   • Cerrar esta ventana PowerShell" -ForegroundColor Gray
    Write-Host "   • Cerrar sesión RDP" -ForegroundColor Gray
    Write-Host "   • Apagar tu computadora local" -ForegroundColor Gray
    Write-Host "   • El monitoreo continuará en el servidor" -ForegroundColor Gray
    Write-Host ""
    Write-Host "🔍 Para ver progreso más tarde:" -ForegroundColor Yellow
    Write-Host "   .\check-monitoring-status.ps1" -ForegroundColor Cyan
} elseif ($jobs -and $jobs[0].State -eq "Running") {
    Write-Host "✅ " -NoNewline -ForegroundColor Green
    Write-Host "PowerShell Job está ACTIVO" -ForegroundColor White
    Write-Host ""
    Write-Host "⚠️  IMPORTANTE:" -ForegroundColor Yellow
    Write-Host "   • NO cierres esta ventana PowerShell" -ForegroundColor Red
    Write-Host "   • NO cierres sesión RDP" -ForegroundColor Red
    Write-Host "   • El job se perdería" -ForegroundColor Red
    Write-Host ""
    Write-Host "💡 Recomendación:" -ForegroundColor Yellow
    Write-Host "   Usa Task Scheduler en lugar de PowerShell Jobs para 48h" -ForegroundColor Cyan
} else {
    Write-Host "❌ " -NoNewline -ForegroundColor Red
    Write-Host "No se detectó monitoreo activo" -ForegroundColor White
    Write-Host ""
    Write-Host "🔧 Para iniciar monitoreo:" -ForegroundColor Yellow
    Write-Host "   .\launch-workload-monitor-task.ps1 -Duration 2880" -ForegroundColor Cyan
}

Write-Host ""
