#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"

FORCE=false
DRY_RUN=false
YES=false
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=true ;;
        --dry-run) DRY_RUN=true ;;
        --yes) YES=true ;;
    esac
done

echo "--- Inicio de actualización de EXO ---"
log "--- Inicio de actualización ---"

if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Modo simulación activado"
    log "[DRY-RUN] Modo simulación activado"
fi

# Check diario (salta con --force)
if [ "$FORCE" = false ]; then
    check_daily
fi

# Dependencias
check_deps git curl python3

# Verificar nueva versión
VERSION_INFO=$(check_latest_version || true)
if [ -z "$VERSION_INFO" ]; then
    echo "EXO ya está actualizado. Última versión local."
    log "No hay nueva versión disponible"
    update_timestamp
    exit 0
fi

echo "Nueva versión disponible: $VERSION_INFO"
log "Nueva versión disponible: $VERSION_INFO"

if [ "$DRY_RUN" = true ]; then
    echo "[DRY-RUN] Se habría actualizado a $VERSION_INFO"
    log "[DRY-RUN] Se habría actualizado a $VERSION_INFO"
    update_timestamp
    exit 0
fi

# Confirmación interactiva
if [ "$YES" = false ]; then
    echo "Se actualizará EXO de $(git -C "$EXO_DIR" describe --tags 2>/dev/null || echo "unknown") a $VERSION_INFO"
    read -r -p "¿Continuar? [s/N] " respuesta
    case "$respuesta" in
        [sSyY]*) ;;
        *) echo "Actualización cancelada."; exit 0 ;;
    esac
fi

# Guardar modelos activos antes de detener
save_active_models || true

# Detener EXO
echo "Deteniendo EXO..."
"$SCRIPT_DIR/stop_exo.sh" || true

# Backup
echo "Creando backup..."
BACKUP_PATH=$(backup_dir "$EXO_DIR" || true)
if [ -n "$BACKUP_PATH" ]; then
    echo "Backup creado: $BACKUP_PATH"
fi

# Espacio en disco
check_disk_space "$(dirname "$EXO_DIR")"

# --- Rollback automático: si algo falla de aquí en adelante, restaura el backup ---
ROLLBACK_ACTIVE=false
rollback_on_fail() {
    local exit_code=$?
    if [ "$exit_code" -ne 0 ] && [ "$ROLLBACK_ACTIVE" = true ] && [ -n "${BACKUP_PATH:-}" ] && [ -d "$BACKUP_PATH" ]; then
        echo "ERROR: Falló la actualización. Restaurando backup..."
        log "ERROR: Falló la actualización. Restaurando backup desde $BACKUP_PATH"
        rm -rf "$EXO_DIR"
        cp -a "$BACKUP_PATH" "$EXO_DIR"
        echo "Backup restaurado: $EXO_DIR"
        log "Backup restaurado desde $BACKUP_PATH"
    fi
}
trap rollback_on_fail EXIT

ROLLBACK_ACTIVE=true

# Clonar nuevo
rm -rf "$EXO_DIR"
echo "Clonando EXO $VERSION_INFO..."
git clone "https://github.com/$GITHUB_REPO" "$EXO_DIR"

# Validar integridad del clon
if [ ! -f "$EXO_DIR/flake.nix" ]; then
    error "El clon no contiene flake.nix. Posible clon corrupto."
fi

ROLLBACK_ACTIVE=false

# Iniciar EXO
echo "Iniciando EXO..."
"$SCRIPT_DIR/start_exo.sh" || {
    echo "ERROR: No se pudo iniciar EXO"
    log "ERROR: No se pudo iniciar EXO después del update"
    exit 1
}

# Esperar a que la API esté lista
if wait_for_api 90; then
    restore_active_models || true
else
    warn "EXO iniciado pero la API no responde. Los modelos se pueden desplegar manualmente."
fi

update_timestamp
rotate_backups 5

echo "--- Actualización completada a $VERSION_INFO ---"
log "--- Actualización completada a $VERSION_INFO ---"
