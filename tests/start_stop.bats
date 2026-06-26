load helpers/setup.bash

teardown() {
    if [ -f "$PID_FILE" ]; then
        local pid
        pid=$(cat "$PID_FILE" 2>/dev/null)
        [ -n "$pid" ] && kill "$pid" 2>/dev/null || true
    fi
    rm -rf "${TEST_DIR:-}"
}

# ---------- start_exo.sh ----------

@test "start_exo: ya corriendo sale con mensaje" {
    MOCK_PGREP_PID=12345 run "$PROJECT_ROOT/start_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO ya está corriendo"* ]]
}

@test "start_exo: sin directorio lanza error" {
    rm -rf "$EXO_DIR"
    run "$PROJECT_ROOT/start_exo.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Directorio"*"no existe"* ]]
}

@test "start_exo: inicia y escribe PID file" {
    run "$PROJECT_ROOT/start_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO iniciado"* ]]
    [ -f "$PID_FILE" ]
    [ -n "$(cat "$PID_FILE")" ]
}

@test "start_exo: no inicia dos veces" {
    run "$PROJECT_ROOT/start_exo.sh"
    [ "$status" -eq 0 ]
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    MOCK_PGREP_PID="$pid" run "$PROJECT_ROOT/start_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO ya está corriendo"* ]]
}

# ---------- stop_exo.sh ----------

@test "stop_exo: sin proceso sale limpio" {
    run "$PROJECT_ROOT/stop_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No hay proceso EXO activo"* ]]
}

@test "stop_exo: detiene proceso y limpia PID file" {
    run "$PROJECT_ROOT/start_exo.sh"
    [ "$status" -eq 0 ]
    local pid
    pid=$(cat "$PID_FILE" 2>/dev/null)
    [ -n "$pid" ]

    run "$PROJECT_ROOT/stop_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO detenido"* ]]
    [ ! -f "$PID_FILE" ]
}
