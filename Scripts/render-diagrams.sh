#!/usr/bin/env bash
# Render all Mermaid diagram sources to SVG.
#
# Requirements: Node.js >= 18
# Uses mmdc from @mermaid-js/mermaid-cli via npx (no prior install needed).
# To use a globally-installed mmdc instead, ensure it is on your PATH.
#
# Usage:
#   ./Scripts/render-diagrams.sh
#
# Output:
#   Sources/DHModels/DaggerheartModels.docc/Resources/*.svg  (from diagrams/DHModels/*.mmd)
#   Sources/DHKit/DHKit.docc/Resources/*.svg                 (from diagrams/DHKit/*.mmd)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIAGRAMS="$REPO_ROOT/diagrams"
DHMODELS_OUT="$REPO_ROOT/Sources/DHModels/DaggerheartModels.docc/Resources"
DHKIT_OUT="$REPO_ROOT/Sources/DHKit/DHKit.docc/Resources"

mkdir -p "$DHMODELS_OUT"
mkdir -p "$DHKIT_OUT"

if command -v mmdc &>/dev/null; then
    MMDC=mmdc
else
    MMDC="npx --yes @mermaid-js/mermaid-cli"
fi

render() {
    local src="$1" dst="$2"
    echo "  $(basename "$src") → $(basename "$dst")"
    $MMDC -i "$src" -o "$dst"
}

echo "=== DHModels ==="
for f in "$DIAGRAMS/DHModels"/*.mmd; do
    name="$(basename "${f%.mmd}")"
    render "$f" "$DHMODELS_OUT/${name}.svg"
done

echo "=== DHKit ==="
for f in "$DIAGRAMS/DHKit"/*.mmd; do
    name="$(basename "${f%.mmd}")"
    render "$f" "$DHKIT_OUT/${name}.svg"
done

echo "Done."
