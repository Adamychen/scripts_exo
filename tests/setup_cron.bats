setup() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

    TEST_DIR=$(mktemp -d)
    MOCK_CRON_DIR="$TEST_DIR/cron-mock"
    mkdir -p "$MOCK_CRON_DIR"
    export MOCK_CRON_FILE="$MOCK_CRON_DIR/crontab_state"

    cat > "$MOCK_CRON_DIR/crontab" <<'SCRIPT'
#!/bin/bash
MOCK_CRON_FILE="${MOCK_CRON_FILE:-/tmp/.bats_mock_crontab}"
case "${1:-}" in
    -l)
        if [ -f "$MOCK_CRON_FILE" ]; then
            cat "$MOCK_CRON_FILE"
        fi
        exit 0
        ;;
    -*|"")
        cat > "$MOCK_CRON_FILE"
        exit 0
        ;;
    *)
        exit 1
        ;;
esac
SCRIPT
    chmod +x "$MOCK_CRON_DIR/crontab"

    export EXO_DIR="$TEST_DIR/exo"
    export LOG_FILE="$TEST_DIR/exo.log"
    export PID_FILE="$TEST_DIR/exo.pid"
    export LOCK_FILE="$TEST_DIR/exo_check.lock"
    export BACKUP_DIR="$TEST_DIR/exo_backup"
    export LAST_UPDATE_FILE="$TEST_DIR/.exo_last_update"
    export MODELS_STATE_FILE="$TEST_DIR/exo_models.json"

    mkdir -p "$EXO_DIR" "$BACKUP_DIR"
    export PATH="$MOCK_CRON_DIR:$PATH"

    source "$PROJECT_ROOT/exo_lib.sh"
}

teardown() {
    rm -rf "${TEST_DIR:-}"
}

@test "setup_cron: status dice no instalado al inicio" {
    run "$PROJECT_ROOT/setup_cron.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"No instalado"* ]]
}

@test "setup_cron: install añade cron job" {
    run "$PROJECT_ROOT/setup_cron.sh" install
    [ "$status" -eq 0 ]
    [[ "$output" == *"instalado"* ]]
    [ -f "$MOCK_CRON_FILE" ]
    grep -q "exo-auto-update" "$MOCK_CRON_FILE"
}

@test "setup_cron: install duplicado no falla" {
    run "$PROJECT_ROOT/setup_cron.sh" install
    [ "$status" -eq 0 ]
    run "$PROJECT_ROOT/setup_cron.sh" install
    [ "$status" -eq 0 ]
    [[ "$output" == *"ya está instalado"* ]]
}

@test "setup_cron: status dice instalado después de install" {
    run "$PROJECT_ROOT/setup_cron.sh" install
    run "$PROJECT_ROOT/setup_cron.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Instalado"* ]]
}

@test "setup_cron: remove elimina cron job" {
    run "$PROJECT_ROOT/setup_cron.sh" install
    run "$PROJECT_ROOT/setup_cron.sh" remove
    [ "$status" -eq 0 ]
    [[ "$output" == *"eliminado"* ]]
    if [ -f "$MOCK_CRON_FILE" ]; then
        ! grep -q "exo-auto-update" "$MOCK_CRON_FILE"
    fi
}

@test "setup_cron: remove sin instalar no falla" {
    run "$PROJECT_ROOT/setup_cron.sh" remove
    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay cron job"* ]]
}

@test "setup_cron: status muestra Nunca si no hay timestamp" {
    rm -f "$LAST_UPDATE_FILE"
    run "$PROJECT_ROOT/setup_cron.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"Nunca"* ]]
}
