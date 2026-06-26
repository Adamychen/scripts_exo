#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

FOREGROUND=false
for arg in "$@"; do
    case "$arg" in
        --foreground) FOREGROUND=true ;;
    esac
done

# Nix en macOS puede no estar en PATH cuando launchd ejecuta el script
# (PATH de launchd es limitado: /usr/bin:/bin/usr/sbin:/sbin)
if [ -z "$(command -v nix 2>/dev/null)" ]; then
    for profile in \
        "$HOME/.nix-profile/etc/profile.d/nix-daemon.sh" \
        "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" \
        "/etc/profile.d/nix.sh" \
        "/etc/profile.d/nix-daemon.sh"
    do
        if [ -f "$profile" ]; then
            # shellcheck disable=SC1090
            source "$profile"
            break
        fi
    done
fi

check_deps nix pgrep

# Verificar directorio
if [ ! -d "$EXO_DIR" ]; then
    error "Directorio $EXO_DIR no existe"
fi

# En foreground mode (launchd) permitir múltiples instancias no aplica
if [ "$FOREGROUND" = false ]; then
    if is_exo_running; then
        log "EXO ya está en ejecución (PID $(find_exo_pid)). Abortando."
        echo "EXO ya está corriendo. PID: $(find_exo_pid)"
        exit 0
    fi
fi

log "Iniciando EXO desde $EXO_DIR"
cleanup_events

cd "$EXO_DIR"

NIX_BIN=$(command -v nix)
if [ -z "$NIX_BIN" ]; then
    error "No se encontró 'nix' en el PATH"
fi

if [ "$FOREGROUND" = true ]; then
    exec "$NIX_BIN" run .#exo --print-build-logs
fi

nohup "$NIX_BIN" run .#exo --print-build-logs >> "$LOG_FILE" 2>&1 &
EXO_PID=$!
echo "$EXO_PID" > "$PID_FILE"

log "EXO iniciado con PID $EXO_PID"
echo "EXO iniciado (PID $EXO_PID). Log: $LOG_FILE"
