# ADR-28 — O Cérebro procura no aparelho o que está salvo

**Status:** aceito (decisão explícita do usuário, 2026-10-20: "Faça todos",
itens 18 a 22 de `docs/DECISOES-PENDENTES.md`)
**Data:** 2026-10-20

## Contexto

No teste no aparelho de 2026-10-20 (`docs/TESTE-APARELHO.md`), o usuário
mandou códigos de barras pelo Cérebro e a IA inventou o produto ("é o
Oreo", "é o Bis"). A IA não tem nenhuma base de códigos, e o Cérebro não
consultava os itens que o usuário tinha cadastrado. Além disso, "repita o
café da manhã salvo" não funcionava, porque a IA não vê o que está salvo.
Bebidas estimadas por foto ficavam em gramas, "Café" aparecia com a medida
"fatia", e o mesmo café estimado aparecia repetido na busca.

## Decisão

O que está salvo **não vai para a IA**. A IA só diz o que entendeu; o app
procura no aparelho, como já fazia com os remédios.

- **Código de barras** (digitado ou com os números visíveis na foto): a IA
  copia só os dígitos, sem nomear o produto. O app procura o código nos
  itens cadastrados. Se achar, o cartão usa os valores do item salvo
  ("dos seus itens salvos", sem a marca de estimativa). Se não achar, o
  item sai do cartão e o app explica como cadastrar.
- **Repetir refeição** ("repete o café da manhã de ontem"): a IA devolve
  `repeat_meals` (tipo e dia: hoje, ontem ou a mais recente). O app acha a
  refeição salva e propõe um cartão com os mesmos itens.
- **"O que eu comi hoje/ontem?"**: pergunta respondida pelo app
  (`get_meals`), sem a IA.
- **Bebidas**: a foto do prato também marca bebida (`liquid`). A bebida
  estimada fica marcada no id do alimento (`chat-ml-…`, `photo-ml-…`), e as
  medidas aparecem em ml (copo, xícara). "Café", "chá", "leite" e outras
  bebidas sozinhas também contam como bebida pelo nome.
- **Estimados repetidos**: um estimado igual (mesmo nome e valores) é
  reaproveitado em vez de criado de novo, e a busca mostra cada um uma vez.
- **Tempo esgotado** tem mensagem própria, separada de "Sem conexão".

## Consequências

- A IA continua sem ver a lista de itens e as refeições salvas. Só vai para
  ela o que já aparece na própria conversa: os cartões e as respostas do app
  (por exemplo, a lista de "o que comi hoje") voltam como "Conversa até
  agora" na mensagem seguinte, como já acontecia com o "Resumo de hoje"
  (`app/lib/screens/brain/brain_screen.dart:277-301`).
- Quantidade em unidades ("6 biscoitos") de um item cadastrado continua com
  gramas estimadas pela IA, porque o item guarda só valores por 100 g. A
  pessoa corrige as gramas no cartão.
- O pacote de nutrição não mudou (sala limpa, `.claude/rules/port.md`):
  tudo isso está no app (`app/lib/ai/brain_ai.dart`,
  `app/lib/data/nutrition_store.dart`, `app/lib/data/household_measures.dart`).
