<#
.SYNOPSIS
    Genera carga sintética en SQL Server para simular picos de actividad

.DESCRIPTION
    Ejecuta múltiples queries concurrentes contra bases de datos de prueba
    para estresar CPU, memoria, disco I/O y conexiones simultáneas.
    
    Útil para validar el dimensionamiento de Azure VMs durante monitoreo.

.PARAMETER ServerInstance
    Instancia SQL Server (default: localhost)

.PARAMETER Duration
    Duración de la carga en minutos (default: 60)

.PARAMETER Intensity
    Nivel de intensidad: Low, Medium, High, Extreme (default: Medium)

.PARAMETER Databases
    Bases de datos a usar (default: Northwind, AdventureWorks2022)

.PARAMETER PeakPattern
    Simular patrón de picos: Constant, Waves, RandomSpikes (default: Waves)

.EXAMPLE
    .\Generate-SQLWorkload.ps1 -Duration 120 -Intensity High
    Genera carga alta durante 2 horas

.EXAMPLE
    .\Generate-SQLWorkload.ps1 -Intensity Medium -PeakPattern RandomSpikes
    Genera picos aleatorios de carga media

.NOTES
    Author: Alejandro Almeida - Azure Architect Pro
    Date: November 19, 2025
    
    ⚠️ IMPORTANTE: Ejecutar ANTES o DURANTE el monitoreo para capturar picos realistas
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$ServerInstance = "localhost",
    
    [Parameter(Mandatory=$false)]
    [int]$Duration = 60,
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Low", "Medium", "High", "Extreme")]
    [string]$Intensity = "Medium",
    
    [Parameter(Mandatory=$false)]
    [string[]]$Databases = @("Northwind", "AdventureWorks2022"),
    
    [Parameter(Mandatory=$false)]
    [ValidateSet("Constant", "Waves", "RandomSpikes")]
    [string]$PeakPattern = "Waves"
)

$ErrorActionPreference = "Stop"

Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "║   🔥 SQL Server Workload Generator - Synthetic Load Testing                 ║" -ForegroundColor Cyan
Write-Host "║                                                                              ║" -ForegroundColor Cyan
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Verificar módulo SqlServer
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    Write-Host "⚠️  Instalando módulo SqlServer..." -ForegroundColor Yellow
    Install-Module -Name SqlServer -Force -AllowClobber -Scope CurrentUser
}
Import-Module SqlServer -ErrorAction SilentlyContinue

# Configuración de intensidad
$intensityConfig = @{
    "Low" = @{
        Threads = 2
        QueriesPerThread = 5
        DelayMs = 2000
        Description = "Carga ligera (2 threads, delays largos)"
    }
    "Medium" = @{
        Threads = 5
        QueriesPerThread = 10
        DelayMs = 1000
        Description = "Carga media (5 threads, delays moderados)"
    }
    "High" = @{
        Threads = 10
        QueriesPerThread = 20
        DelayMs = 500
        Description = "Carga alta (10 threads, delays cortos)"
    }
    "Extreme" = @{
        Threads = 20
        QueriesPerThread = 50
        DelayMs = 100
        Description = "Carga extrema (20 threads, delays mínimos)"
    }
}

$config = $intensityConfig[$Intensity]

Write-Host "⚙️  Configuración:" -ForegroundColor Yellow
Write-Host "   Servidor:        $ServerInstance" -ForegroundColor White
Write-Host "   Duración:        $Duration minutos" -ForegroundColor White
Write-Host "   Intensidad:      $Intensity - $($config.Description)" -ForegroundColor White
Write-Host "   Threads:         $($config.Threads)" -ForegroundColor White
Write-Host "   Patrón:          $PeakPattern" -ForegroundColor White
Write-Host "   Bases de datos:  $($Databases -join ', ')" -ForegroundColor White
Write-Host ""

# Verificar conectividad
Write-Host "🔍 Verificando conexión..." -ForegroundColor Yellow
try {
    $version = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT @@VERSION AS Version" -TrustServerCertificate -ErrorAction Stop
    Write-Host "   ✅ Conectado a SQL Server" -ForegroundColor Green
    Write-Host ""
}
catch {
    Write-Host "   ❌ Error de conexión: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Verificar bases de datos existen
Write-Host "📊 Verificando bases de datos..." -ForegroundColor Yellow
$availableDbs = @()
foreach ($db in $Databases) {
    try {
        $dbCheck = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query "SELECT DB_ID('$db') AS DbId" -TrustServerCertificate
        if ($dbCheck.DbId) {
            Write-Host "   ✅ $db encontrada" -ForegroundColor Green
            $availableDbs += $db
        } else {
            Write-Host "   ⚠️  $db no existe, saltando..." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "   ⚠️  Error verificando $db" -ForegroundColor Yellow
    }
}

if ($availableDbs.Count -eq 0) {
    Write-Host ""
    Write-Host "❌ No hay bases de datos disponibles para generar carga" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Queries de carga por base de datos
$workloadQueries = @{
    "Northwind" = @(
        # CPU-intensive: joins y aggregations
        "SELECT c.CompanyName, COUNT(o.OrderID) AS Orders, SUM(od.Quantity * od.UnitPrice) AS TotalSales FROM Customers c LEFT JOIN Orders o ON c.CustomerID = o.CustomerID LEFT JOIN [Order Details] od ON o.OrderID = od.OrderID GROUP BY c.CompanyName ORDER BY TotalSales DESC"
        
        # Memory-intensive: cross joins (cuidado)
        "SELECT TOP 1000 c.CustomerID, o.OrderID, p.ProductName FROM Customers c CROSS JOIN Orders o CROSS JOIN Products p"
        
        # Disk I/O: table scans
        "SELECT * FROM Orders WHERE YEAR(OrderDate) = 1997 ORDER BY OrderDate"
        
        # Mixed workload
        "SELECT e.FirstName, e.LastName, COUNT(o.OrderID) AS OrdersProcessed FROM Employees e LEFT JOIN Orders o ON e.EmployeeID = o.EmployeeID GROUP BY e.FirstName, e.LastName"
        
        # Insert/Update (transactional)
        "INSERT INTO Customers (CustomerID, CompanyName, ContactName, Country) SELECT 'TEST' + CAST(NEWID() AS NVARCHAR(5)), 'Test Company', 'Test Contact', 'USA' WHERE NOT EXISTS (SELECT 1 FROM Customers WHERE CustomerID LIKE 'TEST%')"
        
        # Aggregation heavy
        "SELECT p.CategoryID, COUNT(*) AS ProductCount, AVG(p.UnitPrice) AS AvgPrice, SUM(od.Quantity) AS TotalSold FROM Products p LEFT JOIN [Order Details] od ON p.ProductID = od.ProductID GROUP BY p.CategoryID"
    )
    
    "AdventureWorks2022" = @(
        # Complex joins
        "SELECT TOP 100 p.FirstName, p.LastName, soh.OrderDate, SUM(sod.LineTotal) AS OrderTotal FROM Person.Person p INNER JOIN Sales.Customer c ON p.BusinessEntityID = c.PersonID INNER JOIN Sales.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID INNER JOIN Sales.SalesOrderDetail sod ON soh.SalesOrderID = sod.SalesOrderID GROUP BY p.FirstName, p.LastName, soh.OrderDate ORDER BY OrderTotal DESC"
        
        # Subqueries
        "SELECT ProductID, Name, ListPrice FROM Production.Product WHERE ListPrice > (SELECT AVG(ListPrice) FROM Production.Product) ORDER BY ListPrice DESC"
        
        # Window functions
        "SELECT TOP 100 SalesOrderID, OrderDate, TotalDue, ROW_NUMBER() OVER (PARTITION BY YEAR(OrderDate) ORDER BY TotalDue DESC) AS RankInYear FROM Sales.SalesOrderHeader"
        
        # Text search (CPU intensive)
        "SELECT Name, ProductNumber FROM Production.Product WHERE Name LIKE '%Bike%' OR ProductNumber LIKE '%BK%'"
        
        # Aggregations with HAVING
        "SELECT ProductID, SUM(OrderQty) AS TotalQty, AVG(UnitPrice) AS AvgPrice FROM Sales.SalesOrderDetail GROUP BY ProductID HAVING SUM(OrderQty) > 100 ORDER BY TotalQty DESC"
        
        # Complex WHERE
        "SELECT * FROM Sales.SalesOrderHeader WHERE TotalDue > 10000 AND YEAR(OrderDate) >= 2013 AND Status = 5"
    )
    
    "AdventureWorksLT2022" = @(
        # Similar but lighter workload
        "SELECT TOP 50 c.CompanyName, COUNT(soh.SalesOrderID) AS Orders FROM SalesLT.Customer c LEFT JOIN SalesLT.SalesOrderHeader soh ON c.CustomerID = soh.CustomerID GROUP BY c.CompanyName"
        
        "SELECT p.Name, p.ListPrice, pc.Name AS Category FROM SalesLT.Product p INNER JOIN SalesLT.ProductCategory pc ON p.ProductCategoryID = pc.ProductCategoryID WHERE p.ListPrice > 100"
        
        "SELECT SalesOrderID, OrderDate, TotalDue FROM SalesLT.SalesOrderHeader WHERE YEAR(OrderDate) = 2008 ORDER BY TotalDue DESC"
    )
}

# ScriptBlock para ejecutar queries en paralelo
$workloadScriptBlock = {
    param($ServerInstance, $Database, $Queries, $Duration, $DelayMs, $ThreadId, $PeakPattern)
    
    Import-Module SqlServer -ErrorAction SilentlyContinue
    
    $startTime = Get-Date
    $endTime = $startTime.AddMinutes($Duration)
    $queryCount = 0
    
    Write-Host "[Thread $ThreadId] Iniciando carga en $Database..." -ForegroundColor Cyan
    
    while ((Get-Date) -lt $endTime) {
        # Calcular intensidad según patrón
        $currentIntensity = 1.0
        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        
        switch ($PeakPattern) {
            "Waves" {
                # Ondas sinusoidales: picos cada 10 minutos
                $currentIntensity = 0.5 + 0.5 * [Math]::Sin(($elapsed / 10) * 2 * [Math]::PI)
            }
            "RandomSpikes" {
                # Picos aleatorios (20% probabilidad de spike 2x)
                $currentIntensity = if ((Get-Random -Minimum 0 -Maximum 100) -lt 20) { 2.0 } else { 1.0 }
            }
            "Constant" {
                $currentIntensity = 1.0
            }
        }
        
        # Seleccionar query aleatoria
        $query = $Queries | Get-Random
        
        try {
            $result = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $query -TrustServerCertificate -QueryTimeout 30 -ErrorAction SilentlyContinue
            $queryCount++
            
            if ($queryCount % 10 -eq 0) {
                Write-Host "[Thread $ThreadId] $Database - $queryCount queries ejecutadas (Intensidad: $([math]::Round($currentIntensity * 100))%)" -ForegroundColor Gray
            }
        }
        catch {
            # Ignorar errores individuales (timeouts, etc.)
        }
        
        # Delay ajustado por intensidad
        $adjustedDelay = [int]($DelayMs / $currentIntensity)
        Start-Sleep -Milliseconds $adjustedDelay
    }
    
    Write-Host "[Thread $ThreadId] Finalizado - Total queries: $queryCount" -ForegroundColor Green
    return $queryCount
}

# Iniciar generación de carga
Write-Host "🔥 Iniciando generación de carga..." -ForegroundColor Yellow
Write-Host "   Finalización estimada: $((Get-Date).AddMinutes($Duration).ToString('HH:mm:ss'))" -ForegroundColor Gray
Write-Host ""
Write-Host "⚠️  CONSEJO: Ejecuta el script de monitoreo en OTRA ventana de PowerShell:" -ForegroundColor Yellow
Write-Host "   .\sql-workload-monitor-extended.ps1 -Duration $Duration -SampleInterval 60" -ForegroundColor Cyan
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""

$jobs = @()
$threadId = 1

# Crear threads de carga
for ($i = 0; $i -lt $config.Threads; $i++) {
    $db = $availableDbs[$i % $availableDbs.Count]
    
    if ($workloadQueries.ContainsKey($db)) {
        $queries = $workloadQueries[$db]
        
        $job = Start-Job -ScriptBlock $workloadScriptBlock -ArgumentList $ServerInstance, $db, $queries, $Duration, $config.DelayMs, $threadId, $PeakPattern
        $jobs += $job
        
        Write-Host "✅ Thread $threadId iniciado → $db" -ForegroundColor Green
        $threadId++
        
        Start-Sleep -Milliseconds 500  # Stagger thread start
    }
}

Write-Host ""
Write-Host "🔄 $($jobs.Count) threads de carga activos" -ForegroundColor Cyan
Write-Host ""

# Monitorear progreso
$lastUpdate = Get-Date
$updateInterval = 30  # segundos

while ($jobs | Where-Object { $_.State -eq "Running" }) {
    $now = Get-Date
    
    if (($now - $lastUpdate).TotalSeconds -ge $updateInterval) {
        $runningCount = ($jobs | Where-Object { $_.State -eq "Running" }).Count
        $completedCount = ($jobs | Where-Object { $_.State -eq "Completed" }).Count
        $elapsed = [math]::Round(($now - (Get-Date).AddMinutes(-$Duration)).TotalMinutes + $Duration, 1)
        $remaining = [math]::Round($Duration - $elapsed, 1)
        
        Write-Host "[$(Get-Date -Format 'HH:mm:ss')] " -NoNewline -ForegroundColor Gray
        Write-Host "Threads activos: $runningCount | Completados: $completedCount | Tiempo restante: $remaining min" -ForegroundColor White
        
        $lastUpdate = $now
    }
    
    Start-Sleep -Seconds 5
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Gray
Write-Host ""
Write-Host "⏹️  Recolectando resultados..." -ForegroundColor Yellow
Write-Host ""

# Recolectar resultados
$totalQueries = 0
foreach ($job in $jobs) {
    $result = Receive-Job -Job $job -Wait
    if ($result) {
        $totalQueries += $result
    }
    Remove-Job -Job $job
}

Write-Host "╔══════════════════════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "║   ✅ GENERACIÓN DE CARGA COMPLETADA                                          ║" -ForegroundColor Green
Write-Host "║                                                                              ║" -ForegroundColor Green
Write-Host "╚══════════════════════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Estadísticas:" -ForegroundColor Yellow
Write-Host "   Duración:         $Duration minutos" -ForegroundColor White
Write-Host "   Threads:          $($jobs.Count)" -ForegroundColor White
Write-Host "   Queries totales:  $totalQueries" -ForegroundColor White
Write-Host "   Queries/min:      $([math]::Round($totalQueries / $Duration, 2))" -ForegroundColor White
Write-Host "   Intensidad:       $Intensity" -ForegroundColor White
Write-Host "   Patrón:           $PeakPattern" -ForegroundColor White
Write-Host ""
Write-Host "💡 Próximo paso:" -ForegroundColor Yellow
Write-Host "   Revisa los resultados del monitoreo en:" -ForegroundColor White
Write-Host "   C:\AzureMigration\Assessment\sql_workload_extended_*.html" -ForegroundColor Cyan
Write-Host ""
