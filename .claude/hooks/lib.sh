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

# Uma ADR vale como decidida se o status começa com "aceito", ou se foi
# "substituído por ADR-N" e a ADR-N vale como decidida (ADR-2 → ADR-11,
# 2026-10-02). Profundidade limitada pra não entrar em ciclo.
adr_decidida() {
  local id="$1" depth="${2:-0}" status next
  (( depth > 5 )) && return 1
  status=$(adr_status "$id")
  [[ "$status" == aceito* ]] && return 0
  # "[^ ]*" em vez de "[íi]": no locale C o "í" vira 2 bytes e quebra o colchete.
  if [[ "$status" =~ ^substitu[^\ ]*\ por\ ADR-([0-9]+) ]]; then
    next=$(printf '%03d' "$((10#${BASH_REMATCH[1]}))")
    adr_decidida "$next" "$((depth + 1))"
    return $?
  fi
  return 1
}

adrs_1_2_3_aceitas() {
  adr_decidida 001 && adr_decidida 002 && adr_decidida 003
}
