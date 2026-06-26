load helpers/setup.bash

@test "log: escribe mensaje con timestamp en LOG_FILE" {
    log "test message"
    run cat "$LOG_FILE"
    [ "$status" -eq 0 ]
    [[ "$output" == *"test message" ]]
    [[ "$output" =~ [0-9]{4}-[0-9]{2}-[0-9]{2} ]]
}

@test "log: append en lugar de sobrescribir" {
    log "first"
    log "second"
    run wc -l < "$LOG_FILE"
    [ "$output" -eq 2 ]
}

@test "check_deps: pasa cuando todas las dependencias existen" {
    run check_deps git curl
    [ "$status" -eq 0 ]
}

@test "check_deps: falla cuando falta una dependencia" {
    run check_deps nonexistent_cmd_xyz
    [ "$status" -eq 1 ]
    [[ "$output" == *"Faltan dependencias: nonexistent_cmd_xyz"* ]]
}

@test "acquire_lock: crea el directorio lock" {
    acquire_lock
    [ -d "$LOCK_FILE" ]
    rm -rf "$LOCK_FILE"
}

@test "acquire_lock: lock doble no falla" {
    acquire_lock
    run acquire_lock
    [ "$status" -eq 0 ]
    rm -rf "$LOCK_FILE"
}

@test "find_exo_pid: no devuelve PID si el proceso no existe" {
    echo "99999" > "$PID_FILE"
    run find_exo_pid
    [ "$status" -eq 1 ]
}

@test "find_exo_pid: devuelve PID cuando el proceso existe" {
    MOCK_PGREP_PID=12345
    run find_exo_pid
    [ "$status" -eq 0 ]
    [[ "$output" == "12345" ]]
}

@test "is_exo_running: true cuando hay PID" {
    MOCK_PGREP_PID=12345
    run is_exo_running
    [ "$status" -eq 0 ]
}

@test "is_exo_running: false cuando no hay PID" {
    run is_exo_running
    [ "$status" -eq 1 ]
}

@test "wait_for_exit: detecta que un proceso terminó" {
    run wait_for_exit 99999 1
    [ "$status" -eq 0 ]
}

@test "wait_for_exit: timeout si el proceso no termina" {
    run wait_for_exit "$$" 1
    [ "$status" -eq 1 ]
}

@test "check_disk_space: pasa cuando hay suficiente espacio" {
    MOCK_DF_AVAILABLE=9000
    run check_disk_space "$TEST_DIR" 1024
    [ "$status" -eq 0 ]
}

@test "check_disk_space: falla cuando el espacio es insuficiente" {
    MOCK_DF_AVAILABLE=100
    run check_disk_space "$TEST_DIR" 1024
    [ "$status" -eq 1 ]
    [[ "$output" == *"Espacio insuficiente"* ]]
}

@test "backup_dir: crea backup del directorio" {
    echo "test" > "$EXO_DIR/test.txt"
    run backup_dir "$EXO_DIR"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [ -d "$output" ]
    [ -f "$output/test.txt" ]
}

@test "backup_dir: falla si el origen no existe" {
    run backup_dir "$TEST_DIR/nonexistent"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No se encontró"* ]]
}

@test "rotate_backups: no elimina si hay <= N backups" {
    mkdir -p "$BACKUP_DIR/backup.1" "$BACKUP_DIR/backup.2"
    run rotate_backups 5
    [ "$status" -eq 0 ]
}

@test "rotate_backups: elimina los más antiguos si hay > N" {
    mkdir -p "$BACKUP_DIR/backup.1" "$BACKUP_DIR/backup.2" "$BACKUP_DIR/backup.3" "$BACKUP_DIR/backup.4"
    run rotate_backups 2
    [ "$status" -eq 0 ]
    run ls -1 "$BACKUP_DIR" 2>/dev/null
    [ "${#lines[@]}" -le 2 ]
}

@test "check_daily: sale si el último update fue hace menos de 24h" {
    echo "$(date '+%s')" > "$LAST_UPDATE_FILE"
    run check_daily
    [ "$status" -eq 0 ]
}

@test "check_daily: continua si el último update fue hace más de 24h (no escribe log)" {
    echo "0" > "$LAST_UPDATE_FILE"
    run check_daily
    [ "$status" -eq 0 ]
    [[ ! -s "$LOG_FILE" ]]
}

@test "update_timestamp: escribe timestamp actual" {
    run update_timestamp
    [ "$status" -eq 0 ]
    [ -f "$LAST_UPDATE_FILE" ]
    run cat "$LAST_UPDATE_FILE"
    [ -n "$output" ]
    [ "$output" -gt 1000000000 ]
}

@test "check_latest_version: detecta nueva versión" {
    run check_latest_version
    [ "$status" -eq 0 ]
    [[ "$output" == "v2.0.0" ]]
}

@test "check_latest_version: dice ya actualizado si está en la última" {
    MOCK_GIT_TAG=v2.0.0
    MOCK_GITHUB_RESPONSE='{"tag_name": "v2.0.0"}'
    run check_latest_version
    [ "$status" -eq 1 ]
}

@test "check_latest_version: primera instalación si EXO_DIR no existe" {
    rm -rf "$EXO_DIR"
    run check_latest_version
    [ "$status" -eq 0 ]
    [[ "$output" == "v2.0.0" ]]
}

@test "wait_for_api: detecta cuando la API responde" {
    MOCK_API_READY=true
    run wait_for_api 5
    [ "$status" -eq 0 ]
}

@test "wait_for_api: timeout si la API no responde" {
    MOCK_CURL_FAIL=true
    unset MOCK_API_READY
    run wait_for_api 3
    [ "$status" -eq 1 ]
}

@test "save_active_models: guarda estado cuando la API responde" {
    cat > "$TEST_DIR/instances.json" <<'EOF'
{
    "inst1": {
        "shard_assignments": {
            "model_id": "llama-7b",
            "runner_to_shard": {"node1": {"type": "TensorParallel"}},
            "node_to_runner": {"node1": "runner1"}
        },
        "hosts_by_node": {"node1": ["host1"]}
    }
}
EOF
    MOCK_INSTANCES_FILE="$TEST_DIR/instances.json"
    run save_active_models
    [ "$status" -eq 0 ]
    [ -f "$MODELS_STATE_FILE" ]
}

@test "save_active_models: no falla si la API no responde" {
    MOCK_CURL_FAIL=true
    run save_active_models
    [ "$status" -eq 1 ]
    [ ! -f "$MODELS_STATE_FILE" ]
}

@test "restore_active_models: restaura modelos guardados" {
    cat > "$MODELS_STATE_FILE" <<'EOF'
[{"model_id": "llama-7b", "sharding": "Tensor", "instance_meta": "MlxRing", "min_nodes": 1}]
EOF
    run restore_active_models
    [ "$status" -eq 0 ]
    [[ "$output" == *"Restaurados: 1 OK"* ]]
    [ ! -f "$MODELS_STATE_FILE" ]
}

@test "restore_active_models: no hace nada si no hay archivo" {
    run restore_active_models
    [ "$status" -eq 0 ]
    run grep "No hay archivo" "$LOG_FILE"
    [ "$status" -eq 0 ]
}

@test "restore_active_models: no hace nada si el archivo está vacío" {
    echo '[]' > "$MODELS_STATE_FILE"
    run restore_active_models
    [ "$status" -eq 0 ]
    run grep "vacío" "$LOG_FILE"
    [ "$status" -eq 0 ]
}

@test "warn: escribe a stderr y al log" {
    run warn "alerta de prueba"
    [ "$status" -eq 0 ]
    [[ "$output" == "WARN: alerta de prueba" ]]
}

@test "error: termina con código 1 y mensaje" {
    run error "error fatal"
    [ "$status" -eq 1 ]
    [[ "$output" == "ERROR: error fatal" ]]
}

@test "cleanup_events: elimina el directorio de eventos si existe" {
    mkdir -p "$HOME/.exo/event_log"
    run cleanup_events
    [ "$status" -eq 0 ]
    [ ! -d "$HOME/.exo/event_log" ]
    rm -rf "$HOME/.exo"
}
