# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **F3, F4, F5, F6, F7 e (parcial) F8 concluídas.** Health Data
Core, passos, o pipeline do cérebro, nutrição (com **catálogo real de
alimentos** — Tabela TACO, NEPA/UNICAMP, 578 itens, ver abaixo), academia
e corrida/caminhada (só a parte sem Android real). Além disso: esqueleto
de Entitlements/Pagamento (F10/F11, sem provedor configurado) e duas
ferramentas novas do cérebro (`get_daily_summary`, `search_food`).
Detalhe completo em `docs/HISTORICO.md`.

**Ciclo atual:** manhã de trabalho — tudo que não depende de
device/emulador Android, numa sessão só (múltiplos commits):

1. **F8 (corrida/GPS), só a parte sem Android.** Decisão já tomada
   (`docs/adr/009-gps.md`) é WRAP do OpenTracks no Android — captura de
   GPS real fica de fora. Implementado: migração `accuracy_meters`,
   `RunCalculator`, GPX export/import, `obfuscateRouteEnds`, `RunLogger`,
   `get_run_summary`. `start_run` (escrita) não implementada — sem
   captura real não há o que fazer de verdade.
2. **F10/F11, esqueleto sem provedor.** `Entitlement` assinado Ed25519
   (verificação real testada — sign/verify/detecção de adulteração),
   `Subscription`, `PendingPayment` (Pix assíncrono), idempotência de
   webhook. Nenhum SDK de pagamento, nenhuma chave real, nenhum servidor.
3. **`get_daily_summary`** (novo pacote `packages/summary`, cruza
   steps/meal/workout_session/gps_track) e **`search_food`** (nutrition).
4. **Catálogo real de alimentos.** Open Food Facts (fonte original)
   segue bloqueado pelo proxy — encontrada alternativa real e aberta:
   **Tabela TACO** (NEPA/UNICAMP, dado público, reprodução permitida com
   citação da fonte, sem nenhuma relação com o OpenNutriTracker). 578 de
   597 alimentos importados via `brolesi/taco` (MIT, dados reorganizados
   do NEPA/UNICAMP). `FoodRepository.open()` agora semeia com o catálogo
   real por padrão. **Bug pego e corrigido antes de aceitar como
   pronto:** reabrir um arquivo já semeado batia na `PRIMARY KEY` de
   `foods.id` — corrigido com `INSERT OR IGNORE` só no caminho de
   reseed, `insertCustomFood` continua estourando alto em duplicata real.

Itens 3-4 tocam `packages/nutrition/**`, fora do alcance desta sessão
(clean room, `.claude/rules/port.md`) — implementados por subagentes
limpos (3 no total), cada um verificado independentemente antes do
commit (não só aceito pelo autorrelato do subagente).

**Pendências ativas (revisado):**
- **Adiado por decisão, não por bloqueio técnico:** `BarcodeDecoder`
  concreto com `flutter_zxing` em `app/` — sem câmera/emulador real pra
  validar, e o `app/` ainda não tem infraestrutura de UI. Fica pra quando
  o app shell ganhar UI de verdade.
- `start_run` (ferramenta de escrita de F8) e a captura de GPS real
  (WRAP OpenTracks Android, PORT iOS) — bloqueadas por falta de
  SDK/device Android/iOS neste ambiente, mesmo limite de F4.
- Água (novo tipo de `HealthEvent`) e refeição/receita composta de
  ingredientes — pendências já registradas em `docs/specs/nutricao.md`,
  não implementadas.
- Nenhum provedor de pagamento real configurado (F10/F11 é só
  esqueleto, por decisão) — Play Billing/StoreKit/Stripe/Pix ficam pra
  quando o app tiver UI e o servidor existir.

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
| 10/11 | Entitlements/Pagamento | **PARCIAL, esqueleto** (`packages/entitlements`) — `Entitlement`/`EntitlementVerifier` (Ed25519 real), `Subscription`, `PendingPayment`, `WebhookIdempotencyGuard`; nenhum provedor configurado, por decisão |
| — | `get_daily_summary` (ferramenta do cérebro) | **CONCLUÍDO** (`packages/summary`, novo pacote) — só leitura, cruza steps/meal/workout_session/gps_track |
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
