# 🤝 Contributing Guide

¡Gracias por tu interés en contribuir al Azure SQL Benchmark Toolkit!

## 📋 Tabla de Contenidos

- [Código de Conducta](#código-de-conducta)
- [Cómo Contribuir](#cómo-contribuir)
- [Reportar Bugs](#reportar-bugs)
- [Sugerir Features](#sugerir-features)
- [Pull Requests](#pull-requests)
- [Guía de Estilo](#guía-de-estilo)
- [Proceso de Desarrollo](#proceso-de-desarrollo)
- [Comunidad](#comunidad)

## 📜 Código de Conducta

Este proyecto sigue el [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/).

### Resumen

- **Sé respetuoso**: Trata a todos con respeto
- **Sé inclusivo**: Acepta diferentes perspectivas
- **Sé constructivo**: Crítica constructiva, no destructiva
- **Sé profesional**: Mantén un tono profesional

## 🚀 Cómo Contribuir

Hay muchas formas de contribuir:

### 💡 Compartir Casos de Uso

¿Usaste el toolkit exitosamente? Comparte tu experiencia:

1. Abre una [Discussion](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)
2. Categoría: "Show and Tell"
3. Describe:
   - Cliente (anónimo si es necesario)
   - Tamaño del servidor (CPU, RAM, IOPS)
   - Duración del benchmark
   - Resultados interesantes
   - Lecciones aprendidas

### 📝 Mejorar Documentación

La documentación siempre puede mejorar:

- **Typos y errores**: PRs pequeños son bienvenidos
- **Clarificaciones**: Si algo no está claro, explícalo mejor
- **Traducciones**: Ayuda traduciendo a otros idiomas
- **Tutoriales**: Crea guías paso a paso
- **Videos**: Graba screencasts de uso

### 🐛 Reportar Bugs

Ver sección [Reportar Bugs](#reportar-bugs) abajo.

### ✨ Proponer Features

Ver sección [Sugerir Features](#sugerir-features) abajo.

### 💻 Contribuir Código

Ver sección [Pull Requests](#pull-requests) abajo.

## 🐛 Reportar Bugs

### Antes de Reportar

1. **Busca issues existentes**: Quizás ya fue reportado
2. **Verifica la versión**: ¿Usas la última versión?
3. **Reproduce el bug**: Asegúrate de poder reproducirlo
4. **Recopila información**: Logs, screenshots, etc.

### Cómo Reportar un Bug

1. Ve a [Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues/new)
2. Selecciona "Bug Report"
3. Completa el template:

```markdown
## Descripción del Bug
Descripción clara y concisa de qué es el bug.

## Pasos para Reproducir
1. Ejecutar comando '...'
2. Con parámetros '...'
3. Ver error

## Comportamiento Esperado
Qué esperabas que sucediera.

## Comportamiento Actual
Qué sucedió realmente.

## Screenshots/Logs
Si aplica, añade screenshots o logs.

## Entorno
- OS: [e.g., Ubuntu 22.04]
- Python: [e.g., 3.9.2]
- Versión toolkit: [e.g., 2.0.0]
- SQL Server: [e.g., 2019 Enterprise]

## Contexto Adicional
Cualquier otra información relevante.
```

### Bugs de Seguridad

🚨 **NO reportes bugs de seguridad en Issues públicos**.

Envía email a: alejandro.almeida@example.com

Ver [SECURITY.md](../SECURITY.md) para más detalles.

## ✨ Sugerir Features

### Antes de Sugerir

1. **Verifica el roadmap**: Quizás ya está planeado
2. **Busca issues**: Quizás alguien ya lo sugirió
3. **Piensa en el caso de uso**: ¿Beneficia a muchos usuarios?

### Cómo Sugerir un Feature

1. Ve a [Issues](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/issues/new)
2. Selecciona "Feature Request"
3. Completa el template:

```markdown
## Resumen
Descripción breve del feature (1-2 líneas).

## Motivación
¿Qué problema resuelve este feature?

## Solución Propuesta
Cómo funcionaría técnicamente.

## Alternativas Consideradas
Otras formas de resolver el problema.

## Casos de Uso
Ejemplos concretos de uso.

## Impacto
¿A quiénes beneficia? (consultores, arquitectos, ops)

## Complejidad Estimada
- [ ] Simple (< 1 día)
- [ ] Media (1-3 días)
- [ ] Compleja (> 1 semana)
```

## 🔀 Pull Requests

### Proceso de PR

1. **Fork el repositorio**
2. **Crea una rama** desde `main`:
   ```bash
   git checkout -b feature/nombre-descriptivo
   # o
   git checkout -b fix/descripcion-bug
   ```
3. **Haz tus cambios**
4. **Commit con mensajes claros** (ver [Guía de Estilo](#guía-de-estilo))
5. **Push a tu fork**
6. **Abre un Pull Request**

### Checklist Pre-PR

Antes de abrir el PR, verifica:

- [ ] **Código funciona**: Probado localmente
- [ ] **Tests pasan**: Si hay tests automatizados
- [ ] **Documentación actualizada**: README, docs/
- [ ] **Sin credenciales**: No hay passwords hardcodeados
- [ ] **Commits limpios**: Mensajes descriptivos
- [ ] **Branch actualizado**: Rebased con `main`

### Template de PR

```markdown
## Tipo de Cambio
- [ ] Bug fix
- [ ] Nueva funcionalidad
- [ ] Mejora de documentación
- [ ] Refactoring
- [ ] Otro: _________

## Descripción
¿Qué hace este PR?

## Issue Relacionado
Fixes #123

## Cambios Realizados
- Cambio 1
- Cambio 2
- Cambio 3

## Screenshots (si aplica)

## Testing
¿Cómo se probó?

## Checklist
- [ ] Código funciona
- [ ] Documentación actualizada
- [ ] Sin credenciales hardcodeadas
- [ ] Commits con mensajes claros
```

### Revisión de PR

Tu PR será revisado por un maintainer. Espera:

1. **Feedback constructivo**: Sugerencias de mejora
2. **Iteraciones**: Puede requerir cambios
3. **Aprobación**: Cuando esté listo
4. **Merge**: Por un maintainer

## 🎨 Guía de Estilo

### Commits

Usamos [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Formato
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**

- `feat`: Nueva funcionalidad
- `fix`: Bug fix
- `docs`: Documentación
- `style`: Formato (sin cambios de código)
- `refactor`: Refactoring
- `test`: Tests
- `chore`: Mantenimiento

**Ejemplos:**

```bash
feat(monitoring): add support for Azure SQL Managed Instance

- Add new connection string format
- Update monitor_sql_workload.py
- Add docs for MI-specific config

Closes #45

---

fix(reports): correct CPU avg calculation

The avg was calculated incorrectly due to null values.
Now filters null before averaging.

Fixes #67

---

docs(setup): add macOS installation steps

Added detailed steps for Homebrew installation on macOS.

---

refactor(scripts): simplify run_benchmark.sh logic

Extracted validation to separate function for readability.
```

### Código Bash

**Estilo:**

```bash
#!/bin/bash
set -euo pipefail  # Exit on error, undefined var, pipe fail

# Constantes en MAYÚSCULAS
readonly TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly CONFIG_FILE="$TOOLKIT_DIR/config/settings.env"

# Variables en snake_case
client_name="$1"
benchmark_duration="${2:-86400}"

# Funciones descriptivas
validate_client_exists() {
    local client="$1"
    
    if [[ ! -d "$TOOLKIT_DIR/customers/$client" ]]; then
        echo "❌ Error: Cliente '$client' no existe"
        return 1
    fi
    
    return 0
}

# Comentarios útiles
# Cargar configuración del cliente
source "$TOOLKIT_DIR/customers/$client_name/config/client-config.env"

# Llamar funciones con argumentos claros
if validate_client_exists "$client_name"; then
    echo "✅ Cliente válido"
fi
```

### Código Python

**Estilo:** [PEP 8](https://peps.python.org/pep-0008/)

```python
"""
Monitor SQL Server workload metrics.

This module provides SQLServerMonitor class for capturing
performance metrics from SQL Server using DMVs.
"""

import logging
from datetime import datetime
from typing import Dict, List, Optional

# Constantes
DEFAULT_INTERVAL = 120
DEFAULT_DURATION = 86400

logger = logging.getLogger(__name__)


class SQLServerMonitor:
    """Monitor SQL Server performance metrics."""
    
    def __init__(
        self,
        server: str,
        database: str,
        username: Optional[str] = None,
        password: Optional[str] = None,
        trusted_connection: bool = True
    ):
        """
        Initialize SQL Server monitor.
        
        Args:
            server: SQL Server hostname or IP
            database: Database name to connect
            username: SQL auth username (optional)
            password: SQL auth password (optional)
            trusted_connection: Use Windows Authentication
        """
        self.server = server
        self.database = database
        # ... resto de inicialización
    
    def collect_metrics(self) -> Dict[str, any]:
        """
        Collect current performance metrics.
        
        Returns:
            Dictionary with metrics: cpu_percent, ram_percent, etc.
            
        Raises:
            ConnectionError: If SQL Server is unreachable
        """
        try:
            metrics = {
                'timestamp': datetime.now().isoformat(),
                'cpu_percent': self._get_cpu_usage(),
                'ram_percent': self._get_memory_usage(),
            }
            return metrics
        except Exception as e:
            logger.error(f"Error collecting metrics: {e}")
            raise
    
    def _get_cpu_usage(self) -> float:
        """Get current CPU usage (private method)."""
        # Implementation
        pass
```

### Documentación

**Markdown:**

- Headers con emojis (`## 🚀 Section`)
- Code blocks con lenguaje (```bash, ```python)
- Tablas para comparaciones
- Links relativos a otros docs
- Screenshots en `docs/images/`

**Ejemplo:**

```markdown
## 🔧 Instalación

### Ubuntu/Debian

Instala las dependencias:

```bash
sudo apt-get update
sudo apt-get install -y python3 python3-pip
```

Ver [SETUP.md](SETUP.md) para más detalles.

### Troubleshooting

Si encuentras errores, consulta la tabla:

| Error | Solución |
|-------|----------|
| `module not found` | `pip install pyodbc` |
| `connection failed` | Verificar firewall |
```

## 🛠️ Proceso de Desarrollo

### Setup Local

```bash
# 1. Fork y clonar
git clone https://github.com/TU-USUARIO/azure-sql-benchmark-toolkit.git
cd azure-sql-benchmark-toolkit

# 2. Añadir upstream
git remote add upstream https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit.git

# 3. Crear rama
git checkout -b feature/mi-feature

# 4. Hacer cambios
# ... editar archivos ...

# 5. Commit
git add .
git commit -m "feat(scope): descripción"

# 6. Push
git push origin feature/mi-feature

# 7. Abrir PR en GitHub
```

### Mantener Fork Actualizado

```bash
# Fetch upstream
git fetch upstream

# Merge cambios de main
git checkout main
git merge upstream/main

# Rebase tu rama
git checkout feature/mi-feature
git rebase main
```

### Testing Local

```bash
# Test de instalación
./tools/utils/validate_installation.sh

# Test de conexión SQL
python3 -c "import pyodbc; print('✅ pyodbc OK')"

# Test de script
./tools/utils/create_client.sh test-client
ls -la customers/test-client/

# Cleanup
rm -rf customers/test-client/
```

## 👥 Comunidad

### Dónde Participar

- **GitHub Issues**: Bugs y features
- **GitHub Discussions**: Preguntas y casos de uso
- **Pull Requests**: Contribuciones de código

### Mantenedores

| Nombre | GitHub | Rol |
|--------|--------|-----|
| Alejandro Almeida | [@alejandrolmeida](https://github.com/alejandrolmeida) | Creator & Maintainer |

### Contribuidores

Ver [Contributors](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/graphs/contributors) en GitHub.

### Reconocimientos

¿Contribuiste de forma significativa? Serás añadido a:

- `README.md` sección de agradecimientos
- `CONTRIBUTORS.md` (si se crea)
- Release notes

## 📄 Licencia

Al contribuir, aceptas que tus contribuciones se licenciarán bajo [MIT License](../LICENSE).

## ❓ Preguntas

¿Tienes dudas sobre cómo contribuir?

- Abre una [Discussion](https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit/discussions)
- Lee [USAGE.md](USAGE.md) para entender el toolkit
- Contacta a los maintainers

---

**¡Gracias por contribuir!** 🎉

Cada contribución, sin importar su tamaño, hace que este proyecto sea mejor para toda la comunidad.

---

**Última actualización**: 2025-11-26  
**Versión**: 2.0.0
