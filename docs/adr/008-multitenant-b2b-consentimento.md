# ADR-8 — Multi-tenant B2B e modelo de consentimento

**Status:** proposto
**Data:** 2026-08-05

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

## Decisão

**Opção 1**, com a lacuna da opção 3 registrada como pendência, não
decidida aqui — decisão de isolamento de banco é implementação, não
modelo de consentimento, e exige dado de custo/escala que não tenho
(não li `docs/CUSTOS.md` neste ciclo, fora da área tocada por esta ADR).

O modelo de consentimento fica exatamente como `docs/B2B.md` já
especifica: `CareLink` é o objeto de consentimento — escopo granular por
tipo de dado, status revogável, expiração, log de auditoria obrigatório.
Isso já é compatível com o que ADR-3 (proposta) definiu para o Health Data
Core: `CareLink` não duplica dado, só concede escopo de leitura/escrita
sobre o mesmo `HealthEvent` log que já existe no aparelho do paciente —
quando sincronizado (Premium/B2B), não antes.

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

## Não verificado

- Isolamento de dados entre `Organization`s: banco separado vs. escopo
  compartilhado por `organization_id` — lacuna técnica real, não decidida
  aqui, precisa de dado de custo/escala (`docs/CUSTOS.md`, não lido neste
  ciclo) e possivelmente de uma ADR própria se for decisão grande o
  suficiente.
- Requisito específico da LGPD para log de acesso a dado de saúde por
  terceiro (profissional) — `docs/B2B.md` já assume que precisa existir,
  mas não verifiquei o texto da lei linha a linha para confirmar o nível
  de detalhe exigido (retenção do log, o que precisa conter). Não é
  parecer jurídico, é mapa — mesma ressalva de `docs/LICENSE-AUDIT.md`.
