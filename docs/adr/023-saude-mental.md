# ADR-23 — Saúde mental: humor do dia, sintomas e aviso de crise, só no celular

**Status:** aceito (decisão explícita do usuário, 2026-10-18)
**Data:** 2026-10-18

## Contexto

O usuário pediu uma área de saúde mental para quem tem depressão,
bipolaridade, ansiedade ou outro transtorno, para ter o registro e para a
IA entender o que a pessoa está passando (sem ser médica). Dado de saúde
mental é o mais sensível que o app guarda (LGPD, dado sensível).

## Opções consideradas

1. **Registro local** (humor do dia, sintomas, questionários opcionais),
   nada vai à IA sem consentimento próprio (ADR-25).
2. Registro já mandado à IA junto com o resto.

## Decisão

Opção 1, recomendada e escolhida pelo usuário (2026-10-18):

- Novo tipo de evento `mood` (append-only, como os outros): humor 1–5,
  energia 1–5 e ansiedade 1–5 opcionais, sentimentos (lista curta) e
  nota livre. Um toque basta (só o humor).
- Tela Saúde › Saúde mental: "Como você está hoje?", histórico dos
  últimos 30 dias e o caminho para registrar sintomas mentais no diário
  de sintomas que já existe.
- Aviso fixo do app, sempre visível na tela e no Cérebro quando a IA
  marca `seek_care`: CVV 188 (24 h, gratuito) e SAMU 192. O texto é do
  app, nunca da IA.
- Questionários de rastreio (PHQ-9, GAD-7): entram só com o texto
  oficial em português conferido na fonte — até lá, pendentes
  (`TODO(frankstein)`). Mostram pontuação e evolução, nunca diagnóstico.
- Cuidador (ex.: Alzheimer) fica para depois: pede perfil de cuidador.

## Consequências

- **Fica mais fácil:** ver a evolução do humor (útil em bipolaridade e
  depressão) e levar ao profissional.
- **Passa a ser proibido:** a IA rotular transtorno; humor ir à IA sem o
  consentimento separado do ADR-25.
