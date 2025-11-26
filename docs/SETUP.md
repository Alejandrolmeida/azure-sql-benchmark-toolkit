# 🛠️ Setup Guide - Azure SQL Benchmark Toolkit

Guía completa de instalación y configuración del toolkit.

## 📋 Tabla de Contenidos

- [Requisitos del Sistema](#requisitos-del-sistema)
- [Instalación por Sistema Operativo](#instalación-por-sistema-operativo)
- [Configuración Avanzada](#configuración-avanzada)
- [Validación de la Instalación](#validación-de-la-instalación)
- [Troubleshooting](#troubleshooting)
- [Desinstalación](#desinstalación)

## 🖥️ Requisitos del Sistema

### Requisitos Mínimos

| Componente | Requisito |
|------------|-----------|
| **SO** | Linux (Ubuntu 18.04+), Windows 10+, macOS 10.15+ |
| **Python** | 3.8 o superior |
| **RAM** | 2 GB disponible |
| **Disco** | 1 GB libre (más espacio para benchmarks) |
| **Red** | Conexión a SQL Server (puerto 1433) |

### Requisitos de Red

- **Puerto 1433**: Acceso a SQL Server
- **Puertos 443/80**: Para descargar dependencias (opcional)
- **Firewall**: Permitir tráfico desde máquina de benchmark a SQL Server

### Permisos SQL Server

El usuario de conexión debe tener:

```sql
-- Permisos mínimos necesarios
GRANT VIEW SERVER STATE TO [usuario_benchmark];
GRANT VIEW ANY DATABASE TO [usuario_benchmark];
GO
```

Para Windows Authentication, el usuario de Windows debe estar en el grupo local con estos permisos.

## 🐧 Instalación por Sistema Operativo

### Ubuntu/Debian (Recomendado)

#### 1. Actualizar Sistema

```bash
sudo apt-get update
sudo apt-get upgrade -y
```

#### 2. Instalar Python 3.8+

```bash
# Verificar versión actual
python3 --version

# Si es < 3.8, instalar:
sudo apt-get install -y python3 python3-pip python3-venv

# Verificar instalación
python3 --version  # Debe mostrar 3.8 o superior
pip3 --version
```

#### 3. Instalar ODBC Driver para SQL Server

```bash
# Añadir repositorio de Microsoft
curl https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

# Ubuntu 20.04
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Ubuntu 22.04
curl https://packages.microsoft.com/config/ubuntu/22.04/prod.list | sudo tee /etc/apt/sources.list.d/mssql-release.list

# Actualizar e instalar
sudo apt-get update
sudo ACCEPT_EULA=Y apt-get install -y msodbcsql17

# Instalar herramientas opcionales (sqlcmd)
sudo ACCEPT_EULA=Y apt-get install -y mssql-tools
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc
```

#### 4. Instalar unixODBC Development

```bash
sudo apt-get install -y unixodbc-dev
```

#### 5. Instalar Dependencias Python

```bash
pip3 install --user pyodbc
```

#### 6. Clonar Repositorio

```bash
cd ~
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit
```

#### 7. Hacer Scripts Ejecutables

```bash
chmod +x tools/utils/*.sh
chmod +x scripts/**/*.sh
```

### Windows 10/11

#### 1. Instalar Python 3.8+

1. Descargar desde: https://www.python.org/downloads/
2. **Importante**: Marcar "Add Python to PATH" durante instalación
3. Verificar en PowerShell:

```powershell
python --version
pip --version
```

#### 2. Instalar ODBC Driver para SQL Server

1. Descargar: https://go.microsoft.com/fwlink/?linkid=2249004
2. Ejecutar `msodbcsql.msi`
3. Seguir wizard de instalación

#### 3. Instalar Git (si no lo tienes)

1. Descargar: https://git-scm.com/download/win
2. Instalar con opciones por defecto

#### 4. Instalar pyodbc

```powershell
pip install pyodbc
```

#### 5. Clonar Repositorio

```powershell
cd $HOME
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit
```

#### 6. (Opcional) Instalar WSL para Scripts Bash

Si quieres ejecutar scripts `.sh` nativamente:

```powershell
# PowerShell como Administrador
wsl --install
```

Reinicia y luego sigue las instrucciones de Ubuntu dentro de WSL.

### macOS

#### 1. Instalar Homebrew (si no lo tienes)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

#### 2. Instalar Python 3.8+

```bash
brew install python@3.9
```

Añadir a PATH en `~/.zshrc` o `~/.bash_profile`:

```bash
export PATH="/usr/local/opt/python@3.9/bin:$PATH"
```

Recargar shell:

```bash
source ~/.zshrc  # o ~/.bash_profile
```

#### 3. Instalar ODBC Driver para SQL Server

```bash
# Añadir repositorio de Microsoft
brew tap microsoft/mssql-release https://github.com/Microsoft/homebrew-mssql-release

# Instalar driver
brew update
HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql17 mssql-tools
```

#### 4. Instalar pyodbc

```bash
pip3 install pyodbc
```

#### 5. Clonar Repositorio

```bash
cd ~
git clone https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit
```

#### 6. Hacer Scripts Ejecutables

```bash
chmod +x tools/utils/*.sh
```

## ⚙️ Configuración Avanzada

### Variables de Entorno Globales

Crea un archivo `.env` en la raíz del proyecto:

```bash
cp .env.example .env
nano .env
```

Configura:

```bash
# Azure Credentials (opcional para MCP servers)
AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_TENANT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
AZURE_CLIENT_SECRET="tu-client-secret"

# GitHub Token (opcional para GitHub MCP)
GITHUB_TOKEN="ghp_xxxxxxxxxxxxxxxxxxxx"

# Brave Search API (opcional)
BRAVE_API_KEY="BSA_xxxxxxxxxxxxxxxxxxxx"

# SQL Server por defecto (opcional)
DEFAULT_SQL_SERVER="servidor.domain.local"
DEFAULT_SQL_DATABASE="master"
DEFAULT_SQL_AUTH="windows"
```

### Configuración Global del Toolkit

Edita `config/settings.env`:

```bash
nano config/settings.env
```

Personaliza:

```bash
# Benchmark Settings
DEFAULT_INTERVAL="120"     # 2 minutos
DEFAULT_DURATION="86400"   # 24 horas

# Azure Defaults
DEFAULT_AZURE_REGION="westeurope"
DEFAULT_VM_FAMILY="Esv5"
DEFAULT_CURRENCY="EUR"  # o "USD", "GBP"

# Report Settings
REPORT_LANGUAGE="es"       # "en", "es", "fr", "de"
REPORT_THEME="azure"       # "azure", "dark", "light"

# Logging
LOG_LEVEL="INFO"           # DEBUG, INFO, WARNING, ERROR
LOG_FILE="benchmark.log"

# Security
ENCRYPT_PASSWORDS="true"
STORE_CREDENTIALS_IN_KEYVAULT="false"
```

### Integración con Azure Key Vault (Producción)

Para almacenar credenciales de forma segura:

```bash
# 1. Crear Key Vault
az keyvault create \
  --name "kv-benchmark-prod" \
  --resource-group "rg-toolkit" \
  --location "westeurope"

# 2. Almacenar credenciales
az keyvault secret set \
  --vault-name "kv-benchmark-prod" \
  --name "sql-prod-password" \
  --value "P@ssw0rd123!"

# 3. Configurar en settings.env
STORE_CREDENTIALS_IN_KEYVAULT="true"
AZURE_KEYVAULT_NAME="kv-benchmark-prod"
```

### MCP Servers (GitHub Copilot Agent)

Si usas VS Code con GitHub Copilot, los MCP servers ya están configurados en `mcp.json`.

Asegúrate de tener las variables de entorno:

```bash
# En tu ~/.bashrc o ~/.zshrc
export AZURE_SUBSCRIPTION_ID="tu-subscription-id"
export AZURE_TENANT_ID="tu-tenant-id"
export GITHUB_TOKEN="tu-github-token"
export BRAVE_API_KEY="tu-brave-api-key"
```

Reinicia VS Code para que tome los cambios.

## ✅ Validación de la Instalación

### Test Completo de Instalación

```bash
# Ejecutar script de validación
./tools/utils/validate_installation.sh
```

**Salida esperada:**

```
========================================
  Installation Validation
========================================

✅ Python 3.9.2 detected
✅ pip 21.0.1 detected
✅ pyodbc 4.0.35 installed
✅ ODBC Driver 17 for SQL Server found
✅ Scripts are executable
✅ Directory structure is correct
✅ Config files exist

========================================
  All checks passed! ✅
========================================
```

### Validación Manual

#### 1. Verificar Python

```bash
python3 --version
# Debe mostrar >= 3.8
```

#### 2. Verificar pyodbc

```python
python3 -c "import pyodbc; print(pyodbc.version)"
# Debe mostrar versión sin errores
```

#### 3. Verificar ODBC Drivers

```bash
# Linux/macOS
odbcinst -q -d

# Debe listar:
# [ODBC Driver 17 for SQL Server]
```

```powershell
# Windows PowerShell
Get-OdbcDriver | Where-Object {$_.Name -like "*SQL Server*"}
```

#### 4. Test de Conexión SQL Server

```bash
# Crear script de test
cat > test_connection.py << 'EOF'
import pyodbc

server = "tu-servidor.domain.local"
database = "master"

try:
    # Windows Authentication
    conn = pyodbc.connect(
        f"DRIVER={{ODBC Driver 17 for SQL Server}};"
        f"SERVER={server};"
        f"DATABASE={database};"
        f"Trusted_Connection=yes;"
    )
    print("✅ Conexión exitosa!")
    cursor = conn.cursor()
    cursor.execute("SELECT @@VERSION")
    row = cursor.fetchone()
    print(f"SQL Server Version: {row[0][:50]}...")
    conn.close()
except Exception as e:
    print(f"❌ Error de conexión: {e}")
EOF

python3 test_connection.py
```

## 🔧 Troubleshooting

### Problema: "pyodbc module not found"

**Solución:**

```bash
pip3 install --user pyodbc

# Si persiste, intenta:
python3 -m pip install pyodbc
```

### Problema: "ODBC Driver 17 for SQL Server not found"

**Linux:**

```bash
# Verificar instalación
dpkg -l | grep msodbcsql

# Si no aparece, reinstalar:
sudo apt-get remove msodbcsql17
sudo apt-get install -y msodbcsql17
```

**Windows:**

- Descargar e instalar manualmente: https://go.microsoft.com/fwlink/?linkid=2249004

**macOS:**

```bash
# Reinstalar
brew uninstall msodbcsql17
HOMEBREW_ACCEPT_EULA=Y brew install msodbcsql17
```

### Problema: "Login failed for user"

**Causa**: Credenciales incorrectas o permisos insuficientes.

**Solución:**

```sql
-- En SQL Server, verificar permisos:
USE master;
GO

-- Ver permisos del usuario
SELECT 
    SUSER_NAME() AS CurrentUser,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW SERVER STATE') AS HasViewServerState,
    HAS_PERMS_BY_NAME(NULL, NULL, 'VIEW ANY DATABASE') AS HasViewAnyDatabase;
GO

-- Si faltan, otorgar:
GRANT VIEW SERVER STATE TO [DOMAIN\user];
GRANT VIEW ANY DATABASE TO [DOMAIN\user];
GO
```

### Problema: "Connection timeout"

**Causa**: Firewall bloqueando puerto 1433.

**Solución:**

```bash
# Test de conectividad
telnet servidor.domain.local 1433

# Si falla, verificar firewall:
# Windows Server
netsh advfirewall firewall show rule name="SQL Server"

# Linux
sudo iptables -L | grep 1433

# Abrir puerto si está cerrado:
# Windows Server
New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -LocalPort 1433 -Protocol TCP -Action Allow
```

### Problema: Scripts no ejecutables (Linux/macOS)

**Solución:**

```bash
chmod +x tools/utils/*.sh
chmod +x scripts/**/*.sh
```

### Problema: Python no encontrado (Windows)

**Solución:**

1. Reinstalar Python marcando "Add to PATH"
2. O añadir manualmente a PATH:
   - Panel de Control → Sistema → Variables de entorno
   - Añadir `C:\Python39` y `C:\Python39\Scripts` a PATH

## 🗑️ Desinstalación

### Desinstalar Toolkit

```bash
# Eliminar directorio completo
cd ~
rm -rf azure-sql-benchmark-toolkit
```

### Desinstalar Dependencias

**Ubuntu/Debian:**

```bash
sudo apt-get remove -y msodbcsql17 mssql-tools
pip3 uninstall pyodbc
```

**Windows:**

1. Panel de Control → Programas → Desinstalar
2. Buscar "Microsoft ODBC Driver for SQL Server"
3. Desinstalar

```powershell
pip uninstall pyodbc
```

**macOS:**

```bash
brew uninstall msodbcsql17 mssql-tools
pip3 uninstall pyodbc
```

## 📞 Soporte

Si tienes problemas durante la instalación:

1. **Consulta**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
2. **Issues GitHub**: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues
3. **Discussions**: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions

## 🔗 Referencias

- **[QUICKSTART.md](QUICKSTART.md)** - Inicio rápido después de instalar
- **[USAGE.md](USAGE.md)** - Guía completa de uso
- **[README.md](../README.md)** - Documentación principal

---

**Última actualización**: 2025-11-26  
**Versión**: 2.0.0
