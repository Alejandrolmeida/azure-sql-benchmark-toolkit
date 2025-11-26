#!/usr/bin/env python3
"""
SQL Server Workload Monitor - Installer
========================================

Instalador para la herramienta offline de monitorización SQL Server.
Valida dependencias, conectividad, permisos, y prepara el entorno.

Uso:
    python INSTALL.py
    python INSTALL.py --server MYSERVER\\SQL2022 --username sa --password P@ssw0rd
"""

import sys
import os
import shutil
import argparse
import subprocess
from pathlib import Path


def print_banner():
    """Imprime banner del instalador."""
    print("")
    print("=" * 70)
    print("  SQL SERVER WORKLOAD MONITOR - INSTALLER")
    print("  Azure SQL Benchmark Toolkit - Offline Edition")
    print("=" * 70)
    print("")


def check_python_version() -> bool:
    """Verifica versión de Python."""
    print("[1/8] Checking Python version...")
    
    version = sys.version_info
    
    if version.major < 3 or (version.major == 3 and version.minor < 8):
        print(f"  [FAIL] Python 3.8+ required (found {version.major}.{version.minor})")
        return False
    
    print(f"  [OK] Python {version.major}.{version.minor}.{version.micro}")
    return True


def check_pyodbc() -> bool:
    """Verifica instalación de pyodbc."""
    print("[2/8] Checking pyodbc installation...")
    
    try:
        import pyodbc
        print(f"  [OK] pyodbc {pyodbc.version} installed")
        return True
    except ImportError:
        print("  [FAIL] pyodbc not installed")
        print("  Install with: pip install pyodbc")
        return False


def check_odbc_driver() -> bool:
    """Verifica driver ODBC para SQL Server."""
    print("[3/8] Checking ODBC driver...")
    
    try:
        import pyodbc
        drivers = pyodbc.drivers()
        
        if 'ODBC Driver 17 for SQL Server' in drivers:
            print("  [OK] ODBC Driver 17 for SQL Server found")
            return True
        elif any('SQL Server' in d for d in drivers):
            other = [d for d in drivers if 'SQL Server' in d][0]
            print(f"  [WARN] Using {other} (Driver 17 recommended)")
            return True
        else:
            print("  [FAIL] No SQL Server ODBC driver found")
            print("  Install ODBC Driver 17 for SQL Server:")
            print("    Linux:   https://docs.microsoft.com/sql/connect/odbc/linux-mac/installing-the-microsoft-odbc-driver-for-sql-server")
            print("    Windows: https://docs.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server")
            return False
            
    except Exception as e:
        print(f"  [FAIL] Error checking ODBC driver: {e}")
        return False


def check_scripts() -> bool:
    """Verifica que los scripts necesarios existan."""
    print("[4/8] Checking script files...")
    
    required_files = [
        'monitor_sql_workload.py',
        'workload-sample-query.sql',
        'check_monitoring_status.py',
        'diagnose_monitoring.py',
        'Generate-SQLWorkload.py'
    ]
    
    missing = []
    for filename in required_files:
        if not os.path.exists(filename):
            missing.append(filename)
    
    if missing:
        print(f"  [FAIL] Missing files: {', '.join(missing)}")
        return False
    
    print(f"  [OK] All {len(required_files)} required files found")
    return True


def test_connectivity(server: str, username: str = None, password: str = None) -> bool:
    """Prueba conectividad a SQL Server."""
    print("[5/8] Testing SQL Server connectivity...")
    
    try:
        import pyodbc
        
        trusted = username is None
        
        if trusted:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"Trusted_Connection=yes;"
                f"Connection Timeout=10;"
            )
        else:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"UID={username};"
                f"PWD={password};"
                f"Connection Timeout=10;"
            )
        
        conn = pyodbc.connect(conn_str)
        
        cursor = conn.cursor()
        cursor.execute("SELECT @@SERVERNAME, @@VERSION")
        row = cursor.fetchone()
        
        print(f"  [OK] Connected to: {row[0]}")
        print(f"       Version: {row[1].split(chr(10))[0][:60]}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"  [FAIL] Could not connect: {e}")
        return False


def check_permissions(server: str, username: str = None, password: str = None) -> bool:
    """Verifica permisos VIEW SERVER STATE."""
    print("[6/8] Checking permissions...")
    
    try:
        import pyodbc
        
        trusted = username is None
        
        if trusted:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"Trusted_Connection=yes;"
            )
        else:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"UID={username};"
                f"PWD={password};"
            )
        
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        cursor.execute("""
            SELECT 
                SUSER_SNAME() AS CurrentUser,
                HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasViewServerState,
                IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin
        """)
        row = cursor.fetchone()
        
        print(f"  User: {row.CurrentUser}")
        
        if row.IsSysAdmin == 1:
            print(f"  [OK] User is sysadmin")
            cursor.close()
            conn.close()
            return True
        elif row.HasViewServerState == 1:
            print(f"  [OK] User has VIEW SERVER STATE permission")
            cursor.close()
            conn.close()
            return True
        else:
            print(f"  [FAIL] User lacks VIEW SERVER STATE permission")
            print(f"  Grant with: GRANT VIEW SERVER STATE TO [{row.CurrentUser}]")
            cursor.close()
            conn.close()
            return False
            
    except Exception as e:
        print(f"  [FAIL] Error checking permissions: {e}")
        return False


def test_query(server: str, username: str = None, password: str = None) -> bool:
    """Prueba ejecución de query de monitorización."""
    print("[7/8] Testing monitoring query...")
    
    try:
        import pyodbc
        import time
        
        # Leer query
        with open('workload-sample-query.sql', 'r', encoding='utf-8') as f:
            query = f.read()
        
        trusted = username is None
        
        if trusted:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"Trusted_Connection=yes;"
            )
        else:
            conn_str = (
                f"DRIVER={{ODBC Driver 17 for SQL Server}};"
                f"SERVER={server};"
                f"DATABASE=master;"
                f"UID={username};"
                f"PWD={password};"
            )
        
        conn = pyodbc.connect(conn_str)
        cursor = conn.cursor()
        
        start = time.time()
        cursor.execute(query)
        row = cursor.fetchone()
        duration = time.time() - start
        
        print(f"  [OK] Query executed in {duration:.3f} seconds")
        
        # Mostrar valores de ejemplo
        print(f"       Sample values:")
        print(f"         CPUs: {row.TotalCPUs}")
        print(f"         Memory: {row.TotalMemoryMB:,} MB")
        print(f"         Connections: {row.UserConnections}")
        
        if duration > 2.0:
            print(f"  [WARN] Query took > 2 seconds (consider optimization)")
        
        cursor.close()
        conn.close()
        
        return True
        
    except Exception as e:
        print(f"  [FAIL] Query test failed: {e}")
        return False


def create_directories() -> bool:
    """Crea directorios necesarios."""
    print("[8/8] Creating directories...")
    
    try:
        dirs = [
            'output',
            'checkpoints',
            'logs'
        ]
        
        for dirname in dirs:
            Path(dirname).mkdir(exist_ok=True)
        
        print(f"  [OK] Created {len(dirs)} directories")
        return True
        
    except Exception as e:
        print(f"  [FAIL] Error creating directories: {e}")
        return False


def print_usage():
    """Imprime instrucciones de uso."""
    print("")
    print("=" * 70)
    print("  INSTALLATION COMPLETE")
    print("=" * 70)
    print("")
    print("Quick Start:")
    print("")
    print("  1. Test connectivity:")
    print("     python diagnose_monitoring.py --server .")
    print("")
    print("  2. Run 15-minute test:")
    print("     python monitor_sql_workload.py --server . --duration 15 --interval 60")
    print("")
    print("  3. Monitor status (in another terminal):")
    print("     python check_monitoring_status.py sql_workload_monitor_checkpoint.json")
    print("")
    print("  4. Generate workload (optional, for testing):")
    print("     python Generate-SQLWorkload.py --server . --intensity light --duration 30")
    print("")
    print("Production Usage (24-hour monitoring):")
    print("")
    print("  python monitor_sql_workload.py --server . --duration 1440 --interval 120")
    print("")
    print("SQL Authentication:")
    print("")
    print("  python monitor_sql_workload.py --server MYSERVER\\SQL2022 \\")
    print("         --username sa --password YourPassword --duration 1440")
    print("")
    print("For more information:")
    print("  - See README.md")
    print("  - Run: python diagnose_monitoring.py --help")
    print("  - Run: python monitor_sql_workload.py --help")
    print("")


def main():
    """Función principal."""
    parser = argparse.ArgumentParser(
        description='SQL Server Workload Monitor - Installer'
    )
    
    parser.add_argument('--server', default='.', help='SQL Server to test (default: .)')
    parser.add_argument('--username', help='SQL username (if SQL authentication)')
    parser.add_argument('--password', help='SQL password (if SQL authentication)')
    parser.add_argument('--skip-connectivity', action='store_true', 
                       help='Skip connectivity test')
    
    args = parser.parse_args()
    
    print_banner()
    
    # Ejecutar checks
    checks = [
        ('Python Version', check_python_version, []),
        ('pyodbc Module', check_pyodbc, []),
        ('ODBC Driver', check_odbc_driver, []),
        ('Script Files', check_scripts, []),
    ]
    
    if not args.skip_connectivity:
        checks.extend([
            ('SQL Connectivity', test_connectivity, [args.server, args.username, args.password]),
            ('User Permissions', check_permissions, [args.server, args.username, args.password]),
            ('Query Test', test_query, [args.server, args.username, args.password]),
        ])
    
    checks.append(('Directories', create_directories, []))
    
    # Ejecutar todos los checks
    all_passed = True
    
    for check_name, check_func, check_args in checks:
        result = check_func(*check_args)
        if not result:
            all_passed = False
            if check_name in ['Python Version', 'pyodbc Module', 'ODBC Driver']:
                # Checks críticos - no continuar
                print("")
                print(f"[FAIL] Critical check failed: {check_name}")
                print("Please fix the issue and run the installer again.")
                sys.exit(1)
    
    print("")
    
    if all_passed:
        print("[OK] All checks passed!")
        print_usage()
        sys.exit(0)
    else:
        print("[WARN] Some checks failed, but installation may still work")
        print("Run diagnostics: python diagnose_monitoring.py --server .")
        sys.exit(1)


if __name__ == '__main__':
    main()
