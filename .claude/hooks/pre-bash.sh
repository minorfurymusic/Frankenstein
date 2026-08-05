#!/usr/bin/env bash
# PreToolUse — Bash. Três checagens, nesta ordem.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${DIR}/lib.sh"

INPUT="$(cat)"
COMMAND="$(jq -r '.tool_input.command // empty' <<<"$INPUT")"

[[ -z "$COMMAND" ]] && exit 0

# 1) Commit sem `make test` rodado neste ciclo.
if echo "$COMMAND" | grep -Eq '(^|[;&|[:space:]])git[[:space:]]+commit([;&|[:space:]]|$)'; then
  mkdir -p "$STATE_DIR"
  if [[ ! -f "$TEST_MARKER" ]]; then
    deny "Ciclo sem 'make test' executado ainda. Rode 'make test' e cole a saída antes de commitar — CLAUDE.md: 'Nenhum ciclo termina sem make test executado e a saída colada.'"
  fi
fi

# 2) Dependência da lista proibida via instalador de pacote.
if echo "$COMMAND" | grep -Eiq '(flutter[[:space:]]+pub[[:space:]]+add|npm[[:space:]]+(install|i|add)|yarn[[:space:]]+add|pnpm[[:space:]]+add|pip3?[[:space:]]+install|go[[:space:]]+(get|install))'; then
  if echo "$COMMAND" | grep -Eiq "$FORBIDDEN_REGEX"; then
    deny "Comando de instalação parece referenciar dependência da lista proibida em .claude/rules/licenca.md (SDK de anúncio, Play Services, ML Kit, Firebase, SDK social proprietário). Se não for, ajuste o comando para não bater no filtro, ou peça revisão humana."
  fi
fi

# 3) Escrita em packages/ ou server/ via bash, antes de ADR-1/2/3 aceitas.
# Regex amarra o verbo de escrita DIRETO ao caminho (mesma cláusula), para
# não disparar em ocorrências soltas de "packages/"/"server/" (ex.: `ls
# packages/`) nem em redirecionamentos não relacionados (ex.: `2>&1`).
WRITE_INTO_PACKAGES_SERVER='(mkdir(\s+-p)?|touch|tee(\s+-a)?|cp|mv)\s+[^;|&\n]*\b(packages|server)/|>{1,2}\s*"?'"'"'?(packages|server)/|git[[:space:]]+add\s+[^;|&\n]*\b(packages|server)/'
if echo "$COMMAND" | grep -Eq "$WRITE_INTO_PACKAGES_SERVER"; then
  if ! adrs_1_2_3_aceitas; then
    deny "packages/ e server/ estão bloqueados até ADR-1, ADR-2 e ADR-3 estarem com Status: aceito em docs/adr/. Pelo menos uma ainda está 'proposto'."
  fi
fi

exit 0
