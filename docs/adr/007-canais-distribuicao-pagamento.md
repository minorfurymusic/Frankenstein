# ADR-7 — Canais de distribuição e meios de pagamento

**Status:** proposto
**Data:** 2026-08-05 (revisão 2, mesmo dia — Opção 4 acrescentada em revisão)

## Contexto

`docs/MONETIZACAO.md:47-56` já lista os 4 canais candidatos (Google Play,
App Store, F-Droid/APK direto, Web) e pede explicitamente: "Confirme as
regras vigentes da loja antes de implementar e cite a fonte no ADR-7." Fiz
essa pesquisa via `WebSearch` (não é leitura de documentação oficial
primária linha a linha — ressalva de método no fim).

**Google Play:** a partir de 30/06/2026, EUA/Reino Unido/EEE ganham
pagamento externo com escolha lado a lado (Play Billing x link externo) e
taxa de 5% (Play Billing) ou isenta de taxa de billing no link externo,
mais uma taxa de serviço de 10% sobre o primeiro US$1 milhão/ano
independente do método. Brasil está na lista de países com opção de
sistema de faturamento alternativo (programa mais antigo, escolha in-app
entre processadores), mas a onda mais nova de **link externo** só chega a
mercados globais, Brasil incluso, até 30/09/2027 segundo uma das fontes.
[Google Play external billing](https://developer.android.com/google/play/billing/externalpaymentlinks),
[9to5google](https://9to5google.com/2026/06/24/google-play-store-external-billing-june-30/),
[PagBrasil sobre alternative billing no Brasil](https://www.pagbrasil.com/blog/markets/gaming/google-play-alternative-billing-in-brazil-a-guide-to-d2c-monetization-on-android/).

**Apple App Store:** nos EUA, desde maio/2025 (caso Epic), apps no
storefront americano podem incluir links externos de pagamento via
`StoreKit External Purchase` entitlement. Na UE existe entitlement
separada. Não encontrei confirmação de que isso vale para o Brasil.
[Apple Developer — External Purchase](https://developer.apple.com/documentation/storekit/external-purchase),
[Apple Developer — UE](https://developer.apple.com/support/communication-and-promotion-of-offers-on-the-app-store-in-the-eu/).

**Ligação com a ADR-5 (revisão 2):** o cliente agora é proposto como
Apache-2.0 (não mais GPL-3.0) — o risco histórico de conflito de licença
com os Termos da App Store (`docs/LICENSE-AUDIT.md`) não se aplica mais.
Essa parte da tensão que existia entre as duas ADRs está resolvida na
ADR-5, não aqui; esta ADR trata só de canal/pagamento.

## Opções consideradas

1. **Web como canal primário de pagamento** (Pix, cartão, boleto,
   checkout fora do app), com Google Play e App Store como canais de
   distribuição que **apontam** para o checkout web quando a política da
   loja/região permitir.
2. **Billing nativo de cada loja como primário** (Play Billing,
   StoreKit) — comissão de loja sempre, inclusive quando a política já
   permite evitar.
3. **F-Droid/APK direto como canal principal** — sem comissão, alcance
   bem menor.
4. **Nenhuma interface de pagamento dentro do app — acrescentada nesta
   revisão.** O app não vende nada, não tem botão de assinar, não tem
   link, não menciona onde pagar. Ele só lê e valida um entitlement
   assinado (`docs/MONETIZACAO.md`: `Entitlement { sub, plan, features,
   exp, sig: Ed25519 }`, já é a estrutura de dados que o projeto pretende
   usar). A assinatura é vendida **só no site** do Frankstein, fora do
   app, por qualquer meio (Pix, cartão, boleto). Como não há link, não há
   menção, não há botão — nenhuma regra de "external purchase link", de
   "reader app", ou de anti-steering das lojas é acionada, porque nenhuma
   delas regula um app que simplesmente não vende nada dentro de si.

## Por que a Opção 4 muda o peso da decisão

Toda a incerteza registrada nesta ADR (datas de rollout no Brasil,
percentuais de taxa, se a Apple já libera link externo para conta
brasileira) é sobre **como vender por link dentro do fluxo da loja**. A
Opção 4 não usa esse fluxo — não precisa da entitlement de link externo,
não precisa esperar a onda de 2027 chegar ao Brasil, não depende de
nenhuma das duas fontes que divergem entre si. É **implementável hoje**,
sem depender de nenhuma confirmação regulatória pendente.

O que ela custa: a compra fica fora do fluxo do app — o usuário precisa
sair, ir ao site, comprar, e só então o app reconhece o entitlement. Pior
conversão que um botão "assinar" dentro do app teria, provavelmente. É
uma troca de conveniência de checkout por zero risco de política de loja
e zero dependência de prazo regulatório incerto — mesmo tipo de troca que
a ADR-5 fez entre custo de engenharia e redução de risco jurídico.

## Decisão

**Opção 4 como caminho inicial, Opção 1 como evolução condicional.**

- **Agora:** nenhuma interface de pagamento no app. O app só lê/valida o
  entitlement assinado. Assinatura vendida exclusivamente no site
  (Pix, cartão, boleto — `docs/MONETIZACAO.md:52`). Distribuição nas 4
  frentes (Google Play, App Store, F-Droid, APK direto) sem nenhuma delas
  precisar de tratamento especial de billing, porque o app não vende nada
  nelas.
- **Evolução condicional, não decidida agora:** se/quando a política de
  link externo for confirmada para contas brasileiras (Google Play e/ou
  App Store), reavaliar se vale trazer um link de checkout **dentro** do
  app (Opção 1) para melhorar conversão — nesse ponto, sem o risco que
  motivou a Opção 4 na largada.
- F-Droid/APK direto continua disponível como sempre, sem comissão.

**Isto está proposto, não aceito.** Portão de custo/monetização — mas a
Opção 4 elimina a maior parte da incerteza regulatória que a versão
anterior desta ADR carregava sem resolver.

## Consequências

- **Fica mais fácil:** zero dependência de confirmar regras de loja para
  o Brasil antes de lançar — a Opção 4 funciona sob a política de hoje,
  em qualquer loja, sem entitlement especial. Nenhum risco de suspensão
  de conta por má leitura de uma política em transição.
- **Fica mais difícil:** conversão de assinatura pior (fricção de sair do
  app para pagar no site) — troca deliberada, registrada, não escondida.
  Se a Opção 1 entrar depois, o projeto precisa manter os dois fluxos
  (leitura de entitlement já existe nos dois; o link de checkout é
  aditivo, não substitui).
- **Passa a ser proibido:** qualquer menção a preço, assinatura ou link de
  pagamento dentro do app na fase da Opção 4 — é exatamente essa ausência
  que evita acionar as políticas de loja; um único texto "assine no nosso
  site" dentro do app pode já ser lido como "menção", dependendo da
  política de cada loja — não testei esse limite, trate como proibido até
  confirmar.

## Não verificado

- Se a política de link externo do Google Play já vale para o Brasil
  hoje ou só a partir de uma data futura — relevante só para a evolução
  condicional (Opção 1), não para a Opção 4.
- Se a Apple já permite link externo para contas no storefront
  brasileiro — mesma ressalva.
- Percentuais exatos de taxa (Google 5%/10%; Apple não confirmado) —
  relevantes só se/quando migrar para Opção 1.
- Onde exatamente fica a linha entre "app não menciona pagamento" (Opção
  4, seguro) e "app menciona sem linkar" (zona cinzenta, não avaliada) —
  registrado acima como proibido por precaução, não porque testei o
  limite.
- Preço por região (`price_book`, `docs/MONETIZACAO.md:55`) — decisão
  separada, não tocada aqui.

## Ressalva de método

Toda a pesquisa desta ADR foi via `WebSearch`, não leitura direta dos
textos oficiais do Google/Apple linha a linha. Antes de aceitar esta ADR
e implementar a evolução condicional (Opção 1), reconfirme lendo
`developer.android.com`/`developer.apple.com` diretamente para a conta
real do Frankstein. A Opção 4 (decisão inicial) depende menos dessa
ressalva — é conservadora o bastante para não precisar da confirmação
regulatória fina que a Opção 1 exigiria.
