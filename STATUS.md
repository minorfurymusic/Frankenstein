# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.

**Fase:** 0 — Reconhecimento
**Ciclo atual:** 1
**Objetivo do ciclo 1:** produzir `docs/recon/mlc-llm.md`

## Progresso

| Fase | Item | Status |
|---|---|---|
| 0 | Ficha MLC LLM | pendente |
| 0 | Ficha OpenTracks | pendente |
| 0 | Ficha Gadgetbridge | pendente |
| 0 | Ficha FoodYou | pendente |
| 0 | Ficha OpenNutriTracker | pendente |
| 0 | Ficha wger | pendente |
| 0 | Ficha Fasten Health | pendente |
| 0 | docs/LICENSE-AUDIT.md | pendente |
| 0 | docs/VIABILITY.md | pendente |
| 1 | ADR-1 a ADR-10 | pendente |

## Decisões já tomadas (não reabrir sem motivo novo)

- Código aberto, copyleft aceito.
- **Sem anúncios em nenhuma superfície.** Sistema de anúncios foi cancelado.
- Offline-first: a IA roda no aparelho do usuário.
- Grátis = tudo que roda no aparelho. Pago = tudo que consome servidor.
- Monetização: assinatura R$20/US$10 + B2B para profissionais de saúde.
- Escopo inclui módulo de academia (planos, treino, corrida/caminhada com GPS)
  e compartilhamento social (Instagram, TikTok, Facebook).

## Débito técnico

(vazio)

## Histórico de ciclos

- **Ciclo 0 — organizar estrutura de diretórios do kit inicial.** O kit havia
  sido desempacotado com todos os arquivos soltos na raiz do repositório, sem
  a estrutura que `CLAUDE.md`/`COMECE-AQUI.md` pressupõem. Movidos para
  `docs/`, `docs/adr/`, `docs/recon/`, `.claude/rules/`, `.claude/commands/`
  e `scripts/`. Adicionado `.gitignore` (ausente). Nenhuma ficha de
  reconhecimento foi criada; ciclo 1 (`docs/recon/mlc-llm.md`) continua
  pendente.
- **Ciclo 0.6 — alinhar troca Flutter Steps Tracker → OpenTracks.** O papel de
  "corrida, caminhada e GPS" passou de Flutter Steps Tracker para OpenTracks
  em `docs/PRODUTO.md` e nesta tabela de progresso. `scripts/clone-refs.sh`:
  entrada renomeada para `opentracks` (minúsculas), comentário de cabeçalho
  atualizado, clone de um repositório não aborta mais os demais (erros
  acumulados e resumidos no fim, `exit 1` se algum falhar), hash curto do
  HEAD impresso após cada clone bem-sucedido. Registrado em `docs/PRODUTO.md`
  que o pedômetro do celular não vem de nenhum dos 7 — é código próprio.
  Clone ainda não executado; licença do OpenTracks (permissiva vs. copyleft)
  segue não verificada até a ficha de reconhecimento.
