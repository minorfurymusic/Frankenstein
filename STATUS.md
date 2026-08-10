# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **F3, F4, F5 e F6 concluídas.** Health Data Core, passos
(`StepsRepository`), o pipeline do cérebro e agora o módulo de nutrição
(`packages/nutrition`: `Food`/`FoodRepository` sobre `sqlite3` com
dataset de fixture, `MealLogger`, interface `BarcodeDecoder`, `log_meal`
real registrada no `ToolRegistry`) — implementado por uma sessão nova,
sem contato com `docs/recon/opennutritracker.md`, só a partir de
`docs/specs/nutricao.md` (`.claude/rules/port.md`). Detalhe completo em
`docs/HISTORICO.md`.

**Ciclo atual:** nenhum em andamento. F6 saiu de BLOQUEADA para
CONCLUÍDA neste ciclo — ver `docs/HISTORICO.md`, entrada "F6
(nutrição/código de barras) — implementada".

**Pendências ativas:**
- Decidir entre mais ferramentas do cérebro (`get_daily_summary`,
  `search_food`, `sync_wearable`...) ou outro módulo (F7 Academia; F8
  corrida/GPS) — não decidido.
- Importação real do subconjunto brasileiro do Open Food Facts (hoje
  `packages/nutrition` usa um dataset de fixture, 6 alimentos) —
  trabalho futuro de infraestrutura de dados, `TODO(frankstein)` no
  código.
- Implementação concreta de `BarcodeDecoder` com `flutter_zxing` (MIT,
  ZXing puro, sem ML Kit) em `app/` — precisa de dispositivo/emulador
  real pra validar câmera, não existe neste ambiente.
- `packages/activity/test/interlinked_tools_test.dart` ainda usa o
  handler de demonstração de `log_meal`, não o real de
  `packages/nutrition` — comentário lá ficou desatualizado, trocar num
  ciclo futuro.
- Água (novo tipo de `HealthEvent`) e refeição/receita composta de
  ingredientes — pendências já registradas em `docs/specs/nutricao.md`,
  não implementadas.

**main sincronizado com a branch designada** em 2026-08-06 (fast-forward,
`8a34c86`) — verificar se ainda está em sincronia antes de assumir.

## Progresso

| Fase | Item | Status |
|---|---|---|
| 0 | Ficha MLC LLM | pronta (`docs/recon/mlc-llm.md`) |
| 0 | Ficha OpenTracks | pronta (`docs/recon/opentracks.md`) |
| 0 | Ficha Gadgetbridge | pronta (`docs/recon/gadgetbridge.md`) — **ressalva:** produzida fora deste ambiente, por leitura no navegador (codeberg.org bloqueado pelo proxy); sem clone, sem build |
| 0 | Ficha FoodYou | pronta (`docs/recon/foodyou.md`) |
| 0 | Ficha OpenNutriTracker | pronta (`docs/recon/opennutritracker.md`) |
| 0 | Ficha wger | pronta (`docs/recon/wger.md`) |
| 0 | Ficha Fasten Health | pronta (`docs/recon/fasten-health.md`) |
| 0 | docs/LICENSE-AUDIT.md | **fechado** (`docs/LICENSE-AUDIT.md`, seção "Fechamento") — Cenário B adotado, decisões consolidadas |
| 0 | docs/VIABILITY.md | pronta (`docs/VIABILITY.md`) |
| 1 | ADR-1 (shell/multiplataforma) | **aceito** (`docs/adr/001-shell-multiplataforma.md`) |
| 1 | ADR-2 (modelo LLM) | **aceito** (`docs/adr/002-modelo-llm.md`) |
| 1 | ADR-3 (fonte da verdade/sync) | **aceito** (`docs/adr/003-fonte-verdade-sync.md`) |
| 1 | ADR-4 (wger/Fasten) | **aceito, revisão 1** (`docs/adr/004-wger-fasten.md`) |
| 1 | ADR-4a (Gadgetbridge) | **aceito, revisão 2** (`docs/adr/004a-gadgetbridge.md`) |
| 1 | ADR-5 (licenciamento) | **aceito, revisão 4** (`docs/adr/005-licenciamento-distribuicao.md`) — cliente Apache-2.0 via PORT do OpenNutriTracker, clean room obrigatório |
| 1 | ADR-6 (sem anúncios) | **aceito** (`docs/adr/006-sem-anuncios.md`) |
| 1 | ADR-7 (canais/pagamento) | **aceito, revisão 3** (`docs/adr/007-canais-distribuicao-pagamento.md`) |
| 1 | ADR-8 (multi-tenant B2B/consentimento) | **aceito, revisão 1** (`docs/adr/008-multitenant-b2b-consentimento.md`) |
| 1 | ADR-9 (GPS) | **aceito** (`docs/adr/009-gps.md`) |
| 1 | ADR-10 (substitutos livres) | **aceito** (`docs/adr/010-substitutos-livres.md`) |
| 1 | **11/11 ADRs registradas** | **11/11 aceitas** — Fase 1 concluída |
| 2 | Esqueleto do monorepo (F2) | **CONCLUÍDO** — CI verde (`ubuntu-latest`), sandbox de dev sem SDK Android/KVM (limite de ambiente) |
| 3 | Health Data Core (F3) | **CONCLUÍDO** (`packages/health_core`) — `HealthEvent` append-only, dedup, correção, `gps_track_points` |
| 4 | Passos, foreground service (F4) | **CONCLUÍDO** (`packages/activity`, `StepsRepository`) — agregação de contador cumulativo, reset de aparelho tratado; foreground service Android real fica pra depois (sem device pra testar aqui) |
| 5 | Cérebro com 1+ ferramentas (F5) | **pipeline provado com 2 ferramentas reais** (`get_steps`, `log_meal`) coexistindo no mesmo `BrainPipeline`/`ToolRegistry`; LLM on-device real fica pra depois (sem device pra testar aqui) |
| 6 | Nutrição/código de barras (F6) | **CONCLUÍDO** (`packages/nutrition`) — `Food`/`FoodRepository` (sqlite3, dataset de fixture), `MealLogger`, `BarcodeDecoder` (interface, sem câmera real), `log_meal` real ligada ao `ToolRegistry`; dataset real (Open Food Facts) e `flutter_zxing` concreto ficam pra depois |
| — | Relatório de eficiência (`docs/EFICIENCIA.md`) | Grupo A adotado como prática; Grupo B aplicado (este arquivo) |

## Decisões já tomadas (não reabrir sem motivo novo)

- Código aberto, copyleft aceito.
- **Sem anúncios em nenhuma superfície.** Sistema de anúncios foi cancelado.
- Offline-first: a IA roda no aparelho do usuário.
- Grátis = tudo que roda no aparelho. Pago = tudo que consome servidor.
- Monetização: assinatura R$20/US$10 + B2B para profissionais de saúde.
- Escopo inclui módulo de academia (planos, treino, corrida/caminhada com GPS)
  e compartilhamento social (Instagram, TikTok, Facebook).

## Débito técnico

Nenhum em aberto no momento.
