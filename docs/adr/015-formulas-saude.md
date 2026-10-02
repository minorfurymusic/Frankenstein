# ADR-15 — Fórmulas de saúde usadas nas metas e medidas

**Status:** aceito (decisão explícita do usuário, 2026-10-02). Coeficientes
exatos **a conferir na fonte primária antes de codificar** — os valores
abaixo foram escritos de memória e estão marcados como tal.
**Data:** 2026-10-02

## Contexto

O layout (Onboarding > Metas, Conta > Perfil/Metas, Nutrição > Dieta e metas,
Saúde > Corpo) mostra metas calculadas e "a fórmula usada". O usuário pediu
as fórmulas mais avançadas e aprovou a lista abaixo.

## Decisão

| Uso | Fórmula | Quando |
|---|---|---|
| Gasto em repouso (basal) | **Mifflin-St Jeor** | padrão (sexo, idade, altura, peso) |
| Gasto em repouso (basal) | **Katch-McArdle** | quando houver % de gordura informado — usa uma **ou** outra, nunca média |
| Gasto de exercício | **Compêndio de Atividades Físicas 2024 (METs)** | **por exercício registrado**, só o gasto acima do repouso — o repouso já está no basal |
| Proteína | **g/kg de peso (ISSN)** | meta diária |
| Água | **ml/kg de peso (EFSA)** | meta diária — ver "Não verificado" |
| Peso | **IMC (OMS)** + faixas da OMS | Saúde > Corpo |
| Gordura abdominal | **relação cintura/altura** | Saúde > Corpo |
| % de gordura | **método US Navy** (circunferências) | quando houver medidas |

Referência de memória (a conferir):
- Mifflin-St Jeor: `10·kg + 6,25·cm − 5·idade + 5` (masculino) / `− 161` (feminino).
- Katch-McArdle: `370 + 21,6 · massa magra (kg)`.
- Exercício: `(MET − 1) · kg · horas` — o "− 1" tira o repouso, que já está no basal.
- ISSN (position stand de 2017): 1,4–2,0 g/kg/dia para quem treina.

## Consequências

- Sexo biológico, data de nascimento, altura, peso e (opcional) % de gordura
  passam a ser dados obrigatórios do perfil para calcular metas.
- Toda meta mostra a fórmula usada e aceita ajuste manual (layout já prevê).
- Unidades em SI no banco; a fórmula que pede cm/polegada converte na borda.
- **Não decidido ainda** (pergunta para o ciclo das metas): fator de
  atividade do dia a dia (sem exercício) por nível escolhido no perfil;
  ajuste de calorias por objetivo (perder, manter, ganhar); divisão de
  carboidrato e gordura depois da proteína.

## Não verificado

- Coeficientes das fórmulas acima e do método US Navy (escritos de memória).
- **Água:** pelo que lembro, a EFSA (2010) publica valor fixo por sexo
  (água total por dia), não por kg. Se a fonte confirmar, a meta "ml/kg"
  precisa de outra referência ou vira valor EFSA por sexo — volto com a
  fonte antes de codificar.
