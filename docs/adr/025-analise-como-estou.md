# ADR-25 — "Como estou?": a IA recebe só resumos; humor só com consentimento próprio

**Status:** aceito (decisão explícita do usuário, 2026-10-18)
**Data:** 2026-10-18

## Contexto

O usuário quer que a IA entenda o que acontece com a pessoa e dê
sugestões ("o peso subiu enquanto as calorias ficaram acima da meta").
Hoje a IA só vê a mensagem (ADR-11, `.claude/rules/brain.md`: só
agregados e derivados mínimos).

## Decisão

Opção recomendada e escolhida (2026-10-18): quando a pessoa pede ("Como
estou?"), o app calcula no celular **resumos** da semana e do mês
(médias, tendências, dias cumpridos) e só eles vão à IA — nunca o
histórico, exames ou documentos. Dados de saúde mental (humor, sintomas
mentais, questionários) só entram se a pessoa ligar um consentimento
separado, desligado por padrão. A resposta vem com sugestões em cartões;
a IA não diagnostica nem prescreve.

## Consequências

- Precisa guardar açúcar dos alimentos para falar de açúcar (hoje não
  guarda) — trabalho de dados à parte.
- Uma chamada à IA por análise, na chave do usuário.
