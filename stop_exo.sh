#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

log "Deteniendo EXO..."

PID=$(find_exo_pid || true)

if [ -z "$PID" ]; then
    log "No se encontró ningún proceso de EXO corriendo."
    echo "No hay proceso EXO activo."
    exit 0
fi

log "Enviando SIGTERM a PID $PID..."
kill "$PID" 2>/dev/null || true

if wait_for_exit "$PID" 5; then
    rm -f "$PID_FILE"
    log "EXO detenido correctamente (PID $PID)"
    echo "EXO detenido (PID $PID)"
else
    log "Forzando SIGKILL a PID $PID..."
    kill -9 "$PID" 2>/dev/null || true
    rm -f "$PID_FILE"
    log "EXO forzado a detener (PID $PID)"
    echo "EXO forzado a detener (PID $PID)"
fi
