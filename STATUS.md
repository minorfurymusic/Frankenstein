# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** 2 — esqueleto do monorepo, **concluído** (CI verde, `ubuntu-latest`,
commit `386b711`; no sandbox de dev, `make build` Android e emulador
continuam bloqueados por infra — sem SDK, sem KVM, ver `docs/HISTORICO.md`
Ciclo 27).

**Ciclo atual:** 31 (numeração do usuário) — ADR-4 (wger/Fasten) revisada,
continua proposta, aguardando confirmação explícita.

**Pendências ativas:**
- **ADR-4** (wger/Fasten) — revisada, pronta, falta confirmação explícita.
- **ADR-5** (licenciamento) — última das 11 ainda proposta, bloqueia
  "tudo" por definição própria. Revisão 4 fez limpeza pequena (item
  desatualizado do "Não verificado"); decisão de fundo já estava sólida
  há 3 revisões. Falta confirmação explícita.
- ~~Perfil de dispositivo novo~~ — **feito.** Registrado como eixo
  independente do perfil de RAM da ADR-2, em `docs/PLATFORM-PARITY.md`
  ("Perfil de dispositivo — dois eixos, não um só").
- Confirmação de que Ciclo 32 (eficiência) e "Ciclos 33+" (esqueleto do
  monorepo) de uma mensagem anterior já tinham acontecido nesta sessão
  como Ciclo 32 e Ciclo 27 — sinalizado, sem objeção do usuário até aqui.

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
| 0 | docs/LICENSE-AUDIT.md | pronta (`docs/LICENSE-AUDIT.md`) |
| 0 | docs/VIABILITY.md | pronta (`docs/VIABILITY.md`) |
| 1 | ADR-1 (shell/multiplataforma) | **aceito** (`docs/adr/001-shell-multiplataforma.md`) |
| 1 | ADR-2 (modelo LLM) | **aceito** (`docs/adr/002-modelo-llm.md`) |
| 1 | ADR-3 (fonte da verdade/sync) | **aceito** (`docs/adr/003-fonte-verdade-sync.md`) |
| 1 | ADR-4 (wger/Fasten) | proposto, **revisão 1** (`docs/adr/004-wger-fasten.md`) — consequência de licença fundamentada em `docs/LICENSE-AUDIT.md` (Cenário B) + ADR-5 (cliente Apache-2.0); aguardando confirmação |
| 1 | ADR-4a (Gadgetbridge) | **aceito, revisão 2** (`docs/adr/004a-gadgetbridge.md`) — escrita no Health Connect confirmada por permissão declarada no APK publicado (F-Droid) + documentação oficial |
| 1 | ADR-5 (licenciamento) | proposto, **revisão 4** (`docs/adr/005-licenciamento-distribuicao.md`) — cliente Apache-2.0 via PORT do OpenNutriTracker, clean room obrigatório; aguardando confirmação |
| 1 | ADR-6 (sem anúncios) | **aceito** (`docs/adr/006-sem-anuncios.md`) |
| 1 | ADR-7 (canais/pagamento) | **aceito, revisão 3** (`docs/adr/007-canais-distribuicao-pagamento.md`) |
| 1 | ADR-8 (multi-tenant B2B/consentimento) | **aceito, revisão 1** (`docs/adr/008-multitenant-b2b-consentimento.md`) |
| 1 | ADR-9 (GPS) | **aceito** (`docs/adr/009-gps.md`) |
| 1 | ADR-10 (substitutos livres) | **aceito** (`docs/adr/010-substitutos-livres.md`) |
| 1 | **11/11 ADRs registradas** | **9 aceitas** (1, 2, 3, 4a, 6, 7, 8, 9, 10), 2 propostas (4, 5) |
| 2 | Esqueleto do monorepo (F2) | **CONCLUÍDO** — CI verde (`ubuntu-latest`), sandbox de dev sem SDK Android/KVM (limite de ambiente) |
| — | Relatório de eficiência (`docs/EFICIENCIA.md`) | Grupo A adotado como prática; Grupo B aplicado neste ciclo (este arquivo) |

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
