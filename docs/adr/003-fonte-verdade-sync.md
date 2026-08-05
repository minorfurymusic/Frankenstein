# ADR-3 — Fonte da verdade dos dados e estratégia de sync

**Status:** proposto
**Data:** 2026-08-05

## Contexto

`docs/ARQUITETURA.md:26-41` já define o Health Data Core: SQLite local,
"fonte da verdade, offline-first", schema `HealthEvent` (id, type, source,
occurred_at UTC, recorded_at, payload json, confidence, device_id),
append-only, deduplicação por `(source, external_id)`, correção sempre
como novo evento. `.claude/rules/datacore.md` reforça: nenhum módulo lê o
banco de outro, todos escrevem no mesmo formato. `docs/MONETIZACAO.md:15-16`
lista "Backup criptografado e sincronização entre aparelhos" e "Histórico
consolidado em nuvem" como itens **pagos** (Premium) — ou seja, sync não é
parte do núcleo grátis, é uma extensão. O que falta decidir, e que nenhum
documento resolve ainda: quando o sync existir, quem manda — o aparelho ou
o servidor — e como um evento criado em dois aparelhos offline ao mesmo
tempo se reconcilia.

## Opções consideradas

1. **SQLite local como única fonte de verdade, sempre — inclusive com sync
   ativado.** O servidor (Premium) é um relay/store do log de eventos entre
   aparelhos do mesmo usuário, nunca uma autoridade que sobrescreve o
   local. Sync = replicar o mesmo modelo append-only/dedup que já existe,
   entre aparelhos, em vez de dentro de um aparelho só.
2. **Servidor como autoridade** (aparelho é cache, servidor decide o
   estado final) — incompatível com o próprio modelo de negócio: o degrau
   GRÁTIS (`docs/MONETIZACAO.md:8-11`) explicitamente "sem conta, sem
   nuvem, sem servidor". Se o servidor fosse a fonte de verdade, o app
   grátis não teria fonte de verdade nenhuma quando offline — contradiz
   "offline-first" de `docs/ARQUITETURA.md:70`.
3. **CRDT ou outro merge automático de conflito** para dois aparelhos que
   editam o mesmo evento offline ao mesmo tempo — não avaliei essa opção a
   fundo, é problema real que o modelo append-only só resolve
   parcialmente (ver "Não verificado").

## Decisão

**Opção 1.** SQLite local de cada aparelho continua sendo a fonte de
verdade, com ou sem sync ativado. Quando o Premium ativa sync
(`docs/MONETIZACAO.md`), o servidor funciona como **relay de replicação do
log de eventos**, não como autoridade:

- Cada aparelho empurra os `HealthEvent` novos (por `source`/`device_id`)
  para o servidor.
- Cada aparelho puxa eventos de outros aparelhos do mesmo usuário e os
  aplica localmente pelo mesmo mecanismo de deduplicação já decidido
  (`(source, external_id)`) — um evento vindo de outro aparelho é só mais
  uma fonte a mesclar, não um caso especial.
- Correção continua sendo sempre um novo evento apontando para o anterior
  (já decidido em `docs/ARQUITETURA.md:41`) — isso também é o que evita
  boa parte do problema de conflito: não há "editar", só "adicionar
  correção", e duas correções concorrentes viram dois eventos, não uma
  colisão que precisa de merge.

**Isto está proposto, não aceito.** É portão de arquitetura e de dado de
saúde ao mesmo tempo — dobro de motivo para não decidir sozinho.

## Consequências

- **Fica mais fácil:** sync vira aditivo — não exige redesenhar o modelo
  de dados já decidido, só estender quem escreve no mesmo log. O app
  grátis nunca fica "quebrado" por causa do design de sync, porque nunca
  depende dele.
- **Fica mais difícil:** o servidor de sync (Premium) precisa de
  autenticação, fila de replicação e critério de "quais eventos este
  aparelho já tem" — trabalho de backend real, não é grátis de
  implementar mesmo sendo "só um relay". `docs/CUSTOS.md` deveria ter a
  estimativa disso; não abri esse documento neste ciclo (fora da área que
  esta ADR toca) — verificar antes de aceitar esta ADR.
- **Passa a ser proibido:** sync automático sem ação explícita do usuário
  (`.claude/rules/00-inviolaveis.md`: "dado de saúde... nunca sai do
  aparelho sem ação explícita do usuário"; `CLAUDE.md` regra 7: "Nada de
  rede sem ação explícita do usuário"). Downgrade de Premium para Grátis
  não pode apagar histórico local (`docs/MONETIZACAO.md:44` já decide
  isso) — o relay perder acesso não pode significar perda de dado no
  aparelho.

## Não verificado

- **Conflito de correções concorrentes:** se dois aparelhos offline
  criam correções para o **mesmo** evento anterior ao mesmo tempo, o
  modelo append-only gera dois eventos-correção apontando pro mesmo pai —
  não há regra ainda de qual "vale" na visão consolidada (mostrar os dois?
  o mais recente por `recorded_at`? um alerta pro usuário?). Não decido
  isso aqui — é design de sync que ainda não foi feito, não uma
  consequência que eu possa prever com o que já está escrito.
- Custo de servidor do relay de sync — não lido `docs/CUSTOS.md` neste
  ciclo, por disciplina de "ler só o documento da área que vai tocar".
