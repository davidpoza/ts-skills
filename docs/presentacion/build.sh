#!/usr/bin/env bash
# Genera los diagramas (Mermaid → PNG) y compila la presentación a PDF con Marp.
# Requiere Node y un Chrome/Chromium (Marp lo busca solo; si no, exporta CHROME_PATH).
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# PNG a alta resolución: el texto queda fijado con la fuente con la que Mermaid lo mide.
for src in "$DIR"/diagramas/*.mmd; do
  npx -y -p @mermaid-js/mermaid-cli mmdc -q -i "$src" -o "${src%.mmd}.png" \
    -c "$DIR/diagramas/mermaid.config.json" -b white -s 3
done

# < /dev/null: sin terminal, Marp se queda esperando entrada estándar
npx -y @marp-team/marp-cli "$DIR/presentacion.md" --pdf --html --allow-local-files -o "$DIR/presentacion.pdf" < /dev/null
echo "✓ $DIR/presentacion.pdf"
