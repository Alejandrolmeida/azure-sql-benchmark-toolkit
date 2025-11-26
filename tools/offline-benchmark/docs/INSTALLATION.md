# Installation Guide - Offline Benchmark Tool

Guía detallada de instalación del **SQL Server Workload Monitor - Offline Edition** en diferentes plataformas.

---

## 📋 Tabla de Contenidos

- [Requisitos Previos](#requisitos-previos)
- [Instalación en Linux](#instalación-en-linux)
- [Instalación en Windows](#instalación-en-windows)
- [Instalación en macOS](#instalación-en-macos)
- [Validación Post-Instalación](#validación-post-instalación)
- [Configuración SQL Server](#configuración-sql-server)
- [Troubleshooting de Instalación](#troubleshooting-de-instalación)

---

## ✅ Requisitos Previos

### Software

| Componente | Versión Mínima | Recomendada | Notas |
|------------|---------------|-------------|-------|
| Python | 3.8 | 3.11+ | Python 3.12 probado y funcional |
| pyodbc | 4.0.0 | 5.0+ | Driver Python para ODBC |
| ODBC Driver | 13 | 17 | Driver nativo SQL Server |
| SQL Server | 2016 | 2019+ | Query compatible con 2012+ |

### Permisos SQL Server

- **VIEW SERVER STATE** (mínimo requerido)
- O **sysadmin** role (recomendado para testing)

### Red

- Puerto TCP 1433 abierto en firewall (default SQL Server)
- Conectividad desde servidor monitorizado (puede ser localhost)

---

## 🐧 Instalación en Linux

### Ubuntu/Debian (20.04 LTS, 22.04 LTS, 24.04 LTS)

#### 1. Actualizar sistema

```bash
sudo apt update
sudo apt upgrade -y
```

#### 2. Instalar Python 3.8+

```bash
# Ubuntu 20.04/22.04 ya incluye Python 3.8+
python3 --version

# Si necesitas instalar/actualizar:
sudo apt install python3 python3-pip python3-venv -y
```

#### 3. Instalar dependencias del sistema

```bash
# Herramientas de desarrollo
sudo apt install build-essential unixodbc-dev -y

# Curl para descargar ODBC driver
sudo apt install curl apt-transport-https -y
```

#### 4. Instalar Microsoft ODBC Driver 17

```bash
# Agregar repositorio Microsoft
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

# Ubuntu 22.04 LTS
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Ubuntu 20.04 LTS
# curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Actualizar e instalar
sudo apt update
sudo ACCEPT_EULA=Y apt install msodbcsql17 -y

# Verificar instalación
odbcinst -q -d -n "ODBC Driver 17 for SQL Server"
```

#### 5. Instalar pyodbc

```bash
# Instalación global
sudo pip3 install pyodbc

# O instalación para usuario (recomendado)
pip3 install --user pyodbc

# Verificar
python3 -c "import pyodbc; print(pyodbc.version)"
```

#### 6. Descargar/clonar toolkit

```bash
# Si es repositorio Git
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit/tools/offline-benchmark

# Si es ZIP descargado
unzip azure-sql-benchmark-toolkit.zip
cd azure-sql-benchmark-toolkit/tools/offline-benchmark
```

#### 7. Ejecutar instalador

```bash
# Instalación con Windows Authentication
python3 INSTALL.py

# O con SQL Authentication
python3 INSTALL.py --server localhost --username sa --password YourPassword
```

### Red Hat Enterprise Linux / CentOS 8/9

```bash
# 1. Instalar Python 3.8+
sudo dnf install python3 python3-pip -y

# 2. Instalar dependencias
sudo dnf install unixODBC-devel gcc gcc-c++ -y

# 3. Instalar ODBC Driver 17
sudo curl https://packages.microsoft.com/config/rhel/8/prod.repo | sudo tee /etc/yum.repos.d/mssql-release.repo
sudo dnf remove unixODBC-utf16 unixODBC-utf16-devel
sudo ACCEPT_EULA=Y dnf install msodbcsql17 -y

# 4. Instalar pyodbc
pip3 install pyodbc

# 5. Ejecutar instalador
python3 INSTALL.py
```

---

## 🪟 Instalación en Windows

### Windows 10/11 / Windows Server 2016+

#### 1. Instalar Python 3.8+

**Opción A: Desde python.org (recomendado)**

1. Descargar desde: https://www.python.org/downloads/
2. Ejecutar instalador
3. ✅ **Importante**: Marcar "Add Python to PATH"
4. Click "Install Now"
5. Verificar en PowerShell:

```powershell
python --version
pip --version
```

**Opción B: Microsoft Store**

1. Abrir Microsoft Store
2. Buscar "Python 3.11"
3. Click "Get" / "Instalar"

**Opción C: winget**

```powershell
winget install Python.Python.3.11
```

#### 2. Instalar Microsoft ODBC Driver 17

**Método automático (PowerShell como Administrador):**

```powershell
# Descargar instalador
$url = "https://go.microsoft.com/fwlink/?linkid=2249004"
$output = "$env:TEMP\msodbcsql.msi"
Invoke-WebRequest -Uri $url -OutFile $output

# Instalar silenciosamente
msiexec /i $output /qn IACCEPTMSODBCSQLLICENSETERMS=YES ADDLOCAL=ALL

# Limpiar
Remove-Item $output
```

**Método manual:**

1. Descargar desde: https://docs.microsoft.com/sql/connect/odbc/download-odbc-driver-for-sql-server
2. Ejecutar instalador MSI
3. Aceptar licencia
4. Instalación completa (all features)

**Verificar:**

```powershell
# PowerShell
Get-OdbcDriver | Where-Object {$_.Name -like "*SQL Server*"}
```

#### 3. Instalar pyodbc

```powershell
# CMD o PowerShell
pip install pyodbc

# Verificar
python -c "import pyodbc; print(pyodbc.version)"
```

#### 4. Descargar toolkit

**Opción A: Git**

```powershell
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit\tools\offline-benchmark
```

**Opción B: ZIP**

1. Descargar ZIP desde GitHub
2. Extraer en `C:\AzureMigration\` (recomendado)
3. Navegar a carpeta:

```powershell
cd C:\AzureMigration\azure-sql-benchmark-toolkit\tools\offline-benchmark
```

#### 5. Ejecutar instalador

```powershell
# Windows Authentication (recomendado)
python INSTALL.py

# SQL Authentication
python INSTALL.py --server .\SQL2022 --username sa --password YourPassword
```

---

## 🍎 Instalación en macOS

### macOS 11+ (Big Sur, Monterey, Ventura, Sonoma)

#### 1. Instalar Homebrew

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Instalar Python 3.8+

```bash
brew install python@3.11
python3 --version
```

#### 3. Instalar unixODBC

```bash
brew install unixodbc
```

#### 4. Instalar Microsoft ODBC Driver 17

```bash
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release
brew update
brew install msodbcsql17 mssql-tools
```

#### 5. Configurar PATH (si necesario)

```bash
echo 'export PATH="/usr/local/opt/mssql-tools/bin:$PATH"' >> ~/.zshrc
source ~/.zshrc
```

#### 6. Instalar pyodbc

```bash
pip3 install pyodbc
```

#### 7. Ejecutar instalador

```bash
python3 INSTALL.py --server your-server.database.windows.net --username sa --password YourPassword
```

---

## ✔️ Validación Post-Instalación

### 1. Verificar Python

```bash
python3 --version
# Expected: Python 3.8.0 o superior
```

### 2. Verificar pyodbc

```bash
python3 -c "import pyodbc; print(f'pyodbc {pyodbc.version} OK')"
# Expected: pyodbc 4.x.x OK
```

### 3. Verificar ODBC Driver

**Linux:**
```bash
odbcinst -q -d
# Expected: [ODBC Driver 17 for SQL Server]
```

**Windows:**
```powershell
Get-OdbcDriver | Where-Object {$_.Name -like "*SQL Server*"}
# Expected: ODBC Driver 17 for SQL Server
```

### 4. Test de conectividad SQL

```bash
python3 scripts/diagnose_monitoring.py --server .
```

**Output esperado:**
```
[1/8] Checking Python version...
  [OK] Python 3.11.5

[2/8] Checking pyodbc installation...
  [OK] pyodbc 5.0.1 installed

[3/8] Checking ODBC driver...
  [OK] ODBC Driver 17 for SQL Server found

[4/8] Checking script files...
  [OK] All 5 required files found

[5/8] Testing SQL Server connectivity...
  [OK] Connected to: MYSERVER
       Version: Microsoft SQL Server 2022 (RTM) - 16.0.1000.6 ...

[6/8] Checking permissions...
  User: DOMAIN\User
  [OK] User has VIEW SERVER STATE permission

[7/8] Testing monitoring query...
  [OK] Query executed in 0.145 seconds
       Sample values:
         CPUs: 8
         Memory: 16,384 MB
         Connections: 47

[8/8] Creating directories...
  [OK] Created 3 directories

[OK] All checks passed!
```

### 5. Test rápido de monitorización

```bash
python3 scripts/monitor_sql_workload.py --server . --duration 3 --interval 30
```

Debería recolectar 6 muestras en 3 minutos sin errores.

---

## ⚙️ Configuración SQL Server

### Habilitar SQL Server Authentication (si es necesario)

**SQL Server Management Studio (SSMS):**

1. Conectar a servidor
2. Click derecho en servidor → Properties
3. Security → "SQL Server and Windows Authentication mode"
4. OK → Restart SQL Server service

**T-SQL:**

```sql
EXEC xp_instance_regwrite 
    N'HKEY_LOCAL_MACHINE', 
    N'Software\Microsoft\MSSQLServer\MSSQLServer',
    N'LoginMode', REG_DWORD, 2;
GO

-- Restart SQL Server service required
```

### Crear usuario con permisos mínimos

```sql
-- Crear login
USE master;
GO
CREATE LOGIN monitor_user WITH PASSWORD = 'ComplexP@ssw0rd123!';
GO

-- Grant VIEW SERVER STATE
GRANT VIEW SERVER STATE TO monitor_user;
GO

-- Verificar
SELECT 
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasPermission,
    SUSER_SNAME() AS CurrentUser;
GO
```

### Abrir firewall (si es necesario)

**Windows Firewall:**

```powershell
# PowerShell como Administrador
New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action Allow
```

**Linux (ufw):**

```bash
sudo ufw allow 1433/tcp
sudo ufw reload
```

**Linux (firewalld):**

```bash
sudo firewall-cmd --permanent --add-port=1433/tcp
sudo firewall-cmd --reload
```

### Habilitar TCP/IP protocol

**SQL Server Configuration Manager:**

1. SQL Server Network Configuration
2. Protocols for MSSQLSERVER
3. TCP/IP → Enable
4. Restart SQL Server service

---

## 🐛 Troubleshooting de Instalación

### Python: "command not found"

**Linux:**
```bash
# Verificar instalación
which python3
# Si no existe:
sudo apt install python3
```

**Windows:**
- Reinstalar Python marcando "Add to PATH"
- O agregar manualmente: `C:\Users\<User>\AppData\Local\Programs\Python\Python311`

### pip: "No module named pip"

```bash
# Linux
sudo apt install python3-pip

# Windows
python -m ensurepip --upgrade
```

### pyodbc: "Unable to locate Cursor"

Reinstalar pyodbc:

```bash
pip uninstall pyodbc
pip install --no-cache-dir pyodbc
```

### ODBC Driver: "Data source name not found"

**Verificar drivers disponibles:**

```bash
# Linux
odbcinst -q -d

# Windows (PowerShell)
Get-OdbcDriver
```

**Reinstalar driver:**

- Linux: Seguir pasos de instalación ODBC
- Windows: Descargar e instalar MSI desde Microsoft

### SQL Server: "Login failed"

1. **Verificar usuario/password**
   ```bash
   python3 scripts/diagnose_monitoring.py --server . --username sa --password YourPassword
   ```

2. **Verificar SQL Auth habilitado**
   - Ver sección "Habilitar SQL Server Authentication"

3. **Verificar firewall**
   ```bash
   telnet server-name 1433
   ```

### "Could not connect after 10 seconds"

1. **SQL Server corriendo?**
   ```powershell
   # Windows
   Get-Service MSSQLSERVER
   
   # Linux
   sudo systemctl status mssql-server
   ```

2. **Firewall bloqueando?**
   - Ver sección "Abrir firewall"

3. **Named instance?**
   - Usar `.\INSTANCENAME` en lugar de `.`
   - O `SERVER\INSTANCENAME`

### "User lacks VIEW SERVER STATE permission"

```sql
-- Ejecutar como sysadmin
USE master;
GO
GRANT VIEW SERVER STATE TO [DOMAIN\User];
GO
-- O
GRANT VIEW SERVER STATE TO monitor_user;
GO
```

---

## 📚 Próximos Pasos

Después de instalación exitosa:

1. **[Quick Start](../README.md#-quick-start)**: Test de 15 minutos
2. **[Usage Guide](USAGE.md)**: Uso avanzado y casos de uso
3. **[Troubleshooting](TROUBLESHOOTING.md)**: Solución de problemas comunes

---

**Última actualización**: 2025-01-26  
**Versión del documento**: 1.0
