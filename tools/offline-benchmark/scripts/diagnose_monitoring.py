#!/usr/bin/env python3
"""
SQL Server Workload Monitor - Diagnostic Tool
==============================================

Herramienta de diagnóstico para troubleshooting de monitorización SQL Server.
Verifica conectividad, permisos, drivers ODBC, y query performance.

Uso:
    python diagnose_monitoring.py --server . 
    python diagnose_monitoring.py --server MYSERVER\\SQL2022 --username sa --password P@ssw0rd
"""

import pyodbc
import sys
import os
import argparse
import time
from datetime import datetime


class Colors:
    """ANSI colors para output (solo si terminal lo soporta)."""
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    RESET = '\033[0m'
    BOLD = '\033[1m'


def supports_color():
    """Detecta si terminal soporta colores ANSI."""
    return hasattr(sys.stdout, 'isatty') and sys.stdout.isatty()


def print_header(text: str):
    """Imprime header con formato."""
    if supports_color():
        print(f"\n{Colors.BOLD}{Colors.BLUE}{'=' * 70}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.BLUE}  {text}{Colors.RESET}")
        print(f"{Colors.BOLD}{Colors.BLUE}{'=' * 70}{Colors.RESET}\n")
    else:
        print(f"\n{'=' * 70}")
        print(f"  {text}")
        print(f"{'=' * 70}\n")


def print_ok(message: str):
    """Imprime mensaje OK."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    if supports_color():
        print(f"[{timestamp}] {Colors.GREEN}[OK]{Colors.RESET} {message}")
    else:
        print(f"[{timestamp}] [OK] {message}")


def print_fail(message: str):
    """Imprime mensaje FAIL."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    if supports_color():
        print(f"[{timestamp}] {Colors.RED}[FAIL]{Colors.RESET} {message}")
    else:
        print(f"[{timestamp}] [FAIL] {message}")


def print_warning(message: str):
    """Imprime mensaje WARNING."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    if supports_color():
        print(f"[{timestamp}] {Colors.YELLOW}[WARN]{Colors.RESET} {message}")
    else:
        print(f"[{timestamp}] [WARN] {message}")


def print_info(message: str):
    """Imprime mensaje INFO."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    print(f"[{timestamp}] [INFO] {message}")


def check_odbc_drivers():
    """Verifica drivers ODBC instalados."""
    print_header("1. ODBC DRIVER CHECK")
    
    try:
        drivers = pyodbc.drivers()
        
        if not drivers:
            print_fail("No ODBC drivers found")
            return False
        
        print_info(f"Found {len(drivers)} ODBC driver(s):")
        for driver in drivers:
            print(f"      - {driver}")
        
        # Verificar driver recomendado
        if 'ODBC Driver 17 for SQL Server' in drivers:
            print_ok("ODBC Driver 17 for SQL Server is installed (recommended)")
            return True
        elif any('ODBC Driver' in d and 'SQL Server' in d for d in drivers):
            other_driver = [d for d in drivers if 'ODBC Driver' in d and 'SQL Server' in d][0]
            print_warning(f"Using {other_driver} (Driver 17 recommended)")
            return True
        else:
            print_fail("No SQL Server ODBC driver found")
            print_info("Install with:")
            print_info("  Linux:   sudo apt install unixodbc-dev msodbcsql17")
            print_info("  Windows: Download from Microsoft website")
            return False
            
    except Exception as e:
        print_fail(f"Error checking ODBC drivers: {e}")
        return False


def check_connectivity(server: str, username: str = None, password: str = None):
    """Verifica conectividad a SQL Server."""
    print_header("2. SQL SERVER CONNECTIVITY CHECK")
    
    try:
        # Determinar autenticación
        trusted = username is None
        auth_type = "Windows Authentication" if trusted else "SQL Authentication"
        
        print_info(f"Server:         {server}")
        print_info(f"Authentication: {auth_type}")
        if not trusted:
            print_info(f"Username:       {username}")
        print("")
        
        # Construir connection string
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
        
        # Intentar conexión
        print_info("Attempting connection...")
        start = time.time()
        conn = pyodbc.connect(conn_str)
        duration = time.time() - start
        
        print_ok(f"Connected successfully in {duration:.2f} seconds")
        
        # Información del servidor
        cursor = conn.cursor()
        cursor.execute("""
            SELECT 
                @@VERSION AS Version,
                @@SERVERNAME AS ServerName,
                SERVERPROPERTY('Edition') AS Edition,
                SERVERPROPERTY('ProductLevel') AS ProductLevel,
                SERVERPROPERTY('ProductVersion') AS ProductVersion,
                SERVERPROPERTY('MachineName') AS MachineName,
                GETDATE() AS ServerTime
        """)
        row = cursor.fetchone()
        
        print("")
        print_info("Server Information:")
        print(f"      Server Name:    {row.ServerName}")
        print(f"      Machine Name:   {row.MachineName}")
        print(f"      Edition:        {row.Edition}")
        print(f"      Version:        {row.ProductVersion}")
        print(f"      Level:          {row.ProductLevel}")
        print(f"      Server Time:    {row.ServerTime}")
        print(f"      Full Version:   {row.Version.split(chr(10))[0][:80]}")
        
        cursor.close()
        conn.close()
        
        return True
        
    except pyodbc.Error as e:
        print_fail("Connection failed")
        print_info(f"Error: {e}")
        
        # Mensajes de ayuda según error
        error_msg = str(e).lower()
        print("")
        print_info("Troubleshooting:")
        
        if 'login failed' in error_msg:
            print("      - Verify username and password")
            print("      - Check if SQL Authentication is enabled")
            print("      - Verify user has access to master database")
        elif 'network' in error_msg or 'timeout' in error_msg:
            print("      - Verify SQL Server is running")
            print("      - Check firewall allows TCP/1433")
            print("      - Verify SQL Server Browser service (for named instances)")
            print("      - Test with: telnet server 1433")
        elif 'driver' in error_msg:
            print("      - Install ODBC Driver 17 for SQL Server")
            print("      - Verify driver name in connection string")
        
        return False
        
    except Exception as e:
        print_fail(f"Unexpected error: {e}")
        return False


def check_permissions(server: str, username: str = None, password: str = None):
    """Verifica permisos necesarios."""
    print_header("3. PERMISSIONS CHECK")
    
    try:
        # Conectar
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
        
        # Verificar usuario actual
        cursor.execute("SELECT SUSER_SNAME() AS CurrentUser, SYSTEM_USER AS SystemUser")
        row = cursor.fetchone()
        
        print_info(f"Current User:   {row.CurrentUser}")
        print_info(f"System User:    {row.SystemUser}")
        print("")
        
        # Verificar permisos
        cursor.execute("""
            SELECT 
                HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasViewServerState,
                IS_SRVROLEMEMBER('sysadmin') AS IsSysAdmin
        """)
        row = cursor.fetchone()
        
        has_permission = False
        
        if row.IsSysAdmin == 1:
            print_ok("User is member of sysadmin role")
            has_permission = True
        else:
            print_info("User is NOT sysadmin")
        
        if row.HasViewServerState == 1:
            print_ok("User has VIEW SERVER STATE permission")
            has_permission = True
        else:
            print_fail("User lacks VIEW SERVER STATE permission")
            print_info("Grant with:")
            cursor.execute("SELECT SUSER_SNAME() AS CurrentUser")
            user = cursor.fetchone().CurrentUser
            print(f"      GRANT VIEW SERVER STATE TO [{user}]")
        
        print("")
        
        cursor.close()
        conn.close()
        
        return has_permission
        
    except Exception as e:
        print_fail(f"Error checking permissions: {e}")
        return False


def check_query_file(query_file: str):
    """Verifica archivo query SQL."""
    print_header("4. QUERY FILE CHECK")
    
    try:
        if not os.path.exists(query_file):
            print_fail(f"Query file not found: {query_file}")
            print_info("Expected location: workload-sample-query.sql")
            return False
        
        print_ok(f"Query file found: {query_file}")
        
        # Leer query
        with open(query_file, 'r', encoding='utf-8') as f:
            query = f.read()
        
        file_size = len(query)
        line_count = query.count('\n') + 1
        
        print_info(f"File size:      {file_size:,} bytes")
        print_info(f"Line count:     {line_count}")
        print("")
        
        # Verificar contenido básico
        if 'sys.dm_os_sys_info' not in query:
            print_warning("Query may not contain expected DMV queries")
        
        return True
        
    except Exception as e:
        print_fail(f"Error reading query file: {e}")
        return False


def test_query_execution(
    server: str,
    query_file: str,
    username: str = None,
    password: str = None
):
    """Prueba ejecución de query."""
    print_header("5. QUERY EXECUTION TEST")
    
    try:
        # Leer query
        with open(query_file, 'r', encoding='utf-8') as f:
            query = f.read()
        
        # Conectar
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
        cursor.settimeout(30)
        
        # Ejecutar query
        print_info("Executing query...")
        start = time.time()
        cursor.execute(query)
        row = cursor.fetchone()
        duration = time.time() - start
        
        print_ok(f"Query executed successfully in {duration:.3f} seconds")
        print("")
        
        # Validar columnas
        expected_columns = [
            'SampleTime', 'TotalCPUs', 'SQLServerCPUTimeMs', 
            'TotalMemoryMB', 'CommittedMemoryMB', 'TargetMemoryMB', 'BufferPoolMB',
            'BatchRequestsPerSec', 'CompilationsPerSec', 'UserConnections',
            'TotalReads', 'TotalWrites', 'TotalReadLatencyMs', 'TotalWriteLatencyMs',
            'TotalBytesRead', 'TotalBytesWritten', 'TopWaitType', 'TopWaitTimeMs'
        ]
        
        missing_columns = []
        for col in expected_columns:
            if not hasattr(row, col):
                missing_columns.append(col)
        
        if missing_columns:
            print_fail(f"Query result missing expected columns: {', '.join(missing_columns)}")
            cursor.close()
            conn.close()
            return False
        
        print_ok("All expected columns found")
        print("")
        
        # Mostrar valores de ejemplo
        print_info("Sample Values:")
        print(f"      Sample Time:        {row.SampleTime}")
        print(f"      Total CPUs:         {row.TotalCPUs}")
        print(f"      SQL CPU Time:       {row.SQLServerCPUTimeMs} ms")
        print(f"      Total Memory:       {row.TotalMemoryMB:,} MB")
        print(f"      Committed Memory:   {row.CommittedMemoryMB:,} MB")
        print(f"      Target Memory:      {row.TargetMemoryMB:,} MB")
        print(f"      Buffer Pool:        {row.BufferPoolMB:,} MB")
        print(f"      Batch Req/sec:      {row.BatchRequestsPerSec:.1f}")
        print(f"      User Connections:   {row.UserConnections}")
        print(f"      Total Reads:        {row.TotalReads:,}")
        print(f"      Total Writes:       {row.TotalWrites:,}")
        print(f"      Top Wait Type:      {row.TopWaitType}")
        print("")
        
        # Validar performance
        if duration > 2.0:
            print_warning(f"Query took > 2 seconds ({duration:.3f}s)")
            print_info("Consider optimizing query for faster execution")
        else:
            print_ok("Query performance is good (< 2 seconds)")
        
        cursor.close()
        conn.close()
        
        return True
        
    except pyodbc.OperationalError as e:
        if 'timeout' in str(e).lower():
            print_fail("Query timeout (> 30 seconds)")
            print_info("Query is too slow for monitoring")
        else:
            print_fail(f"Query execution failed: {e}")
        return False
        
    except Exception as e:
        print_fail(f"Error testing query: {e}")
        return False


def print_summary(checks: dict):
    """Imprime resumen de diagnóstico."""
    print_header("DIAGNOSTIC SUMMARY")
    
    total = len(checks)
    passed = sum(1 for v in checks.values() if v)
    failed = total - passed
    
    print(f"Total Checks:   {total}")
    print(f"Passed:         {passed}")
    print(f"Failed:         {failed}")
    print("")
    
    for check_name, result in checks.items():
        if result:
            print_ok(check_name)
        else:
            print_fail(check_name)
    
    print("")
    
    if all(checks.values()):
        print_ok("All checks passed - system ready for monitoring")
        return True
    else:
        print_fail("Some checks failed - review errors above")
        return False


def main():
    """Función principal CLI."""
    parser = argparse.ArgumentParser(
        description='SQL Server Workload Monitor - Diagnostic Tool',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Diagnose with Windows Authentication
  python diagnose_monitoring.py --server .
  
  # Diagnose with SQL Authentication
  python diagnose_monitoring.py --server MYSERVER\\SQL2022 --username sa --password P@ssw0rd
  
  # Specify custom query file
  python diagnose_monitoring.py --server . --query-file custom-query.sql
        """
    )
    
    parser.add_argument('--server', default='.', help='SQL Server instance (default: .)')
    parser.add_argument('--username', help='SQL username (if SQL authentication)')
    parser.add_argument('--password', help='SQL password (if SQL authentication)')
    parser.add_argument('--query-file', default='workload-sample-query.sql', help='SQL query file')
    
    args = parser.parse_args()
    
    # Banner
    print("")
    print("=" * 70)
    print("  SQL SERVER WORKLOAD MONITOR - DIAGNOSTIC TOOL")
    print("=" * 70)
    
    # Ejecutar checks
    checks = {}
    
    checks['ODBC Drivers'] = check_odbc_drivers()
    checks['SQL Server Connectivity'] = check_connectivity(args.server, args.username, args.password)
    
    if checks['SQL Server Connectivity']:
        checks['User Permissions'] = check_permissions(args.server, args.username, args.password)
        checks['Query File'] = check_query_file(args.query_file)
        
        if checks['Query File']:
            checks['Query Execution'] = test_query_execution(
                args.server,
                args.query_file,
                args.username,
                args.password
            )
    
    # Resumen
    success = print_summary(checks)
    
    sys.exit(0 if success else 1)


if __name__ == '__main__':
    main()
