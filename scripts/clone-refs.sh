#!/usr/bin/env bash
# Clona os 7 repositórios FORA do repositório do projeto, em modo shallow.
# refs/ está no .gitignore: é material de leitura, não faz parte do produto.
set -euo pipefail

DEST="${1:-refs}"
mkdir -p "$DEST"

# CONFIRME cada URL na página oficial do projeto antes de rodar.
# Atenção: alguns projetos migraram de host (ex.: Gadgetbridge saiu do GitHub
# para o Codeberg).
REPOS=(
  "mlc-llm|https://github.com/mlc-ai/mlc-llm.git"
  "opentracks|https://github.com/OpenTracksApp/OpenTracks.git"
  "gadgetbridge|https://codeberg.org/Freeyourgadget/Gadgetbridge.git"
  "foodyou|https://github.com/maksimowiczm/FoodYou.git"
  "opennutritracker|https://github.com/simonoppowa/OpenNutriTracker.git"
  "wger|https://github.com/wger-project/wger.git"
  "fasten-health|https://github.com/fastenhealth/fasten-onprem.git"
)

FALHAS=()

for entry in "${REPOS[@]}"; do
  name="${entry%%|*}"
  url="${entry##*|}"

  if [[ "$url" == *"<"* || "$url" == *">"* || "$url" == "<URL>" ]]; then
    echo "PULANDO $name — URL inválida: $url"
    continue
  fi

  if [[ -d "$DEST/$name" ]]; then
    echo "JÁ EXISTE $name"
    continue
  fi
  echo "Clonando $name..."
  if git clone --depth 1 "$url" "$DEST/$name"; then
    hash="$(git -C "$DEST/$name" rev-parse --short HEAD)"
    echo "OK $name @ $hash"
  else
    echo "FALHOU $name"
    FALHAS+=("$name")
  fi

done

echo
echo "Pronto. Repositórios em $DEST/ — somente leitura."
echo "Nada é copiado para o projeto sem ADR aprovado."

if [[ ${#FALHAS[@]} -gt 0 ]]; then
  echo
  echo "Falharam ${#FALHAS[@]} de ${#REPOS[@]}: ${FALHAS[*]}"
  exit 1
fi
