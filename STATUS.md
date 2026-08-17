# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **F3, F4, F5, F6, F7, (parcial) F8, (parcial) F9, (parcial)
F12 e (parcial) F13 concluídas + primeira UI real do app.** Health Data
Core, passos, o pipeline do cérebro, nutrição (**catálogo real** —
Tabela TACO, 578 itens), academia, corrida/caminhada (parte sem Android
real), wearable (FC/sono via Health Connect, parte sem Health Connect
real), compartilhamento social (cards de treino/corrida, parte sem
rasterização real do engine), integração federada com wger/Fasten
(parte sem servidor real). Esqueleto de Entitlements/Pagamento (F10/F11,
sem provedor configurado). Seis ferramentas novas do cérebro
(`get_daily_summary`, `search_food`, `sync_wearable`, `sync_wger`,
`sync_fasten_records`, e o fluxo de compartilhamento embora `share_card`
não seja uma tool do cérebro em si). `app/` deixou de ser tela em
branco: navegação Resumo/Chat de verdade, ligada aos pacotes reais, com
compartilhamento de treino/corrida funcionando de ponta a ponta. Detalhe
completo em `docs/HISTORICO.md`.

**Ciclo mais recente: dashboard mínimo funcional — água, refeição e
treino registráveis por toque, sem digitar comando de chat.** Primeiro
teste real em Android confirmou o app abrindo (fix do
`sqlite3_flutter_libs`) mas revelou o dashboard "morto": das 4 métricas,
só Refeições/Treinos tinham qualquer jeito de gravar dado, e só via
comando de chat digitado (regex exata). Layout final do dashboard
desenhado de uma vez (5 cards: Passos, Água, Refeições, Treinos,
Corridas) pra não precisar redesenhar a cada função nova — Passos e
Corridas ficam com placeholder honesto ("sem sensor real ainda"/"requer
GPS real") porque dependem de trabalho de plataforma nativa Android,
fora deste ciclo. Água/Refeições/Treinos ganharam ação "+" real:
- **Tipo `water` novo** (`packages/health_core`, `docs/ARQUITETURA.md:31-32`,
  `.claude/rules/datacore.md`) — fechava pendência registrada desde
  `docs/specs/nutricao.md`. `packages/nutrition`: `WaterLogger`/
  `log_water` (escrita com confirmação, payload `{amount_ml}`, mesmo
  padrão de `MealLogger`/`log_meal`).
- `get_daily_summary` soma água do dia (`packages/summary`).
- `app/lib/screens/log_meal_screen.dart` (busca real no catálogo TACO +
  toque + gramas) e `log_workout_screen.dart` (formulário) — nenhum dos
  dois reimplementa a lógica de escrita: montam o mesmo texto que o
  roteador de chat aceita e mandam pro mesmo `BrainPipeline.handle`,
  reaproveitando a confirmação humana já existente
  (`.claude/rules/brain.md`, passo 4).
- Diálogo rápido de água inline no dashboard (presets 200/300/500ml +
  quantidade customizada), mesmo caminho de confirmação.
- 3 widget tests novos, ponta a ponta, com dado real gravado no
  `HealthDataCore` (não mock de UI).

**Ciclo anterior: CI publica APK debug como artifact (MVP pra teste
manual).** Sandbox de dev não tem Android SDK (`dl.google.com` bloqueado
pela política de rede do ambiente) — CI (`ubuntu-latest`) já compilava
via `make build`, mas descartava o resultado com o runner.
`.github/workflows/ci.yml`: passo `actions/upload-artifact@v4` publica
`app-debug.apk` (assinatura debug padrão do Flutter, 14 dias de
retenção). Baixar em qualquer run verde da CI, aba "Actions" do
GitHub → run → "Artifacts" → `frankstein-debug-apk`. **Não é canal de
distribuição real** (ADR-7 continua em aberto quanto a isso) — é só
instalação manual pra teste, com "instalar de fontes desconhecidas"
liberado manualmente no aparelho.

**Ciclo anterior: F13 — integração federada com wger e Fasten
(parcial).** `docs/adr/004-wger-fasten.md` (aceita): ambos opcionais,
federados, nunca linkados ao binário do Frankstein — wger fala REST v2
(mantém AGPL-3.0 como programa separado), Fasten fala FHIR (mantém
GPL-3.0). Sem restrição de clean-room (`.claude/rules/port.md` só cobre
`packages/nutrition`) — ambas são APIs públicas padronizadas pra
consumo por terceiros. Dois pacotes novos, mesmo padrão de "escopo
honesto" de F4/F6/F9/F12: `packages/wger` (`WgerSetLogSample`,
`WgerClient`/`FixtureWgerClient`, `WgerSyncLogger` grava `set_log` com
`source: wger`, `sync_wger` — escrita com confirmação) e
`packages/fasten` (`FastenDocumentSample` guarda o recurso FHIR bruto,
`FastenClient`/`FixtureFastenClient`, `FastenSyncLogger` grava
`clinical_doc` com `source: fasten`, `sync_fasten_records` — escrita com
confirmação). Cliente HTTP/FHIR real não escrito — sem servidor
wger/Fasten alcançável neste ambiente, dependência `http` não
adicionada pra não ficar sem teste. Nenhum dos dois registrado em
`app/` (mesmo tratamento de `sync_wearable`: sem cliente real, seria
desonesto ligar o Fixture em produção). De quebra: corrigido um bug
latente em `app/test/widget_test.dart` — datas fixas (`DateTime.utc(2026,
8, 15, ...)`) que quebravam assim que o relógio real passava do dia
fixado (aconteceu neste ciclo, `date -u` mostrou 17/08); trocado por
`_todayNoonUtc()`, calculado em tempo de execução.

**Ciclo anterior: F12 — compartilhamento social (parcial).**
`.claude/rules/share.md`: card renderizado no aparelho, preview
obrigatório, opt-in por campo, nada clínico, rota ofuscada, publicação
nunca automática. Pacote `packages/share`: `WorkoutShareCardData`/
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
Health Connect), `sync_wger`/`sync_fasten_records` (precisam de cliente
HTTP/FHIR real sobre servidor wger/Fasten alcançável), `query_health_record`
(fora do escopo até agora).

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
- `WgerClient`/`FastenClient` real sobre REST v2/FHIR (F13) — precisa de
  servidor wger/Fasten real alcançável (self-hosted, URL+credenciais do
  usuário), não disponível neste ambiente; dependência `http` não
  adicionada pra não entrar sem uso/teste. Filtragem do recurso FHIR
  bruto antes de qualquer prompt de LLM (`.claude/rules/brain.md`) —
  trabalho futuro, ainda não há montagem de prompt real.
- **Resolvido:** água (novo tipo `water` de `HealthEvent`) — `WaterLogger`/
  `log_water`, card no dashboard com registro rápido.
- Refeição/receita composta de ingredientes — pendência ainda em
  `docs/specs/nutricao.md`, não implementada.
- Nenhum provedor de pagamento real configurado (F10/F11 é só
  esqueleto, por decisão) — Play Billing/StoreKit/Stripe/Pix ficam pra
  quando o servidor existir.
- Peso/IMC/calorias/medidas nos cards de compartilhamento (F12) — regra
  de opt-in por campo já registrada em `.claude/rules/share.md`, mas os
  campos em si ainda não existem no card; entram desligados por padrão
  quando entrarem.
- **Resolvido:** todas as 7 ferramentas registradas no app agora têm
  comando de chat (`app/lib/chat_router.dart`) — "buscar alimento X",
  "plano de treino ID", "resumo da corrida ID", "registrar treino:
  exercicio SETxREPSxKG, ...". Testado de ponta a ponta (13 testes de
  widget em `app/test/widget_test.dart`).

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
| 13 | wger + Fasten (F13) | **PARCIAL** (`packages/wger`, `packages/fasten`, novos pacotes) — `WgerSyncLogger`/`sync_wger` (grava `set_log`, `source: wger`) e `FastenSyncLogger`/`sync_fasten_records` (grava `clinical_doc`, `source: fasten`) prontos e testados com Fixture; `WgerClient`/`FastenClient` real sobre REST v2/FHIR bloqueados — sem servidor wger/Fasten alcançável; não registrados no app (sem fonte real pra ligar) |
| — | `get_daily_summary`/`sync_wearable` (ferramentas do cérebro) | **CONCLUÍDO** — `get_daily_summary` (`packages/summary`, só leitura, cruza steps/meal/workout_session/gps_track); `sync_wearable` (`packages/wearable`, escrita com confirmação) |
| — | Primeira UI real do app (`app/`) | **PARCIAL** — telas Resumo + Chat, `AppDependencies` ligada aos pacotes reais, 8 ferramentas registradas (falta `start_run`, bloqueada por hardware), **todas com comando de chat** (`app/lib/chat_router.dart`), compartilhamento de treino/corrida (F12); `path_provider`/rasterização real não verificáveis sem device |
| — | Dashboard mínimo funcional (água/refeição/treino por toque) | **CONCLUÍDO** — 5 cards no layout final (`app/lib/screens/dashboard_screen.dart`), `LogMealScreen`/`LogWorkoutScreen`/diálogo de água montam texto e reaproveitam `BrainPipeline.handle` + confirmação existente; Passos/Corridas com placeholder honesto até sensor/GPS real existir |
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
