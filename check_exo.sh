#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

# Lock atómico para evitar ejecución concurrente
acquire_lock

check_deps pgrep

if is_exo_running; then
    log "check_exo: EXO ya está corriendo (PID $(find_exo_pid))"
    exit 0
fi

echo "EXO no está corriendo. Iniciando..."
log "check_exo: EXO no detectado. Iniciando..."
"$SCRIPT_DIR/start_exo.sh" 2>&1 | tee -a "$LOG_FILE"
if is_exo_running; then
    echo "EXO iniciado correctamente (PID $(find_exo_pid))"
    log "check_exo: EXO iniciado correctamente (PID $(find_exo_pid))"
else
    warn "check_exo: EXO no arrancó después del intento de inicio"
fi
