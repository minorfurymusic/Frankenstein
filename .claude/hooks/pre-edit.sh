#!/usr/bin/env bash
# PreToolUse — Edit|Write. Duas checagens.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./lib.sh
source "${DIR}/lib.sh"

INPUT="$(cat)"
FILE_PATH="$(jq -r '.tool_input.file_path // empty' <<<"$INPUT")"
[[ -z "$FILE_PATH" ]] && exit 0

REL_PATH="${FILE_PATH#"${CLAUDE_PROJECT_DIR}"/}"

# 3) packages/ ou server/ bloqueados até ADR-1/2/3 aceitas.
if [[ "$REL_PATH" == packages/* || "$REL_PATH" == server/* ]]; then
  if ! adrs_1_2_3_aceitas; then
    deny "packages/ e server/ estão bloqueados até ADR-1, ADR-2 e ADR-3 estarem com Status: aceito em docs/adr/. Pelo menos uma ainda está 'proposto'."
  fi
fi

# 2) Dependência proibida em arquivo de manifesto de build.
case "$REL_PATH" in
  pubspec.yaml|*/pubspec.yaml|pubspec.lock|*/pubspec.lock|\
  build.gradle|*/build.gradle|build.gradle.kts|*/build.gradle.kts|\
  Podfile|*/Podfile|*.podspec|package.json|*/package.json|\
  go.mod|*/go.mod|requirements*.txt|*/requirements*.txt)
    CONTENT="$(jq -r '(.tool_input.new_string // "") + " " + (.tool_input.content // "")' <<<"$INPUT")"
    if echo "$CONTENT" | grep -Eiq "$FORBIDDEN_REGEX"; then
      deny "Edição em ${REL_PATH} parece introduzir dependência da lista proibida em .claude/rules/licenca.md. Se não for, ajuste o texto para não bater no filtro, ou peça revisão humana."
    fi
    ;;
esac

exit 0
