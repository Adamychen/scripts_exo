#!/bin/bash

echo "$(date): Deteniendo EXO..." >> /Users/jupyter/exo.log

# 1. Intentar detenerlo de forma elegante por el nombre del ejecutable
# Buscamos procesos que contengan 'exo' en su ruta
PIDS=$(pgrep -f "exo")

if [ -z "$PIDS" ]; then
    echo "$(date): No se encontró ningún proceso de EXO corriendo." >> /Users/jupyter/exo.log
    exit 0
fi

# 2. Enviar señal de terminación (SIGTERM)
kill $PIDS

# Opcional: Esperar un momento y forzar si no cierra (SIGKILL)
sleep 2
kill -9 $PIDS 2>/dev/null

echo "$(date): EXO detenido correctamente." >> /Users/jupyter/exo.log
