# ADR-17 — Peso desejado e objetivo automático

**Status:** aceito
**Data:** 2026-10-05

## Contexto

O perfil guardava só o objetivo (perder, manter, ganhar) e o ritmo em
g/dia (ADR-15). Perguntado se queria um campo de peso desejado, o usuário
respondeu (2026-10-05): "Sim, a pessoa pode colocar esse campo, tem que
mudar a lógica caso ele coloque, pois muda algumas coisas no aplicativo."

## Opções consideradas

1. **Peso desejado só informativo** (linha no gráfico e previsão), objetivo
   continua escolhido à mão.
2. **Peso desejado comanda o objetivo:** com o campo preenchido, o app
   decide perder/manter/ganhar comparando o peso atual com o desejado.

## Decisão

**Opção 2**, porque o usuário pediu que a lógica mude quando o campo existe.

- **Campo opcional** em Conta › Perfil (kg, SI). Vazio = tudo como antes
  (objetivo escolhido à mão).
- **Objetivo efetivo:** peso atual (o registro mais recente) acima do
  desejado por mais de **1 kg** → perder; abaixo por mais de 1 kg → ganhar;
  dentro de ±1 kg → manter. A faixa de 1 kg existe para a oscilação normal
  de um dia para o outro não ficar trocando o objetivo. O objetivo efetivo
  vale para tudo o que dependia do objetivo: ajuste de calorias, proteína
  por kg (ADR-15) e o que conta como "meta do dia cumprida".
- **Ao chegar:** o app passa sozinho para "manter" e diz isso (Corpo e
  Metas). Se a pessoa se afastar mais de 1 kg de novo, o objetivo volta a
  perder/ganhar.
- **Ritmo:** continua o do perfil (g/dia, sem teto — ADR-15). Com ritmo
  zero não há ajuste de calorias nem previsão; a tela pede o ritmo.
- **Previsão:** dias = diferença em gramas ÷ ritmo em g/dia. Mostrada como
  "no ritmo atual, chega em ~N semanas (por volta de dd/mm)". É conta, não
  promessa: o corpo não perde peso em linha reta.
- **Nada é travado** (mesma linha da ADR-15): peso desejado com IMC abaixo
  de 18,5 ou acima de 25 só mostra o IMC daquele peso, como informação.

## Consequências

- **Fica mais fácil:** a pessoa diz aonde quer chegar e o app ajusta
  sozinho, inclusive para manutenção na chegada.
- **Fica mais difícil:** o objetivo escolhido à mão deixa de valer enquanto
  houver peso desejado; a tela de perfil precisa mostrar isso para não
  confundir.
- **Passa a ser proibido:** prometer data de chegada; a previsão é sempre
  rotulada como estimativa pelo ritmo.
