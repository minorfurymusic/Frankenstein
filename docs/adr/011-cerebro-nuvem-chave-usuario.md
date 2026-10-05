# ADR-11 — Cérebro em nuvem com a chave de API do próprio usuário

**Status:** aceito (decisão explícita do usuário, 2026-10-02) — substitui ADR-2;
revisão 1 (2026-10-05): provedor escolhido — Gemini
**Data:** 2026-10-02

## Contexto

ADR-2 escolheu o MLC LLM rodando no aparelho (perfis A/B/C,
`docs/OFFLINE-IA.md`). Desde a ADR-2 (2026-08-05) o motor nunca foi
compilado: os submódulos exigem toolchain LLVM/GPU pesado e parte dos
downloads é bloqueada pela rede do ambiente de desenvolvimento
(`docs/recon/mlc-llm.md`). Ao mesmo tempo, o escopo do cérebro cresceu
(pedido do usuário em 2026-10-02): entender foto de prato com peso,
foto/PDF de receita médica, áudio, vídeo e voz, e quebrar uma frase livre
em vários registros (água + refeição + sintoma + remédio). Isso é
multimodal, e um modelo de 1,5B–3B no aparelho não faz isso de forma útil.

## Opções consideradas

1. **Manter o MLC LLM local** (ADR-2). Mantém tudo no aparelho, mas segue
   sem build, sem medição, e não cobre multimodal.
2. **Cérebro em nuvem hospedado pelo projeto** (o item 5 do Premium em
   `docs/MONETIZACAO.md`). Exige servidor (decidido como uma das últimas
   etapas) e transforma o projeto em controlador de dado de saúde.
3. **Cérebro em nuvem com a chave de API do próprio usuário** (BYOK). O app
   fala direto com o provedor que o usuário escolher, com a chave que ele
   mesmo colou em Configurações. Sem chave, o app funciona inteiro com o
   roteador determinístico e as telas manuais.

## Decisão

**Opção 3.** Detalhes:

- **Sem chave = modo básico, 100% offline.** Roteador determinístico +
  telas manuais. Continua sendo o caminho principal, como
  `docs/OFFLINE-IA.md:13-15` já exigia do perfil C.
- **Com chave = IA ativa, só sob ação explícita.** Rede só quando o usuário
  envia uma mensagem ou anexo na aba Cérebro. Nada em segundo plano, nada
  enviado sozinho.
- **Consentimento antes do primeiro envio.** Tela que diz qual provedor
  recebe os dados e o que é enviado. Revogável (apagar a chave).
- **O pipeline de `.claude/rules/brain.md` continua:** roteador primeiro,
  IA só pro que o roteador não resolveu, saída validada por JSON Schema, e
  **confirmação humana antes de gravar qualquer coisa** — a IA propõe
  cartões ("Água 2 L às 08:00", "Dipirona 500 mg às 09:00"), o usuário
  confirma, edita ou descarta cada um.
- **A IA registra, não prescreve.** Lê o que a receita/usuário diz e
  agenda; nunca sugere dose, troca ou suspensão. Aviso de saúde em toda
  resposta de saúde, mantido.
- **Chave guardada criptografada** no armazenamento seguro do Android;
  nunca em log, nunca em backup/exportação.
- **Sem SDK de provedor:** chamadas REST diretas, pra não puxar SDK
  proprietário (`.claude/rules/licenca.md`).

## Revisão de regra existente (consequência desta ADR)

`.claude/rules/brain.md` dizia "Prontuário/exame bruto NUNCA entra no
prompt". Com esta ADR, a regra passa a ser: **o app nunca anexa sozinho
dado clínico guardado** ao prompt (só agregados e derivados mínimos pra
contexto); um documento que o próprio usuário anexa e envia naquela
mensagem é ação explícita dele e pode ir — depois do consentimento acima.
Atualizado em `.claude/rules/brain.md` junto com esta ADR.

## Consequências

- **Fica mais fácil:** multimodal de verdade sem build nativo nem download
  de modelo; custo de servidor do projeto continua zero (o usuário paga o
  provedor dele); o app fica mais leve.
- **Fica mais difícil:** dado de saúde sai do aparelho quando o usuário usa
  a IA — vai pro provedor que ele escolheu, sob a política de dados desse
  provedor, não nossa. Sem internet ou sem chave, só o modo básico.
  Estimativa de calorias por foto é aproximada por natureza — sempre
  mostrada como estimativa, sempre editável.
- **Passa a ser proibido:** qualquer chamada à IA sem envio explícito do
  usuário; gravar qualquer coisa proposta pela IA sem confirmação;
  enviar a chave pra qualquer lugar que não seja o provedor escolhido.
- **Documentos afetados:** ADR-2 (substituída); `docs/OFFLINE-IA.md`
  (perfis A/B/C e distribuição de pesos ficam históricos); item 4 da
  Definição de Pronto em `docs/PRODUTO.md` ("respondido pelo LLM local,
  offline"); item 5 do Premium em `docs/MONETIZACAO.md` (cérebro hospedado
  vira opção futura, não o caminho).

## Não verificado / em aberto

- **Quais provedores suportar** e o que cada um aceita (imagem, PDF, áudio,
  vídeo) — capacidades mudam rápido; conferir na documentação oficial de
  cada um no ciclo de implementação, não de memória.
- Transcrição de voz: precisa ser feita sem Play Services
  (`.claude/rules/licenca.md`) — provavelmente pelo próprio provedor de IA.
- Texto do consentimento (LGPD) — redação a revisar antes de publicar.

## Revisão 1 (2026-10-05) — provedor: Gemini

**Decisão do usuário (2026-10-05):** "Provedor por enquanto é minha api key
gemini." Primeiro provedor suportado: **Gemini (Google), Gemini Developer
API**, com a chave do próprio usuário.

- **Como é chamado (conferido no código do SDK oficial
  `googleapis/python-genai`, já que a documentação `ai.google.dev` é
  bloqueada na rede de desenvolvimento):** `POST
  https://generativelanguage.googleapis.com/v1beta/models/{modelo}:generateContent`,
  chave no cabeçalho `x-goog-api-key` (nunca na URL), anexos em
  `inlineData` (`mimeType` + base64), instrução em `systemInstruction` e
  resposta em JSON por `generationConfig.responseMimeType` +
  `responseJsonSchema`. Modelo padrão: o apelido `gemini-flash-latest`
  (o mesmo usado nos exemplos do SDK), trocável em Conta › Cérebro (IA).
  Implementação: `packages/ai` (REST com `dart:io`, sem SDK).
- **Chave:** cifrada por chave AES do Android Keystore (`SecureStore.kt`),
  fora do banco; "Apagar chave" e "Apagar todos os dados" a removem. O
  backup automático do Android foi desligado (`allowBackup=false`): ele
  levaria os bancos e a chave para a nuvem do Google sem ação da pessoa.
- **Uso atual:** só ações explícitas — anexar exame (lê os valores),
  e as que vierem (foto do prato, plano de refeições). Toda resposta é
  validada por JSON Schema (até 2 tentativas) e chega como estimativa a
  conferir.
- **Não verificado:** PDF enviado direto em `inlineData` (os exemplos do SDK
  mostram PDF por URI; imagem por bytes). Confirmar no primeiro teste no
  aparelho; se o provedor recusar, o app mostra o erro e a pessoa pode
  mandar foto.

