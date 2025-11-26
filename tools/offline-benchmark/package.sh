#!/usr/bin/env bash
"""
SQL Server Workload Monitor - Package Script
=============================================

Crea un paquete ZIP portable con todos los archivos necesarios.

Uso:
    bash package.sh
    bash package.sh --version 2.1.0 --output releases/
"""

set -euo pipefail

VERSION="${1:-2.1.0}"
OUTPUT_DIR="${2:-releases}"
PACKAGE_NAME="sql-workload-monitor-offline-v${VERSION}"

echo "======================================================================"
echo "  SQL SERVER WORKLOAD MONITOR - PACKAGING"
echo "======================================================================"
echo ""
echo "Version: ${VERSION}"
echo "Output:  ${OUTPUT_DIR}/${PACKAGE_NAME}.zip"
echo ""

# Crear directorio temporal
TEMP_DIR=$(mktemp -d)
PACKAGE_DIR="${TEMP_DIR}/${PACKAGE_NAME}"

mkdir -p "${PACKAGE_DIR}"

echo "[1/7] Creating package structure..."
mkdir -p "${PACKAGE_DIR}"/{scripts,docs,samples,output,checkpoints,logs}

echo "[2/7] Copying scripts..."
cp scripts/monitor_sql_workload.py "${PACKAGE_DIR}/scripts/"
cp scripts/workload-sample-query.sql "${PACKAGE_DIR}/scripts/"
cp scripts/check_monitoring_status.py "${PACKAGE_DIR}/scripts/"
cp scripts/diagnose_monitoring.py "${PACKAGE_DIR}/scripts/"
cp scripts/Generate-SQLWorkload.py "${PACKAGE_DIR}/scripts/"
chmod +x "${PACKAGE_DIR}"/scripts/*.py

echo "[3/7] Copying documentation..."
cp README.md "${PACKAGE_DIR}/"
cp INSTALL.py "${PACKAGE_DIR}/"
cp docs/INSTALLATION.md "${PACKAGE_DIR}/docs/"
cp docs/USAGE.md "${PACKAGE_DIR}/docs/"
[ -f docs/TROUBLESHOOTING.md ] && cp docs/TROUBLESHOOTING.md "${PACKAGE_DIR}/docs/" || echo "  [SKIP] TROUBLESHOOTING.md not found"
[ -f docs/INTEGRATION.md ] && cp docs/INTEGRATION.md "${PACKAGE_DIR}/docs/" || echo "  [SKIP] INTEGRATION.md not found"

echo "[4/7] Creating requirements.txt..."
cat > "${PACKAGE_DIR}/requirements.txt" << 'EOF'
pyodbc>=5.0.0
EOF

echo "[5/7] Creating VERSION file..."
cat > "${PACKAGE_DIR}/VERSION" << EOF
${VERSION}
EOF

echo "[6/7] Creating package info..."
cat > "${PACKAGE_DIR}/PACKAGE_INFO.txt" << EOF
===================================================================
SQL Server Workload Monitor - Offline Edition
===================================================================

Version:     ${VERSION}
Package:     ${PACKAGE_NAME}.zip
Created:     $(date '+%Y-%m-%d %H:%M:%S')
Platform:    Cross-platform (Python 3.8+)

Contents:
  - monitor_sql_workload.py       : Main monitoring script
  - workload-sample-query.sql     : External SQL query
  - check_monitoring_status.py    : Status checker
  - diagnose_monitoring.py        : Diagnostic tool
  - Generate-SQLWorkload.py       : Workload generator
  - INSTALL.py                    : Automated installer
  - README.md                     : Complete documentation
  - docs/                         : Additional guides
  - requirements.txt              : Python dependencies

Installation:
  1. Unzip package
  2. Install Python 3.8+ and ODBC Driver 17
  3. pip install -r requirements.txt
  4. python INSTALL.py

Quick Start:
  python scripts/monitor_sql_workload.py --server . --duration 15 --interval 60

For full documentation, see README.md

License: MIT
Project: Azure SQL Benchmark Toolkit
Repository: https://github.com/alejandrolmeida/azure-sql-benchmark-toolkit

===================================================================
EOF

echo "[7/7] Creating ZIP package..."
mkdir -p "${OUTPUT_DIR}"
cd "${TEMP_DIR}"
zip -r "${OUTPUT_DIR}/${PACKAGE_NAME}.zip" "${PACKAGE_NAME}" > /dev/null

# Limpiar
rm -rf "${TEMP_DIR}"

# Info final
FILE_SIZE=$(du -h "${OUTPUT_DIR}/${PACKAGE_NAME}.zip" | cut -f1)

echo ""
echo "======================================================================"
echo "  PACKAGING COMPLETE"
echo "======================================================================"
echo ""
echo "Package:     ${PACKAGE_NAME}.zip"
echo "Location:    ${OUTPUT_DIR}/"
echo "Size:        ${FILE_SIZE}"
echo ""
echo "Contents:"
unzip -l "${OUTPUT_DIR}/${PACKAGE_NAME}.zip" | head -20
echo "..."
echo ""
echo "Distribution:"
echo "  - Upload to GitHub Releases"
echo "  - Copy to file share"
echo "  - Email to DBAs"
echo "  - Transfer via USB"
echo ""
echo "Integrity check:"
echo "  sha256sum ${OUTPUT_DIR}/${PACKAGE_NAME}.zip"
sha256sum "${OUTPUT_DIR}/${PACKAGE_NAME}.zip"
echo ""
