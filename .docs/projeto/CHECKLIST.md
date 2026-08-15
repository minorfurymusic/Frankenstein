# CHECKLIST — Frankstein

> Gerado pela skill `project-recorder`. Fonte: `docs/PRODUTO.md` (fases e
> Definição de Pronto do MVP) cruzado com `STATUS.md` (estado real).
> Última atualização: 2026-08-15.

## Fases (`docs/PRODUTO.md:39-57`)

- [x] **F0** — Reconhecimento dos 7 repositórios + auditoria de licença (`docs/recon/*.md`, `docs/LICENSE-AUDIT.md`)
- [x] **F1** — ADRs (**11/11 aceitas** — ADR-4 e ADR-5 confirmadas em 2026-08-09, últimas duas)
- [x] **F2** — Esqueleto do monorepo + CI + Makefile (CI verde, `ubuntu-latest`, commit `386b711`)
- [x] **F3** — Health Data Core — schema `HealthEvent` implementado e testado (`packages/health_core`, 15 testes, `make lint`/`make test` verdes).
- [x] **F4** — Passos — `StepsRepository` implementado e testado (`packages/activity`, agregação de contador cumulativo + reset). Foreground service Android real não implementado — sem device pra testar aqui.
- [x] **F5** — Cérebro com ferramentas — pipeline provado com 2 ferramentas reais coexistindo (`get_steps`, `log_meal`). MLC LLM real (on-device) não implementado — sem device pra testar neste ambiente; entra depois via interface `ToolCaller`.
- [x] **F6** — Nutrição + código de barras — `packages/nutrition` implementado e testado (27 testes). **Catálogo real**: Tabela TACO (NEPA/UNICAMP, 578 alimentos) substitui o dataset de fixture na produção desde 2026-08-14. `flutter_zxing` concreto (câmera) fica pra depois.
- [x] **F7** — Academia: planos + sessão + séries — `packages/activity` (`WorkoutPlan`/`WorkoutRepository`, `WorkoutLogger`, `get_workout_plan`/`log_workout_session`), 14 testes novos. Sem dependência de hardware, testado de ponta a ponta.
- [~] **F8** — Corrida/caminhada com GPS — PARCIAL: `RunCalculator`/`RunLogger`/GPX/ofuscação de rota/`get_run_summary` prontos e testados (`packages/activity`); captura de GPS real (WRAP Android/PORT iOS) e `start_run` bloqueados — sem SDK/device Android/iOS neste ambiente (`docs/adr/009-gps.md`)
- [~] **F9** — Wearable BLE — PARCIAL: `packages/wearable` (`WearableSyncLogger`/`sync_wearable`, FC+sono, dedup por `external_id`), 10 testes. FEDERATE via Health Connect (ADR-4a), não BLE/Kotlin direto. `WearableDataSource` real bloqueada — sem Android SDK/device com Gadgetbridge; não registrada no app (sem fonte real)
- [~] **F10** — Entitlements — PARCIAL, esqueleto: `Entitlement`/`EntitlementVerifier` (Ed25519 real, testado), graça offline, `Subscription`, `PendingPayment`, `WebhookIdempotencyGuard` (`packages/entitlements`). Nenhum provedor configurado, por decisão.
- [~] **F11** — Pagamentos (um canal só) — PARCIAL: modelos de `Subscription`/`PendingPayment` (Pix assíncrono) prontos; nenhum provedor (Play Billing/StoreKit/Stripe/Pix real) configurado, por decisão (mecanismo desenhado na ADR-7 aceita)
- [~] **F12** — Compartilhamento social — PARCIAL: `packages/share` (`WorkoutShareCardData`/`RunShareCardData`, checagem estrutural anti-clínico, rota ofuscada), `SharePreviewScreen`/`ShareSheet`/`CardImageCapturer` em `app/`, 8 testes novos. Rasterização real (`RepaintBoundary.toImage`) não verificável sem device
- [ ] **F13** — wger + Fasten — não iniciado (caminho liberado: ADR-4 aceita)
- [ ] **F14** — Painel B2B (produto separado, depois do MVP) — não iniciado

## Definição de Pronto do MVP (`docs/PRODUTO.md:59-68`)

- [ ] 1. Passos contados com a tela bloqueada por 8h, batendo com o sistema (±5%) — precisa de device Android real
- [ ] 2. Refeição registrada por código de barras, com macros no dashboard — catálogo real (TACO) pronto, `log_meal` funcionando na UI (via chat); falta câmera real (`flutter_zxing`, sem device pra validar)
- [~] 3. Pulseira BLE sincroniza FC e sono para o Health Data Core — lógica pronta e testada (`packages/wearable`); falta `WearableDataSource` real sobre Health Connect (sem Android SDK/device com Gadgetbridge aqui)
- [~] 4. "Quantas calorias comi hoje e quanto andei?" respondido pelo LLM local, offline — `get_daily_summary` funciona na UI (tela Resumo + comando de chat "resumo de hoje"); falta o LLM real (roteador determinístico cobre só comando estruturado, não pergunta livre)
- [ ] 5. Plano de treino prescrito, executado com séries e carga, progressão visível — lógica pronta (`get_workout_plan`/`log_workout_session` registradas no app), sem tela dedicada nem comando de chat ainda
- [ ] 6. Corrida de 5 km gravada com tela bloqueada, rota e splits corretos, bateria medida — precisa de captura de GPS real (WRAP Android)
- [~] 7. Card de corrida compartilhado no Instagram com rota ofuscada e nada clínico — card + share sheet nativo funcionam de ponta a ponta (testado com captura fake); falta verificar a rasterização real (`RepaintBoundary.toImage`) num device de verdade
- [ ] 8. Assinatura ativada por Pix; entitlement chega ao app e sobrevive 7 dias offline — modelos prontos (F10/F11), nenhum provedor real configurado
- [x] 9. `docs/LICENSE-AUDIT.md` fechado e modelo de distribuição decidido — **feito** em 2026-08-09, seção "Fechamento"

**3 de 9 itens parcial (3, 4, 7), 1 fechado (9), 5 ainda não começaram de
verdade** — a maioria depende de device Android/iOS real (itens 1, 3, 6,
7) ou de trabalho de UI/escopo ainda não feito (2, 5, 8).

## Primeira UI do app (`app/`) — 2026-08-14

- [x] `app/` deixou de ser `Scaffold` vazio — depende de verdade de `packages/{health_core,tool_registry,brain,activity,nutrition,summary}`
- [x] Tela Resumo (`get_daily_summary` ao abrir)
- [x] Tela Chat (`BrainPipeline` + roteador determinístico + confirmação real via `AlertDialog`)
- [x] 6 de 7 ferramentas mínimas do MVP registradas no `ToolRegistry` do app (falta `start_run`, bloqueada por hardware; `sync_wearable`/`query_health_record` fora de escopo)
- [x] Testado de ponta a ponta com dado real (TACO `taco-1`) — grava `HealthEvent` de verdade, confirmação/recusa provadas
- [ ] `path_provider` (armazenamento real em device) — não verificável sem device
- [ ] Comando de chat pra `search_food`/`get_workout_plan`/`log_workout_session`/`get_run_summary` — só `get_daily_summary`/`get_steps`/`log_meal` têm regra de roteador hoje

## Pendências imediatas

- [x] ~~Confirmação explícita da ADR-4 (wger/Fasten)~~ — aceita 2026-08-09
- [x] ~~Confirmação explícita da ADR-5 (licenciamento)~~ — aceita 2026-08-09
- [x] ~~Fechar `docs/LICENSE-AUDIT.md` com a decisão final~~ — feito
- [x] ~~Iniciar F3 (Health Data Core)~~ — concluído
- [x] ~~F8 (parte sem Android), F10/F11 (esqueleto), ferramentas extras do cérebro, catálogo real de alimentos~~ — concluído 2026-08-14
- [x] ~~Primeira UI do app (Resumo + Chat)~~ — concluído 2026-08-14
- [x] ~~F9 (wearable, FC+sono via Health Connect)~~ — concluído 2026-08-15 (parte sem device)
- [x] ~~F12 (compartilhamento social, cards de treino/corrida)~~ — concluído 2026-08-15 (parte sem device)
- [ ] Próxima etapa em aberto: mais comandos de chat (ferramentas já registradas sem regra de roteador), campos sensíveis opt-in nos cards, ou F13 (wger/Fasten)
