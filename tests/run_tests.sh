#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v bats &>/dev/null; then
    echo "ERROR: bats no está instalado. Ejecuta: npm install -g bats"
    exit 1
fi

if [ $# -eq 0 ]; then
    files=(*.bats)
else
    files=("$@")
fi

exec bats --print-output-on-failure "${files[@]}"
