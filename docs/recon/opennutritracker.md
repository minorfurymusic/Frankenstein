# Ficha de reconhecimento — OpenNutriTracker

> `docs/recon/_MODELO.md` é o template de ADR, não de ficha de repositório
> (débito técnico registrado em `STATUS.md` no Ciclo 1).

**Repositório:** https://github.com/simonoppowa/OpenNutriTracker.git
**Commit avaliado:** `9ab14fe3149a24940bef2800451ad9b8cb9df4e9` (2026-08-02)

## Licença

Lida literalmente de `LICENSE` na raiz do clone: **GNU General Public
License, Version 3** (cabeçalho: "GNU GENERAL PUBLIC LICENSE / Version 3,
29 June 2007", Copyright FSF) — bate com o badge do `README.md`
("license-GPLv3"). Único arquivo de licença no repositório
(`find . -iregex '.*/\(LICENSE\|COPYING\|NOTICE\)[^/]*'` → só `./LICENSE`).
Nada divergente encontrado.

**Relevante para ADR-5:** GPL-3.0 puro, mesmo regime do FoodYou — reforça
copyleft, sem novidade em relação à decisão já tomada.

## Stack observada

Confirmado abrindo o repositório: **Flutter/Dart** (`pubspec.yaml`, 451
arquivos `.dart` em `lib/`, diretórios `android/` e `ios/`) — bate com a
hipótese que já estava em `docs/PRODUTO.md`. `pubspec.yaml`: nome
`opennutritracker`, versão `2.0.2+61`.

## Build

**Não tentei compilar.** Motivo: `flutter` e `dart` não estão instalados
neste ambiente (`which flutter` / `which dart` → não encontrado). Não há
toolchain Flutter disponível para nem sequer tentar `flutter pub get`.

## Observações

- O repositório tem seus próprios `CLAUDE.md`/`AGENTS.md` na raiz — são
  arquivos do projeto OpenNutriTracker para os agentes deles, não têm
  relação com este projeto; não foram tratados como instrução para este
  ciclo.
- Único repositório Flutter confirmado entre os 5 avaliados até agora
  (mlc-llm é C++/Python, OpenTracks é Java, FoodYou é Kotlin Multiplatform)
  — reforça que a decisão de shell/multiplataforma (ADR-1) tem peso real
  aqui: se o shell não for Flutter, este módulo entra como PORT ou WRAP com
  platform channel, não como dependência direta.
