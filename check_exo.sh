#!/bin/bash

# Buscamos el proceso 'exo'. Si no existe, ejecutamos el script de inicio.
if ! pgrep -f "bin/exo" > /dev/null
then
    echo "$(date): EXO no detectado. Reiniciando con Nix..." >> /Users/jupyter/exo.log
    /Users/jupyter/start_exo.sh &
fi
