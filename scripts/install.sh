#!/usr/bin/env bash
# Instala el schema sdd-incremental, la config de ejemplo y los skills sdd-* en un proyecto
# que ya usa OpenSpec. Idempotente: no toca los skills openspec-* ni una config.yaml existente.
#
# Uso: scripts/install.sh <ruta-proyecto> [--tools claude,codex,github-copilot]
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEMA=sdd-incremental

usage() {
  echo "Uso: $0 <ruta-proyecto> [--tools claude,codex,github-copilot]" >&2
  exit 1
}

[[ $# -ge 1 ]] || usage
TARGET="$(cd "$1" && pwd)"
shift
TOOLS="claude,codex,github-copilot"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tools) [[ $# -ge 2 ]] || usage; TOOLS="$2"; shift 2 ;;
    *) usage ;;
  esac
done

if [[ ! -d "$TARGET/openspec" ]]; then
  echo "No existe $TARGET/openspec. Inicializa OpenSpec primero:" >&2
  echo "  cd $TARGET && npx @fission-ai/openspec@latest init --tools $TOOLS" >&2
  exit 1
fi

# 1. Schema
mkdir -p "$TARGET/openspec/schemas"
rm -rf "$TARGET/openspec/schemas/$SCHEMA"
cp -R "$REPO_DIR/openspec/schemas/$SCHEMA" "$TARGET/openspec/schemas/$SCHEMA"
echo "✓ Schema  openspec/schemas/$SCHEMA"

# 2. Config: solo se crea si no existe o si es la generada por 'openspec init' sin personalizar
CONFIG="$TARGET/openspec/config.yaml"
if [[ ! -f "$CONFIG" ]] || ! grep -qvE '^\s*(#|$|schema: spec-driven\s*$)' "$CONFIG"; then
  cp "$REPO_DIR/openspec/config.example.yaml" "$CONFIG"
  echo "✓ Config  openspec/config.yaml"
else
  echo "! openspec/config.yaml ya está personalizada; no se modifica."
  echo "  Pon 'schema: $SCHEMA' y copia lo que necesites de:"
  echo "  $REPO_DIR/openspec/config.example.yaml"
fi

# 3. Skills
IFS=',' read -ra TOOL_LIST <<< "$TOOLS"
for tool in "${TOOL_LIST[@]}"; do
  case "$tool" in
    claude) dir=".claude/skills" ;;
    codex) dir=".agents/skills" ;;
    github-copilot) dir=".github/skills" ;;
    *) echo "! Herramienta desconocida: $tool (usa claude, codex o github-copilot)" >&2; continue ;;
  esac
  mkdir -p "$TARGET/$dir"
  for skill in "$REPO_DIR"/skills/*/; do
    name="$(basename "$skill")"
    rm -rf "$TARGET/$dir/$name"
    cp -R "$skill" "$TARGET/$dir/$name"
  done
  echo "✓ Skills  $dir/sdd-*"
done

echo
echo "Comprueba el schema con: openspec schema validate $SCHEMA"
