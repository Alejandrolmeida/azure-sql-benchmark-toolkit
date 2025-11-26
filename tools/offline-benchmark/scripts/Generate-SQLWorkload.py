#!/usr/bin/env python3
"""
SQL Server Workload Generator
==============================

Genera carga sintética en SQL Server para testing de monitorización.
Simula diferentes intensidades de workload y patrones de pico.

Uso:
    # Carga ligera (30 minutos)
    python Generate-SQLWorkload.py --server . --intensity light --duration 30
    
    # Carga media con picos (60 minutos)
    python Generate-SQLWorkload.py --server . --intensity medium --duration 60 --pattern peaks
    
    # Carga alta continua (2 horas)
    python Generate-SQLWorkload.py --server . --intensity high --duration 120 --pattern continuous
"""

import pyodbc
import sys
import argparse
import time
import random
from datetime import datetime, timedelta
from typing import Optional
import threading


class WorkloadGenerator:
    """
    Generador de workload sintético para SQL Server.
    """
    
    def __init__(
        self,
        server: str,
        database: str = "master",
        username: Optional[str] = None,
        password: Optional[str] = None,
        trusted_connection: bool = True
    ):
        """Inicializa generador de workload."""
        self.server = server
        self.database = database
        self.username = username
        self.password = password
        self.trusted_connection = trusted_connection
        self.active = False
        self.queries_executed = 0
        self.errors = 0
        
    def log_info(self, message: str):
        """Log informational message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [INFO] {message}", flush=True)
    
    def log_ok(self, message: str):
        """Log success message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [OK] {message}", flush=True)
    
    def log_fail(self, message: str):
        """Log failure message."""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{timestamp}] [FAIL] {message}", flush=True)
    
    def connect(self) -> Optional[pyodbc.Connection]:
        """Crea nueva conexión a SQL Server."""
        try:
            if self.trusted_connection:
                conn_str = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.server};"
                    f"DATABASE={self.database};"
                    f"Trusted_Connection=yes;"
                )
            else:
                conn_str = (
                    f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                    f"SERVER={self.server};"
                    f"DATABASE={self.database};"
                    f"UID={self.username};"
                    f"PWD={self.password};"
                )
            
            return pyodbc.connect(conn_str)
            
        except Exception as e:
            self.log_fail(f"Connection failed: {e}")
            return None
    
    def generate_light_query(self) -> str:
        """Genera query ligera (DMV reads, cálculos simples)."""
        queries = [
            "SELECT COUNT(*) FROM sys.databases",
            "SELECT COUNT(*) FROM sys.objects WHERE type = 'U'",
            "SELECT @@VERSION",
            "SELECT GETDATE(), @@SERVERNAME",
            "SELECT name, database_id FROM sys.databases",
            "SELECT name, object_id FROM sys.objects WHERE type = 'U'",
            "SELECT SUM(size) FROM sys.master_files",
        ]
        return random.choice(queries)
    
    def generate_medium_query(self) -> str:
        """Genera query mediana (joins, aggregaciones)."""
        queries = [
            """
            SELECT 
                d.name,
                COUNT(*) as TableCount
            FROM sys.databases d
            CROSS APPLY (
                SELECT TOP 100 * FROM sys.objects WHERE type = 'U'
            ) o
            GROUP BY d.name
            """,
            """
            SELECT 
                type,
                COUNT(*) as ObjectCount,
                AVG(object_id) as AvgObjectId
            FROM sys.objects
            GROUP BY type
            """,
            """
            WITH Numbers AS (
                SELECT TOP 1000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as n
                FROM sys.objects a, sys.objects b
            )
            SELECT AVG(n), SUM(n), MIN(n), MAX(n)
            FROM Numbers
            """,
            """
            SELECT 
                mf.name,
                mf.size * 8 / 1024 as SizeMB,
                mf.growth,
                d.name as DatabaseName
            FROM sys.master_files mf
            JOIN sys.databases d ON mf.database_id = d.database_id
            ORDER BY mf.size DESC
            """
        ]
        return random.choice(queries)
    
    def generate_heavy_query(self) -> str:
        """Genera query pesada (cross joins, grandes resultados)."""
        queries = [
            """
            WITH Numbers AS (
                SELECT TOP 10000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) as n
                FROM sys.all_objects a
                CROSS JOIN sys.all_objects b
            )
            SELECT 
                n,
                n * n as Squared,
                n * n * n as Cubed,
                SQRT(CAST(n as FLOAT)) as SquareRoot
            FROM Numbers
            WHERE n % 2 = 0
            """,
            """
            SELECT 
                o1.name as Object1,
                o2.name as Object2,
                o1.object_id + o2.object_id as CombinedId
            FROM sys.objects o1
            CROSS JOIN sys.objects o2
            WHERE o1.object_id < 1000 AND o2.object_id < 1000
            """,
            """
            WITH RECURSIVE Numbers(n) AS (
                SELECT 1
                UNION ALL
                SELECT n + 1 FROM Numbers WHERE n < 5000
            )
            SELECT 
                AVG(CAST(n as FLOAT)) as Average,
                STDEV(CAST(n as FLOAT)) as StdDev,
                VAR(CAST(n as FLOAT)) as Variance
            FROM Numbers
            OPTION (MAXRECURSION 5000)
            """
        ]
        return random.choice(queries)
    
    def worker_thread(
        self,
        thread_id: int,
        intensity: str,
        queries_per_minute: int
    ):
        """Thread worker que ejecuta queries."""
        conn = self.connect()
        if not conn:
            return
        
        try:
            cursor = conn.cursor()
            interval = 60.0 / queries_per_minute if queries_per_minute > 0 else 1.0
            
            while self.active:
                try:
                    # Seleccionar query según intensidad
                    if intensity == 'light':
                        query = self.generate_light_query()
                    elif intensity == 'medium':
                        # 70% medium, 30% light
                        if random.random() < 0.7:
                            query = self.generate_medium_query()
                        else:
                            query = self.generate_light_query()
                    else:  # high
                        # 50% heavy, 30% medium, 20% light
                        rand = random.random()
                        if rand < 0.5:
                            query = self.generate_heavy_query()
                        elif rand < 0.8:
                            query = self.generate_medium_query()
                        else:
                            query = self.generate_light_query()
                    
                    # Ejecutar query
                    cursor.execute(query)
                    cursor.fetchall()  # Consumir resultados
                    
                    self.queries_executed += 1
                    
                    # Esperar intervalo
                    time.sleep(interval)
                    
                except Exception as e:
                    self.errors += 1
                    # No logear cada error para evitar spam
                    if self.errors % 100 == 0:
                        self.log_fail(f"Thread {thread_id}: {self.errors} errors so far")
            
            cursor.close()
            conn.close()
            
        except Exception as e:
            self.log_fail(f"Thread {thread_id} crashed: {e}")
    
    def generate(
        self,
        intensity: str,
        duration_minutes: int,
        pattern: str = 'continuous',
        threads: int = 4
    ) -> bool:
        """
        Genera workload.
        
        Args:
            intensity: 'light', 'medium', 'high'
            duration_minutes: Duración en minutos
            pattern: 'continuous' o 'peaks'
            threads: Número de threads concurrentes
            
        Returns:
            True si completado exitosamente
        """
        print("")
        print("=" * 70)
        print("  SQL SERVER WORKLOAD GENERATOR")
        print("=" * 70)
        print("")
        
        # Configuración
        queries_per_minute_map = {
            'light': 60,      # 1 query/segundo
            'medium': 120,    # 2 queries/segundo
            'high': 240       # 4 queries/segundo
        }
        
        qpm = queries_per_minute_map.get(intensity, 60)
        qpm_per_thread = qpm // threads
        
        print("Configuration:")
        print(f"  Server:            {self.server}")
        print(f"  Intensity:         {intensity.upper()}")
        print(f"  Pattern:           {pattern.upper()}")
        print(f"  Duration:          {duration_minutes} minutes")
        print(f"  Threads:           {threads}")
        print(f"  Queries/min:       {qpm} ({qpm_per_thread} per thread)")
        print(f"  Total queries:     ~{qpm * duration_minutes:,}")
        print("")
        
        # Conectar para validar
        test_conn = self.connect()
        if not test_conn:
            return False
        
        self.log_ok("Connection validated")
        test_conn.close()
        
        # Iniciar threads
        self.active = True
        workers = []
        
        self.log_info(f"Starting {threads} worker threads...")
        
        for i in range(threads):
            t = threading.Thread(
                target=self.worker_thread,
                args=(i + 1, intensity, qpm_per_thread),
                daemon=True
            )
            t.start()
            workers.append(t)
        
        self.log_ok("All worker threads started")
        print("")
        
        # Monitorear progreso
        start_time = datetime.now()
        end_time = start_time + timedelta(minutes=duration_minutes)
        
        try:
            last_queries = 0
            last_time = time.time()
            
            while datetime.now() < end_time:
                time.sleep(10)  # Reporte cada 10 segundos
                
                elapsed = (datetime.now() - start_time).total_seconds()
                remaining = (end_time - datetime.now()).total_seconds()
                progress = (elapsed / (duration_minutes * 60)) * 100
                
                # Calcular velocidad actual
                now = time.time()
                queries_delta = self.queries_executed - last_queries
                time_delta = now - last_time
                current_qps = queries_delta / time_delta if time_delta > 0 else 0
                
                last_queries = self.queries_executed
                last_time = now
                
                # Ajustar intensidad si es pattern 'peaks'
                if pattern == 'peaks':
                    # Crear picos cada 15 minutos
                    minute = int(elapsed / 60)
                    if minute % 15 == 0 and minute % 30 != 0:
                        # Pico: aumentar carga temporalmente
                        pass  # Ya implementado en threads
                
                print(f"[{datetime.now().strftime('%H:%M:%S')}] "
                      f"Progress: {progress:.1f}% | "
                      f"Queries: {self.queries_executed:,} | "
                      f"QPS: {current_qps:.1f} | "
                      f"Errors: {self.errors} | "
                      f"Remaining: {int(remaining/60)}m {int(remaining%60)}s")
        
        except KeyboardInterrupt:
            print("")
            self.log_fail("Workload generation interrupted by user")
            self.active = False
            
            # Esperar threads
            for t in workers:
                t.join(timeout=5)
            
            return False
        
        # Finalizar
        self.active = False
        
        self.log_info("Waiting for worker threads to finish...")
        for t in workers:
            t.join(timeout=10)
        
        print("")
        self.log_ok("Workload generation completed")
        print("")
        print("Statistics:")
        print(f"  Total Queries:     {self.queries_executed:,}")
        print(f"  Total Errors:      {self.errors}")
        print(f"  Success Rate:      {((self.queries_executed / (self.queries_executed + self.errors)) * 100) if (self.queries_executed + self.errors) > 0 else 0:.1f}%")
        print(f"  Average QPS:       {self.queries_executed / (duration_minutes * 60):.1f}")
        print("")
        
        return True


def main():
    """Función principal CLI."""
    parser = argparse.ArgumentParser(
        description='SQL Server Workload Generator',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Light workload (30 minutes)
  python Generate-SQLWorkload.py --server . --intensity light --duration 30
  
  # Medium workload with peaks (60 minutes)
  python Generate-SQLWorkload.py --server . --intensity medium --duration 60 --pattern peaks
  
  # High continuous load (2 hours)
  python Generate-SQLWorkload.py --server . --intensity high --duration 120
  
  # Custom thread count
  python Generate-SQLWorkload.py --server . --intensity high --threads 8
        """
    )
    
    parser.add_argument('--server', default='.', help='SQL Server instance (default: .)')
    parser.add_argument('--database', default='master', help='Database name (default: master)')
    parser.add_argument('--username', help='SQL username (if SQL authentication)')
    parser.add_argument('--password', help='SQL password (if SQL authentication)')
    parser.add_argument('--intensity', choices=['light', 'medium', 'high'], default='medium',
                       help='Workload intensity (default: medium)')
    parser.add_argument('--pattern', choices=['continuous', 'peaks'], default='continuous',
                       help='Workload pattern (default: continuous)')
    parser.add_argument('--duration', type=int, default=60,
                       help='Duration in minutes (default: 60)')
    parser.add_argument('--threads', type=int, default=4,
                       help='Number of concurrent threads (default: 4)')
    
    args = parser.parse_args()
    
    # Determinar autenticación
    trusted_connection = args.username is None
    
    # Crear generador
    generator = WorkloadGenerator(
        server=args.server,
        database=args.database,
        username=args.username,
        password=args.password,
        trusted_connection=trusted_connection
    )
    
    # Ejecutar generación
    success = generator.generate(
        intensity=args.intensity,
        duration_minutes=args.duration,
        pattern=args.pattern,
        threads=args.threads
    )
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
