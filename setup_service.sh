#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
EXO_LABEL="com.exo.exo"
UPDATE_LABEL="com.exo.update"

usage() {
    echo "Uso: $0 {install|remove|status}"
    echo ""
    echo "  install   Instala servicios launchd para exo (servicio + update diario)"
    echo "  remove    Elimina los servicios launchd"
    echo "  status    Muestra el estado de los servicios"
    exit 1
}

generate_exo_plist() {
    mkdir -p "$LAUNCH_AGENTS_DIR"
    cat > "$LAUNCH_AGENTS_DIR/$EXO_LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$EXO_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/start_exo.sh</string>
        <string>--foreground</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>WorkingDirectory</key>
    <string>$EXO_DIR</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
PLIST
}

generate_update_plist() {
    mkdir -p "$LAUNCH_AGENTS_DIR"
    cat > "$LAUNCH_AGENTS_DIR/$UPDATE_LABEL.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$UPDATE_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/update_exo.sh</string>
        <string>--yes</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>0</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
</dict>
</plist>
PLIST
}

case "${1:-help}" in
    install)
        echo "Generando plists..."
        generate_exo_plist
        generate_update_plist

        echo "Cargando servicios launchd..."
        launchctl load "$LAUNCH_AGENTS_DIR/$EXO_LABEL.plist" 2>/dev/null || \
            launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS_DIR/$EXO_LABEL.plist" 2>/dev/null || \
            warn "No se pudo cargar $EXO_LABEL (puede que ya esté cargado)"
        launchctl load "$LAUNCH_AGENTS_DIR/$UPDATE_LABEL.plist" 2>/dev/null || \
            launchctl bootstrap "gui/$(id -u)" "$LAUNCH_AGENTS_DIR/$UPDATE_LABEL.plist" 2>/dev/null || \
            warn "No se pudo cargar $UPDATE_LABEL (puede que ya esté cargado)"

        log "Servicios launchd instalados"
        echo "Servicios instalados:"
        echo "  $EXO_LABEL        (proceso principal, auto-reinicio)"
        echo "  $UPDATE_LABEL      (update diario a las 00:00)"
        ;;
    remove)
        echo "Descargando servicios launchd..."
        launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENTS_DIR/$EXO_LABEL.plist" 2>/dev/null || \
            launchctl unload "$LAUNCH_AGENTS_DIR/$EXO_LABEL.plist" 2>/dev/null || true
        launchctl bootout "gui/$(id -u)" "$LAUNCH_AGENTS_DIR/$UPDATE_LABEL.plist" 2>/dev/null || \
            launchctl unload "$LAUNCH_AGENTS_DIR/$UPDATE_LABEL.plist" 2>/dev/null || true

        rm -f "$LAUNCH_AGENTS_DIR/$EXO_LABEL.plist" "$LAUNCH_AGENTS_DIR/$UPDATE_LABEL.plist"
        log "Servicios launchd eliminados"
        echo "Servicios eliminados."
        ;;
    status)
        echo "--- Estado de servicios launchd ---"
        echo ""
        for label in "$EXO_LABEL" "$UPDATE_LABEL"; do
            if [ -f "$LAUNCH_AGENTS_DIR/$label.plist" ]; then
                echo "► $label (plist presente)"
                launchctl list "$label" 2>/dev/null || echo "  Estado: no cargado"
            else
                echo "► $label (no instalado)"
            fi
            echo ""
        done
        ;;
    *)
        usage
        ;;
esac
