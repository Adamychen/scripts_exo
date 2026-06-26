#!/bin/bash

export PATH="/nix/var/nix/profiles/default/bin:/Users/jupyter/.nix-profile/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

cd /Users/jupyter/exo/

echo "$(date): Iniciando EXO" >> /Users/jupyter/exo.log

# Clear logs on every start to prevent stale Nack loops
rm -rf ~/.exo/event_log/

NIX_BIN=$(command -v nix)

exec "$NIX_BIN" run .#exo --print-build-logs >> /Users/jupyter/exo.log 2>&1
