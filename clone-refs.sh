#!/usr/bin/env bash
# Clona os 7 repositórios FORA do repositório do projeto, em modo shallow.
# refs/ está no .gitignore: é material de leitura, não faz parte do produto.
set -euo pipefail

DEST="${1:-refs}"
mkdir -p "$DEST"

# CONFIRME cada URL na página oficial do projeto antes de rodar.
# Atenção: alguns projetos migraram de host (ex.: Gadgetbridge saiu do GitHub).
# "Flutter Steps Tracker" tem vários repositórios homônimos — escolha um e anote
# a URL exata na ficha de reconhecimento.
REPOS=(
  "mlc-llm|https://github.com/mlc-ai/mlc-llm.git"
  "flutter-steps-tracker|https://github.com/TarekAlabd/Flutter-Steps-Tracker.git"
  "gadgetbridge|https://codeberg.org/Freeyourgadget/Gadgetbridge.git"
  "foodyou|https://github.com/maksimowiczm/FoodYou.git"
  "opennutritracker|https://github.com/simonoppowa/OpenNutriTracker.git"
  "wger|https://github.com/wger-project/wger.git"
  "fasten-health|https://github.com/fastenhealth/fasten-onprem.git"
)

for entry in "${REPOS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"
  if [[ "$url" == "<URL>" ]]; then
    echo "PULANDO $name — URL não preenchida"
    continue
  fi
  if [[ -d "$DEST/$name" ]]; then
    echo "JÁ EXISTE $name"
    continue
  fi
  echo "Clonando $name..."
  git clone --depth 1 "$url" "$DEST/$name"
done

echo
echo "Pronto. Repositórios em $DEST/ — somente leitura."
echo "Nada é copiado para o projeto sem ADR aprovado."
