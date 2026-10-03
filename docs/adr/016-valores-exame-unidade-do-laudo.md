# ADR-16 — Valores de exame na unidade do laudo

**Status:** aceito
**Data:** 2026-10-03

## Contexto

A tela Exames (pranchetas Exames e ExameMarcador) mostra os valores de cada
exame (glicemia, HbA1c, colesterol…) e um gráfico por marcador. A regra
inviolável `.claude/rules/00-inviolaveis.md` diz "unidades sempre em SI".
Valor de laboratório não se encaixa bem nisso: há centenas de marcadores,
cada laboratório usa a sua unidade (mg/dL, %, U/L, mil/mm³…) e converter
exige fator por analito (glicose ≠ colesterol ≠ creatinina). Uma conversão
errada num dado de saúde é pior do que não converter. Pergunta levada ao
usuário em 2026-10-03.

## Opções consideradas

1. **Converter tudo para SI** ao salvar — exige uma tabela de fatores por
   analito, mantida por nós; erro silencioso se o marcador não estiver na
   tabela ou o nome vier diferente.
2. **Guardar como está no laudo** (valor + unidade escritos no papel/PDF) —
   o que a pessoa vê no app bate com o papel que leva ao médico.

## Decisão

**Opção 2.** Resposta do usuário (2026-10-03): "Esses valores são conforme
o exame puxado. Ao fazer o upload ou foto do exame, o sistema extrai e com
o exame mesmo decide qual utilizar." Cada valor de exame é gravado com a
unidade do próprio laudo, e a faixa de referência também é a do
laboratório. Exceção explícita à regra de SI, válida **só** para valores
transcritos de exame (`HealthDocument.markers`); sinais vitais, corpo,
nutrição e atividade continuam em SI.

## Consequências

- **Fica mais fácil:** o número no app é o mesmo do papel; não há tabela de
  conversão para manter.
- **Fica mais difícil:** o gráfico de um marcador só junta medições na
  mesma unidade. Se dois laboratórios usarem unidades diferentes para o
  mesmo marcador, a lista mostra todas e o gráfico usa a unidade da medição
  mais recente — o app avisa quantas ficaram fora.
- **Leitura automática:** extrair os valores da foto ou do PDF depende da
  IA com a chave do usuário (ADR-11), ainda sem provedor escolhido. Até lá,
  a pessoa digita os valores; quando a IA entrar, ela preenche o mesmo
  formulário marcado "Estimativa" e a pessoa confere antes de salvar.
- **Passa a ser proibido:** o app marcar valor como "alto", "baixo",
  "normal" ou "alterado". Mostra o valor e a faixa do laboratório, com o
  aviso "valores fora da faixa de referência não são diagnóstico"
  (`.claude/rules/brain.md`: registra, não diagnostica).
