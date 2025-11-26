<#
.SYNOPSIS
    Diagnóstico completo del monitoreo SQL Server en ejecución.

.DESCRIPTION
    Identifica exactamente cómo se está ejecutando el monitoreo y dónde está la salida.
#>

param(
    [string]$OutputPath = "C:\AzureMigration\Assessment"
)

Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   🔍 DIAGNÓSTICO COMPLETO - SQL Server Workload Monitor" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar procesos PowerShell activos
Write-Host "1️⃣  PROCESOS POWERSHELL ACTIVOS:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

$psProcesses = Get-Process | Where-Object {$_.ProcessName -match "pwsh|powershell"}

if ($psProcesses) {
    Write-Host "  Procesos PowerShell encontrados: $($psProcesses.Count)" -ForegroundColor White
    
    foreach ($proc in $psProcesses) {
        $runtime = (Get-Date) - $proc.StartTime
        Write-Host "    PID: $($proc.Id) | " -NoNewline -ForegroundColor Gray
        Write-Host "Memoria: $([math]::Round($proc.WorkingSet64/1MB, 0)) MB | " -NoNewline -ForegroundColor Gray
        Write-Host "Tiempo: $($runtime.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
    }
    Write-Host ""
}

# 2. Verificar Task Scheduler
Write-Host "2️⃣  TASK SCHEDULER:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

$tasks = Get-ScheduledTask | Where-Object {$_.TaskName -like "SQLWorkloadMonitor*"}

if ($tasks) {
    Write-Host "  ✅ Task encontrado:" -ForegroundColor Green
    foreach ($task in $tasks) {
        $taskInfo = Get-ScheduledTaskInfo -TaskName $task.TaskName
        Write-Host "     Nombre: $($task.TaskName)" -ForegroundColor Cyan
        Write-Host "     Estado: $($task.State)" -ForegroundColor $(if ($task.State -eq "Running") {"Green"} else {"Yellow"})
        Write-Host "     Última ejecución: $($taskInfo.LastRunTime)" -ForegroundColor Gray
        Write-Host "     Resultado: $($taskInfo.LastTaskResult)" -ForegroundColor Gray
        
        # Intentar obtener la línea de comando
        try {
            $taskXml = Export-ScheduledTask -TaskName $task.TaskName
            if ($taskXml -match '<Arguments>(.*?)</Arguments>') {
                Write-Host "     Comando: $($matches[1].Substring(0, [Math]::Min(100, $matches[1].Length)))..." -ForegroundColor Gray
            }
        } catch {
            Write-Host "     (No se pudo leer comando)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
} else {
    Write-Host "  ℹ️  No hay Task Scheduler activo" -ForegroundColor Yellow
    Write-Host "     Probablemente ejecutaste el script directamente" -ForegroundColor Gray
    Write-Host ""
}

# 3. Verificar PowerShell Jobs
Write-Host "3️⃣  POWERSHELL JOBS (en esta sesión):" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

$jobs = Get-Job | Where-Object {$_.Name -like "SQLWorkloadMonitor*"}

if ($jobs) {
    Write-Host "  ✅ Job encontrado en esta sesión:" -ForegroundColor Green
    foreach ($job in $jobs) {
        Write-Host "     Nombre: $($job.Name)" -ForegroundColor Cyan
        Write-Host "     Estado: $($job.State)" -ForegroundColor $(if ($job.State -eq "Running") {"Green"} else {"Yellow"})
        Write-Host "     Inicio: $($job.PSBeginTime)" -ForegroundColor Gray
        
        if ($job.State -eq "Running") {
            $elapsed = (Get-Date) - $job.PSBeginTime
            Write-Host "     Tiempo transcurrido: $($elapsed.ToString('hh\:mm\:ss'))" -ForegroundColor Cyan
        }
        
        # Ver últimas líneas de output
        Write-Host ""
        Write-Host "     📋 Últimas 5 líneas de output:" -ForegroundColor White
        $output = Receive-Job -Id $job.Id -Keep | Select-Object -Last 5
        if ($output) {
            foreach ($line in $output) {
                Write-Host "        $line" -ForegroundColor Gray
            }
        } else {
            Write-Host "        (Sin output visible todavía)" -ForegroundColor DarkGray
        }
    }
    Write-Host ""
} else {
    Write-Host "  ℹ️  No hay PowerShell jobs en esta sesión" -ForegroundColor Yellow
    Write-Host ""
}

# 4. Buscar archivos en TODAS las ubicaciones posibles
Write-Host "4️⃣  BÚSQUEDA DE ARCHIVOS:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

$searchLocations = @(
    $OutputPath,
    "$env:USERPROFILE\Documents",
    "$env:TEMP",
    "$env:LOCALAPPDATA",
    (Get-Location).Path,
    "C:\Temp",
    "C:\Windows\Temp"
)

$foundFiles = @{
    "task_log" = @()
    "checkpoint" = @()
    "json_report" = @()
    "html_report" = @()
}

foreach ($location in $searchLocations) {
    if (Test-Path $location) {
        Write-Host "  🔍 Buscando en: $location" -ForegroundColor Gray
        
        # Buscar logs
        $logs = Get-ChildItem -Path $location -Filter "task_log_*.txt" -ErrorAction SilentlyContinue
        if ($logs) { $foundFiles["task_log"] += $logs }
        
        # Buscar checkpoints
        $checkpoints = Get-ChildItem -Path $location -Filter "checkpoint_*.json" -ErrorAction SilentlyContinue
        if ($checkpoints) { $foundFiles["checkpoint"] += $checkpoints }
        
        # Buscar reportes JSON
        $jsons = Get-ChildItem -Path $location -Filter "sql_workload_extended_*.json" -ErrorAction SilentlyContinue
        if ($jsons) { $foundFiles["json_report"] += $jsons }
        
        # Buscar reportes HTML
        $htmls = Get-ChildItem -Path $location -Filter "sql_workload_extended_*.html" -ErrorAction SilentlyContinue
        if ($htmls) { $foundFiles["html_report"] += $htmls }
    }
}

Write-Host ""

# Mostrar resultados
if ($foundFiles["task_log"].Count -gt 0) {
    Write-Host "  📄 TASK LOGS encontrados:" -ForegroundColor Green
    foreach ($file in $foundFiles["task_log"] | Sort-Object LastWriteTime -Descending) {
        Write-Host "     $($file.FullName)" -ForegroundColor Cyan
        Write-Host "        Tamaño: $([math]::Round($file.Length/1KB, 2)) KB | " -NoNewline -ForegroundColor Gray
        Write-Host "Modificado: $($file.LastWriteTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
    }
    Write-Host ""
} else {
    Write-Host "  ⚠️  No se encontraron task_log_*.txt" -ForegroundColor Yellow
    Write-Host ""
}

if ($foundFiles["checkpoint"].Count -gt 0) {
    Write-Host "  💾 CHECKPOINTS encontrados:" -ForegroundColor Green
    foreach ($file in $foundFiles["checkpoint"] | Sort-Object LastWriteTime -Descending | Select-Object -First 3) {
        Write-Host "     $($file.FullName)" -ForegroundColor Cyan
        Write-Host "        Tamaño: $([math]::Round($file.Length/1MB, 2)) MB | " -NoNewline -ForegroundColor Gray
        Write-Host "Modificado: $($file.LastWriteTime.ToString('HH:mm:ss'))" -ForegroundColor Gray
        
        # Leer progreso
        try {
            $data = Get-Content $file.FullName | ConvertFrom-Json
            Write-Host "        Progreso: $($data.ProgressPercent)% | " -NoNewline -ForegroundColor Green
            Write-Host "Muestras: $($data.SamplesCollected)/$($data.TotalSamples)" -ForegroundColor Green
        } catch {}
    }
    Write-Host ""
} else {
    Write-Host "  ⏳ No hay checkpoints todavía (normal si lleva < 60 minutos)" -ForegroundColor Yellow
    Write-Host ""
}

if ($foundFiles["json_report"].Count -gt 0) {
    Write-Host "  📊 REPORTES JSON encontrados:" -ForegroundColor Green
    foreach ($file in $foundFiles["json_report"]) {
        Write-Host "     $($file.FullName)" -ForegroundColor Cyan
    }
    Write-Host ""
}

if ($foundFiles["html_report"].Count -gt 0) {
    Write-Host "  📊 REPORTES HTML encontrados:" -ForegroundColor Green
    foreach ($file in $foundFiles["html_report"]) {
        Write-Host "     $($file.FullName)" -ForegroundColor Cyan
    }
    Write-Host ""
}

# 5. Verificar directorio actual del script
Write-Host "5️⃣  CONTEXTO DE EJECUCIÓN:" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────" -ForegroundColor DarkGray

Write-Host "  📁 Directorio actual: " -NoNewline
Write-Host (Get-Location).Path -ForegroundColor Cyan

Write-Host "  👤 Usuario actual: " -NoNewline
Write-Host $env:USERNAME -ForegroundColor Cyan

Write-Host "  💻 Computadora: " -NoNewline
Write-Host $env:COMPUTERNAME -ForegroundColor Cyan

Write-Host ""

# 6. Diagnóstico y recomendaciones
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "   📋 DIAGNÓSTICO Y RECOMENDACIONES" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if (-not $tasks -and $jobs) {
    Write-Host "📌 DETECTADO: PowerShell Job en sesión actual" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   ✅ El monitoreo está corriendo" -ForegroundColor Green
    Write-Host "   ⚠️  NO hay archivo task_log porque NO usaste Task Scheduler" -ForegroundColor Yellow
    Write-Host "   ℹ️  El output está en MEMORIA del job" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Para ver el output del job:" -ForegroundColor White
    Write-Host "   Get-Job | Where-Object {`$_.Name -like 'SQLWorkloadMonitor*'} | Receive-Job -Keep" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   ⚠️  IMPORTANTE: NO cierres esta ventana PowerShell" -ForegroundColor Red
    Write-Host "      Si cierras la ventana, se pierde el job" -ForegroundColor Red
    Write-Host ""
    
    if ($foundFiles["checkpoint"].Count -gt 0) {
        Write-Host "   ✅ HAY checkpoints = está funcionando correctamente" -ForegroundColor Green
        $latest = $foundFiles["checkpoint"] | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "   📂 Archivos se guardan en: $($latest.DirectoryName)" -ForegroundColor Cyan
    } else {
        Write-Host "   ⏳ Aún no hay checkpoints (aparecen a los ~60 minutos)" -ForegroundColor Yellow
    }
    
} elseif ($tasks -and $tasks[0].State -eq "Running") {
    Write-Host "📌 DETECTADO: Task Scheduler activo" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "   ✅ El monitoreo está corriendo vía Task Scheduler" -ForegroundColor Green
    
    if ($foundFiles["task_log"].Count -gt 0) {
        Write-Host "   ✅ Log encontrado: $($foundFiles['task_log'][0].FullName)" -ForegroundColor Green
        Write-Host ""
        Write-Host "   Para ver en tiempo real:" -ForegroundColor White
        Write-Host "   Get-Content '$($foundFiles['task_log'][0].FullName)' -Wait" -ForegroundColor Cyan
    } else {
        Write-Host "   ⚠️  No se encuentra task_log" -ForegroundColor Yellow
        Write-Host "      Puede estar en otra ubicación o aún no se creó" -ForegroundColor Gray
    }
    
} elseif (-not $tasks -and -not $jobs) {
    Write-Host "❌ NO SE DETECTÓ MONITOREO ACTIVO" -ForegroundColor Red
    Write-Host ""
    
    if ($foundFiles["checkpoint"].Count -gt 0) {
        $latest = $foundFiles["checkpoint"] | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        $age = (Get-Date) - $latest.LastWriteTime
        
        Write-Host "   ⚠️  Hay checkpoints pero no hay proceso activo" -ForegroundColor Yellow
        Write-Host "   📂 Último checkpoint: $($latest.Name)" -ForegroundColor Cyan
        Write-Host "   ⏰ Última actualización hace: $([math]::Round($age.TotalMinutes, 0)) minutos" -ForegroundColor Gray
        Write-Host ""
        
        if ($age.TotalMinutes -lt 5) {
            Write-Host "   💡 El checkpoint es reciente, puede que se esté ejecutando" -ForegroundColor Cyan
            Write-Host "      en otra sesión PowerShell o task" -ForegroundColor Gray
        } else {
            Write-Host "   💡 El monitoreo puede haberse detenido" -ForegroundColor Yellow
            Write-Host ""
            Write-Host "   Para reanudar desde checkpoint:" -ForegroundColor White
            Write-Host "   .\sql-workload-monitor-extended.ps1 -ResumeFrom '$($latest.FullName)'" -ForegroundColor Cyan
        }
    } else {
        Write-Host "   Para iniciar monitoreo:" -ForegroundColor White
        Write-Host "   .\launch-workload-monitor-task.ps1 -Duration 2880" -ForegroundColor Cyan
    }
}

Write-Host ""
