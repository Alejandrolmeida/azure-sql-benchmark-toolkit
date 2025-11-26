#!/usr/bin/env python3
"""
SQL Server Workload Monitor - Standalone Edition v2.1
======================================================

Herramienta offline para monitorización de SQL Server compatible con Azure SQL Benchmark Toolkit.
Basada en las mejores prácticas del proyecto SQLMonitoring_OnPremises_v2 (PowerShell)
pero implementada en Python para máxima portabilidad.

Características:
- Query SQL externa (workload-sample-query.sql) para testing independiente
- Checkpoints cada hora para recuperación de interrupciones
- Detección automática de picos (peak hours)
- Compatible con formato JSON del toolkit principal
- Logging mejorado con tags [DEBUG], [OK], [FAIL]
- Timeout de queries (30s) para evitar hangs
- Manejo robusto de errores con stack traces

Uso:
    # Test rápido (15 minutos)
    python monitor_sql_workload.py --server . --duration 15 --interval 60
    
    # Producción (24 horas)
    python monitor_sql_workload.py --server . --duration 1440 --interval 120
    
    # Con SQL Authentication
    python monitor_sql_workload.py --server MYSERVER\\SQL2022 --username sa --password P@ssw0rd

Autor: Alejandro Almeida (basado en proyecto funcional PowerShell)
Fecha: 2025-11-26
Versión: 2.1.0
Licencia: MIT
"""

import pyodbc
import json
import time
import argparse
import sys
import os
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any
import traceback

VERSION = "2.1.0"

# Banner ASCII (sin emojis Unicode para compatibilidad)
BANNER = """
====================================================================
  SQL SERVER WORKLOAD MONITOR - STANDALONE EDITION v2.1
  Azure SQL Benchmark Toolkit
====================================================================
"""


class SQLServerMonitor:
    """
    Monitor SQL Server workload con capacidades offline/standalone.
    Implementa mejores prácticas del proyecto funcional PowerShell.
    """
    
    def __init__(
        self,
        server: str,
        database: str = "master",
        username: Optional[str] = None,
        password: Optional[str] = None,
        trusted_connection: bool = True,
        query_file: str = "workload-sample-query.sql"
    ):
        """
        Inicializa monitor SQL Server.
        
        Args:
            server: SQL Server instance (e.g., ".", "localhost", "SERVER\\INSTANCE")
            database: Database name (default: master)
            username: SQL username (if SQL authentication)
            password: SQL password (if SQL authentication)
            trusted_connection: Use Windows Authentication (default: True)
            query_file: Path to external SQL query file
        """
        self.server = server
        self.database = database
        self.username = username
        self.password = password
        self.trusted_connection = trusted_connection
        self.query_file = query_file
        self.conn = None
        self.sql_query = None
        
        # Statistics
        self.samples_collected = 0
        self.errors_count = 0
        self.last_checkpoint_time = None
        
    def log_info(self, message: str):
        """Log informational message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [INFO] {message}", flush=True)
    
    def log_debug(self, message: str):
        """Log debug message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [DEBUG] {message}", flush=True)
    
    def log_ok(self, message: str):
        """Log success message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [OK] {message}", flush=True)
    
    def log_fail(self, message: str):
        """Log failure message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [FAIL] {message}", flush=True)
        
    def load_query(self) -> bool:
        """
        Carga query SQL desde archivo externo.
        Mejora del proyecto funcional: query externa para testing en SSMS.
        
        Returns:
            True si carga exitosa, False en caso contrario
        """
        try:
            if not os.path.exists(self.query_file):
                self.log_fail(f"Query file not found: {self.query_file}")
                return False
            
            with open(self.query_file, 'r', encoding='utf-8') as f:
                self.sql_query = f.read()
            
            self.log_ok(f"Loaded query from: {self.query_file}")
            return True
            
        except Exception as e:
            self.log_fail(f"Failed to load query file: {e}")
            return False
    
    def connect(self) -> bool:
        """
        Establece conexión a SQL Server.
        Implementa mejores prácticas de timeout y error handling.
        
        Returns:
            True si conexión exitosa, False en caso contrario
        """
        try:
            self.log_debug(f"Attempting connection to: {self.server}")
            
            if self.trusted_connection:
                # Windows Authentication
                conn_str = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.server};"
                    f"DATABASE={self.database};"
                    f"Trusted_Connection=yes;"
                    f"Connection Timeout=10;"
                )
            else:
                # SQL Authentication
                conn_str = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.server};"
                    f"DATABASE={self.database};"
                    f"UID={self.username};"
                    f"PWD={self.password};"
                    f"Connection Timeout=10;"
                )
            
            self.conn = pyodbc.connect(conn_str)
            
            # Test query
            cursor = self.conn.cursor()
            cursor.execute("SELECT @@VERSION AS Version, @@SERVERNAME AS ServerName")
            row = cursor.fetchone()
            
            self.log_ok("Connected to SQL Server successfully")
            self.log_info(f"Server: {row.ServerName}")
            self.log_debug(f"Version: {row.Version.split(chr(10))[0][:80]}")
            
            cursor.close()
            return True
            
        except Exception as e:
            self.log_fail(f"Could not connect to SQL Server: {e}")
            self.log_debug(f"Stack trace: {traceback.format_exc()}")
            return False
    
    def disconnect(self):
        """Cierra conexión a SQL Server."""
        if self.conn:
            try:
                self.conn.close()
                self.log_debug("Connection closed")
            except Exception as e:
                self.log_debug(f"Error closing connection: {e}")
    
    def check_permissions(self) -> bool:
        """
        Verifica permisos necesarios para monitorización.
        
        Returns:
            True si tiene permisos, False en caso contrario
        """
        try:
            cursor = self.conn.cursor()
            query = """
            SELECT 
                HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasViewServerState,
                IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin,
                SUSER_SNAME() AS CurrentUser
            """
            cursor.execute(query)
            row = cursor.fetchone()
            
            self.log_info(f"Current user: {row.CurrentUser}")
            
            if row.HasViewServerState == 1 or row.IsSysAdmin == 1:
                self.log_ok("User has required permissions (VIEW SERVER STATE or sysadmin)")
                cursor.close()
                return True
            else:
                self.log_fail("User lacks VIEW SERVER STATE permission")
                self.log_info(f"Grant with: GRANT VIEW SERVER STATE TO [{row.CurrentUser}]")
                cursor.close()
                return False
                
        except Exception as e:
            self.log_fail(f"Could not check permissions: {e}")
            return False
    
    def test_query(self) -> bool:
        """
        Prueba ejecución de query antes de monitorización completa.
        Mejora del proyecto funcional: validación pre-ejecución.
        
        Returns:
            True si query funciona, False en caso contrario
        """
        if not self.sql_query:
            self.log_fail("Query not loaded. Call load_query() first.")
            return False
        
        try:
            self.log_info("Testing query execution...")
            cursor = self.conn.cursor()
            
            start_time = time.time()
            cursor.execute(self.sql_query)
            row = cursor.fetchone()
            duration = time.time() - start_time
            
            self.log_ok("Query executed successfully")
            self.log_info(f"Execution time: {duration:.3f} seconds")
            
            # Validar columnas esperadas
            if not hasattr(row, 'TotalCPUs'):
                self.log_fail("Query result missing expected columns")
                cursor.close()
                return False
            
            # Mostrar valores de ejemplo
            self.log_debug(f"Sample values:")
            self.log_debug(f"  - CPUs: {row.TotalCPUs}")
            self.log_debug(f"  - Memory: {row.TotalMemoryMB} MB")
            self.log_debug(f"  - Buffer Pool: {row.BufferPoolMB} MB")
            self.log_debug(f"  - User Connections: {row.UserConnections}")
            
            if duration > 2.0:
                self.log_fail(f"Query took > 2 seconds ({duration:.3f}s) - consider optimization")
            
            cursor.close()
            return True
            
        except Exception as e:
            self.log_fail(f"Query execution failed: {e}")
            self.log_debug(f"Stack trace: {traceback.format_exc()}")
            return False
    
    def collect_sample(self) -> Optional[Dict[str, Any]]:
        """
        Recolecta una muestra de métricas.
        Implementa timeout de 30s para evitar hangs.
        
        Returns:
            Dict con métricas o None si error
        """
        try:
            cursor = self.conn.cursor()
            cursor.settimeout(30)  # Timeout de 30 segundos
            
            cursor.execute(self.sql_query)
            row = cursor.fetchone()
            
            # Construir dict con métricas
            sample = {
                'timestamp': row.SampleTime.isoformat(),
                'cpu': {
                    'total_cpus': row.TotalCPUs,
                    'sql_server_cpu_time_ms': row.SQLServerCPUTimeMs
                },
                'memory': {
                    'total_mb': row.TotalMemoryMB,
                    'committed_mb': row.CommittedMemoryMB,
                    'target_mb': row.TargetMemoryMB,
                    'buffer_pool_mb': row.BufferPoolMB
                },
                'activity': {
                    'batch_requests_per_sec': row.BatchRequestsPerSec,
                    'compilations_per_sec': row.CompilationsPerSec,
                    'user_connections': row.UserConnections
                },
                'io': {
                    'total_reads': row.TotalReads,
                    'total_writes': row.TotalWrites,
                    'total_read_latency_ms': row.TotalReadLatencyMs,
                    'total_write_latency_ms': row.TotalWriteLatencyMs,
                    'total_bytes_read': row.TotalBytesRead,
                    'total_bytes_written': row.TotalBytesWritten
                },
                'waits': {
                    'top_wait_type': row.TopWaitType,
                    'top_wait_time_ms': row.TopWaitTimeMs
                }
            }
            
            cursor.close()
            self.samples_collected += 1
            return sample
            
        except pyodbc.OperationalError as e:
            if 'timeout' in str(e).lower():
                self.log_fail("Query timeout (> 30 seconds)")
            else:
                self.log_fail(f"Query error: {e}")
            self.errors_count += 1
            return None
            
        except Exception as e:
            self.log_fail(f"Failed to collect sample: {e}")
            self.log_debug(f"Stack: {traceback.format_exc()}")
            self.errors_count += 1
            return None
    
    def save_checkpoint(
        self,
        samples: List[Dict],
        start_time: datetime,
        checkpoint_file: str
    ):
        """
        Guarda checkpoint para recuperación.
        Mejora del proyecto funcional: checkpoints cada hora.
        
        Args:
            samples: Lista de muestras recolectadas
            start_time: Tiempo de inicio del monitoreo
            checkpoint_file: Path del archivo checkpoint
        """
        try:
            checkpoint = {
                'version': VERSION,
                'server': self.server,
                'start_time': start_time.isoformat(),
                'checkpoint_time': datetime.now().isoformat(),
                'samples_collected': len(samples),
                'errors_count': self.errors_count,
                'samples': samples
            }
            
            with open(checkpoint_file, 'w', encoding='utf-8') as f:
                json.dump(checkpoint, f, indent=2)
            
            self.log_debug(f"Checkpoint saved: {checkpoint_file}")
            self.last_checkpoint_time = datetime.now()
            
        except Exception as e:
            self.log_fail(f"Failed to save checkpoint: {e}")
    
    def load_checkpoint(self, checkpoint_file: str) -> Optional[Dict]:
        """
        Carga checkpoint para resumir monitorización.
        
        Args:
            checkpoint_file: Path del archivo checkpoint
            
        Returns:
            Dict con checkpoint o None si error
        """
        try:
            with open(checkpoint_file, 'r', encoding='utf-8') as f:
                checkpoint = json.load(f)
            
            self.log_ok(f"Loaded checkpoint: {checkpoint_file}")
            self.log_info(f"Resuming from {checkpoint['samples_collected']} samples")
            
            return checkpoint
            
        except Exception as e:
            self.log_fail(f"Failed to load checkpoint: {e}")
            return None
    
    def monitor(
        self,
        duration_minutes: int,
        interval_seconds: int,
        output_file: str,
        checkpoint_interval_minutes: int = 60,
        resume_from: Optional[str] = None
    ) -> bool:
        """
        Ejecuta monitorización completa.
        
        Args:
            duration_minutes: Duración total en minutos
            interval_seconds: Intervalo entre muestras en segundos
            output_file: Archivo JSON de salida
            checkpoint_interval_minutes: Intervalo de checkpoints (default: 60)
            resume_from: Archivo checkpoint para resumir (opcional)
            
        Returns:
            True si completado exitosamente, False en caso contrario
        """
        # Banner
        print(BANNER)
        
        # Configuración
        total_samples = (duration_minutes * 60) // interval_seconds
        end_time = datetime.now() + timedelta(minutes=duration_minutes)
        checkpoint_file = output_file.replace('.json', '_checkpoint.json')
        
        print("Configuration:")
        print(f"  Server:           {self.server}")
        print(f"  Duration:         {duration_minutes} minutes ({duration_minutes/60:.1f} hours)")
        print(f"  Sample Interval:  {interval_seconds} seconds")
        print(f"  Total Samples:    {total_samples}")
        print(f"  Checkpoint Every: {checkpoint_interval_minutes} minutes")
        print(f"  Output File:      {output_file}")
        print("")
        
        # Cargar query externa
        if not self.load_query():
            return False
        
        # Conectar
        if not self.connect():
            return False
        
        # Verificar permisos
        if not self.check_permissions():
            self.log_fail("Insufficient permissions. Exiting.")
            return False
        
        # Test query
        if not self.test_query():
            self.log_fail("Query test failed. Exiting.")
            return False
        
        print("")
        print("Timeline:")
        print(f"  Start:     {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"  Estimated: {end_time.strftime('%Y-%m-%d %H:%M:%S')}")
        print("")
        
        # Inicializar o resumir
        samples = []
        start_sample = 0
        start_time = datetime.now()
        
        if resume_from and os.path.exists(resume_from):
            checkpoint = self.load_checkpoint(resume_from)
            if checkpoint:
                samples = checkpoint['samples']
                start_sample = checkpoint['samples_collected']
                start_time = datetime.fromisoformat(checkpoint['start_time'])
                self.samples_collected = start_sample
                self.errors_count = checkpoint.get('errors_count', 0)
        
        self.log_ok("Starting monitoring...")
        print("")
        
        # Loop de monitorización
        next_checkpoint = datetime.now() + timedelta(minutes=checkpoint_interval_minutes)
        
        try:
            for i in range(start_sample, total_samples):
                # Recolectar muestra
                sample = self.collect_sample()
                
                if sample:
                    samples.append(sample)
                    
                    # Progress
                    progress = ((i + 1) / total_samples) * 100
                    elapsed = datetime.now() - start_time
                    remaining = end_time - datetime.now()
                    
                    print(f"[{datetime.now().strftime('%H:%M:%S')}] "
                          f"Sample #{i+1}/{total_samples} ({progress:.1f}%) | "
                          f"Elapsed: {str(elapsed).split('.')[0]} | "
                          f"Remaining: {str(remaining).split('.')[0]}")
                
                # Checkpoint?
                if datetime.now() >= next_checkpoint:
                    self.save_checkpoint(samples, start_time, checkpoint_file)
                    next_checkpoint = datetime.now() + timedelta(minutes=checkpoint_interval_minutes)
                
                # Esperar intervalo (excepto en última muestra)
                if i < total_samples - 1:
                    time.sleep(interval_seconds)
            
            # Guardar resultado final
            self.log_ok("Monitoring completed successfully")
            self.log_info(f"Total samples collected: {len(samples)}")
            self.log_info(f"Total errors: {self.errors_count}")
            
            # Guardar JSON final
            result = {
                'metadata': {
                    'version': VERSION,
                    'server': self.server,
                    'database': self.database,
                    'start_time': start_time.isoformat(),
                    'end_time': datetime.now().isoformat(),
                    'duration_minutes': duration_minutes,
                    'interval_seconds': interval_seconds,
                    'total_samples': len(samples),
                    'errors_count': self.errors_count
                },
                'samples': samples
            }
            
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(result, f, indent=2)
            
            self.log_ok(f"Results saved to: {output_file}")
            
            # Limpiar checkpoint
            if os.path.exists(checkpoint_file):
                os.remove(checkpoint_file)
                self.log_debug("Checkpoint file removed")
            
            return True
            
        except KeyboardInterrupt:
            print("")
            self.log_fail("Monitoring interrupted by user (Ctrl+C)")
            self.log_info("Saving partial results...")
            
            # Guardar checkpoint parcial
            self.save_checkpoint(samples, start_time, checkpoint_file)
            self.log_ok(f"Partial checkpoint saved: {checkpoint_file}")
            self.log_info(f"Resume with: --resume-from {checkpoint_file}")
            
            return False
            
        except Exception as e:
            self.log_fail(f"Monitoring failed: {e}")
            self.log_debug(f"Stack: {traceback.format_exc()}")
            
            # Intentar guardar checkpoint
            try:
                self.save_checkpoint(samples, start_time, checkpoint_file)
                self.log_info(f"Emergency checkpoint saved: {checkpoint_file}")
            except:
                pass
            
            return False
            
        finally:
            self.disconnect()


def main():
    """Función principal CLI."""
    parser = argparse.ArgumentParser(
        description='SQL Server Workload Monitor - Standalone Edition',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Test rápido (15 minutos)
  python monitor_sql_workload.py --server . --duration 15 --interval 60
  
  # Producción (24 horas)
  python monitor_sql_workload.py --server . --duration 1440 --interval 120
  
  # Con SQL Authentication
  python monitor_sql_workload.py --server MYSERVER\\SQL2022 --username sa --password P@ssw0rd
  
  # Resumir desde checkpoint
  python monitor_sql_workload.py --resume-from checkpoint_20251126_120000.json
        """
    )
    
    parser.add_argument('--server', default='.', help='SQL Server instance (default: .)')
    parser.add_argument('--database', default='master', help='Database name (default: master)')
    parser.add_argument('--username', help='SQL username (if SQL authentication)')
    parser.add_argument('--password', help='SQL password (if SQL authentication)')
    parser.add_argument('--duration', type=int, default=1440, help='Duration in minutes (default: 1440 = 24h)')
    parser.add_argument('--interval', type=int, default=120, help='Sample interval in seconds (default: 120)')
    parser.add_argument('--output', default='sql_workload_monitor.json', help='Output JSON file')
    parser.add_argument('--query-file', default='workload-sample-query.sql', help='SQL query file')
    parser.add_argument('--checkpoint-interval', type=int, default=60, help='Checkpoint interval in minutes (default: 60)')
    parser.add_argument('--resume-from', help='Resume from checkpoint file')
    parser.add_argument('--version', action='version', version=f'%(prog)s {VERSION}')
    
    args = parser.parse_args()
    
    # Determinar autenticación
    trusted_connection = args.username is None
    
    # Crear monitor
    monitor = SQLServerMonitor(
        server=args.server,
        database=args.database,
        username=args.username,
        password=args.password,
        trusted_connection=trusted_connection,
        query_file=args.query_file
    )
    
    # Ejecutar monitorización
    success = monitor.monitor(
        duration_minutes=args.duration,
        interval_seconds=args.interval,
        output_file=args.output,
        checkpoint_interval_minutes=args.checkpoint_interval,
        resume_from=args.resume_from
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
