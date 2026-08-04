---
paths:
  - "packages/brain/**"
  - "**/mlc_*.dart"
  - "**/*brain*.dart"
---
# Regras do cérebro (MLC LLM)

Pipeline obrigatório, nesta ordem:
1. Roteador determinístico (regex/palavras-chave). Comando frequente NÃO chama o modelo.
2. LLM com tool-calling, só para o que o roteador não resolveu.
3. Validação por JSON Schema. Saída inválida = rejeita e repete (máx. 2 tentativas),
   depois cai em "não entendi, você quis dizer X?".
4. Confirmação humana obrigatória para toda ferramenta de escrita.

Segurança:
- Prontuário/exame bruto NUNCA entra no prompt. Só agregados e derivados.
- Toda resposta de saúde carrega o aviso: o app não diagnostica nem prescreve.
- Sintoma preocupante = orientar a procurar profissional.

Recursos do aparelho:
- Perfil A (>=8 GB RAM): modelo 3B q4f16_1. Perfil B (6 GB): 1,5B. Perfil C (<=4 GB):
  NENHUM modelo — só roteador + templates, e precisa funcionar bem.
- O modelo nunca vai dentro do APK/AAB. Download sob demanda, Wi-Fi por padrão,
  retomável, com verificação de hash e botão de desinstalar.
- Descarregue o modelo da RAM ao ir para segundo plano ou ao iniciar GPS.
- Teto térmico: se esquentar, degrade para o roteador e avise.
