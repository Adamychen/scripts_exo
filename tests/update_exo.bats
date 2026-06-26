load helpers/setup.bash

teardown() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    fi
    rm -rf "${TEST_DIR:-}"
}

@test "update: dry-run no modifica nada" {
    run "$PROJECT_ROOT/update_exo.sh" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"DRY-RUN"* ]]
    [ ! -f "$PID_FILE" ]
}

@test "update: --yes salta confirmación" {
    echo "content" > "$EXO_DIR/flake.nix"
    run "$PROJECT_ROOT/update_exo.sh" --yes --force
    [ "$status" -eq 1 ]
    [[ "$output" == *"Clonando EXO"* ]]
}

@test "update: version check detecta nueva versión" {
    MOCK_GIT_TAG=v0.9.0 run "$PROJECT_ROOT/update_exo.sh" --yes --force
    [ "$status" -eq 1 ]
    [[ "$output" == *"Nueva versión disponible"* ]]
}

@test "update: sin nueva versión sale temprano" {
    MOCK_GIT_TAG=v2.0.0 MOCK_GITHUB_RESPONSE='{"tag_name": "v2.0.0"}' run "$PROJECT_ROOT/update_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO ya está actualizado"* ]]
}

@test "update: backup se crea antes de intentar clonar" {
    echo "content" > "$EXO_DIR/flake.nix"
    run "$PROJECT_ROOT/update_exo.sh" --yes --force
    run find "$BACKUP_DIR" -name flake.nix 2>/dev/null
    [ -n "$output" ]
}

@test "update: clon corrupto dispara rollback y restaura backup" {
    echo "original-data" > "$EXO_DIR/flake.nix"
    run "$PROJECT_ROOT/update_exo.sh" --yes --force
    [ "$status" -eq 1 ]
    [[ "$(cat "$EXO_DIR/flake.nix" 2>/dev/null)" == "original-data" ]]
}

@test "update: rotate_backups se llama" {
    mkdir -p "$BACKUP_DIR/backup.old.1" "$BACKUP_DIR/backup.old.2"
    echo "content" > "$EXO_DIR/flake.nix"
    run "$PROJECT_ROOT/update_exo.sh" --yes --force
    run rotate_backups 5
    [ "$status" -eq 0 ]
}
