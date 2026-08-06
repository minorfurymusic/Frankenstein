# ADR-8 — Multi-tenant B2B e modelo de consentimento

**Status:** proposto
**Data:** 2026-08-05
**Revisão:** 1 (2026-08-06) — lacuna de isolamento de banco (Opção 3)
resolvida depois de ler `docs/CUSTOS.md` por completo, como pedido antes de
tocar nesta ADR de novo.

## Contexto

`docs/B2B.md` já especifica um modelo de dados completo — não é decisão em
aberto, é uma especificação já escrita que esta ADR formaliza e testa
contra o resto do projeto:

```
Organization (clínica/academia)
 +- Seat (profissional)  -- RBAC: owner | professional | assistant | viewer
     +- CareLink (profissional <-> paciente)
         scopes: [nutrition.read, workout.write, clinical.read, vitals.read]
         status: invited | active | paused | revoked
         expires_at
         audit_log
```

E 8 princípios inegociáveis (`docs/B2B.md:22-33`), entre eles: o dado é do
paciente, não da clínica; consentimento granular e revogável a um toque;
revogação imediata; toda leitura de dado clínico gera log visível ao
paciente; painel profissional web, multi-tenant, separado do app do
paciente; AGPL no servidor implica rota `/source` — já citado e usado em
`docs/LICENSE-AUDIT.md` (Cenário A, pergunta 4).

## Opções consideradas

1. **Adotar o modelo Organization/Seat/CareLink como está**, com
   isolamento multi-tenant por `Organization` — decisão de estrutura de
   dados já madura em `docs/B2B.md`, só falta formalizar como ADR.
2. **Acesso binário (tudo ou nada) por vínculo profissional-paciente**,
   sem escopos granulares — rejeitada: contradiz diretamente o princípio
   já escrito "consentimento granular e revogável a um toque, com tela de
   'quem vê o quê'" (`docs/B2B.md:24`). Não é opção real, é o que já foi
   descartado.
3. **Isolamento por banco de dados separado por Organization** vs.
   **banco compartilhado com escopo por `organization_id` em cada linha**
   — `docs/B2B.md` não decide isso, é uma lacuna técnica real que esta ADR
   expõe.
   - 3a. Banco/instância dedicada por `Organization`.
   - 3b. Banco compartilhado, isolamento só por coluna `organization_id`
     e filtro de aplicação em cada query.
   - 3c. Banco compartilhado, isolamento por **schema separado por
     `Organization`** dentro da mesma instância de servidor — meio-termo
     entre 3a e 3b.

## Decisão

**Opção 1**, mais **Opção 3c** para o isolamento de banco — decidida
agora que `docs/CUSTOS.md` foi lido por completo (era a pendência
explícita para reabrir esta ADR).

O modelo de consentimento fica exatamente como `docs/B2B.md` já
especifica: `CareLink` é o objeto de consentimento — escopo granular por
tipo de dado, status revogável, expiração, log de auditoria obrigatório.
Isso já é compatível com o que ADR-3 (proposta) definiu para o Health Data
Core: `CareLink` não duplica dado, só concede escopo de leitura/escrita
sobre o mesmo `HealthEvent` log que já existe no aparelho do paciente —
quando sincronizado (Premium/B2B), não antes.

**Isolamento de banco — 3c, schema separado por `Organization`, mesma
instância de servidor.** Fundamentação a partir de `docs/CUSTOS.md`:

- O custo de servidor não é dominado por quantidade de tenants, é
  dominado por tráfego — a VPS mínima já inclui 20 TB de banda por
  ~EUR 5,50–6,00/mês (`docs/CUSTOS.md:24`). Rodar N schemas Postgres na
  mesma instância, em vez de uma tabela só com coluna `organization_id`,
  não muda essa conta: o custo em dinheiro de 3c é igual ao de 3b até a
  VPS mínima ficar pequena de verdade (não é o caso previsto nos
  cenários de `docs/CUSTOS.md:29-38`, nem no de 1.000 usuários gratuitos
  nem no de crescimento de assinantes pagos).
- 3a (instância dedicada por `Organization`) é o padrão de custo que
  `docs/CUSTOS.md:14-16` já lista como "escala com usuário, nunca
  grátis" — mesma categoria de "instância hospedada de Fasten/wger".
  Faria sentido para clínicas muito grandes pedindo isolamento físico
  contratual, mas não é o ponto de partida: multiplicaria o custo fixo
  por cliente B2B sem necessidade, e `docs/B2B.md:27` já especifica o
  painel como "web, multi-tenant" — uma instância por cliente contradiz
  isso.
- 3b (só coluna `organization_id` + filtro na aplicação) é a opção mais
  barata e mais simples de implementar, mas o próprio texto desta ADR
  (linha 60 da versão original) já chama a combinação B2B de "a mais
  sensível do projeto" — dado clínico de paciente, terceiro (profissional)
  lendo, LGPD. Um filtro de `WHERE organization_id = ?` esquecido em uma
  query é o tipo de bug que vaza dado de uma clínica para outra sem
  nenhum sinal visível até virar incidente. `docs/CUSTOS.md` não tem
  informação de custo que justifique correr esse risco: schema separado
  não custa mais caro em dinheiro (primeiro ponto acima), então não há
  trade-off financeiro real a proteger escolhendo 3b sobre 3c.
- 3c dá isolamento estrutural (um schema não enxerga outro sem trocar a
  conexão/`search_path` explicitamente — a classe inteira de bug do
  parágrafo acima fica muito mais difícil de escrever por acidente),
  mantendo o custo de 3b e a arquitetura "web, multi-tenant, uma
  instância" de `docs/B2B.md:27`.

Isolamento físico por cliente (3a) fica registrado como upgrade possível
depois, se um cliente B2B grande exigir isolamento contratual/físico —
não é o padrão.

**Isto está proposto, não aceito.** Portão duplo: dado de saúde (LGPD) e
arquitetura — a combinação mais sensível do projeto.

## Consequências

- **Fica mais fácil:** o modelo já resolve a exigência de LGPD de
  consentimento granular e revogável sem desenho adicional — só
  implementar o que já está especificado.
- **Fica mais difícil:** cada leitura de dado clínico por um profissional
  precisa gerar log visível ao paciente em tempo real (`docs/B2B.md:26`)
  — isso é requisito de auditoria fim-a-fim, não um campo de log
  qualquer; exige que o app do paciente mostre esse log de forma legível,
  o que é trabalho de UX ainda não desenhado.
- **Passa a ser proibido:** qualquer leitura de `CareLink` sem escopo
  explícito concedido, qualquer painel B2B compartilhando UI/código com o
  app do paciente (já exigido como "separado" em `docs/B2B.md:27` —
  reforça a separação de shell que ADR-1 propõe para o app principal), e
  qualquer anúncio em superfície B2B (já decidido, ADR-6 aceito).
- **Fica mais difícil (nova, da revisão 1):** toda migration de schema
  do servidor precisa rodar por `Organization` (N schemas em vez de 1),
  e a conexão de cada request do painel B2B precisa resolver o
  `Organization` primeiro e fixar o `search_path`/schema certo antes de
  qualquer query — camada de roteamento que não existiria com 3b. É o
  preço deliberado por trocar "fácil de implementar" por "difícil de
  vazar dado entre clínicas por acidente".
- **Passa a ser proibido (nova, da revisão 1):** qualquer query do painel
  B2B que resolva o schema/`organization_id` a partir de dado vindo do
  cliente sem revalidar contra a sessão autenticada no servidor — normal
  para qualquer isolamento multi-tenant, mas vale registrar porque é
  exatamente a classe de bug que 3c existe para tornar mais difícil, não
  impossível.

## Não verificado

- Em que ponto de crescimento 3c (schema compartilhado) para de ser
  suficiente e algum cliente B2B precisa de 3a (instância dedicada) —
  não há gatilho numérico definido, só o registro de que é upgrade
  possível depois.
- Requisito específico da LGPD para log de acesso a dado de saúde por
  terceiro (profissional) — `docs/B2B.md` já assume que precisa existir,
  mas não verifiquei o texto da lei linha a linha para confirmar o nível
  de detalhe exigido (retenção do log, o que precisa conter). Não é
  parecer jurídico, é mapa — mesma ressalva de `docs/LICENSE-AUDIT.md`.
