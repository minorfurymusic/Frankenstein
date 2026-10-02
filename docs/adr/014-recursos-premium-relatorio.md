# ADR-14 — Relatório para consulta é Premium; lista de recursos da tela Assinatura

**Status:** aceito (decisão explícita do usuário, 2026-10-02)
**Data:** 2026-10-02
Altera `docs/MONETIZACAO.md` (degrau grátis = "tudo que roda no aparelho").

## Contexto

A revisão do layout (`docs/design/REVISAO-LAYOUT.md`, seção 3) achou dois
recursos Premium na tela `ContaAssinatura` que não estavam em
`docs/MONETIZACAO.md`:

1. "Relatórios para levar à consulta" — gerado no aparelho, então pela regra
   de `docs/MONETIZACAO.md:13` seria grátis.
2. "Mais espaço para fotos e exames" — o armazenamento local não tem limite.

## Opções consideradas

1. Relatório grátis (regra antiga: tudo local é grátis).
2. Relatório Premium, mesmo sendo gerado no aparelho.

## Decisão

- **Relatório para levar à consulta é só do Premium** (opção 2).
- **"Mais espaço para fotos e exames" sai da tela** — não existe limite de
  espaço no aparelho.

## Consequências

- O degrau grátis deixa de ser "tudo que roda no aparelho": o relatório é a
  exceção. `docs/MONETIZACAO.md` atualizado.
- **Relatório não é exportação.** Exportar os próprios dados (LGPD art. 18)
  continua grátis e sem limite (`docs/MONETIZACAO.md`, "NUNCA pagar"). O
  relatório é o documento formatado para o profissional; os dados crus sempre
  saem de graça pela exportação.
- Como nenhum degrau pago é decidido no cliente (`.claude/rules/00-inviolaveis.md`),
  o relatório só fica liberado com entitlement assinado pelo servidor. Até o
  servidor existir, a tela aparece com o selo "Premium" e o recurso não abre
  no APK de produção.
- Tela Assinatura passa a listar: conectar prontuário de hospital, relatório
  para levar à consulta, backup criptografado e sincronização entre aparelhos,
  acesso pelo navegador, histórico na nuvem, conta familiar, suporte
  prioritário. Sem preço, sem link de compra (ADR-7).
