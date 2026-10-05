# ADR-18 — Plano de refeições: importar, montar ou pedir à IA

**Status:** aceito
**Data:** 2026-10-05

## Contexto

O design citava um plano de refeições opcional, sem especificação.
Perguntado, o usuário decidiu (2026-10-05): "A pessoa pode importar caso
pegue com um profissional, mas ela pode ela mesmo criar e também ela pode
pedir para a ia."

## Opções consideradas

1. Só importar e montar (sem IA sugerindo cardápio).
2. Os três caminhos, com a sugestão da IA marcada como sugestão.

## Decisão

**Opção 2**, como pedido:

- **Importar do profissional:** foto ou PDF do plano. Com a IA ativa
  (ADR-11, Gemini), ela **transcreve** refeições e itens sem mudar,
  trocar ou acrescentar nada; kcal/macros vêm do documento ou como
  estimativa marcada. Sem IA, o documento fica guardado e a pessoa digita.
  O arquivo fica na pasta privada do app e entra na exportação.
- **Montar o próprio:** refeições (café, lanche, almoço, jantar) e itens
  com kcal/macros opcionais.
- **Pedir à IA:** vai **só** o mínimo — metas do dia (calorias, macros,
  fibra) e preferências, alergias e o que a pessoa não gosta; nada de
  nome, histórico ou dado clínico. A instrução proíbe alérgenos,
  suplementos, remédios, chás medicinais e jejum. Sai como **"Sugestão da
  IA"**, com o aviso fixo "Não é prescrição: um nutricionista pode
  ajustar."
- Tudo chega como **rascunho a revisar**; nada é salvo sem "Salvar".
  Consentimento antes do primeiro envio (ADR-11).
- Um plano por vez (dia-tipo). Cada item com kcal pode ser registrado no
  diário com um toque (vira adição rápida reaproveitada).

## Consequências

- **Fica mais fácil:** seguir o plano do nutricionista dentro do app, ou
  começar de uma sugestão.
- **Fica mais difícil / risco:** no Brasil, prescrição dietética é
  atividade de nutricionista (Lei 8.234/1991). A sugestão da IA é
  apresentada como sugestão de cardápio para revisão, nunca como
  prescrição, e não usa dado clínico. **Não verificado:** o texto da lei
  não foi lido neste ambiente; vale revisão jurídica antes de publicar
  (junto com o texto do consentimento, já pendente na ADR-11).
- **Passa a ser proibido:** a IA mudar o plano importado do profissional;
  sugestão com alérgeno informado, suplemento ou remédio.
