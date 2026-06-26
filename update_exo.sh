
#!/bin/bash

# Detener el script si ocurre algún error
set -e

# Configuración de variables y rutas
BASE_DIR="/Users/jupyter"
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

echo "--- Iniciando actualización de EXO ---"

# Ir al directorio base
cd "$BASE_DIR"

# 1. Eliminar la carpeta exo existente
if [ -d "exo" ]; then
    echo "Eliminando versión anterior de 'exo'..."
    rm -rf exo
else
    echo "No se encontró carpeta 'exo' previa, continuando..."
fi
  
# 2. Clonar el repositorio
echo "Clonando el repositorio..."
git clone https://github.com/exo-explore/exo


echo "Actualización completada."


