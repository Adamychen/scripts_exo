load helpers/setup.bash

setup_file() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    cp "$PROJECT_ROOT/start_exo.sh" "$PROJECT_ROOT/.start_exo.bak"
    cat > "$PROJECT_ROOT/start_exo.sh" <<'SCRIPT'
#!/bin/bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/exo_lib.sh"
echo "99999" > "$PID_FILE"
echo "EXO iniciado (PID 99999). Log: $LOG_FILE"
SCRIPT
}

teardown_file() {
    PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    if [ -f "$PROJECT_ROOT/.start_exo.bak" ]; then
        cp "$PROJECT_ROOT/.start_exo.bak" "$PROJECT_ROOT/start_exo.sh"
        rm -f "$PROJECT_ROOT/.start_exo.bak"
    fi
}

@test "check_exo: EXO corriendo no hace nada" {
    MOCK_PGREP_PID=12345 run "$PROJECT_ROOT/check_exo.sh"
    [ "$status" -eq 0 ]
}

@test "check_exo: EXO caído lo reinicia" {
    run "$PROJECT_ROOT/check_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO no está corriendo"* ]]
}

@test "check_exo: intenta verificar el proceso tras iniciar" {
    run "$PROJECT_ROOT/check_exo.sh"
    [ "$status" -eq 0 ]
    [[ "$output" == *"EXO no arrancó"* ]]
}
