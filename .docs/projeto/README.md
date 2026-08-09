# `.docs/projeto/` — registro gerado pela skill `project-recorder`

Adaptado pro Claude Code neste ciclo (2026-08-09). A skill original foi
desenhada pro claude.ai (artifacts, `conversation_search`, Zapier) — nada
disso existe neste ambiente. O que foi mantido e o que foi adaptado:

- **`CHANGELOG.md`** — gerado a partir de `git log` real deste
  repositório (46 commits), não de artifacts/conversas.
- **`CHECKLIST.md`** — gerado a partir de `docs/PRODUTO.md` (fases e
  Definição de Pronto do MVP) cruzado com `STATUS.md`.
- **`ERROR_LOG.md`** — erros reais já documentados em `docs/HISTORICO.md`
  e nos commits, não inventados pra preencher o formato.
- **`TOKEN_ANALYSIS.md`** — **não criado**. Este projeto já tem
  `docs/EFICIENCIA.md`, que faz a mesma análise com dado literal do
  transcript da sessão (não estimativa) e é mais rigoroso que o que a
  skill produziria do zero. Duplicar criaria duas fontes de verdade
  conflitantes — vá direto em `docs/EFICIENCIA.md`.
- **`artifacts.json` / `conversations.json`** — **não aplicável**. Não
  existem artifacts do claude.ai nem `conversation_search` neste ambiente
  (Claude Code opera sobre o repositório Git, não sobre uma conversa do
  claude.ai com artifacts anexados).

Este diretório é redundante por natureza com `STATUS.md` +
`docs/HISTORICO.md` + `docs/adr/*.md`, que já são a fonte de verdade
deste projeto, num formato mais rigoroso (prova literal, citação
`arquivo:linha`, gate de aceite explícito por ADR). Trate `.docs/projeto/`
como um índice de conveniência no formato que a skill espera — não como
uma segunda fonte de verdade. Se os dois divergirem, `STATUS.md`/
`docs/HISTORICO.md` ganham.
