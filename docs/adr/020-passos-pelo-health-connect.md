# ADR-20 — Passos: Health Connect como fonte principal; contador do app como reserva

**Status:** aceito (decisão explícita do usuário, 2026-10-16)
**Data:** 2026-10-16

## Contexto

No teste no aparelho (docs/TESTE-APARELHO.md, item 2), o RLT contou ~400
passos num dia com caminhada de 1,2 km (~1.580 passos pela passada de
0,415 × 1,83 m). Prints do Conexão Saúde mostraram que o próprio celular
(Android 14+, contagem nativa do Health Connect) e o Google Fit já gravam
os passos lá, mas o RLT só pedia sono e frequência cardíaca — nunca
`READ_STEPS`. A leitura só acontecia ao abrir o app ou tocar em
"Sincronizar agora". O contador próprio do RLT (`TYPE_STEP_COUNTER` num
foreground service) depende de o Android não derrubar o serviço.

## Opções consideradas

1. Só o contador próprio do app.
2. **Health Connect como fonte principal; contador do app como reserva.**
3. Somar as duas fontes.

## Decisão

Opção 2, recomendada e aceita pelo usuário ("Sim, concordo com sua
recomendação", 2026-10-16):

- O RLT pede `READ_STEPS` ao Health Connect e lê o **total por dia** (o
  Health Connect já junta celular e Google Fit sem duplicar).
- Cada leitura que muda o total vira um evento `steps` com
  `daily_total: true` (`source: wearable`) — fica no banco do RLT para
  sempre, mesmo que o Health Connect apague depois.
- **Uma fonte por dia:** vale o maior entre o total mais recente do Health
  Connect e a soma do contador do app (`dailyStepCount`,
  `packages/health_core/lib/src/daily_steps.dart`). Nunca a soma das duas.
- Atualiza ao abrir o app, ao voltar para ele e a cada 5 minutos com ele
  aberto. **Sem leitura com o app fechado** (decisão do usuário: ao abrir,
  atualiza).

## Consequências

- **Fica mais fácil:** os passos contados pelo próprio Android aparecem no
  RLT sem depender do serviço do app sobreviver.
- **Limite do Health Connect:** na primeira permissão, só entrega dados de
  até 30 dias antes; depois disso, o que o RLT leu fica guardado.
- **Passa a ser proibido:** somar Health Connect e contador do app no
  mesmo dia.
