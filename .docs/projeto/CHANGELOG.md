# CHANGELOG — Frankstein

> Gerado pela skill `project-recorder`, adaptada pro Claude Code (sem
> artifacts nem `conversation_search` — essas fontes não existem neste
> ambiente). Dado real, extraído de `git log` neste repositório. Não
> substitui `docs/HISTORICO.md` (que tem a narrativa completa de cada
> ciclo, com prova literal) — este arquivo é o índice cronológico curto,
> no formato que a skill espera.

**Repositório:** `github.com/minorfurymusic/Frankenstein`
**Última atualização:** 2026-08-10 (commit `4a46d43`)
**Total de commits:** 56

## 2026-08-10 (Fase 7 — Academia)

- `4a46d43` — feat(activity): Academia (Fase 7) - WorkoutPlan/WorkoutRepository, WorkoutLogger, get_workout_plan/log_workout_session

## 2026-08-09 (Fases 3, 4, 5 e 6 — primeiro código de verdade do projeto)

- `7f39559` — fix(activity): interlinked_tools_test usa log_meal real (F6 pendencia)
- `3f03b9a` — feat(nutrition): diario alimentar por PORT (Fase 6) - Food/FoodRepository, MealLogger, log_meal real
- `a3dd877` — docs: F6 (nutricao) BLOQUEADA - clean room, sem codigo escrito
- `fd4c276` — docs: atualizar registro do project-recorder (Fases 3, 4, 5)
- `17aaa8a` — feat(activity): passos (Fase 4) + ferramenta get_steps interligada ao F5
- `64cf3e7` — feat(brain,tool_registry): pipeline do cérebro configurado (Fase 5)
- `829e096` — feat(health_core): schema HealthEvent append-only (Fase 3)
- `e4d10e0` — docs: ADR-4 e ADR-5 aceitas; LICENSE-AUDIT.md fechado - 11/11 ADRs
- `79ddfc4` — docs: primeiro registro via skill project-recorder (adaptado)
- `59d837b` — docs: registrar eixo "perfil de dispositivo" (RAM x versão Android)
- `dd6c93c` — docs: aplicar Grupo A/B de EFICIENCIA.md + limpeza da ADR-5
- `091aaf5` — docs(adr): ADR-4 revisão 1 - consequência de licença fundamentada
- `c3fe322` — docs(adr): ADR-4a aceita - Health Connect write confirmado via APK/F-Droid
- `6e7441a` — docs: relatório de eficiência de contexto (Ciclo 32)
- `78219d7` — docs(adr): ADR-8 aceita; ADR-4a revisão 1 (tentativa de leitura primeira mão)
- `8a34c86` — docs(adr): ADR-8 revisão 1 - isolamento de banco decidido após ler CUSTOS.md

## 2026-08-05 a 2026-08-06

- `cbca816` — docs(status): fecha Ciclo 27 - CI confirma make build/test/lint verdes
- `386b711` — fix: Makefile roda pub get antes de build/test/lint (CI quebrava)
- `8c12105` — feat: esqueleto do monorepo (Fase 2, Ciclo 1) - PARCIAL, bloqueio documentado
- `e60ad5c` — docs(adr): ADR-7 aceita (revisão 3); ADR-5 revisão 3
- `c1a4c45` — docs: transformar o PORT da ADR-5 em regra verificável
- `4473675` — docs(adr): revisar ADR-5/ADR-7 e aceitar ADR-1/2/3/9/10
- `36fbc13` — docs: criar docs/PLATFORM-PARITY.md
- `2e00db3` — docs(recon): ler licenças dos 6 submódulos do MLC LLM
- `46fd4fe`, `707bcda` — hooks de PreToolUse/PostToolUse do projeto
- `99eb578` a `9f12e3d` — as 11 ADRs propostas pela primeira vez (Fase 1)
- `68e312c` — ADR-6 (sem anúncios) formalizada
- `bc47086` — docs/VIABILITY.md
- `da60388` — docs/LICENSE-AUDIT.md
- `240d9ea`, `c7eaba0`, `b09b05e`, `a2ea73c`, `1ee3a3c`, `8dafe1b`, `4988fce`, `fb92b93` — as 7 fichas de reconhecimento (Fase 0)

## 2026-08-04

- `4a3ee4a`, `0cd12af`, `39f7f07` — ajustes de escopo (troca Flutter Steps Tracker → OpenTracks, bloqueio da ficha Gadgetbridge)
- `e680eea`, `3cd03ca`, `5b23781`, `f19fcd0` — upload inicial do kit (`minorfurymusic`)
- `d4348b6` — organização de diretórios do kit inicial (Ciclo 0)

## Onde ver mais

- Narrativa completa, com prova literal de cada ciclo: `docs/HISTORICO.md`.
- Estado atual do projeto: `STATUS.md`.
- Decisões de arquitetura: `docs/adr/000-pendentes.md` e `docs/adr/*.md`.
