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

## Clean room — obrigatório, não recomendação

Decidido em `docs/adr/005-licenciamento-distribuicao.md` (revisão 3).
Quem escreve código aqui **não pode ter aberto, nesta sessão ou em
qualquer momento anterior que informe o que está escrevendo**:

- O código-fonte do OpenNutriTracker (`github.com/simonoppowa/OpenNutriTracker`,
  `refs/opennutritracker/`).
- **`docs/recon/opennutritracker.md`.** Essa ficha foi escrita lendo o
  código-fonte (clone aberto, `pubspec.yaml`, árvore de `lib/`
  inspecionada) — usá-la como referência de implementação quebra o clean
  room por definição, porque a ficha já é, ela mesma, um produto de ter
  lido o código. Ela continua valendo para licença/stack/decisão de ADR,
  não para "como o módulo se comporta".

**Única fonte permitida para a implementação: `docs/specs/nutricao.md`.**
Se um comportamento não está lá, ele não existe até alguém atualizar a
especificação primeiro — separado, no tempo, de quem está implementando.

## Proibido

- Copiar código, estrutura de arquivos, nomes de classe/método, ou
  comentários do OpenNutriTracker — para dentro de `packages/nutrition/**`
  ou qualquer outro lugar do monorepo.
- Ter o código-fonte do OpenNutriTracker, ou `docs/recon/opennutritracker.md`,
  aberto lado a lado enquanto se escreve código aqui. Se a especificação
  não responde "como fazer isso", pare e atualize `docs/specs/nutricao.md`
  numa sessão separada — não abra o código deles para preencher a lacuna.
- Nomear arquivo, classe, variável ou rota de forma que espelhe a
  organização interna do OpenNutriTracker. Coincidência de nome óbvio de
  domínio (`meal`, `food`, `barcode`) é inevitável e não é o problema; o
  problema é replicar a árvore de diretórios ou a divisão de
  responsabilidades deles.

## Obrigatório

- A reimplementação parte só de `docs/specs/nutricao.md`.
- Todo arquivo-fonte do módulo de nutrição leva, no cabeçalho, a
  declaração:

  ```
  // Implementação original do Frankstein. Não deriva do código-fonte do
  // OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.
  ```

  (adaptar o formato de comentário à linguagem do arquivo; o texto é o
  que importa.)

## Consequência de violar

`docs/adr/005-licenciamento-distribuicao.md` registra: PORT só é válido
sob estas condições. Se qualquer uma for violada, a suposição que mantém
o cliente Apache-2.0 cai — o cliente vira GPL-3.0 automaticamente, sem
precisar de nova ADR para declarar isso. É consequência, não punição.
