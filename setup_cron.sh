#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

CRON_LINE="0 0 * * * $SCRIPT_DIR/update_exo.sh"
CRON_ID="# exo-auto-update"

usage() {
    echo "Uso: $0 {install|remove|status}"
    echo ""
    echo "  install   Instala el cron job para actualizar EXO diariamente a las 00:00"
    echo "  remove    Elimina el cron job"
    echo "  status    Muestra el estado del cron job"
    exit 1
}

case "${1:-help}" in
    install)
        if crontab -l 2>/dev/null | grep -q "$CRON_ID"; then
            echo "El cron job ya está instalado."
            crontab -l 2>/dev/null | grep "$CRON_ID"
        else
            (crontab -l 2>/dev/null || true; echo "$CRON_LINE  $CRON_ID") | crontab -
            echo "Cron job instalado:"
            echo "  $CRON_LINE"
            log "Cron job instalado para update diario a las 00:00"
        fi
        ;;
    remove)
        if crontab -l 2>/dev/null | grep -q "$CRON_ID"; then
            crontab -l 2>/dev/null | sed "/$CRON_ID/d" | crontab -
            echo "Cron job eliminado."
            log "Cron job de update eliminado"
        else
            echo "No hay cron job instalado."
        fi
        ;;
    status)
        echo "--- Estado del cron job ---"
        if crontab -l 2>/dev/null | grep -q "$CRON_ID"; then
            echo "Instalado:"
            crontab -l 2>/dev/null | grep "$CRON_ID"
        else
            echo "No instalado"
        fi
        echo ""
        echo "Último update:"
        if [ -f "$LAST_UPDATE_FILE" ]; then
            ts=$(cat "$LAST_UPDATE_FILE")
            echo "  $(date -d "@$ts" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "$ts")"
        else
            echo "  Nunca"
        fi
        ;;
    *)
        usage
        ;;
esac
