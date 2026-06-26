# exo-scripts

Scripts de gestión para [exo-explore/exo](https://github.com/exo-explore/exo), un sistema de inferencia ML distribuido.

## Requisitos

- Bash 4+
- `git`, `curl`, `python3`, `pgrep`
- `nix` (para ejecutar exo)
- `bats` (solo para tests)

## Despliegue

```bash
cp -r scripts_exo/ "$HOME/exo-scripts/"
```

Los scripts se auto-descubren entre sí usando rutas relativas, por lo que pueden vivir en cualquier directorio.

## Configuración

Copiar `exo.conf.sample` a `~/.exo.conf` y ajustar:

```bash
cp exo.conf.sample ~/.exo.conf
# editar ~/.exo.conf con tus valores
```

Variables disponibles:

| Variable | Default | Descripción |
|---|---|---|---|
| `EXO_CONF` | `$HOME/.exo.conf` | Ruta al archivo de configuración |
| `EXO_DIR` | `$HOME/exo` | Directorio del proyecto exo |
| `LOG_FILE` | `$HOME/exo.log` | Archivo de log |
| `PID_FILE` | `/tmp/exo.pid` | PID del proceso exo |
| `LOCK_FILE` | `/tmp/exo_check.lock` | Lock para check_exo |
| `EXO_PATTERN` | `nix.*run.*exo` | Patrón pgrep para detectar exo |
| `BACKUP_DIR` | `$HOME/exo_backup` | Backups pre-update |
| `MIN_DISK_MB` | `1024` | Espacio mínimo requerido en disco para update |
| `LAST_UPDATE_FILE` | `$HOME/.exo_last_update` | Timestamp del último update |
| `MODELS_STATE_FILE` | `/tmp/exo_models.json` | Estado de modelos activos para backup/restore |
| `API_BASE_URL` | `http://localhost:52415` | URL base de la API REST de exo |
| `GITHUB_REPO` | `exo-explore/exo` | Repositorio de GitHub |

El archivo `~/.exo.conf` se **auto-carga** al ejecutar cualquier script (vía `exo_lib.sh`). También se pueden exportar las variables directamente en el entorno.

## Scripts

### `start_exo.sh`

Inicia el proceso exo con `nix run .#exo`. Verifica que no haya otra instancia corriendo y escribe el PID en `$PID_FILE`.

```bash
./start_exo.sh                     # modo background (por defecto)
./start_exo.sh --foreground        # modo foreground (para launchd/systemd)
```

### `stop_exo.sh`

Detiene exo gracefulmente (SIGTERM + wait 5s, fallback a SIGKILL).

```bash
./stop_exo.sh
```

### `check_exo.sh`

Monitor que verifica si exo está corriendo y lo reinicia automáticamente si no. Usa un lock atómico para evitar ejecución concurrente. Ideal para cron.

```bash
./check_exo.sh
```

### `update_exo.sh`

Actualiza exo a la última versión de GitHub. Guarda modelos activos, detiene exo, crea backup, clona, valida integridad, restaura modelos.

```bash
./update_exo.sh                # con confirmación interactiva
./update_exo.sh --yes          # sin preguntar
./update_exo.sh --force        # salta el check diario
./update_exo.sh --dry-run      # solo muestra qué haría
```

Flags:

| Flag | Descripción |
|---|---|---|
| `--yes` | Salta la confirmación interactiva |
| `--force` | Ignora el throttle de 24h entre updates |
| `--dry-run` | Modo simulación, no modifica nada |

**Protecciones:**

- **Rollback automático**: si el `git clone` falla o el repositorio clonado no contiene `flake.nix`, se restaura el backup automáticamente. El backup se crea justo antes de borrar `$EXO_DIR`.
- **Validación de integridad**: después de clonar verifica que exista `$EXO_DIR/flake.nix`. Si falta, se considera clon corrupto y se dispara el rollback.
- **Rotación de backups**: los backups antiguos se limpian automáticamente (se mantienen los últimos 5). Configurable en `rotate_backups()`.
- **Throttle diario**: solo permite un update cada 24h. Salta con `--force`.

### `setup_cron.sh`

Gestiona un cron job que ejecuta `update_exo.sh` diariamente a las 00:00.

```bash
./setup_cron.sh install    # instalar cron
./setup_cron.sh remove     # eliminar cron
./setup_cron.sh status     # ver estado
```

## Servicio launchd (macOS)

Gestiona exo como un servicio launchd que arranca al iniciar sesión, se reinicia automáticamente si falla y se actualiza cada medianoche.

```bash
./setup_service.sh install     # generar plists y cargar servicios
./setup_service.sh remove      # descargar y eliminar plists
./setup_service.sh status      # ver estado de los servicios
```

Genera dos archivos en `~/Library/LaunchAgents/`:

| Plist | Comportamiento | Descripción |
|---|---|---|
| `com.exo.exo.plist` | `RunAtLoad` + `KeepAlive` | Proceso principal: arranca al iniciar sesión y se reinicia automáticamente si falla. Usa `start_exo.sh --foreground` |
| `com.exo.update.plist` | `StartCalendarInterval` (00:00) | Update diario: ejecuta `update_exo.sh --yes` cada medianoche |

**Flujo launchd:**

1. Al iniciar sesión, launchd arranca `start_exo.sh --foreground`
2. `start_exo.sh` ejecuta `exec nix run .#exo` (foreground), launchd mantiene el PID
3. Si el proceso se cae, launchd lo reinicia automáticamente (con throttle de 10s)
4. A las 00:00, launchd ejecuta `update_exo.sh --yes` (oneshot)
5. Los logs van a `$LOG_FILE` configurado en `~/.exo.conf`

**Ventajas sobre cron + check_exo.sh:**
- Arranque automático al boot/inicio de sesión
- No necesita polling (launchd notifica cambios de estado)
- Logging integrado (o via `$LOG_FILE`)

> **Nota**: `setup_service.sh` reemplaza a `setup_cron.sh` y `check_exo.sh` cuando se usa launchd.

## Tests

Requiere [bats](https://github.com/bats-core/bats-core):

```bash
npm install -g bats
./tests/run_tests.sh
```

57 tests que cubren:

- Funciones de `exo_lib.sh` (log, PID, backup, version check, API helpers)
- Ciclo de vida start/stop
- Monitor check_exo
- Update con rollback y validación
- Gestión de cron y servicios

## Notas

- El check diario evita actualizar más de una vez cada 24h (salta con `--force`)
- El lock de `check_exo.sh` evita múltiples reinicios concurrentes (seguro para cron)
- `setup_service.sh` reemplaza a `setup_cron.sh` + `check_exo.sh` cuando usas launchd

### Comparativa de modos de operación

| Modo | Arranque automático | Auto-reinicio | Update automático | Dependencias |
|---|---|---|---|---|
| **cron + check** | ❌ (manual) | ✅ (cada minuto) | ✅ (00:00) | `crontab`, `check_exo.sh` |
| **launchd** | ✅ (RunAtLoad) | ✅ (KeepAlive) | ✅ (timer diario) | `setup_service.sh` |
| **manual** | ❌ | ❌ | ❌ | `start_exo.sh` / `stop_exo.sh` |

launchd es el modo recomendado en macOS: arranque limpio, sin polling, tolerante a fallos.
