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

UID_USER=$(id -u)

load_service() {
    local label="$1"
    local plist="$LAUNCH_AGENTS_DIR/$label.plist"

    if launchctl list "$label" 2>/dev/null | grep -q "$label"; then
        echo "  $label ya cargado. Reiniciando..."
        launchctl kickstart -kp "gui/$UID_USER/$label" 2>/dev/null || true
        return 0
    fi

    echo "  Cargando $label..."
    launchctl bootstrap "gui/$UID_USER" "$plist" 2>/dev/null || {
        warn "No se pudo cargar $label (intenta: launchctl bootstrap gui/$UID_USER $plist)"
        return 1
    }
    launchctl enable "gui/$UID_USER/$label" 2>/dev/null || true
    launchctl kickstart -kp "gui/$UID_USER/$label" 2>/dev/null || true
}

unload_service() {
    local label="$1"
    if launchctl list "$label" 2>/dev/null | grep -q "$label"; then
        echo "  Descargando $label..."
        launchctl bootout "gui/$UID_USER/$label" 2>/dev/null || \
            launchctl bootout "gui/$UID_USER" "$LAUNCH_AGENTS_DIR/$label.plist" 2>/dev/null || true
    fi
}

case "${1:-help}" in
    install)
        echo "Generando plists..."
        mkdir -p "$LAUNCH_AGENTS_DIR"
        generate_exo_plist
        generate_update_plist

        echo "Cargando servicios launchd..."
        load_service "$EXO_LABEL"
        load_service "$UPDATE_LABEL"

        log "Servicios launchd instalados"
        echo "Servicios instalados:"
        echo "  $EXO_LABEL        (proceso principal, auto-reinicio)"
        echo "  $UPDATE_LABEL      (update diario a las 00:00)"
        ;;
    remove)
        echo "Descargando servicios launchd..."
        unload_service "$EXO_LABEL"
        unload_service "$UPDATE_LABEL"

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
                launchctl print "gui/$UID_USER/$label" 2>/dev/null | head -5 || \
                    echo "  Estado: no cargado"
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
