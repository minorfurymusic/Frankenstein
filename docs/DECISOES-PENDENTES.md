# Decisões pendentes — para você decidir

Ciclos feitos sozinho a seu pedido ("faça os próximos 3 ciclos sozinho,
guarde as decisões minhas para amanhã de manhã", 2026-10-06). Onde precisei
escolher, fiz a opção **mais conservadora e fácil de desfazer** e anotei
aqui. Nada abaixo virou ADR "aceita" sem você.

Responda pelo número (ex.: "1: ok; 3: B; 9: A").

## Ciclo A — voz no Cérebro

1. **Permissão de microfone.** O app passou a declarar o microfone
   (`RECORD_AUDIO`). O Android só pergunta quando a pessoa segura o botão
   de gravar no Cérebro, com a IA ativa. Antes ele era removido de
   propósito do APK. **A (feito)** manter · **B** tirar a voz.
2. **O áudio não fica guardado.** Depois de enviado ao Gemini ele some; na
   conversa fica só "Mensagem de voz · 0:14" e a transcrição.
   **A (feito)** não guardar · **B** guardar o áudio no celular junto da
   conversa (entraria na exportação).
3. **Vídeo no Cérebro** (a prancheta CerebroEntradas mostra "Vídeo"):
   **não fiz**. Vídeo é pesado (o app manda até 15 MB por vez à IA) e gasta
   muita cota. **A** deixar de fora por enquanto · **B** vídeos curtos
   (até ~30 s).
4. **Treino por voz ou texto** (está na prancheta, então fiz): uma mensagem
   vira **uma** sessão de treino; o nome é casado com a biblioteca de
   exercícios no celular; exercício fora da biblioteca entra como "livre"
   com o nome dito. Confere?

## Ciclo B — conversas do Cérebro

5. **"Desfazer" no cartão confirmado** (prancheta CerebroCartoesEstados):
   **não fiz** — é decisão de arquitetura de dados. O banco de saúde só
   acrescenta (nunca apaga); desfazer exige um registro de "anulação" e que
   **todas** as telas (Início, Nutrição, metas, gráficos, exportação)
   passem a ignorar o que foi anulado. **A** fazer isso numa ADR nova
   (recomendo: serve para corrigir qualquer registro, não só do Cérebro)
   · **B** ficar sem desfazer (a pessoa corrige na tela da área).
6. **Contexto da conversa vai junto para a IA.** Para entender "pode
   salvar a dipirona" ou "foi às 9h mesmo", cada mensagem leva as últimas
   falas **desta conversa** (o que a pessoa disse, as respostas e se cada
   cartão foi confirmado ou descartado), até ~3.000 letras. Nada de fora da
   conversa vai. **A (feito)** manter · **B** mandar só a mensagem atual
   (a IA deixa de entender referências ao que veio antes).
7. **Conversas guardadas no celular** (lista "Conversas"): entram na
   exportação e saem em "apagar todos os dados". Apagar uma conversa não
   apaga o que foi confirmado nela. Cartão sem resposta ao sair fica como
   "Descartado — nada foi salvo". Confere?
8. **Remédio novo pela conversa** ("comecei a tomar vitamina D"): só vira
   cartão de cadastro quando a pessoa diz nome, dose e horário; senão a IA
   pergunta. As respostas rápidas oferecem só horários — o app joga fora
   qualquer sugestão que pareça dose. Confere?
9. **"Como foi minha semana?"** (prancheta CerebroConversas): **não fiz** —
   hoje o Cérebro só responde o resumo do dia, calculado no celular.
   **A** fazer um resumo da semana calculado no celular (sem mandar dados
   à IA) · **B** deixar para depois.

## Ciclo C — calendário do Início

10. **Metas de dias passados** (calendário do Início e Diário): cada dia é
    pintado dentro/fora da meta usando o **perfil e o peso de hoje**, não
    os daquele dia. Para quem emagreceu muito, dias antigos podem aparecer
    com a cor "errada". **A** calcular com o peso registrado mais perto
    daquele dia · **B** deixar como está.
11. **Sequência de dias** ("12 dias seguidos registrando") aparece só no
    dia de hoje; em dia anterior aparece o aviso "Você está vendo um dia
    anterior" (como na prancheta). Confere?

## Pendentes de antes

12. **Especificação de nutrição** (`docs/specs/nutricao.md`): posso incluir
    "foto do prato" e "texto/voz no Cérebro" como formas de registrar
    refeição? Hoje a refeição estimada pela IA é gravada por uma
    ferramenta do app, porque o pacote de nutrição só muda depois da
    especificação (regra de sala limpa).
13. **Avaliação ao vivo com a sua chave.** Rodar
    `GEMINI_API_KEY=sua_chave dart test test/live_eval_test.dart` dentro de
    `packages/ai` mostra quanto o Gemini acerta nos 12 exemplos reais
    (gasta 12 chamadas).
14. **Ícone do app**: você disse que mandaria depois.
