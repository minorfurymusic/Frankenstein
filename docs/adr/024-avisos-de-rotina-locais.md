# ADR-24 — Aviso de quebra de rotina: detectado no celular, sem IA

**Status:** aceito (decisão explícita do usuário, 2026-10-18)
**Data:** 2026-10-18

## Contexto

O usuário quer que, quando a rotina quebra (ex.: sempre caminha e ficou
3 dias sem caminhar), venha uma notificação perguntando como a pessoa
está — muitas vezes é algo emocional que ela não registrou. O ADR-11
proíbe chamar a IA em segundo plano.

## Opções consideradas

1. **Detecção local** com texto fixo; a IA só entra quando a pessoa
   responde no Cérebro.
2. IA em segundo plano escrevendo a notificação.

## Decisão

Opção 1 (recomendada, escolhida pelo usuário em 2026-10-18). O app
compara os últimos dias com o hábito das semanas anteriores (caminhada,
treino, registro de comida, remédio, humor em queda) e, quando quebra,
mostra uma notificação local com pergunta fixa ("Faz 3 dias sem
caminhada. Está tudo bem?"). Tocar abre o Cérebro. No máximo um aviso
por dia; a pessoa pode desligar cada tipo.

## Consequências

- Grátis, sem internet, sem cota. Nenhum dado sai do celular.
- O texto do aviso é do app; a conversa depois é com a IA, só se a
  pessoa responder.
