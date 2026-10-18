---
paths:
  - "packages/brain/**"
  - "**/*brain*.dart"
  - "**/*llm*.dart"
---
# Regras do cérebro (IA em nuvem com a chave do usuário — ADR-11)

Pipeline obrigatório, nesta ordem:
1. Roteador determinístico (regex/palavras-chave). Comando frequente NÃO chama a IA.
2. IA com tool-calling, só para o que o roteador não resolveu — e só se o usuário
   configurou a própria chave. Sem chave: modo básico, nunca erro.
3. Validação por JSON Schema. Saída inválida = rejeita e repete (máx. 2 tentativas),
   depois cai em "não entendi, você quis dizer X?".
4. Confirmação humana obrigatória para toda ferramenta de escrita. A IA propõe
   cartões; nada é gravado antes do usuário confirmar cada um.

Rede e privacidade:
- Chamada à IA só quando o usuário envia uma mensagem ou anexo. Nunca em segundo plano.
- Consentimento explícito antes do primeiro envio, dizendo qual provedor recebe os dados.
- O app nunca anexa sozinho dado clínico guardado (prontuário, exame, receita) ao
  prompt — só agregados e derivados mínimos pra contexto. Documento que o próprio
  usuário anexou naquela mensagem pode ir: é ação explícita dele.
- Chave em armazenamento seguro do Android. Nunca em log, backup ou exportação.
- REST direto no provedor. Sem SDK de provedor (.claude/rules/licenca.md).

Saúde:
- A IA registra, não prescreve: nunca sugere dose, troca ou suspensão de remédio.
- Exceção (ADR-26): pode propor troca equivalente dentro do plano alimentar ou de treino
  já existente, sem mudar metas, sempre como cartão confirmado. Dieta nova, não.
- Saúde mental (ADR-23/25): nunca rotula transtorno; humor só vai à IA com o
  consentimento próprio. Crise: texto fixo do app com CVV 188 e SAMU 192.
- Toda resposta de saúde carrega o aviso: o app não diagnostica nem prescreve.
- Sintoma preocupante = orientar a procurar profissional.
- Estimativa (ex.: calorias por foto) é sempre marcada como estimativa e editável.
