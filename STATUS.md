# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **3 — Health Data Core, em andamento.** Schema `HealthEvent`
implementado e testado em `packages/health_core` (append-only, dedup por
`(source, external_id)`, correção como evento novo, tabela própria de
`gps_track_points`). Detalhe completo em `docs/HISTORICO.md`.

**Ciclo atual:** health_core prova: `make lint`/`make test` verdes (15
testes novos, incluindo o teste de ida-e-volta com arquivo real exigido
por `.claude/rules/datacore.md`). Próximo: nenhum módulo consome o Core
ainda — F4 (passos) é o primeiro candidato natural.

**Pendências ativas:** nenhuma.

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
| 3 | Health Data Core (F3) | **schema implementado e testado** (`packages/health_core`) — `HealthEvent` append-only, dedup, correção, `gps_track_points`; nenhum módulo consome o Core ainda |
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
