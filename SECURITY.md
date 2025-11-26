# Security Policy

## 🔒 Seguridad y Manejo de Credenciales

Este proyecto maneja información sensible como credenciales de SQL Server y claves de API. Sigue estas prácticas de seguridad:

## ⚠️ Información Sensible - NUNCA Commitear

**NUNCA** incluyas en commits:

- ❌ Contraseñas de SQL Server
- ❌ Connection strings con credenciales
- ❌ Azure Service Principal secrets
- ❌ GitHub Personal Access Tokens
- ❌ API Keys (Brave Search, etc.)
- ❌ Claves privadas SSH/TLS
- ❌ Archivos `.env` con valores reales
- ❌ Configuraciones de cliente con datos reales (`customers/*/config/client-config.env`)

## ✅ Archivos Protegidos por .gitignore

El `.gitignore` ya está configurado para proteger:

```
# Environment variables
.env
.env.local
*.env.local

# Customer configurations
customers/*/config/client-config.env

# Azure credentials
.azure/
*.publishsettings

# SSH keys
*.pem
*.key
id_rsa*

# Benchmark data
customers/*/benchmarks/*/sql_workload_*.json
```

## 🔐 Mejores Prácticas

### 1. Variables de Entorno

Usa el archivo `.env` (nunca commiteado):

```bash
# Copia el template
cp .env.example .env

# Edita con tus credenciales reales
vim .env
```

### 2. Azure Key Vault (Recomendado para Producción)

En `config/settings.env` activa Key Vault:

```bash
STORE_CREDENTIALS_IN_KEYVAULT="true"
AZURE_KEYVAULT_NAME="tu-keyvault-name"
```

### 3. Configuración de Clientes

Cada cliente debe tener su configuración protegida:

```bash
# Crear cliente con configuración segura
./tools/utils/create_client.sh "NombreCliente"

# Editar configuración (NO commitear este archivo)
vim customers/NombreCliente/config/client-config.env
```

### 4. MCP Servers (Model Context Protocol)

Las credenciales de MCP deben estar en variables de entorno:

```bash
export GITHUB_TOKEN="ghp_xxxxxxxxxxxx"
export BRAVE_API_KEY="BSA_xxxxxxxxxxxx"
export AZURE_SUBSCRIPTION_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

### 5. Autenticación SQL Server

**Opción 1: Windows Authentication (Trusted Connection)**
```bash
SQL_AUTH_TYPE="windows"
```

**Opción 2: SQL Authentication (con Key Vault)**
```bash
SQL_AUTH_TYPE="sql"
SQL_USERNAME="sa"
# Password almacenado en Key Vault
```

## 🚨 Si Accidentalmente Commiteas Secretos

1. **Rota inmediatamente** todas las credenciales expuestas
2. Elimina el secreto del historial Git:
   ```bash
   # Usa BFG Repo-Cleaner o git-filter-repo
   git filter-repo --path customers/*/config/client-config.env --invert-paths
   ```
3. Force push al remoto:
   ```bash
   git push -f origin main
   ```
4. **Cambia todas las contraseñas/tokens afectados**

## 📋 Checklist de Seguridad Pre-Commit

Antes de cada commit, verifica:

- [ ] No hay contraseñas hardcodeadas en código
- [ ] Los archivos `.env` NO están en staging
- [ ] Configuraciones de cliente usan variables o placeholders
- [ ] Connection strings NO contienen credenciales
- [ ] Archivos de benchmark NO contienen datos sensibles
- [ ] `.gitignore` está actualizado

## 🔍 Auditoría de Seguridad

Revisa regularmente:

```bash
# Buscar posibles secretos en código
git grep -E '(password|secret|key|token).*=.*["\047][^$\{]' -- '*.sh' '*.py' '*.ps1'

# Verificar qué archivos están trackeados
git ls-files | grep -E '\.(env|key|pem)$'

# Check .gitignore efectivo
git check-ignore -v customers/*/config/client-config.env
```

## 📞 Reportar Vulnerabilidades

Si encuentras una vulnerabilidad de seguridad:

1. **NO** abras un issue público
2. Contacta directamente: [tu-email@example.com]
3. Incluye detalles del problema y pasos para reproducir
4. Espera confirmación antes de divulgar públicamente

## 🛡️ Compliance & Cumplimiento

Este toolkit está diseñado para cumplir con:

- **GDPR**: Protección de datos personales (no almacenamos PII en git)
- **ISO 27001**: Gestión de seguridad de la información
- **Azure Security Best Practices**: Key Vault, Managed Identities, RBAC

## 🔗 Referencias

- [GitHub Secret Scanning](https://docs.github.com/en/code-security/secret-scanning)
- [Azure Key Vault Best Practices](https://learn.microsoft.com/azure/key-vault/general/best-practices)
- [OWASP Top 10](https://owasp.org/www-project-top-ten/)
- [Git Secret Management](https://git-scm.com/book/en/v2/Git-Tools-Credential-Storage)

---

**Última actualización**: 2025-11-26  
**Versión**: 2.0.0
