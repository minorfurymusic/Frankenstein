# ADR-26 — A IA pode propor trocas equivalentes no plano do profissional

**Status:** aceito (decisão explícita do usuário, 2026-10-18)
**Data:** 2026-10-18

## Contexto

`.claude/rules/brain.md` proíbe a IA recomendar dieta ou tratamento. O
usuário quer que, quando a pessoa enjoa ("não aguento mais ovo"), a IA
ajude a trocar o item do plano para a pessoa não abandonar o plano.

## Decisão

Opção recomendada e escolhida (2026-10-18): a IA pode propor só **trocas
equivalentes dentro do plano já existente** — alimento por outro de
macronutrientes parecidos na mesma refeição; exercício por outro do mesmo
grupo muscular — sem mudar metas de calorias, cargas ou número de
refeições. Sempre como cartão que a pessoa confirma, com o lembrete de
avisar o nutricionista ou o profissional de educação física. Dieta nova,
restrição, suplemento ou remédio continuam proibidos.

## Consequências

- Exceção explícita à regra "nunca recomenda dieta", limitada a trocas.
- Plano clínico (ex.: renal, diabetes) segue igual: a troca mantém os
  números do plano.
