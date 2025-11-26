#!/usr/bin/env python3
"""
SQL Server Workload Monitor - Extended Edition
Monitor comprehensive SQL Server metrics for Azure migration analysis

This tool captures:
- CPU usage (overall and SQL Server specific)
- Memory utilization (RAM, Buffer Pool, Page Life Expectancy)
- Disk I/O metrics (IOPS, throughput, latency)
- Transaction statistics (TPS, batch requests)
- Wait statistics and bottleneck detection
- Database sizes and growth patterns

Usage:
    python monitor_sql_workload.py --server SERVER --database DB --interval 120 --duration 86400

Output:
    - JSON file with time-series metrics
    - CSV file for Excel analysis
    - Console real-time monitoring

Author: Azure SQL Benchmark Toolkit
Version: 2.0.0
Date: 2025-11-25
"""

import pyodbc
import time
import json
import csv
import argparse
import sys
from datetime import datetime
import os

class SQLServerMonitor:
    """Monitor SQL Server performance metrics"""
    
    def __init__(self, server, database, username=None, password=None, trusted_connection=True):
        """
        Initialize SQL Server connection
        
        Args:
            server: SQL Server hostname or IP
            database: Database name
            username: SQL authentication username (optional)
            password: SQL authentication password (optional)
            trusted_connection: Use Windows authentication (default: True)
        """
        self.server = server
        self.database = database
        self.username = username
        self.password = password
        self.trusted_connection = trusted_connection
        self.connection = None
        
    def connect(self):
        """Establish connection to SQL Server"""
        try:
            if self.trusted_connection:
                connection_string = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.server};"
                    f"DATABASE={self.database};"
                    f"Trusted_Connection=yes;"
                )
            else:
                connection_string = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.server};"
                    f"DATABASE={self.database};"
                    f"UID={self.username};"
                    f"PWD={self.password};"
                )
            
            self.connection = pyodbc.connect(connection_string, timeout=30)
            print(f"✅ Connected to SQL Server: {self.server}")
            return True
            
        except Exception as e:
            print(f"❌ Connection failed: {str(e)}")
            return False
    
    def execute_query(self, query):
        """Execute SQL query and return results"""
        try:
            cursor = self.connection.cursor()
            cursor.execute(query)
            
            # Get column names
            columns = [column[0] for column in cursor.description]
            
            # Fetch all rows
            rows = cursor.fetchall()
            
            # Convert to list of dictionaries
            results = []
            for row in rows:
                results.append(dict(zip(columns, row)))
            
            cursor.close()
            return results
            
        except Exception as e:
            print(f"⚠️  Query error: {str(e)}")
            return []
    
    def get_cpu_metrics(self):
        """Get CPU utilization metrics"""
        query = """
        SELECT 
            CAST(100.0 * SUM(signal_wait_time_ms) / SUM(wait_time_ms) AS DECIMAL(5,2)) AS cpu_usage_pct,
            CAST(@@CPU_BUSY / (@@TIMETICKS / 1000.0) AS DECIMAL(10,2)) AS sql_cpu_time_ms
        FROM sys.dm_os_wait_stats
        WHERE wait_time_ms > 0;
        """
        return self.execute_query(query)
    
    def get_memory_metrics(self):
        """Get memory utilization metrics"""
        query = """
        SELECT 
            (total_physical_memory_kb / 1024) AS total_ram_mb,
            (available_physical_memory_kb / 1024) AS available_ram_mb,
            (total_physical_memory_kb - available_physical_memory_kb) / 1024 AS used_ram_mb,
            CAST(100.0 * (total_physical_memory_kb - available_physical_memory_kb) / total_physical_memory_kb AS DECIMAL(5,2)) AS ram_usage_pct,
            (system_memory_state_desc) AS memory_state
        FROM sys.dm_os_sys_memory;
        
        SELECT 
            (cntr_value / 1024) AS buffer_pool_mb
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Database Cache Memory (KB)';
        
        SELECT 
            cntr_value AS page_life_expectancy_sec
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Page life expectancy'
        AND object_name LIKE '%Buffer Manager%';
        """
        results = self.execute_query(query)
        
        # Consolidate results
        if results and len(results) >= 3:
            memory_info = results[0]
            memory_info['buffer_pool_mb'] = results[1]['buffer_pool_mb'] if len(results) > 1 else 0
            memory_info['page_life_expectancy_sec'] = results[2]['page_life_expectancy_sec'] if len(results) > 2 else 0
            return [memory_info]
        return results
    
    def get_disk_io_metrics(self):
        """Get disk I/O metrics"""
        query = """
        SELECT 
            DB_NAME(database_id) AS database_name,
            SUM(num_of_reads) AS total_reads,
            SUM(num_of_writes) AS total_writes,
            SUM(num_of_reads + num_of_writes) AS total_iops,
            SUM(num_of_bytes_read) / 1048576 AS total_mb_read,
            SUM(num_of_bytes_written) / 1048576 AS total_mb_written,
            CAST(SUM(io_stall_read_ms) AS DECIMAL(10,2)) AS total_read_latency_ms,
            CAST(SUM(io_stall_write_ms) AS DECIMAL(10,2)) AS total_write_latency_ms,
            CASE 
                WHEN SUM(num_of_reads) > 0 THEN CAST(SUM(io_stall_read_ms) / SUM(num_of_reads) AS DECIMAL(10,2))
                ELSE 0 
            END AS avg_read_latency_ms,
            CASE 
                WHEN SUM(num_of_writes) > 0 THEN CAST(SUM(io_stall_write_ms) / SUM(num_of_writes) AS DECIMAL(10,2))
                ELSE 0 
            END AS avg_write_latency_ms
        FROM sys.dm_io_virtual_file_stats(NULL, NULL)
        WHERE database_id > 4  -- Exclude system databases
        GROUP BY database_id;
        """
        return self.execute_query(query)
    
    def get_transaction_metrics(self):
        """Get transaction and batch request metrics"""
        query = """
        SELECT 
            cntr_value AS transactions_per_sec
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Transactions/sec'
        AND instance_name = '_Total';
        
        SELECT 
            cntr_value AS batch_requests_per_sec
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'Batch Requests/sec';
        
        SELECT 
            cntr_value AS sql_compilations_per_sec
        FROM sys.dm_os_performance_counters
        WHERE counter_name = 'SQL Compilations/sec';
        """
        results = self.execute_query(query)
        
        # Consolidate results
        if results and len(results) >= 3:
            txn_info = {
                'transactions_per_sec': results[0]['transactions_per_sec'] if results else 0,
                'batch_requests_per_sec': results[1]['batch_requests_per_sec'] if len(results) > 1 else 0,
                'sql_compilations_per_sec': results[2]['sql_compilations_per_sec'] if len(results) > 2 else 0
            }
            return [txn_info]
        return results
    
    def get_wait_statistics(self):
        """Get top wait statistics"""
        query = """
        SELECT TOP 10
            wait_type,
            waiting_tasks_count,
            CAST(wait_time_ms / 1000.0 AS DECIMAL(10,2)) AS wait_time_sec,
            CAST(max_wait_time_ms / 1000.0 AS DECIMAL(10,2)) AS max_wait_time_sec,
            CAST(signal_wait_time_ms / 1000.0 AS DECIMAL(10,2)) AS signal_wait_time_sec
        FROM sys.dm_os_wait_stats
        WHERE wait_type NOT IN (
            'CLR_SEMAPHORE', 'LAZYWRITER_SLEEP', 'RESOURCE_QUEUE', 'SLEEP_TASK',
            'SLEEP_SYSTEMTASK', 'SQLTRACE_BUFFER_FLUSH', 'WAITFOR', 'LOGMGR_QUEUE',
            'CHECKPOINT_QUEUE', 'REQUEST_FOR_DEADLOCK_SEARCH', 'XE_TIMER_EVENT',
            'BROKER_TO_FLUSH', 'BROKER_TASK_STOP', 'CLR_MANUAL_EVENT',
            'CLR_AUTO_EVENT', 'DISPATCHER_QUEUE_SEMAPHORE', 'FT_IFTS_SCHEDULER_IDLE_WAIT',
            'XE_DISPATCHER_WAIT', 'XE_DISPATCHER_JOIN', 'SQLTRACE_INCREMENTAL_FLUSH_SLEEP'
        )
        AND wait_time_ms > 0
        ORDER BY wait_time_ms DESC;
        """
        return self.execute_query(query)
    
    def get_database_sizes(self):
        """Get database sizes and growth"""
        query = """
        SELECT 
            DB_NAME(database_id) AS database_name,
            CAST(SUM(size) * 8.0 / 1024 AS DECIMAL(10,2)) AS size_mb,
            type_desc AS file_type
        FROM sys.master_files
        WHERE database_id > 4  -- Exclude system databases
        GROUP BY database_id, type_desc;
        """
        return self.execute_query(query)
    
    def collect_metrics(self):
        """Collect all metrics in a single snapshot"""
        timestamp = datetime.now().isoformat()
        
        metrics = {
            'timestamp': timestamp,
            'server': self.server,
            'database': self.database,
            'cpu': self.get_cpu_metrics(),
            'memory': self.get_memory_metrics(),
            'disk_io': self.get_disk_io_metrics(),
            'transactions': self.get_transaction_metrics(),
            'wait_stats': self.get_wait_statistics(),
            'database_sizes': self.get_database_sizes()
        }
        
        return metrics
    
    def close(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            print("✅ Connection closed")


def monitor_workload(server, database, username, password, trusted_connection, 
                     interval, duration, output_file):
    """
    Main monitoring loop
    
    Args:
        server: SQL Server hostname
        database: Database name
        username: SQL auth username
        password: SQL auth password
        trusted_connection: Use Windows auth
        interval: Sampling interval in seconds
        duration: Total monitoring duration in seconds
        output_file: Output JSON filename
    """
    print("\n" + "="*70)
    print("🔍 SQL SERVER WORKLOAD MONITOR - EXTENDED EDITION")
    print("="*70)
    print(f"Server: {server}")
    print(f"Database: {database}")
    print(f"Interval: {interval}s")
    print(f"Duration: {duration}s ({duration/3600:.1f} hours)")
    print(f"Output: {output_file}")
    print("="*70 + "\n")
    
    # Initialize monitor
    monitor = SQLServerMonitor(server, database, username, password, trusted_connection)
    
    if not monitor.connect():
        print("❌ Failed to connect to SQL Server")
        sys.exit(1)
    
    # Prepare output
    all_metrics = []
    start_time = time.time()
    sample_count = 0
    
    try:
        while (time.time() - start_time) < duration:
            sample_count += 1
            iteration_start = time.time()
            
            print(f"\n📊 Sample #{sample_count} at {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
            
            # Collect metrics
            metrics = monitor.collect_metrics()
            all_metrics.append(metrics)
            
            # Display summary
            if metrics['cpu']:
                cpu_usage = metrics['cpu'][0].get('cpu_usage_pct', 0)
                print(f"  CPU: {cpu_usage}%")
            
            if metrics['memory']:
                ram_usage = metrics['memory'][0].get('ram_usage_pct', 0)
                buffer_pool = metrics['memory'][0].get('buffer_pool_mb', 0)
                print(f"  RAM: {ram_usage}% | Buffer Pool: {buffer_pool} MB")
            
            if metrics['disk_io']:
                total_iops = sum(db.get('total_iops', 0) for db in metrics['disk_io'])
                print(f"  IOPS: {total_iops}")
            
            if metrics['transactions']:
                tps = metrics['transactions'][0].get('transactions_per_sec', 0)
                print(f"  TPS: {tps}")
            
            # Save intermediate results every 10 samples
            if sample_count % 10 == 0:
                with open(output_file, 'w') as f:
                    json.dump(all_metrics, f, indent=2, default=str)
                print(f"  💾 Saved {sample_count} samples to {output_file}")
            
            # Wait for next interval
            elapsed = time.time() - iteration_start
            sleep_time = max(0, interval - elapsed)
            
            if sleep_time > 0:
                print(f"  ⏱️  Waiting {sleep_time:.1f}s until next sample...")
                time.sleep(sleep_time)
        
        # Final save
        with open(output_file, 'w') as f:
            json.dump(all_metrics, f, indent=2, default=str)
        
        # Generate CSV summary
        csv_file = output_file.replace('.json', '_summary.csv')
        generate_csv_summary(all_metrics, csv_file)
        
        print("\n" + "="*70)
        print("✅ MONITORING COMPLETED")
        print("="*70)
        print(f"Total samples: {sample_count}")
        print(f"Duration: {(time.time() - start_time)/3600:.2f} hours")
        print(f"JSON output: {output_file}")
        print(f"CSV output: {csv_file}")
        print("="*70 + "\n")
        
    except KeyboardInterrupt:
        print("\n\n⚠️  Monitoring interrupted by user")
        print(f"Collected {sample_count} samples before interruption")
        
        # Save partial results
        with open(output_file, 'w') as f:
            json.dump(all_metrics, f, indent=2, default=str)
        print(f"💾 Partial results saved to {output_file}")
        
    finally:
        monitor.close()


def generate_csv_summary(metrics_data, csv_file):
    """Generate CSV summary for Excel analysis"""
    if not metrics_data:
        return
    
    with open(csv_file, 'w', newline='') as f:
        writer = csv.writer(f)
        
        # Header
        writer.writerow([
            'Timestamp', 'CPU %', 'RAM %', 'Buffer Pool MB', 'Page Life Exp (s)',
            'Total IOPS', 'Avg Read Latency (ms)', 'Avg Write Latency (ms)',
            'Transactions/sec', 'Batch Requests/sec', 'Top Wait Type', 'Wait Time (s)'
        ])
        
        # Data rows
        for sample in metrics_data:
            timestamp = sample.get('timestamp', '')
            
            cpu_pct = sample['cpu'][0].get('cpu_usage_pct', 0) if sample.get('cpu') else 0
            
            ram_pct = sample['memory'][0].get('ram_usage_pct', 0) if sample.get('memory') else 0
            buffer_pool = sample['memory'][0].get('buffer_pool_mb', 0) if sample.get('memory') else 0
            ple = sample['memory'][0].get('page_life_expectancy_sec', 0) if sample.get('memory') else 0
            
            total_iops = sum(db.get('total_iops', 0) for db in sample.get('disk_io', []))
            avg_read_lat = sum(db.get('avg_read_latency_ms', 0) for db in sample.get('disk_io', [])) / max(len(sample.get('disk_io', [])), 1)
            avg_write_lat = sum(db.get('avg_write_latency_ms', 0) for db in sample.get('disk_io', [])) / max(len(sample.get('disk_io', [])), 1)
            
            tps = sample['transactions'][0].get('transactions_per_sec', 0) if sample.get('transactions') else 0
            batch_req = sample['transactions'][0].get('batch_requests_per_sec', 0) if sample.get('transactions') else 0
            
            top_wait = sample['wait_stats'][0].get('wait_type', '') if sample.get('wait_stats') else ''
            wait_time = sample['wait_stats'][0].get('wait_time_sec', 0) if sample.get('wait_stats') else 0
            
            writer.writerow([
                timestamp, cpu_pct, ram_pct, buffer_pool, ple,
                total_iops, f"{avg_read_lat:.2f}", f"{avg_write_lat:.2f}",
                tps, batch_req, top_wait, wait_time
            ])
    
    print(f"✅ CSV summary generated: {csv_file}")


def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description='SQL Server Workload Monitor - Capture performance metrics for Azure migration analysis',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Monitor with Windows authentication for 24 hours
  python monitor_sql_workload.py --server SQLPROD01 --database master --interval 120 --duration 86400

  # Monitor with SQL authentication for 1 hour
  python monitor_sql_workload.py --server 192.168.1.10 --database AppDB --username sa --password P@ssw0rd --interval 60 --duration 3600

  # Quick 10-minute test
  python monitor_sql_workload.py --server localhost --database master --interval 30 --duration 600

Output Files:
  - sql_workload_YYYYMMDD_HHMMSS.json - Complete metrics in JSON format
  - sql_workload_YYYYMMDD_HHMMSS_summary.csv - Summary for Excel analysis
        """
    )
    
    # Connection parameters
    parser.add_argument('--server', required=True, help='SQL Server hostname or IP address')
    parser.add_argument('--database', default='master', help='Database name (default: master)')
    parser.add_argument('--username', help='SQL authentication username (optional)')
    parser.add_argument('--password', help='SQL authentication password (optional)')
    parser.add_argument('--trusted', action='store_true', default=True, 
                       help='Use Windows authentication (default: True)')
    
    # Monitoring parameters
    parser.add_argument('--interval', type=int, default=120, 
                       help='Sampling interval in seconds (default: 120)')
    parser.add_argument('--duration', type=int, default=86400,
                       help='Total monitoring duration in seconds (default: 86400 = 24 hours)')
    
    # Output parameters
    parser.add_argument('--output', 
                       default=f"sql_workload_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json",
                       help='Output JSON filename')
    
    args = parser.parse_args()
    
    # Validate parameters
    if args.interval < 10:
        print("⚠️  Warning: Interval < 10 seconds may impact SQL Server performance")
    
    if args.duration < args.interval:
        print("❌ Error: Duration must be greater than interval")
        sys.exit(1)
    
    # Determine authentication mode
    use_trusted = args.trusted if not args.username else False
    
    # Start monitoring
    monitor_workload(
        server=args.server,
        database=args.database,
        username=args.username,
        password=args.password,
        trusted_connection=use_trusted,
        interval=args.interval,
        duration=args.duration,
        output_file=args.output
    )


if __name__ == '__main__':
    main()
