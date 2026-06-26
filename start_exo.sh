#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

check_deps nix pgrep

# Verificar si ya está corriendo
if is_exo_running; then
    log "EXO ya está en ejecución (PID $(find_exo_pid)). Abortando."
    echo "EXO ya está corriendo. PID: $(find_exo_pid)"
    exit 0
fi

# Verificar directorio
if [ ! -d "$EXO_DIR" ]; then
    error "Directorio $EXO_DIR no existe"
fi

log "Iniciando EXO desde $EXO_DIR"
cleanup_events

cd "$EXO_DIR"

NIX_BIN=$(command -v nix)
if [ -z "$NIX_BIN" ]; then
    error "No se encontró 'nix' en el PATH"
fi

nohup "$NIX_BIN" run .#exo --print-build-logs >> "$LOG_FILE" 2>&1 &
EXO_PID=$!
echo "$EXO_PID" > "$PID_FILE"

log "EXO iniciado con PID $EXO_PID"
echo "EXO iniciado (PID $EXO_PID). Log: $LOG_FILE"
