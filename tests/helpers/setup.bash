setup() {
    PROJECT_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

    TEST_DIR=$(mktemp -d)
    MOCK_DIR="$TEST_DIR/mocks"
    mkdir -p "$MOCK_DIR"

    export EXO_DIR="$TEST_DIR/exo"
    export LOG_FILE="$TEST_DIR/exo.log"
    export PID_FILE="$TEST_DIR/exo.pid"
    export LOCK_FILE="$TEST_DIR/exo_check.lock"
    export BACKUP_DIR="$TEST_DIR/exo_backup"
    export LAST_UPDATE_FILE="$TEST_DIR/.exo_last_update"
    export MODELS_STATE_FILE="$TEST_DIR/exo_models.json"
    export MIN_DISK_MB=1024
    export GITHUB_REPO="exo-explore/exo"
    export API_BASE_URL="http://localhost:52415"

    mkdir -p "$EXO_DIR" "$BACKUP_DIR"
    export PATH="$MOCK_DIR:$PATH"

    source "$PROJECT_ROOT/exo_lib.sh"

    # --- Mock executables ---
    cat > "$MOCK_DIR/nix" <<MOCK
#!/bin/bash
exec sleep 3600
MOCK
    chmod +x "$MOCK_DIR/nix"

    # Mock: git
    git() {
        case "$*" in
            *describe*--tags*) echo "${MOCK_GIT_TAG:-v1.0.0}" ;;
            *) return 0 ;;
        esac
    }
    export -f git

    # Mock: curl
    curl() {
        if [ -n "${MOCK_CURL_FAIL:-}" ]; then
            return 1
        fi
        if [[ "$*" == *"/releases/latest"* ]]; then
            echo "${MOCK_GITHUB_RESPONSE:-{\"tag_name\": \"v2.0.0\"}}"
        elif [[ "$*" == *"/state/instances"* ]]; then
            cat "${MOCK_INSTANCES_FILE:-/dev/null}" 2>/dev/null || echo "{}"
        elif [[ "$*" == *"/state"* ]]; then
            if [ -n "${MOCK_API_READY:-}" ]; then echo "200"; else return 1; fi
        else
            echo "mock-curl-output"
        fi
    }
    export -f curl

    # Mock: df
    df() {
        if [[ "$*" == *"-m"* ]]; then
            echo "Filesystem 1M-blocks Used Available Use% Mounted on"
            echo "tmpfs 10000 1000 ${MOCK_DF_AVAILABLE:-9000} 10% /"
        else
            echo "Filesystem 1K-blocks Used Available Use% Mounted on"
            echo "tmpfs 10000000 1000000 ${MOCK_DF_AVAILABLE:-9000000} 10% /"
        fi
    }
    export -f df

    # Mock: pgrep
    pgrep() {
        if [ -n "${MOCK_PGREP_PID:-}" ]; then
            echo "$MOCK_PGREP_PID"; return 0
        fi
        return 1
    }
    export -f pgrep

    # Mock: python3
    REAL_PYTHON3=$(command -v python3)
    export REAL_PYTHON3

    python3() {
        if [[ "$*" == *"urllib"* ]]; then
            if [ -n "${MOCK_PYTHON3_FAIL:-}" ]; then
                return 1
            fi
            echo "Restaurados: 1 OK, 0 fallos"
        else
            "$REAL_PYTHON3" "$@"
        fi
    }
    export -f python3
}

teardown() {
    rm -rf "${TEST_DIR:-}"
}
