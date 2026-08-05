# ADR-5 — Licenciamento e modelo de distribuição

**Status:** proposto
**Data:** 2026-08-05 (revisão 2, mesmo dia — três correções pedidas em revisão)

## Nota de revisão (o que mudou e por quê)

A versão anterior desta ADR cometeu três erros, todos apontados em
revisão:

1. Descartou a opção de reimplementar (PORT) o OpenNutriTracker citando a
   regra 3 do `CLAUDE.md` ("não reabrir decisão sem motivo novo") —
   **errado**. `docs/VIABILITY.md` (Ciclo 8) decidiu **qual repositório**
   usar para nutrição (OpenNutriTracker em vez de FoodYou). Nunca decidiu
   **como absorver** esse repositório (link de código vs. reimplementação).
   São perguntas diferentes. Reabrir a segunda não reabre a primeira.
2. Tratou "aberto" e "copyleft" como sinônimos. Não são: Apache-2.0 é
   código aberto e não é copyleft. GPL-3.0 é código aberto e é copyleft.
   A decisão "copyleft aceito" em `STATUS.md` significa que o projeto
   **aceita** copyleft quando um repositório absorvido o exige por
   licença — não que o projeto **busca** copyleft por si só. Esta versão
   distingue os dois em vez de misturar.
3. A versão anterior registrava o conflito histórico GPL-3.0 × Termos da
   App Store como "herdado, não resolvido por esta ADR" — e a ADR-7,
   escrita ao mesmo tempo, mantinha a App Store como canal, sem que
   ninguém batesse as duas pontas. Duas ADRs do mesmo dia se contradizendo
   sem aviso é exatamente o tipo de coisa que este projeto existe para
   evitar. Esta versão resolve, não herda.

## Contexto

`docs/adr/000-pendentes.md` marca esta ADR como bloqueando "tudo" — a
licença final do produto é consequência de onde cada um dos 7
repositórios entra:

- **ADR-1 (aceita):** Flutter shell. MLC LLM e OpenTracks entram por WRAP
  no Android (bindings/código nativo chamado por platform channel) — os
  dois são Apache-2.0, então WRAP não traz copyleft nenhum, linkar ou não
  linkar dá na mesma para fins de licença.
- **ADR-4 (proposta):** wger (AGPL-3.0) e Fasten (GPL-3.0) opcionais,
  **federados** — nunca linkados ao cliente.
- **ADR-4a (proposta):** Gadgetbridge (AGPL-3.0) via Health Connect — nem
  federado, nem linkado, zero contato de código.
- **OpenNutriTracker (GPL-3.0):** o único dos 7 cuja licença é copyleft
  **e** que `docs/VIABILITY.md` recomenda usar dentro do núcleo grátis do
  MVP (não federado, porque roda no aparelho, offline). É o único ponto
  onde a pergunta "linkar ou reimplementar" muda a licença do cliente
  inteiro — por isso é o centro desta ADR.

## Opções consideradas

1. **Cliente GPL-3.0, via VENDOR/link do código do OpenNutriTracker.**
   Usa o código Dart do OpenNutriTracker como dependência dentro do app
   Flutter (é o mesmo processo/binário — não há fronteira de processo
   como há entre apps Android nativos via platform channel). Isso é
   linkagem de verdade: o app inteiro, compilado num único binário Dart
   AOT, vira GPL-3.0 por força da própria licença.
2. **Cliente GPL-3.0, servidor autoral proprietário** (só o legalmente
   obrigatório fica aberto). Continua rejeitada: contradiz "Código
   aberto, copyleft aceito" (`STATUS.md`) sem motivo novo para reabrir —
   aqui sim a regra 3 do `CLAUDE.md` se aplica de verdade, porque é a
   mesma pergunta (abrir ou não o servidor) já respondida antes.
3. **Cliente Apache-2.0, via PORT (reimplementação) do OpenNutriTracker.**
   Reaberta nesta revisão. O Frankstein escreve seu próprio módulo de
   diário alimentar/macros/código de barras, informado pelo que o
   OpenNutriTracker faz (é a referência de produto — `docs/VIABILITY.md`
   continua valendo nisso), mas sem copiar o código dele. Nenhuma licença
   copyleft entra no cliente por essa via: MLC LLM e OpenTracks já são
   Apache-2.0: o cliente inteiro pode ser Apache-2.0.

## A pergunta que a revisão pediu, respondida direto

**O OpenNutriTracker entra por cópia de código ou por PORT?**

**PORT.** Não é cópia. Recomendo a opção 3.

Motivo, em ordem de peso:

1. **Resolve a contradição GPL × App Store sem tirar o iOS do plano**
   (ver seção seguinte) — sozinho, isso já decidiria a favor.
2. `docs/adr/009-gps.md` (aceita) já escolheu PORT para o equivalente
   iOS do OpenTracks — reimplementar informado por um repositório de
   referência, sem copiar, já é padrão aceito neste projeto, não é
   novidade sendo inventada agora só para fugir da GPL.
3. Apache-2.0 no cliente **continua sendo código aberto** — não é uma
   escolha "menos aberta", é uma escolha não-copyleft. `docs/adr/006-sem-anuncios.md`
   e o resto do projeto continuam de pé sem depender de o cliente ser
   copyleft especificamente.
4. Custo: reimplementar diário alimentar/macros/código de barras é
   trabalho real, não é grátis — o OpenNutriTracker foi escolhido
   originalmente (`docs/PRODUTO.md`) exatamente para evitar esse esforço.
   Isto **não é decidido de graça**: é a troca de um custo de engenharia
   (reescrever) por uma redução de risco jurídico e de plataforma (App
   Store). Registro o custo, não finjo que é zero.

**Ressalva de interpretação jurídica, não fato:** "PORT" no sentido de
`docs/PRODUTO.md` (reimplementar a lógica) não é automaticamente livre de
risco de "obra derivada" em todas as leituras possíveis de direito
autoral — ideias e funcionalidade não são protegidas por copyright, só a
expressão (o código em si) é; ter lido o código GPL do OpenNutriTracker
para entender como ele resolve um problema, e depois escrever código
próprio diferente que resolve o mesmo problema, é a prática comum e
geralmente aceita, mas "geralmente aceita" não é "juridicamente
garantida em todo caso". Isso é opinião jurídica, que não tenho
autoridade para dar. Se quiser blindar ainda mais, a prática de
"clean room" (quem escreve o PORT nunca abre o código-fonte do
OpenNutriTracker, só a especificação de comportamento) reduz esse risco
residual — não decido isso aqui, é detalhe de processo de implementação.

## Resolução da contradição GPL × App Store

A versão anterior desta ADR aceitava GPL-3.0 no cliente (herdando o
risco histórico de conflito com os Termos da App Store,
`docs/LICENSE-AUDIT.md`, caso FSF x Apple/GNU Go 2010) **e** a ADR-7
mantinha a App Store como canal — duas ADRs do mesmo dia se
contradizendo. Com a opção 3 (PORT, cliente Apache-2.0):

- **Não há mais GPL no cliente.** MLC LLM (Apache-2.0) + OpenTracks
  (Apache-2.0, WRAP) + OpenNutriTracker-como-PORT (código próprio,
  licença própria) = cliente inteiro Apache-2.0.
- **O conflito não existe mais para o cliente.** Apache-2.0 nunca teve o
  problema que gerou o caso FSF x Apple — a cláusula de "sem restrições
  adicionais" que a GPL tem (e que colide com os Termos de Uso da App
  Store) não existe na Apache-2.0.
- **O iOS continua no plano, a App Store continua no plano** — a
  contradição não precisou ser resolvida abrindo mão de uma das duas,
  porque a premissa (cliente tem que ser GPL) deixou de ser verdadeira.
- O **servidor** autoral (entitlements, B2B, relay de sync — ADR-3/ADR-8)
  não é distribuído em loja nenhuma, então nada disso o afeta: ele pode
  continuar AGPL-3.0 por escolha, como já estava, sem reabrir a discussão
  de App Store.

## Decisão

**Opção 3.** Modelo de licenciamento revisado:

- **Cliente (app):** **Apache-2.0**. OpenNutriTracker entra por PORT
  (reimplementação informada, não cópia de código) — decisão desta ADR,
  não mais "a decidir depois". MLC LLM e OpenTracks continuam por WRAP
  (ADR-1), sem alteração — já eram Apache-2.0, WRAP nunca foi o problema.
  FoodYou continua fora (`docs/VIABILITY.md`), redundante com
  OpenNutriTracker independente de licença.
- **Componentes de servidor autorais do Frankstein** (entitlements, B2B,
  relay de sync — ADR-3/ADR-8): **AGPL-3.0 por escolha**, sem alteração
  em relação à versão anterior — continua sendo escolha de princípio, não
  obrigação legal estrita, e continua sem afetar o cliente porque servidor
  e cliente são licenciados separadamente.
- **wger, se hospedado para B2B:** expõe o próprio código-fonte via rota
  `/source` (`docs/B2B.md:31-33`), sem alteração.
- **Modelo de distribuição:** multi-canal conforme ADR-7 — agora sem a
  tensão GPL×App Store que a versão anterior carregava.

**Isto está proposto, não aceito.** Continua sendo a ADR mais consequente
do projeto. A diferença desta revisão: a decisão não depende mais de
resolver uma contradição entre duas ADRs — resolvi a contradição aqui.

## Consequências

- **Fica mais fácil:** não há mais tensão entre a licença do cliente e o
  canal de distribuição — App Store, Play Store, F-Droid, APK direto
  funcionam todos sem risco de conflito de licença específico do cliente.
  O modelo de licença vira uma regra simples: cliente permissivo, servidor
  copyleft por escolha.
- **Fica mais difícil:**
  - Custo de engenharia real de reimplementar o módulo de nutrição em vez
    de linkar o OpenNutriTracker pronto — não quantifiquei esse custo
    (não é dado que eu tenha; estimativa de esforço não é meu papel aqui).
  - **AGPL no servidor permite que clientes B2B se auto-hospedem e
    deixem de pagar.** Como o servidor autoral é AGPL-3.0 por escolha, e
    AGPL obriga a oferecer o código-fonte a quem interage com ele pela
    rede, qualquer clínica/academia cliente do B2B (`docs/B2B.md`) pode
    pegar esse código-fonte publicado e rodar a própria instância, sem
    pagar pela hospedagem do Frankstein — o mesmo modelo que
    `docs/B2B.md:31-33` já assumia para o wger hospedado se aplica agora
    ao próprio produto B2B do Frankstein. `docs/MONETIZACAO.md` conta com
    receita de hospedagem B2B ("20 nutricionistas a R$ 80/mês valem
    mais..."); isso é uma tensão real entre a escolha de licença por
    princípio e o modelo de receita, não resolvida aqui — fica registrada
    para quem for aceitar esta ADR pesar.
- **Passa a ser proibido:** copiar/portar código do OpenNutriTracker
  literalmente sob pretexto de "PORT" — se for reimplementação, tem que
  ser reimplementação de verdade, não cópia com nomes trocados (isso
  seria pior que linkar abertamente: violaria a GPL escondendo a origem).

## Não verificado

- ~~Licenças dos 6 submódulos do MLC LLM~~ — resolvido no Ciclo B, todas
  permissivas, não muda esta ADR.
- Direção real do Gadgetbridge no Health Connect, confirmada só por busca
  indexada (ADR-4a).
- Regras de link de pagamento externo confirmadas para o Brasil
  especificamente — ver ADR-7 revisão 2, que reduz a dependência disso
  com a Opção 4.
- Texto primário da FSF sobre compatibilidade de licença — só resumo de
  `WebSearch` em todo o projeto até aqui.
- **Novo:** custo de engenharia de reimplementar (PORT) o módulo de
  nutrição — não estimado nesta ADR.
- **Novo:** se "clean room" é necessário ou só recomendável para o PORT
  do OpenNutriTracker — é interpretação jurídica, sinalizada, não
  resolvida.
