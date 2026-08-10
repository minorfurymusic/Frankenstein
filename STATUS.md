# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **F3, F4, F5, F6 e F7 concluídas.** Health Data Core, passos
(`StepsRepository`), o pipeline do cérebro, o módulo de nutrição
(`packages/nutrition`) e agora o módulo de academia
(`packages/activity`: `WorkoutPlan`/`WorkoutRepository` sobre `sqlite3`,
`WorkoutLogger` gravando `workout_session`+`set_log`, `get_workout_plan`/
`log_workout_session` reais no `ToolRegistry`). Detalhe completo em
`docs/HISTORICO.md`.

**Ciclo atual:** F7 — Academia. Sem dependência de hardware desta vez
(diferente de passos/GPS): tudo testável de verdade, sem ressalva de
"precisa de device". `docs/PRODUTO.md:28` ("planos, sessão ao vivo,
séries/repetições/carga, RPE, recordes, progressão") implementado como:
catálogo de planos (`WorkoutPlan`/`PlannedExercise`, local, não é
`HealthEvent` — mesmo padrão do catálogo `Food` da nutrição) + sessão
executada (`WorkoutSessionInput`/`SetEntry`, grava 1 `workout_session` +
N `set_log` por sessão) + recorde pessoal calculado por consulta sobre
`set_log` (não armazenado). Nenhuma tabela de "Exercise" catalogada —
exercício é `exerciseId`/`exerciseName` livre escolhido pelo chamador,
evitando escopo prematuro.

**Pendências ativas (revisado):**
- **Corrigido:** `packages/activity/test/interlinked_tools_test.dart`
  agora usa `log_meal` real (`FoodRepository`/`MealLogger` de
  `packages/nutrition`), não mais o handler de demonstração.
- **Confirmado não resolvível aqui:** Open Food Facts
  (`world/static/br.openfoodfacts.org`) bloqueado pelo proxy deste
  ambiente (mesmo padrão de outros domínios já documentado) — testado
  de novo antes de desistir, sem mirror pequeno viável encontrado.
  `packages/nutrition` continua com dataset de fixture (6 alimentos).
- **Adiado por decisão, não por bloqueio técnico:** `BarcodeDecoder`
  concreto com `flutter_zxing` em `app/` — daria pra escrever o código,
  mas sem câmera/emulador real pra validar, e o `app/` ainda não tem
  nenhuma infraestrutura de UI (navegação, tema) pra essa tela se
  encaixar — implementar isso isolado, sem poder testar e sem o resto
  do app em volta, é mais risco que ganho agora. Fica pra quando o app
  shell começar a ganhar UI de verdade.
- Água (novo tipo de `HealthEvent`) e refeição/receita composta de
  ingredientes — pendências já registradas em `docs/specs/nutricao.md`,
  não implementadas.
- Decidir entre mais ferramentas do cérebro (`get_daily_summary`,
  `search_food`, `sync_wearable`...) ou outro módulo (F8 corrida/GPS,
  que herda o mesmo limite de hardware que passos: sem device/emulador
  pra validar GPS de verdade neste ambiente) — não decidido.

**main sincronizado com a branch designada** — verificar se ainda está em
sincronia antes de assumir (checar `git log` das duas antes de reusar
este status sem revalidar).

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
| 7 | Academia (F7) | **CONCLUÍDO** (`packages/activity`) — `WorkoutPlan`/`WorkoutRepository` (sqlite3), `WorkoutLogger` (`workout_session`+`set_log`, recorde por consulta), `get_workout_plan`/`log_workout_session` reais no `ToolRegistry`; sem dependência de hardware, testado de ponta a ponta |
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
