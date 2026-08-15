# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **F3, F4, F5, F6, F7, (parcial) F8, (parcial) F9 e (parcial)
F12 concluídas + primeira UI real do app.** Health Data Core, passos, o
pipeline do cérebro, nutrição (**catálogo real** — Tabela TACO, 578
itens), academia, corrida/caminhada (parte sem Android real), wearable
(FC/sono via Health Connect, parte sem Health Connect real),
compartilhamento social (cards de treino/corrida, parte sem rasterização
real do engine). Esqueleto de Entitlements/Pagamento (F10/F11, sem
provedor configurado). Quatro ferramentas novas do cérebro
(`get_daily_summary`, `search_food`, `sync_wearable`, e o fluxo de
compartilhamento embora `share_card` não seja uma tool do cérebro em si).
`app/` deixou de ser tela em branco: navegação Resumo/Chat de verdade,
ligada aos pacotes reais, com compartilhamento de treino/corrida
funcionando de ponta a ponta. Detalhe completo em `docs/HISTORICO.md`.

**Ciclo mais recente: F12 — compartilhamento social (parcial).**
`.claude/rules/share.md`: card renderizado no aparelho, preview
obrigatório, opt-in por campo, nada clínico, rota ofuscada, publicação
nunca automática. Novo pacote `packages/share`: `WorkoutShareCardData`/
`RunShareCardData` + `buildWorkoutShareCard`/`buildRunShareCard` — **nunca
aceitam `HealthEvent` de tipo clínico** (checagem estrutural, não
convenção), reutilizam `obfuscateRouteEnds` (F8) pra rota. Em `app/`:
`SharePreviewScreen` (o card visível na tela é literalmente o mesmo
widget capturado — preview = o que sai, sem diferença), `ShareSheet`
(real via `share_plus`, BSD-3-Clause — só invoca o share sheet nativo do
SO, não é SDK de rede social), `CardImageCapturer` (abstrai
`RepaintBoundary.toImage()`, que **não completa neste ambiente headless**
— mesma categoria de `path_provider`; a lógica em volta — botão dispara
captura, preview obrigatório, nada compartilha sozinho — é testada com
`FakeCardImageCapturer`, só a rasterização real do engine fica não
verificada). Sem campos sensíveis (peso/IMC/calorias/medidas) ainda —
decisão registrada, não fabricados pra ter uma UI de opt-in sem dado
real por trás.

**Não registradas ainda no app:** `start_run` (precisa de captura de GPS
real), `sync_wearable` (precisa de `WearableDataSource` real sobre
Health Connect), `query_health_record` (fora do escopo até agora).

**Pendências ativas (revisado):**
- **Adiado por decisão, não por bloqueio técnico:** `BarcodeDecoder`
  concreto com `flutter_zxing` em `app/` — sem câmera/emulador real pra
  validar.
- `start_run` (F8) e a captura de GPS real (WRAP OpenTracks Android,
  PORT iOS) — bloqueadas por falta de SDK/device Android/iOS, mesmo
  limite de F4.
- `WearableDataSource` real sobre Health Connect (F9) — precisa do
  plugin Flutter que envolve a API nativa + Android SDK/device com
  Health Connect e Gadgetbridge de verdade instalados
  (`docs/adr/004a-gadgetbridge.md`). Equivalente iOS (HealthKit) nem
  investigado — Gadgetbridge é Android-only.
- `path_provider` e `CardImageCapturer` real (F12) — platform
  channel/pipeline de rasterização real, não verificáveis em
  `flutter test`/sem device. Todo o resto do app é testável e testado
  sem isso.
- Água (novo tipo de `HealthEvent`) e refeição/receita composta de
  ingredientes — pendências já registradas em `docs/specs/nutricao.md`,
  não implementadas.
- Nenhum provedor de pagamento real configurado (F10/F11 é só
  esqueleto, por decisão) — Play Billing/StoreKit/Stripe/Pix ficam pra
  quando o servidor existir.
- Peso/IMC/calorias/medidas nos cards de compartilhamento (F12) — regra
  de opt-in por campo já registrada em `.claude/rules/share.md`, mas os
  campos em si ainda não existem no card; entram desligados por padrão
  quando entrarem.
- `search_food`, `get_workout_plan`, `log_workout_session`,
  `get_run_summary` estão registradas no `ToolRegistry` do app mas sem
  regra de roteador de chat ainda (só acessíveis hoje pela tela de
  Resumo ou programaticamente) — dar comando de chat pra cada uma é
  trabalho de UI futuro.

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
| 6 | Nutrição/código de barras (F6) | **CONCLUÍDO** (`packages/nutrition`) — `Food`/`FoodRepository` (sqlite3), `MealLogger`, `BarcodeDecoder` (interface, sem câmera real), `log_meal`/`search_food` reais no `ToolRegistry`; **catálogo real** = Tabela TACO (NEPA/UNICAMP, 578 alimentos) desde este ciclo; `flutter_zxing` concreto fica pra depois |
| 7 | Academia (F7) | **CONCLUÍDO** (`packages/activity`) — `WorkoutPlan`/`WorkoutRepository` (sqlite3), `WorkoutLogger` (`workout_session`+`set_log`, recorde por consulta), `get_workout_plan`/`log_workout_session` reais no `ToolRegistry`; sem dependência de hardware, testado de ponta a ponta |
| 8 | Corrida/caminhada com GPS (F8) | **PARCIAL** (`packages/activity`) — `RunCalculator`, `RunLogger`, GPX, ofuscação de rota, `get_run_summary` concluídos e testados; captura de GPS real (WRAP Android/PORT iOS) e `start_run` bloqueados — sem SDK/device Android/iOS neste ambiente |
| 9 | Wearable BLE (F9) | **PARCIAL** (`packages/wearable`, novo pacote) — `WearableSyncLogger`/`sync_wearable` prontos e testados (FC + sono, dedup por `external_id`); `WearableDataSource` real sobre Health Connect bloqueada — sem Android SDK/device com Gadgetbridge instalado; não registrada no app (sem fonte real pra ligar) |
| 10/11 | Entitlements/Pagamento | **PARCIAL, esqueleto** (`packages/entitlements`) — `Entitlement`/`EntitlementVerifier` (Ed25519 real), `Subscription`, `PendingPayment`, `WebhookIdempotencyGuard`; nenhum provedor configurado, por decisão |
| 12 | Compartilhamento social (F12) | **PARCIAL** (`packages/share`, novo pacote) — `WorkoutShareCardData`/`RunShareCardData`, builders com checagem estrutural anti-clínico, rota ofuscada; em `app/`: `SharePreviewScreen`/`ShareSheet`(`share_plus`)/`CardImageCapturer`, testado de ponta a ponta com `FakeCardImageCapturer`; rasterização real (`RepaintBoundary.toImage`) não verificável neste ambiente headless |
| — | `get_daily_summary`/`sync_wearable` (ferramentas do cérebro) | **CONCLUÍDO** — `get_daily_summary` (`packages/summary`, só leitura, cruza steps/meal/workout_session/gps_track); `sync_wearable` (`packages/wearable`, escrita com confirmação) |
| — | Primeira UI real do app (`app/`) | **PARCIAL** — telas Resumo + Chat, `AppDependencies` ligada aos pacotes reais, 6 de 7 ferramentas mínimas registradas, roteador de chat cobre 3 delas (`get_daily_summary`, `get_steps`, `log_meal` com confirmação real), compartilhamento de treino/corrida (F12); `path_provider`/rasterização real não verificáveis sem device |
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
