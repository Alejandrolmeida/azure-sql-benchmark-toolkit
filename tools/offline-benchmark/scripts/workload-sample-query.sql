-- ================================================================
-- SQL Server Workload Metrics Sample Query
-- ================================================================
-- Purpose: Capture real-time performance metrics for Azure VM sizing
--          Optimized for fast execution in monitoring loops (< 1 second)
-- 
-- Compatible with: Azure SQL Benchmark Toolkit v2.0+
-- Author: Azure Architect Pro Team
-- Date: November 26, 2025
-- 
-- Requirements: 
--   - SQL Server 2016+ (compatible with SQL Server 2025)
--   - VIEW SERVER STATE permission
-- 
-- Usage:
--   Test independently in SSMS:
--     File -> Open -> workload-sample-query.sql -> Execute (F5)
--
--   From sqlcmd:
--     sqlcmd -S . -E -i workload-sample-query.sql -o results.txt
--
--   From PowerShell:
--     $query = Get-Content workload-sample-query.sql -Raw -Encoding UTF8
--     Invoke-Sqlcmd -ServerInstance "." -Query $query -TrustServerCertificate
--
--   From Python (pyodbc):
--     with open('workload-sample-query.sql', 'r', encoding='utf-8') as f:
--         query = f.read()
--     cursor.execute(query)
--     row = cursor.fetchone()
--
-- Optimization Notes:
--   - Single result set for easy parsing
--   - All subqueries use ISNULL for null safety
--   - Expected execution time: < 1 second
--   - No blocking locks or table scans
--   - Works on SQL Server 2016-2025
-- ================================================================

SELECT 
    -- Timestamp
    GETDATE() AS SampleTime,
    
    -- CPU Metrics
    si.cpu_count AS TotalCPUs,
    CAST(@@CPU_BUSY * CAST(si.cpu_ticks AS FLOAT) / (si.cpu_ticks / si.ms_ticks) / 1000 AS BIGINT) AS SQLServerCPUTimeMs,
    
    -- Memory Metrics (in MB for consistency)
    CAST(si.physical_memory_kb / 1024 AS BIGINT) AS TotalMemoryMB,
    CAST(si.committed_kb / 1024 AS BIGINT) AS CommittedMemoryMB,
    CAST(si.committed_target_kb / 1024 AS BIGINT) AS TargetMemoryMB,
    (SELECT COUNT(*) * 8 / 1024 FROM sys.dm_os_buffer_descriptors) AS BufferPoolMB,
    
    -- Activity Metrics
    ISNULL((SELECT TOP 1 cntr_value 
            FROM sys.dm_os_performance_counters 
            WHERE counter_name = 'Batch Requests/sec' 
            AND object_name LIKE '%SQL Statistics%'), 0) AS BatchRequestsPerSec,
    
    ISNULL((SELECT TOP 1 cntr_value 
            FROM sys.dm_os_performance_counters 
            WHERE counter_name = 'SQL Compilations/sec' 
            AND object_name LIKE '%SQL Statistics%'), 0) AS CompilationsPerSec,
    
    ISNULL((SELECT TOP 1 cntr_value 
            FROM sys.dm_os_performance_counters 
            WHERE counter_name = 'User Connections' 
            AND object_name LIKE '%General Statistics%'), 0) AS UserConnections,
    
    -- I/O Metrics (cumulative since SQL Server start)
    ISNULL((SELECT SUM(num_of_reads) 
            FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalReads,
    
    ISNULL((SELECT SUM(num_of_writes) 
            FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalWrites,
    
    ISNULL((SELECT SUM(io_stall_read_ms) 
            FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalReadLatencyMs,
    
    ISNULL((SELECT SUM(io_stall_write_ms) 
            FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalWriteLatencyMs,
    
    ISNULL((SELECT SUM(num_of_bytes_read) 
            FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalBytesRead,
    
    ISNULL((SELECT SUM(num_of_bytes_written) 
            FROM sys.dm_io_virtual_file_stats(NULL, NULL)), 0) AS TotalBytesWritten,
    
    -- Wait Statistics - Top wait type
    ISNULL((SELECT TOP 1 wait_type 
            FROM sys.dm_os_wait_stats 
            WHERE wait_type NOT IN (
                'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 
                'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 
                'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE'
            )
            ORDER BY wait_time_ms DESC), 'NONE') AS TopWaitType,
    
    ISNULL((SELECT TOP 1 wait_time_ms 
            FROM sys.dm_os_wait_stats 
            WHERE wait_type NOT IN (
                'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 
                'SLEEP_TASK', 'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 
                'WAITFOR', 'LOGMGR_QUEUE', 'CHECKPOINT_QUEUE'
            )
            ORDER BY wait_time_ms DESC), 0) AS TopWaitTimeMs

FROM sys.dm_os_sys_info si;
