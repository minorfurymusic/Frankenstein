# CHECKLIST — Frankstein

> Gerado pela skill `project-recorder`. Fonte: `docs/PRODUTO.md` (fases e
> Definição de Pronto do MVP) cruzado com `STATUS.md` (estado real).
> Última atualização: 2026-08-09.

## Fases (`docs/PRODUTO.md:39-57`)

- [x] **F0** — Reconhecimento dos 7 repositórios + auditoria de licença (`docs/recon/*.md`, `docs/LICENSE-AUDIT.md`)
- [x] **F1** — ADRs (11/11 registradas, 9 aceitas: 1, 2, 3, 4a, 6, 7, 8, 9, 10; 2 propostas aguardando confirmação: 4, 5)
- [x] **F2** — Esqueleto do monorepo + CI + Makefile (CI verde, `ubuntu-latest`, commit `386b711`)
- [ ] **F3** — Health Data Core — não iniciado
- [ ] **F4** — Passos (foreground service) — não iniciado
- [ ] **F5** — Cérebro com 1 ferramenta só — não iniciado
- [ ] **F6** — Nutrição + código de barras — não iniciado (bloqueado por ADR-5 até confirmação: nutrição é PORT do OpenNutriTracker)
- [ ] **F7** — Academia: planos + sessão + séries — não iniciado
- [ ] **F8** — Corrida/caminhada com GPS — não iniciado
- [ ] **F9** — Wearable BLE — não iniciado (caminho liberado: ADR-4a aceita)
- [ ] **F10** — Entitlements — não iniciado
- [ ] **F11** — Pagamentos (um canal só) — não iniciado (mecanismo já desenhado na ADR-7 aceita)
- [ ] **F12** — Compartilhamento social — não iniciado
- [ ] **F13** — wger + Fasten — não iniciado (ADR-4 revisada, aguardando confirmação)
- [ ] **F14** — Painel B2B (produto separado, depois do MVP) — não iniciado

## Definição de Pronto do MVP (`docs/PRODUTO.md:59-68`)

- [ ] 1. Passos contados com a tela bloqueada por 8h, batendo com o sistema (±5%)
- [ ] 2. Refeição registrada por código de barras, com macros no dashboard
- [ ] 3. Pulseira BLE sincroniza FC e sono para o Health Data Core
- [ ] 4. "Quantas calorias comi hoje e quanto andei?" respondido pelo LLM local, offline
- [ ] 5. Plano de treino prescrito, executado com séries e carga, progressão visível
- [ ] 6. Corrida de 5 km gravada com tela bloqueada, rota e splits corretos, bateria medida
- [ ] 7. Card de corrida compartilhado no Instagram com rota ofuscada e nada clínico
- [ ] 8. Assinatura ativada por Pix; entitlement chega ao app e sobrevive 7 dias offline
- [ ] 9. `docs/LICENSE-AUDIT.md` fechado e modelo de distribuição decidido — **bloqueado**: falta ADR-5 aceita + seção de fechamento no próprio `LICENSE-AUDIT.md`

**Nenhum dos 9 itens está completo.** Só a fundação (F0-F2) existe.

## Pendências imediatas

- [ ] Confirmação explícita da ADR-4 (wger/Fasten)
- [ ] Confirmação explícita da ADR-5 (licenciamento) — bloqueia "tudo"
- [ ] Fechar `docs/LICENSE-AUDIT.md` com a decisão final, depois da ADR-5
- [ ] Decidir por qual fase (F3+) começar a implementação de módulo de verdade
