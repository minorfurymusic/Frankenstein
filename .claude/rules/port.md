---
paths:
  - "packages/nutrition/**"
---
# Regras de PORT — módulo de nutrição

O módulo de nutrição existe por **PORT** (reimplementação), decidido em
`docs/adr/005-licenciamento-distribuicao.md`. É a condição que mantém o
cliente Apache-2.0 em vez de GPL-3.0 — não é estilo de código, é a linha
que decide a licença do produto inteiro. Trate como inviolável, não como
preferência.

## Proibido

- Copiar código, estrutura de arquivos, nomes de classe/método, ou
  comentários do OpenNutriTracker (`github.com/simonoppowa/OpenNutriTracker`,
  GPL-3.0) — para dentro de `packages/nutrition/**` ou qualquer outro
  lugar do monorepo.
- Ter o código-fonte do OpenNutriTracker aberto lado a lado enquanto se
  escreve código aqui. Se precisar consultar "como eles fizeram", pare,
  feche o código deles, e volte para `docs/specs/nutricao.md` — se a
  resposta não estiver lá, a especificação está incompleta; corrija a
  especificação, não copie a solução deles.
- Nomear arquivo, classe, variável ou rota de forma que espelhe a
  organização interna do OpenNutriTracker. Coincidência de nome óbvio de
  domínio (`meal`, `food`, `barcode`) é inevitável e não é o problema; o
  problema é replicar a árvore de diretórios ou a divisão de
  responsabilidades deles.

## Obrigatório

- A reimplementação parte de `docs/specs/nutricao.md` — a especificação
  funcional em prosa —, não do código-fonte do OpenNutriTracker. Se um
  comportamento não está na especificação, ele não existe até alguém
  atualizar `docs/specs/nutricao.md` primeiro.
- Todo arquivo-fonte do módulo de nutrição leva, no cabeçalho, a
  declaração:

  ```
  // Implementação original do Frankstein. Não deriva do código-fonte do
  // OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.
  ```

  (adaptar o formato de comentário à linguagem do arquivo; o texto é o
  que importa.)
- `docs/recon/opennutritracker.md` vale como referência de **o que** o
  módulo faz — funcionalidade, telas, fluxos observáveis, comportamento
  anunciado publicamente. **Nunca** de **como**: nenhuma linha de código,
  nenhuma estrutura de dados interna, nenhum algoritmo específico deles
  entra por essa porta.

## Consequência de violar

`docs/adr/005-licenciamento-distribuicao.md` registra: PORT só é válido
sob estas condições. Se qualquer uma for violada, a suposição que mantém
o cliente Apache-2.0 cai — o cliente vira GPL-3.0 automaticamente, sem
precisar de nova ADR para declarar isso. É consequência, não punição.
