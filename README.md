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
|---|---|---|
| `EXO_DIR` | `$HOME/exo` | Directorio del proyecto exo |
| `LOG_FILE` | `$HOME/exo.log` | Archivo de log |
| `PID_FILE` | `/tmp/exo.pid` | PID del proceso exo |
| `LOCK_FILE` | `/tmp/exo_check.lock` | Lock para check_exo |
| `EXO_PATTERN` | `nix.*run.*exo` | Patrón pgrep para detectar exo |
| `BACKUP_DIR` | `$HOME/exo_backup` | Backups pre-update |
| `MIN_DISK_MB` | `1024` | Espacio mínimo para update |
| `LAST_UPDATE_FILE` | `$HOME/.exo_last_update` | Timestamp del último update |
| `API_BASE_URL` | `http://localhost:52415` | API de exo |
| `GITHUB_REPO` | `exo-explore/exo` | Repo de GitHub |

También se pueden exportar como variables de entorno.

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
|---|---|
| `--yes` | Salta la confirmación interactiva |
| `--force` | Ignora el throttle de 24h entre updates |
| `--dry-run` | Modo simulación, no modifica nada |

### `setup_cron.sh`

Gestiona un cron job que ejecuta `update_exo.sh` diariamente a las 00:00.

```bash
./setup_cron.sh install    # instalar cron
./setup_cron.sh remove     # eliminar cron
./setup_cron.sh status     # ver estado
```

## Servicio launchd (macOS)

Gestiona exo como un servicio del sistema que arranca al iniciar sesión y se reinicia automáticamente si falla.

```bash
./setup_service.sh install     # instalar servicios
./setup_service.sh remove      # eliminar servicios
./setup_service.sh status      # ver estado
```

Genera dos plists en `~/Library/LaunchAgents/`:

| Plist | Función |
|---|---|
| `com.exo.exo.plist` | Proceso principal con auto-reinicio (`KeepAlive`) |
| `com.exo.update.plist` | Update diario a las 00:00 (`StartCalendarInterval`) |

El servicio usa `start_exo.sh --foreground` para que launchd gestione el ciclo de vida.

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

- El rollback de `update_exo.sh` restaura el backup automáticamente si falla el clone o la validación
- Los backups se rotan automáticamente (se mantienen los últimos 5)
- El check diario evita actualizar más de una vez cada 24h (salta con `--force`)
- El lock de `check_exo.sh` evita múltiples reinicios concurrentes (seguro para cron)
- `setup_service.sh` reemplaza a `setup_cron.sh` y `check_exo.sh` si usas launchd
