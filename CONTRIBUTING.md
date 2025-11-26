# Contributing to Azure SQL Benchmark Toolkit

¡Gracias por tu interés en contribuir! 🎉

## Cómo Contribuir

### 1. Reportar Bugs

Usa [GitHub Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues) para reportar bugs:

1. Busca primero si el bug ya fue reportado
2. Crea un nuevo issue con:
   - **Título descriptivo**
   - **Pasos para reproducir**
   - **Comportamiento esperado vs actual**
   - **Versión del toolkit**: `git rev-parse HEAD`
   - **Sistema operativo**: `uname -a` (Linux/Mac) o `ver` (Windows)
   - **Versión Python**: `python3 --version`
   - **Logs relevantes**

### 2. Sugerir Mejoras

Para nuevas features o mejoras:

1. Abre un [GitHub Discussion](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)
2. Describe:
   - **Problema que resuelve**
   - **Solución propuesta**
   - **Alternativas consideradas**
   - **Impacto en usuarios existentes**

### 3. Enviar Pull Requests

#### Setup de Desarrollo

```bash
# Fork y clone
git clone https://github.com/TU-USUARIO/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit

# Crear branch para tu feature
git checkout -b feature/mi-nueva-feature

# Instalar dependencias dev
pip install -r requirements-dev.txt  # Si existe
```

#### Guía de Código

**Python:**
- Seguir [PEP 8](https://pep8.org/)
- Docstrings en todas las funciones
- Type hints cuando sea posible
- Máximo 120 caracteres por línea

```python
def monitor_sql_server(server: str, duration: int) -> dict:
    """
    Monitor SQL Server performance metrics.
    
    Args:
        server: SQL Server hostname or IP
        duration: Monitoring duration in seconds
    
    Returns:
        dict: Performance metrics collected
    """
    # Implementation
```

**Bash:**
- Usar `set -euo pipefail` al inicio
- Comillas dobles en variables: `"$VAR"`
- Funciones con nombres descriptivos
- Comentarios para lógica compleja

```bash
#!/bin/bash
set -euo pipefail

# Function to validate input
validate_input() {
    local input="$1"
    # Validation logic
}
```

**HTML/CSS/JavaScript:**
- Indentación de 2 espacios
- Comentarios descriptivos
- Nombres de variables en camelCase
- CSS en formato BEM cuando sea posible

#### Commits

Formato de mensajes:

```
tipo(scope): descripción corta

Descripción detallada opcional explicando el porqué del cambio.

Fixes #123
```

Tipos:
- `feat`: Nueva feature
- `fix`: Bug fix
- `docs`: Cambios en documentación
- `style`: Formato, sin cambio de código
- `refactor`: Refactorización
- `test`: Añadir tests
- `chore`: Tareas de mantenimiento

Ejemplos:
```
feat(monitoring): add support for Azure SQL Managed Instance

fix(reports): correct TCO calculation for Reserved Instances

docs(quickstart): update installation steps for macOS

refactor(utils): simplify client creation logic
```

#### Testing

Antes de enviar PR:

```bash
# Validar sintaxis bash
bash -n tools/utils/*.sh

# Validar sintaxis Python
python -m py_compile tools/monitoring/*.py

# Ejecutar linter (si está configurado)
pylint tools/monitoring/*.py

# Probar tus cambios
./tools/utils/create_client.sh test-client
```

#### Pull Request Process

1. Actualiza README si añades features
2. Actualiza CHANGELOG.md con tus cambios
3. Asegúrate de que todos los checks pasan
4. Request review de un maintainer
5. Responde a comentarios de review

Template de PR:

```markdown
## Descripción
Breve descripción del cambio.

## Tipo de cambio
- [ ] Bug fix
- [ ] Nueva feature
- [ ] Breaking change
- [ ] Documentación

## Testing
Describe cómo testeaste tus cambios.

## Checklist
- [ ] Mi código sigue el style guide del proyecto
- [ ] He realizado self-review
- [ ] He comentado código complejo
- [ ] He actualizado la documentación
- [ ] Mis cambios no generan warnings
- [ ] He añadido tests (si aplica)
```

### 4. Mejorar Documentación

Documentación siempre es bienvenida:

- Corregir typos
- Clarificar explicaciones
- Añadir ejemplos
- Traducir a otros idiomas
- Mejorar diagramas

### 5. Compartir Templates

¿Creaste templates personalizados de informes?

1. Guárdalos en `templates/community/`
2. Añade README explicando uso
3. Envía PR

## Style Guidelines

### Python Code Style

```python
# ✅ Good
def calculate_iops(reads: int, writes: int) -> int:
    """Calculate total IOPS from read and write operations."""
    return reads + writes

# ❌ Bad
def calc(r,w):
    return r+w
```

### Shell Script Style

```bash
# ✅ Good
if [ -z "$CLIENT_NAME" ]; then
    print_error "Client name is required"
    exit 1
fi

# ❌ Bad
if [ -z $CLIENT_NAME ]
then
echo "error"
exit 1
fi
```

### Documentation Style

```markdown
# ✅ Good
## Installation

Follow these steps:

1. Install Python 3.8+
2. Install ODBC driver
3. Clone repository

\`\`\`bash
git clone https://github.com/...
\`\`\`

# ❌ Bad
## installation
install python, install odbc driver, clone repo
```

## Directrices de Comunidad

### Código de Conducta

- Sé respetuoso y profesional
- Acepta críticas constructivas
- Enfócate en lo mejor para la comunidad
- Muestra empatía hacia otros

### Comunicación

- **Issues**: Para bugs y features concretas
- **Discussions**: Para preguntas y ideas generales
- **PR Comments**: Para feedback de código
- **X (Twitter)**: [@alejandrolmeida](https://x.com/alejandrolmeida) - Para temas privados (DM)
- **LinkedIn**: [linkedin.com/in/alejandrolmeida](https://linkedin.com/in/alejandrolmeida) - Para temas privados (DM)

## Prioridades del Proyecto

### High Priority
- 🔴 Bugs críticos que afectan funcionalidad core
- 🔴 Security vulnerabilities
- 🔴 Documentación faltante o incorrecta

### Medium Priority
- 🟡 Nuevas features solicitadas frecuentemente
- 🟡 Mejoras de performance
- 🟡 Refactorización de código legacy

### Low Priority
- 🟢 Nice-to-have features
- 🟢 Optimizaciones menores
- 🟢 Mejoras cosméticas

## Versionado

Seguimos [Semantic Versioning](https://semver.org/):

- **MAJOR**: Cambios incompatibles de API
- **MINOR**: Nuevas features backwards-compatible
- **PATCH**: Bug fixes backwards-compatible

Ejemplo: v2.1.3

## Release Process

1. Update version en `config/settings.env`
2. Update CHANGELOG.md
3. Create Git tag: `git tag -a v2.1.0 -m "Release v2.1.0"`
4. Push tag: `git push origin v2.1.0`
5. Create GitHub Release con notas
6. Announce en Discussions

## Licencia

Al contribuir, aceptas que tus contribuciones serán licenciadas bajo la licencia MIT del proyecto.

## Reconocimientos

Todos los contributors serán añadidos al README.md:

```markdown
## Contributors

- @alejandrolmeida - Creator
- @tu-usuario - Feature X, Bug Y
```

## Preguntas?

- 💬 [GitHub Discussions](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)
- 📧 alejandro.almeida@example.com
- 🐛 [Report Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues)

---

**Gracias por hacer que Azure SQL Benchmark Toolkit sea mejor!** 🚀
