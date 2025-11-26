#!/usr/bin/env python3
"""
SQL Server Workload Monitor - Status Checker
=============================================

Verifica el estado de un proceso de monitorización en ejecución.
Lee archivos checkpoint y muestra estadísticas actuales.

Uso:
    python check_monitoring_status.py checkpoint_20251126_120000.json
    python check_monitoring_status.py --watch checkpoint.json  # Refrescar cada 30s
"""

import json
import sys
import os
import time
import argparse
from datetime import datetime, timedelta


def format_duration(seconds: float) -> str:
    """Formatea duración en formato legible."""
    td = timedelta(seconds=int(seconds))
    days = td.days
    hours, remainder = divmod(td.seconds, 3600)
    minutes, seconds = divmod(remainder, 60)
    
    parts = []
    if days > 0:
        parts.append(f"{days}d")
    if hours > 0:
        parts.append(f"{hours}h")
    if minutes > 0:
        parts.append(f"{minutes}m")
    if seconds > 0 or not parts:
        parts.append(f"{seconds}s")
    
    return " ".join(parts)


def analyze_checkpoint(checkpoint_file: str):
    """
    Analiza archivo checkpoint y muestra estadísticas.
    
    Args:
        checkpoint_file: Path del archivo checkpoint
    """
    if not os.path.exists(checkpoint_file):
        print(f"[FAIL] Checkpoint file not found: {checkpoint_file}")
        return False
    
    try:
        # Cargar checkpoint
        with open(checkpoint_file, 'r', encoding='utf-8') as f:
            checkpoint = json.load(f)
        
        # Parsear timestamps
        start_time = datetime.fromisoformat(checkpoint['start_time'])
        checkpoint_time = datetime.fromisoformat(checkpoint['checkpoint_time'])
        now = datetime.now()
        
        # Calcular tiempos
        elapsed = (checkpoint_time - start_time).total_seconds()
        since_checkpoint = (now - checkpoint_time).total_seconds()
        
        # Estadísticas básicas
        samples = checkpoint.get('samples', [])
        samples_count = len(samples)
        errors_count = checkpoint.get('errors_count', 0)
        
        # Banner
        print("")
        print("=" * 70)
        print("  SQL SERVER WORKLOAD MONITOR - STATUS CHECKER")
        print("=" * 70)
        print("")
        
        # Información general
        print("Checkpoint Information:")
        print(f"  File:            {checkpoint_file}")
        print(f"  File Size:       {os.path.getsize(checkpoint_file):,} bytes")
        print(f"  Modified:        {datetime.fromtimestamp(os.path.getmtime(checkpoint_file)).strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Version:         {checkpoint.get('version', 'Unknown')}")
        print("")
        
        # Información del servidor
        print("Server Information:")
        print(f"  Server:          {checkpoint.get('server', 'Unknown')}")
        print(f"  Database:        {checkpoint.get('database', 'master')}")
        print("")
        
        # Timeline
        print("Timeline:")
        print(f"  Start Time:      {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Last Checkpoint: {checkpoint_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Current Time:    {now.strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Elapsed:         {format_duration(elapsed)}")
        print(f"  Since Checkpoint:{format_duration(since_checkpoint)}")
        print("")
        
        # Estadísticas de muestras
        print("Collection Statistics:")
        print(f"  Samples Collected:{samples_count:,}")
        print(f"  Errors Encountered:{errors_count}")
        print(f"  Success Rate:     {((samples_count / (samples_count + errors_count)) * 100) if (samples_count + errors_count) > 0 else 0:.1f}%")
        print("")
        
        # Análisis de últimas muestras
        if samples:
            print("Recent Samples (last 5):")
            for sample in samples[-5:]:
                ts = datetime.fromisoformat(sample['timestamp']).strftime('%H:%M:%S')
                cpu_pct = (sample['cpu']['sql_server_cpu_time_ms'] / (sample['cpu']['total_cpus'] * 1000)) * 100 if sample['cpu']['total_cpus'] > 0 else 0
                mem_used = sample['memory']['buffer_pool_mb']
                mem_total = sample['memory']['total_mb']
                connections = sample['activity']['user_connections']
                
                print(f"  [{ts}] CPU: {cpu_pct:5.1f}% | Memory: {mem_used:,}/{mem_total:,} MB | Conn: {connections}")
            print("")
            
            # Métricas promedio
            print("Average Metrics (all samples):")
            
            avg_cpu = sum((s['cpu']['sql_server_cpu_time_ms'] / (s['cpu']['total_cpus'] * 1000) * 100) for s in samples) / len(samples)
            avg_mem = sum(s['memory']['buffer_pool_mb'] for s in samples) / len(samples)
            avg_batch = sum(s['activity']['batch_requests_per_sec'] for s in samples) / len(samples)
            avg_conn = sum(s['activity']['user_connections'] for s in samples) / len(samples)
            avg_reads = sum(s['io']['total_reads'] for s in samples) / len(samples)
            avg_writes = sum(s['io']['total_writes'] for s in samples) / len(samples)
            
            print(f"  CPU Usage:          {avg_cpu:.1f}%")
            print(f"  Buffer Pool Memory: {avg_mem:,.0f} MB")
            print(f"  Batch Requests/sec: {avg_batch:.1f}")
            print(f"  User Connections:   {avg_conn:.0f}")
            print(f"  Total Reads:        {avg_reads:,.0f}")
            print(f"  Total Writes:       {avg_writes:,.0f}")
            print("")
            
            # Picos detectados
            print("Peak Values:")
            
            max_cpu_sample = max(samples, key=lambda s: s['cpu']['sql_server_cpu_time_ms'])
            max_cpu = (max_cpu_sample['cpu']['sql_server_cpu_time_ms'] / (max_cpu_sample['cpu']['total_cpus'] * 1000) * 100)
            max_cpu_time = datetime.fromisoformat(max_cpu_sample['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
            
            max_mem_sample = max(samples, key=lambda s: s['memory']['buffer_pool_mb'])
            max_mem = max_mem_sample['memory']['buffer_pool_mb']
            max_mem_time = datetime.fromisoformat(max_mem_sample['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
            
            max_conn_sample = max(samples, key=lambda s: s['activity']['user_connections'])
            max_conn = max_conn_sample['activity']['user_connections']
            max_conn_time = datetime.fromisoformat(max_conn_sample['timestamp']).strftime('%Y-%m-%d %H:%M:%S')
            
            print(f"  Peak CPU:         {max_cpu:.1f}% at {max_cpu_time}")
            print(f"  Peak Memory:      {max_mem:,} MB at {max_mem_time}")
            print(f"  Peak Connections: {max_conn} at {max_conn_time}")
            print("")
        
        # Status
        if since_checkpoint > 300:  # > 5 minutos
            print("[WARNING] Checkpoint is stale (> 5 minutes old)")
            print("          Monitoring process may have stopped or crashed")
        else:
            print("[OK] Monitoring appears to be running normally")
        
        print("")
        print("=" * 70)
        print("")
        
        return True
        
    except json.JSONDecodeError as e:
        print(f"[FAIL] Invalid JSON in checkpoint file: {e}")
        return False
        
    except Exception as e:
        print(f"[FAIL] Error reading checkpoint: {e}")
        return False


def watch_checkpoint(checkpoint_file: str, interval: int = 30):
    """
    Monitorea checkpoint continuamente.
    
    Args:
        checkpoint_file: Path del archivo checkpoint
        interval: Intervalo de refresco en segundos
    """
    try:
        while True:
            # Limpiar pantalla
            os.system('clear' if os.name == 'posix' else 'cls')
            
            # Mostrar status
            analyze_checkpoint(checkpoint_file)
            
            # Esperar
            print(f"Refreshing in {interval} seconds... (Ctrl+C to exit)")
            time.sleep(interval)
            
    except KeyboardInterrupt:
        print("\n\n[OK] Exiting status checker")
        sys.exit(0)


def main():
    """Función principal CLI."""
    parser = argparse.ArgumentParser(
        description='SQL Server Workload Monitor - Status Checker',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Check status once
  python check_monitoring_status.py checkpoint.json
  
  # Watch continuously (refresh every 30s)
  python check_monitoring_status.py --watch checkpoint.json
  
  # Watch with custom interval
  python check_monitoring_status.py --watch --interval 60 checkpoint.json
        """
    )
    
    parser.add_argument('checkpoint_file', help='Checkpoint JSON file')
    parser.add_argument('--watch', action='store_true', help='Watch continuously')
    parser.add_argument('--interval', type=int, default=30, help='Refresh interval in seconds (default: 30)')
    
    args = parser.parse_args()
    
    if args.watch:
        watch_checkpoint(args.checkpoint_file, args.interval)
    else:
        success = analyze_checkpoint(args.checkpoint_file)
        sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
