#!/usr/bin/env bash
# Regenera as instâncias estáticas da Figtree usadas pelo app.
#
# Origem: google/fonts, ofl/figtree/Figtree[wght].ttf (fonte variável,
# eixo wght 300–900, versão 2.002). Licença: SIL Open Font License 1.1, sem
# "Reserved Font Name" declarado — gerar instâncias é modificação permitida.
# SHA-256 da fonte variável baixada em 2026-10-02:
#   26ad3db9b31ff7dde67a91ff515d022d2f495cd506590699cf264f0bfe6fb714
#
# Por que instâncias estáticas: a fonte variável tem peso padrão 300 e o
# Flutter só aplica o eixo wght com `fontVariations` explícito; com arquivos
# estáticos declarados por peso no pubspec, qualquer `FontWeight` funciona.
#
# Requer: curl, fonttools (`pip install fonttools`).
set -euo pipefail

out="$(cd "$(dirname "$0")/../.." && pwd)/app/assets/fonts/figtree"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

base="https://raw.githubusercontent.com/google/fonts/main/ofl/figtree"
curl -sSfL -o "$tmp/Figtree.ttf" "$base/Figtree%5Bwght%5D.ttf"
curl -sSfL -o "$out/OFL.txt" "$base/OFL.txt"
echo "26ad3db9b31ff7dde67a91ff515d022d2f495cd506590699cf264f0bfe6fb714  $tmp/Figtree.ttf" | sha256sum -c -

for w in 400 500 600 700 800; do
  fonttools varLib.instancer -q "$tmp/Figtree.ttf" "wght=$w" \
    --update-name-table -o "$out/Figtree-w$w.ttf"
done
ls -la "$out"
