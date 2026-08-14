# CHECKLIST — Frankstein

> Gerado pela skill `project-recorder`. Fonte: `docs/PRODUTO.md` (fases e
> Definição de Pronto do MVP) cruzado com `STATUS.md` (estado real).
> Última atualização: 2026-08-14.

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
- [ ] **F9** — Wearable BLE — não iniciado (caminho liberado: ADR-4a aceita)
- [~] **F10** — Entitlements — PARCIAL, esqueleto: `Entitlement`/`EntitlementVerifier` (Ed25519 real, testado), graça offline, `Subscription`, `PendingPayment`, `WebhookIdempotencyGuard` (`packages/entitlements`). Nenhum provedor configurado, por decisão.
- [~] **F11** — Pagamentos (um canal só) — PARCIAL: modelos de `Subscription`/`PendingPayment` (Pix assíncrono) prontos; nenhum provedor (Play Billing/StoreKit/Stripe/Pix real) configurado, por decisão (mecanismo desenhado na ADR-7 aceita)
- [ ] **F12** — Compartilhamento social — não iniciado
- [ ] **F13** — wger + Fasten — não iniciado (caminho liberado: ADR-4 aceita)
- [ ] **F14** — Painel B2B (produto separado, depois do MVP) — não iniciado

## Definição de Pronto do MVP (`docs/PRODUTO.md:59-68`)

- [ ] 1. Passos contados com a tela bloqueada por 8h, batendo com o sistema (±5%)
- [ ] 2. Refeição registrada por código de barras, com macros no dashboard — catálogo real (TACO) pronto; falta câmera real (`flutter_zxing`) e UI do app
- [ ] 3. Pulseira BLE sincroniza FC e sono para o Health Data Core
- [ ] 4. "Quantas calorias comi hoje e quanto andei?" respondido pelo LLM local, offline
- [ ] 5. Plano de treino prescrito, executado com séries e carga, progressão visível
- [ ] 6. Corrida de 5 km gravada com tela bloqueada, rota e splits corretos, bateria medida
- [ ] 7. Card de corrida compartilhado no Instagram com rota ofuscada e nada clínico
- [ ] 8. Assinatura ativada por Pix; entitlement chega ao app e sobrevive 7 dias offline
- [x] 9. `docs/LICENSE-AUDIT.md` fechado e modelo de distribuição decidido — **feito** em 2026-08-09, seção "Fechamento"

**8 dos 9 itens ainda não começaram** (dependem de código de módulo, F3+).
Item 9 é o primeiro a fechar — decisão, não implementação.

## Pendências imediatas

- [x] ~~Confirmação explícita da ADR-4 (wger/Fasten)~~ — aceita 2026-08-09
- [x] ~~Confirmação explícita da ADR-5 (licenciamento)~~ — aceita 2026-08-09
- [x] ~~Fechar `docs/LICENSE-AUDIT.md` com a decisão final~~ — feito
- [x] ~~Iniciar F3 (Health Data Core)~~ — concluído
- [x] ~~F8 (parte sem Android), F10/F11 (esqueleto), ferramentas extras do cérebro, catálogo real de alimentos~~ — concluído 2026-08-14
- [ ] Decidir próxima etapa: UI do app (destranca vários itens da Definição de Pronto de uma vez) ou F9 (wearable BLE) — pergunta em aberto pro usuário
