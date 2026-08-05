# ADR-6 — Sem anúncios em nenhuma superfície

**Status:** aceito
**Data:** 2026-08-05

## Contexto

A decisão já estava tomada antes desta ADR existir como documento — está
registrada em `CLAUDE.md` ("Sem anúncios. Sem telemetria. Sem rastreador."),
em `STATUS.md` ("Decisões já tomadas": "**Sem anúncios em nenhuma
superfície.** Sistema de anúncios foi cancelado."), em
`docs/MONETIZACAO.md:3-4` ("O sistema de anúncios foi cancelado: SDKs de
anúncio são binários proprietários e linká-los a módulos GPL/AGPL viola a
licença") e em `.claude/rules/monetizacao.md:12` ("PROIBIDO qualquer código
de anúncio"). `docs/adr/000-pendentes.md` já listava ADR-6 como "(decidido —
registrar formalmente)". Esta ADR não decide nada novo — só formaliza o que
já rege o projeto, porque `docs/LICENSE-AUDIT.md` (Ciclo 7) e as 7 fichas de
reconhecimento (Ciclos 1-7) confirmaram o motivo de licença que sustenta a
decisão: 4 dos 7 repositórios absorvidos são copyleft (GPL-3.0 ou
AGPL-3.0 — ver `docs/LICENSE-AUDIT.md`), e SDKs de anúncio são binários
proprietários sem código-fonte disponível, incompatíveis com qualquer
licença copyleft por definição.

## Opções consideradas

1. **Nenhum anúncio, em nenhuma superfície** (grátis, premium ou B2B) —
   a que já está em vigor em todos os documentos citados acima.
2. Anúncios só no degrau grátis, como nos apps de saúde mais comuns no
   mercado — **rejeitada antes desta ADR**, é a opção que `docs/MONETIZACAO.md`
   descreve como "cancelada".
3. Anúncios não-intrusivos de parceiros de saúde (planos, farmácias) —
   não foi cogitada em nenhum documento lido; não invento essa opção como
   tendo sido avaliada.

## Decisão

Nenhuma superfície do Frankstein — grátis, Premium ou painel B2B — carrega
anúncio de qualquer tipo, forma ou parceiro, e nenhum SDK de anúncio
(AdMob, Meta Audience Network, AppLovin, Unity Ads, ou qualquer binário
proprietário equivalente) entra como dependência, em nenhuma fase.

## Consequências

- **Fica mais fácil:** a compatibilidade de licença com os módulos
  copyleft absorvidos (GPL-3.0/AGPL-3.0, confirmado em
  `docs/LICENSE-AUDIT.md`) deixa de ser uma questão — não há binário
  proprietário para colidir com o copyleft.
- **Fica mais difícil:** o modelo de monetização depende inteiramente de
  assinatura (Premium) e B2B (`docs/MONETIZACAO.md`), sem a receita
  auxiliar que anúncio costuma dar no degrau grátis — o produto precisa que
  o Premium e o B2B sozinhos sustentem o projeto.
- **Passa a ser proibido:** qualquer dependência de SDK de anúncio, em
  qualquer branch ou experimento, mesmo temporário. Já é regra inviolável
  em `CLAUDE.md` e em `.claude/rules/00-inviolaveis.md`; esta ADR não muda
  o que já era proibido, só documenta formalmente a decisão para não
  precisar ser reaberta.
