# ADR-27 — O Cérebro conversa como a IA da pessoa, com avisos e travas mínimas

**Status:** aceito (decisão explícita do usuário, 2026-10-18)
**Data:** 2026-10-18

## Contexto

No teste no aparelho, "vc conversa tmb?" e "pode explicar o que cada um
desses remédios fazem?" foram recusados: a regra mandava só registrar. O
usuário decidiu: "Função igual ao Gemini ou a IA que a pessoa coloca a sua
API key. Só manter os avisos de que não é médico."

## Decisão

O Cérebro conversa como um assistente de IA comum (a chave é da pessoa —
ADR-11): responde perguntas gerais, explica remédios e doenças como a bula
e fontes de saúde, fala de alimentação e exercício, motiva e acolhe. Ficam
as travas mínimas:

- Não manda a pessoa começar, parar, trocar ou mudar dose de remédio ou
  tratamento; explica, e lembra que a decisão é com o médico.
- Não afirma diagnóstico da pessoa.
- Crise ou emergência: texto fixo do app (CVV 188, SAMU 192).
- Registro só por cartão confirmado (como sempre).
- Toda resposta da IA leva o aviso "A IA não é médica: decisões de saúde,
  com um profissional."

## Consequências

- Substitui a parte de `.claude/rules/brain.md` que mandava recusar e
  dizer que "o app só registra".
- Respostas mais longas gastam um pouco mais da cota da chave da pessoa.
