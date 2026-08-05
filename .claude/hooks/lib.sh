#!/usr/bin/env bash
# Funções compartilhadas pelos hooks do Frankstein. Não é executável sozinho.

: "${CLAUDE_PROJECT_DIR:?CLAUDE_PROJECT_DIR não definido}"

STATE_DIR="${CLAUDE_PROJECT_DIR}/.claude/state"
TEST_MARKER="${STATE_DIR}/test-ok"
ADR_DIR="${CLAUDE_PROJECT_DIR}/docs/adr"

# Lista derivada de .claude/rules/licenca.md. "pixel" sozinho não entra:
# é palavra ambígua demais (Google Pixel, pixel de tela) para um grep
# confiável — só o par explícito facebook/meta pixel.
FORBIDDEN_REGEX='admob|audience[_ -]?network|applovin|unity[_ -]?ads|play-services|play_services|com\.google\.android\.gms|com\.google\.gms|mlkit|ml[_ -]?kit|com\.google\.mlkit|firebase|facebook[_ -]?sdk|com\.facebook|facebook[_ -]?pixel|meta[_ -]?pixel|tiktok[_ -]?sdk|com\.tiktok'

deny() {
  local reason="$1"
  jq -n --arg reason "$reason" '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'
  exit 0
}

# Status literal de uma ADR (001, 002, 003...), lido da linha "**Status:** X".
adr_status() {
  local file
  file=$(ls "${ADR_DIR}/$1"-*.md 2>/dev/null | head -1)
  if [[ -z "$file" ]]; then
    echo "AUSENTE"
    return
  fi
  grep -m1 '^\*\*Status:\*\*' "$file" | sed -E 's/^\*\*Status:\*\* *//'
}

adrs_1_2_3_aceitas() {
  local s1 s2 s3
  s1=$(adr_status 001)
  s2=$(adr_status 002)
  s3=$(adr_status 003)
  [[ "$s1" == "aceito" && "$s2" == "aceito" && "$s3" == "aceito" ]]
}
