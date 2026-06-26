#!/bin/bash

# --- Funciones compartidas para scripts de exo ---
# Uso: source "$(dirname "$0")/exo_lib.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- Cargar configuración del usuario ----
CONF_FILE="${EXO_CONF:-$HOME/.exo.conf}"
[ -f "$CONF_FILE" ] && source "$CONF_FILE"

# ---- Configuración con defaults ----
EXO_DIR="${EXO_DIR:-$HOME/exo}"
LOG_FILE="${LOG_FILE:-$HOME/exo.log}"
PID_FILE="${PID_FILE:-/tmp/exo.pid}"
LOCK_FILE="${LOCK_FILE:-/tmp/exo_check.lock}"
EXO_PATTERN="${EXO_PATTERN:-"nix.*run.*exo"}"
BACKUP_DIR="${BACKUP_DIR:-$HOME/exo_backup}"
MIN_DISK_MB="${MIN_DISK_MB:-1024}"

# ---- Logging ----
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOG_FILE"
}

error() {
    log "ERROR: $*"
    echo "ERROR: $*" >&2
    exit 1
}

warn() {
    log "WARN: $*"
    echo "WARN: $*" >&2
}

# ---- Búsqueda de PID ----
find_exo_pid() {
    # Intentar leer PID file primero
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            echo "$pid"
            return 0
        fi
        rm -f "$PID_FILE"
    fi

    # Fallback: buscar por patrón, excluyendo el shell actual y procesos del sistema
    local pids
    pids=$(pgrep -f "$EXO_PATTERN" 2>/dev/null | grep -v -E "$$|$PPID" || true)
    if [ -n "$pids" ]; then
        echo "$pids" | head -1
        return 0
    fi

    return 1
}

is_exo_running() {
    find_exo_pid > /dev/null 2>&1
}

# ---- Espera activa ----
wait_for_exit() {
    local pid="$1"
    local max_seconds="${2:-5}"

    for ((i=0; i<max_seconds; i++)); do
        if ! kill -0 "$pid" 2>/dev/null; then
            log "Proceso $pid terminado después de ${i}s"
            return 0
        fi
        sleep 1
    done

    log "Proceso $pid no terminó después de ${max_seconds}s"
    return 1
}

# ---- Verificación de dependencias ----
check_deps() {
    local deps=("$@")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        error "Faltan dependencias: ${missing[*]}"
    fi
}

# ---- Lock atómico para check_exo ----
acquire_lock() {
    if ! mkdir "$LOCK_FILE" 2>/dev/null; then
        log "check_exo ya está en ejecución (lock en $LOCK_FILE)"
        exit 0
    fi
    # Registrar cleanup al salir
    trap 'rm -rf "$LOCK_FILE"' EXIT
}

# ---- Espacio en disco ----
check_disk_space() {
    local dir="$1"
    local min_mb="${2:-$MIN_DISK_MB}"
    local available

    available=$(df -m "$dir" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$available" ] || [ "$available" -lt "$min_mb" ]; then
        error "Espacio insuficiente en $dir: ${available:-0}MB disponibles (mínimo ${min_mb}MB)"
    fi
}

# ---- Limpieza de eventos ----
cleanup_events() {
    local event_dir="$HOME/.exo/event_log"
    if [ -d "$event_dir" ]; then
        rm -rf "$event_dir"
        log "Event log limpiado: $event_dir"
    fi
}

# ---- Backup de directorio ----
backup_dir() {
    local src="$1"
    local backup_name
    backup_name="$(basename "$src").$(date '+%Y%m%d_%H%M%S')"

    if [ -d "$src" ]; then
        mkdir -p "$BACKUP_DIR"
        cp -a "$src" "$BACKUP_DIR/$backup_name"
        log "Backup creado: $BACKUP_DIR/$backup_name"
        echo "$BACKUP_DIR/$backup_name"
    else
        warn "No se encontró $src para respaldar"
        return 1
    fi
}

# ---- Rotación de backups ----
rotate_backups() {
    local max_backups="${1:-5}"
    local count=0

    for backup in "$BACKUP_DIR"/*/; do
        [ -d "$backup" ] && count=$((count + 1))
    done

    if [ "$count" -gt "$max_backups" ]; then
        local to_remove=$((count - max_backups))
        ls -1t "$BACKUP_DIR" | tail -n "$to_remove" | while IFS= read -r backup; do
            rm -rf "$BACKUP_DIR/$backup"
            log "Backup antiguo eliminado: $backup"
        done
    fi
}

# ---- Variables de update ----
LAST_UPDATE_FILE="${LAST_UPDATE_FILE:-$HOME/.exo_last_update}"
MODELS_STATE_FILE="${MODELS_STATE_FILE:-/tmp/exo_models.json}"
API_BASE_URL="${API_BASE_URL:-http://localhost:52415}"
GITHUB_REPO="${GITHUB_REPO:-exo-explore/exo}"

# ---- Check diario (24h) ----
check_daily() {
    if [ -f "$LAST_UPDATE_FILE" ]; then
        local last
        last=$(cat "$LAST_UPDATE_FILE" 2>/dev/null || echo 0)
        local now
        now=$(date '+%s')
        local elapsed=$((now - last))
        if [ "$elapsed" -lt 86400 ]; then
            log "Check diario: pasaron ${elapsed}s, faltan $((86400 - elapsed))s para el próximo"
            exit 0
        fi
    fi
}

update_timestamp() {
    date '+%s' > "$LAST_UPDATE_FILE"
    log "Timestamp de update actualizado: $(date -d "@$(cat "$LAST_UPDATE_FILE")" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || cat "$LAST_UPDATE_FILE")"
}

# ---- Comparación de versiones ----
check_latest_version() {
    local local_tag remote_tag

    if [ -d "$EXO_DIR" ]; then
        local_tag=$(git -C "$EXO_DIR" describe --tags 2>/dev/null || echo "unknown")
    else
        local_tag="none"
        log "Directorio $EXO_DIR no existe - primera instalación"
    fi

    remote_tag=$(curl -sf "https://api.github.com/repos/$GITHUB_REPO/releases/latest" 2>/dev/null \
        | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d.get("tag_name",""))' 2>/dev/null) || {
        warn "No se pudo obtener la última versión de GitHub (rate limit?)"
        return 1
    }

    if [ -z "$remote_tag" ]; then
        warn "Respuesta inválida de GitHub API"
        return 1
    fi

    log "Versión local: ${local_tag:-none} | Versión remota: $remote_tag"

    if [ "$local_tag" = "none" ]; then
        echo "$remote_tag"
        return 0
    fi

    local higher
    higher=$(printf '%s\n' "$local_tag" "$remote_tag" | sort -V | tail -1)

    if [ "$higher" != "$local_tag" ]; then
        echo "$remote_tag"
        return 0
    fi

    log "Ya está en la última versión ($local_tag)"
    return 1
}

# ---- Capturar modelos activos ----
save_active_models() {
    local data
    data=$(curl -sf "$API_BASE_URL/state/instances" 2>/dev/null) || {
        warn "No se pudo conectar a la API de exo (puerto 52415). Los modelos no se restaurarán."
        rm -f "$MODELS_STATE_FILE"
        return 1
    }

    echo "$data" | python3 -c '
import json, sys

instances = json.load(sys.stdin)
result = []
for inst_id, inst in instances.items():
    sa = inst.get("shard_assignments", {})
    model_id = sa.get("model_id", "")
    if not model_id:
        continue

    sharding = "Pipeline"
    for runner, shard in sa.get("runner_to_shard", {}).items():
        stype = shard.get("type", "")
        if "Tensor" in stype:
            sharding = "Tensor"
            break

    if "hosts_by_node" in inst:
        instance_meta = "MlxRing"
    elif "jaccl_devices" in inst:
        instance_meta = "MlxJaccl"
    else:
        instance_meta = "MlxRing"

    min_nodes = max(len(sa.get("node_to_runner", {})), 1)

    result.append({
        "model_id": model_id,
        "sharding": sharding,
        "instance_meta": instance_meta,
        "min_nodes": min_nodes
    })

with open("'"$MODELS_STATE_FILE"'", "w") as f:
    json.dump(result, f, indent=2)
'
    log "Modelos activos guardados en $MODELS_STATE_FILE"
}

# ---- Restaurar modelos guardados ----
restore_active_models() {
    if [ ! -f "$MODELS_STATE_FILE" ]; then
        log "No hay archivo de modelos para restaurar"
        return 0
    fi

    local count
    count=$(python3 -c "import json; print(len(json.load(open('$MODELS_STATE_FILE'))))" 2>/dev/null || echo 0)

    if [ "$count" -eq 0 ]; then
        log "Archivo de modelos vacío, nada que restaurar"
        return 0
    fi

    log "Restaurando $count instancia(s) de modelo..."

    python3 -c '
import json, urllib.request, sys

with open("'"$MODELS_STATE_FILE"'") as f:
    models = json.load(f)

api = "'"$API_BASE_URL"'"
headers = {"Content-Type": "application/json"}
ok = 0
fail = 0

for m in models:
    body = json.dumps({
        "model_id": m["model_id"],
        "sharding": m["sharding"],
        "instance_meta": m["instance_meta"],
        "min_nodes": m["min_nodes"]
    }).encode()
    try:
        req = urllib.request.Request(api + "/place_instance", data=body, headers=headers, method="POST")
        resp = urllib.request.urlopen(req, timeout=30)
        ok += 1
        print(f"  OK: {m[\"model_id\"]} ({m[\"sharding\"]}, {m[\"instance_meta\"]}, {m[\"min_nodes\"]} nodos)")
    except Exception as e:
        fail += 1
        print(f"  FAIL: {m[\"model_id\"]}: {e}", file=sys.stderr)

print(f"Restaurados: {ok} OK, {fail} fallos")
' 2>&1 | while IFS= read -r line; do log "$line"; echo "$line"; done

    rm -f "$MODELS_STATE_FILE"
}

# ---- Esperar a que la API responda ----
wait_for_api() {
    local timeout="${1:-90}"
    local interval=2
    local elapsed=0

    log "Esperando a que la API responda en $API_BASE_URL/state (timeout ${timeout}s)..."

    while [ "$elapsed" -lt "$timeout" ]; do
        local code
        code=$(curl -sf -o /dev/null -w '%{http_code}' "$API_BASE_URL/state" 2>/dev/null || true)
        if [ "$code" = "200" ]; then
            log "API respondió después de ${elapsed}s"
            return 0
        fi
        sleep "$interval"
        elapsed=$((elapsed + interval))
    done

    warn "API no respondió después de ${timeout}s"
    return 1
}
