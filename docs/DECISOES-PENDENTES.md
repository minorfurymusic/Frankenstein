# Decisões pendentes — para você decidir

Ciclos feitos sozinho a seu pedido ("faça os próximos 3 ciclos sozinho,
guarde as decisões minhas para amanhã de manhã", 2026-10-06). Onde precisei
escolher, fiz a opção **mais conservadora e fácil de desfazer** e anotei
aqui. Nada abaixo virou ADR "aceita" sem você.

Responda pelo número (ex.: "1: ok; 2: B").

## Do ciclo A — voz no Cérebro (2026-10-06)

1. **Permissão de microfone.** O app passou a declarar o microfone
   (`RECORD_AUDIO`). O Android só pergunta quando a pessoa segura o botão
   de gravar no Cérebro, com a IA ativa. Antes ele era removido de
   propósito do APK. Opções: **A (feito)** manter; **B** tirar a voz.
2. **O áudio não fica guardado.** Depois de enviado ao Gemini ele some;
   na conversa fica só "Mensagem de voz · 0:14" e a transcrição.
   Opções: **A (feito)** não guardar; **B** guardar o áudio no celular
   junto da conversa (entra na exportação).
3. **Vídeo no Cérebro** (a prancheta CerebroEntradas mostra "Vídeo"): **não
   fiz**. Vídeo é pesado (o app manda até 15 MB por vez à IA) e gasta muita
   cota. Opções: **A** deixar de fora por enquanto; **B** vídeos curtos (até
   ~30 s).
4. **Treino por voz ou texto** (está na prancheta, então fiz): uma mensagem
   vira **uma** sessão de treino; o nome é casado com a biblioteca de
   exercícios no celular. Exercício que não está na biblioteca entra como
   "livre" com o nome dito. Confere?

## Pendentes de antes

5. **Especificação de nutrição** (`docs/specs/nutricao.md`): posso incluir
   "foto do prato" e "texto/voz no Cérebro" como formas de registrar
   refeição? Hoje a refeição estimada pela IA é gravada por uma ferramenta
   do app, porque o pacote de nutrição só muda depois da especificação
   (regra de sala limpa).
6. **Avaliação ao vivo com a sua chave.** Rodar
   `GEMINI_API_KEY=sua_chave dart test test/live_eval_test.dart` dentro de
   `packages/ai` mostra quanto o Gemini acerta nos 12 exemplos reais (gasta
   12 chamadas).
7. **Ícone do app**: você disse que mandaria depois.
