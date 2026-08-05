#!/usr/bin/env bash
# PostToolUse — Bash. Mantém o estado que pre-bash.sh consulta.
#
# Nota: a documentação de hooks descreve um campo `tool_error` no input do
# PostToolUse. Na prática, esta implementação manda `tool_response.stdout`/
# `.stderr` (sem sinal explícito de sucesso/falha do comando interno — o
# exit code do comando não é exposto aqui). Por isso o marcador é limpo em
# qualquer `git commit` que chegue até aqui, sem tentar adivinhar se o
# commit "passou": pior caso é pedir um `make test` a mais, nunca de menos.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${DIR}/lib.sh"

INPUT="$(cat)"
COMMAND="$(jq -r '.tool_input.command // empty' <<<"$INPUT")"

[[ -z "$COMMAND" ]] && exit 0

mkdir -p "$STATE_DIR"

# `make test` rodou (independente de passar) — Fase 0/1 falha de propósito,
# o que a regra exige é ter sido executado e a saída colada, não ter passado.
if echo "$COMMAND" | grep -Eq '(^|[;&|[:space:]])make[[:space:]]+test([;&|[:space:]]|$)'; then
  touch "$TEST_MARKER"
fi

# Qualquer `git commit` que chegue ao PostToolUse (ou seja, não foi negado
# no PreToolUse) consome o marcador — o próximo ciclo precisa rodar
# `make test` de novo antes do próximo commit.
if echo "$COMMAND" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([;&|[:space:]]|$)'; then
  rm -f "$TEST_MARKER"
fi

exit 0
