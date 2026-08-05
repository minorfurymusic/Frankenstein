# ADR-7 — Canais de distribuição e meios de pagamento

**Status:** proposto
**Data:** 2026-08-05

## Contexto

`docs/MONETIZACAO.md:47-56` já lista os 4 canais candidatos (Google Play,
App Store, F-Droid/APK direto, Web) e pede explicitamente: "Confirme as
regras vigentes da loja antes de implementar e cite a fonte no ADR-7." Fiz
essa pesquisa agora, via `WebSearch` (não é leitura de documentação oficial
primária linha a linha — ressalva de método no fim). O achado muda o peso
relativo dos 4 canais: em 2026, tanto Google quanto Apple abriram (ou estão
abrindo) checkout externo por decisão judicial, algo que não estava
garantido quando `docs/MONETIZACAO.md` chamou a Web de "preferível".

**Google Play:** a partir de 30/06/2026, EUA/Reino Unido/EEE ganham
pagamento externo com escolha lado a lado (Play Billing x link externo) e
taxa de 5% (Play Billing) ou isenta de taxa de billing no link externo,
mais uma taxa de serviço de 10% sobre o primeiro US$1 milhão/ano
independente do método. **Brasil está na lista de países com opção de
sistema de faturamento alternativo** (programa mais antigo, escolha
in-app entre processadores), mas a onda mais nova de **link externo**
(a mesma do EUA/UK/EEE) só chega a mercados globais, Brasil incluso, até
30/09/2027 segundo uma das fontes — não é o mesmo prazo do EUA.
[Google Play external billing](https://developer.android.com/google/play/billing/externalpaymentlinks),
[9to5google](https://9to5google.com/2026/06/24/google-play-store-external-billing-june-30/),
[PagBrasil sobre alternative billing no Brasil](https://www.pagbrasil.com/blog/markets/gaming/google-play-alternative-billing-in-brazil-a-guide-to-d2c-monetization-on-android/).

**Apple App Store:** nos EUA, desde a decisão de maio/2025 no caso Epic
(apelação da Apple negada), apps no storefront americano podem incluir
botões e links externos para pagamento fora do app, via
`StoreKit External Purchase` entitlement. Na UE existe uma entitlement
separada (`External Purchase Link (EU)`) com termos próprios. **Não
encontrei confirmação de que isso se aplica ao Brasil** — as fontes falam
especificamente de EUA e UE.
[Apple Developer — External Purchase](https://developer.apple.com/documentation/storekit/external-purchase),
[Apple Developer — comunicação de ofertas na UE](https://developer.apple.com/support/communication-and-promotion-of-offers-on-the-app-store-in-the-eu/).

## Opções consideradas

1. **Web como canal primário de pagamento** (Pix, cartão, boleto, checkout
   fora do app), com Google Play e App Store como canais de distribuição
   que **apontam** para o checkout web quando a política da loja/região
   permitir — mais margem, sem depender de comissão de loja.
2. **Billing nativo de cada loja como primário** (Play Billing, StoreKit),
   Web como alternativa secundária — mais simples de implementar (sem
   entitlement extra, sem tela de escolha), mas com comissão de loja
   sempre, inclusive nos casos em que a política já permite evitar.
3. **F-Droid/APK direto como canal principal** — sem comissão nenhuma,
   mas alcance de usuário muito menor que as lojas oficiais; coerente com
   o resto do projeto ser copyleft/F-Droid-friendly (`docs/LICENSE-AUDIT.md`),
   mas não decide a questão de meio de pagamento por si só.

## Decisão

**Opção 1, com uma condição regional explícita.** Web como canal
preferencial de pagamento (Pix, cartão, boleto — `docs/MONETIZACAO.md:52`
já pede isso), mantendo Google Play e App Store como canais de
**distribuição** sempre. O uso de link de pagamento externo dentro do
fluxo da loja (evitando a comissão) só entra quando a política da loja
**já estiver confirmada para o Brasil** — não antes, e não por suposição
de que a regra dos EUA/UE se estende automaticamente. F-Droid/APK direto
continua disponível, sem comissão, como já estava.

**Isto está proposto, não aceito.** É portão de custo/monetização — e a
parte mais importante da decisão (quando o link externo é legal e sem
retaliação de política no Brasil, especificamente no Google Play) ainda
não está confirmada com a mesma força que a dos EUA/UE.

## Consequências

- **Fica mais fácil:** se/quando a onda de link externo chegar ao Brasil
  (Google já lista o país no programa mais antigo de billing alternativo;
  a extensão específica de link externo tem data-alvo de até 09/2027 por
  uma fonte), o Frankstein já está desenhado para Web como canal
  preferencial — não precisa reestruturar o fluxo de pagamento depois.
- **Fica mais difícil:** o Brasil não tem, hoje (confirmado só até
  onde a busca alcançou), a mesma clareza jurídica que EUA/UE sobre link
  externo em app — decisão de implementação real (ADR-7 aceito) só deveria
  travar depois de alguém confirmar a regra vigente lendo a documentação
  oficial do Google Play Console/Apple Developer para a conta e a região
  específicas do Frankstein, não por uma busca de agente.
- **Passa a ser proibido:** implementar link de pagamento externo dentro
  do fluxo da loja sem antes confirmar, na conta de desenvolvedor real, que
  a política vigente permite para o Brasil — risco de suspensão de conta
  se a suposição estiver errada.

## Não verificado

- Se a política de link externo do Google Play já vale para o Brasil
  hoje (2026-08-05) ou só a partir de uma data futura — as fontes
  divergem em nível de detalhe (uma cita Brasil na lista de billing
  alternativo já disponível, outra cita 09/2027 como prazo de rollout
  global do link externo especificamente).
- Se a Apple já permite link externo para contas no storefront brasileiro
  — não encontrei fonte que confirme isso, só EUA e UE.
- Percentuais exatos de taxa (Google: 5%/10%; Apple: não confirmado) —
  mudam com frequência e por programa; não trave a implementação nesses
  números sem reconferir na fonte oficial no momento de implementar.
- Preço por região (`price_book`, `docs/MONETIZACAO.md:55`) não foi
  tocado por esta ADR — é decisão separada.

## Ressalva de método

Toda a pesquisa desta ADR foi via `WebSearch` (resumos de busca, não
leitura direta e completa dos textos oficiais do Google/Apple linha a
linha) — mesma limitação de método já registrada em `docs/LICENSE-AUDIT.md`.
Antes de aceitar esta ADR e implementar, reconfirme lendo
`developer.android.com`/`developer.apple.com` diretamente para a conta
real do Frankstein.
