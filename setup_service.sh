#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

EXO_LABEL="com.exo.exo"
UPDATE_LABEL="com.exo.update"
DAEMON=false
AGENT_DIR="$HOME/Library/LaunchAgents"
DAEMON_DIR="/Library/LaunchDaemons"

usage() {
    echo "Uso: $0 {install|remove|status} [--daemon]"
    echo ""
    echo "  install         Instala servicios launchd para exo"
    echo "  remove          Elimina los servicios launchd"
    echo "  status          Muestra el estado de los servicios"
    echo ""
    echo "  --daemon        Instala como LaunchDaemon del sistema (requiere sudo)"
    echo "                  Útil en servidores SSH sin sesión gráfica"
    exit 1
}

while [ $# -gt 0 ]; do
    case "$1" in
        --daemon) DAEMON=true; shift ;;
        install|remove|status) break ;;
        *) usage ;;
    esac
done

if [ "$DAEMON" = true ]; then
    PLIST_DIR="$DAEMON_DIR"
    PLIST_USER="$USER"
    SUDO="sudo"
    DOMAIN="system"
else
    PLIST_DIR="$AGENT_DIR"
    UID_USER=$(id -u)
    SUDO=""
    DOMAIN="gui/$UID_USER"
fi

generate_exo_plist() {
    if [ "$DAEMON" = true ]; then
        $SUDO mkdir -p "$PLIST_DIR"
        $SUDO tee "$PLIST_DIR/$EXO_LABEL.plist" >/dev/null <<PLIST
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
    <key>UserName</key>
    <string>$PLIST_USER</string>
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
    else
        mkdir -p "$PLIST_DIR"
        cat > "$PLIST_DIR/$EXO_LABEL.plist" <<PLIST
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
    fi
}

generate_update_plist() {
    if [ "$DAEMON" = true ]; then
        $SUDO tee "$PLIST_DIR/$UPDATE_LABEL.plist" >/dev/null <<PLIST
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
    <key>UserName</key>
    <string>$PLIST_USER</string>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>WorkingDirectory</key>
    <string>$SCRIPT_DIR</string>
</dict>
</plist>
PLIST
    else
        cat > "$PLIST_DIR/$UPDATE_LABEL.plist" <<PLIST
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
    fi
}

ensure_dirs() {
    local log_dir
    log_dir=$(dirname "$LOG_FILE")
    if [ "$DAEMON" = true ]; then
        $SUDO mkdir -p "$log_dir" "$EXO_DIR"
        $SUDO chown "$PLIST_USER:staff" "$log_dir" "$EXO_DIR"
    else
        mkdir -p "$log_dir" "$EXO_DIR"
    fi
}

load_service() {
    local label="$1"
    local plist="$PLIST_DIR/$label.plist"

    if [ "$DAEMON" = true ]; then
        if $SUDO launchctl list "$label" 2>/dev/null | grep -q "$label"; then
            echo "  $label ya cargado. Reiniciando..."
            $SUDO launchctl kickstart -kp "system/$label" 2>/dev/null || true
            return 0
        fi
    else
        if launchctl list "$label" 2>/dev/null | grep -q "$label"; then
            echo "  $label ya cargado. Reiniciando..."
            launchctl kickstart -kp "gui/$UID_USER/$label" 2>/dev/null || \
                launchctl kickstart -kp "$label" 2>/dev/null || true
            return 0
        fi
    fi

    echo "  Cargando $label..."

    if [ "$DAEMON" = true ]; then
        $SUDO launchctl load "$plist" 2>&1 || {
            error "No se pudo cargar $label. Revisa: plutil -lint $plist"
        }
        $SUDO launchctl kickstart -k "system/$label" 2>/dev/null || true
    else
        if launchctl bootstrap "$DOMAIN" "$plist" 2>/dev/null; then
            launchctl enable "$DOMAIN/$label" 2>/dev/null || true
            launchctl kickstart -kp "$DOMAIN/$label" 2>/dev/null || true
        else
            echo "  (usando launchctl load como fallback)"
            launchctl load "$plist" 2>&1 || {
                error "No se pudo cargar $label. Revisa: plutil -lint $plist"
            }
        fi
    fi
}

unload_service() {
    local label="$1"
    if [ "$DAEMON" = true ]; then
        if $SUDO launchctl list "$label" 2>/dev/null | grep -q "$label"; then
            echo "  Descargando $label..."
            $SUDO launchctl bootout "system/$label" 2>/dev/null || \
                $SUDO launchctl unload "$PLIST_DIR/$label.plist" 2>/dev/null || true
        fi
    else
        if launchctl list "$label" 2>/dev/null | grep -q "$label"; then
            echo "  Descargando $label..."
            launchctl bootout "$DOMAIN/$label" 2>/dev/null || \
                launchctl bootout "$DOMAIN" "$PLIST_DIR/$label.plist" 2>/dev/null || \
                launchctl unload "$PLIST_DIR/$label.plist" 2>/dev/null || true
        fi
    fi
}

case "${1:-help}" in
    install)
        if [ "$DAEMON" = true ]; then
            echo "Modo daemon (requiere sudo). Plists en $PLIST_DIR"
        else
            echo "Modo agente. Plists en $PLIST_DIR"
        fi
        echo "Asegurando directorios..."
        ensure_dirs

        echo "Generando plists..."
        generate_exo_plist
        generate_update_plist

        if [ "$DAEMON" = true ]; then
            $SUDO chown root:wheel "$PLIST_DIR/$EXO_LABEL.plist" "$PLIST_DIR/$UPDATE_LABEL.plist"
            $SUDO chmod 644 "$PLIST_DIR/$EXO_LABEL.plist" "$PLIST_DIR/$UPDATE_LABEL.plist"
        fi

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

        if [ "$DAEMON" = true ]; then
            $SUDO rm -f "$PLIST_DIR/$EXO_LABEL.plist" "$PLIST_DIR/$UPDATE_LABEL.plist"
        else
            rm -f "$PLIST_DIR/$EXO_LABEL.plist" "$PLIST_DIR/$UPDATE_LABEL.plist"
        fi
        log "Servicios launchd eliminados"
        echo "Servicios eliminados."
        ;;
    status)
        echo "--- Estado de servicios launchd ---"
        if [ "$DAEMON" = true ]; then
            echo "(LaunchDaemon)"
        else
            echo "(LaunchAgent)"
        fi
        echo ""
        for label in "$EXO_LABEL" "$UPDATE_LABEL"; do
            if [ -f "$PLIST_DIR/$label.plist" ]; then
                echo "► $label (plist presente)"
                if [ "$DAEMON" = true ]; then
                    $SUDO launchctl print "system/$label" 2>/dev/null | head -5 || \
                        echo "  Estado: no cargado"
                else
                    launchctl print "gui/$UID_USER/$label" 2>/dev/null | head -5 || \
                        echo "  Estado: no cargado"
                fi
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
