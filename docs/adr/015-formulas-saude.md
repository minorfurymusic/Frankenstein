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
| Água | **ml/kg de peso, com piso por sexo (EFSA 2010)** | meta diária — ver "Água" abaixo |
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

## Água (decidido pelo usuário em 2026-10-02: cálculo por kg + valor por sexo)

Fontes (pesquisa de 2026-10-02):
- EFSA 2010, *Scientific Opinion on Dietary Reference Values for water*
  (doi:10.2903/j.efsa.2010.1459): ingestão adequada de **água total** de
  **2,0 L/dia (mulher)** e **2,5 L/dia (homem)**, para temperatura e atividade
  moderadas; água total inclui a dos alimentos, que a EFSA supõe ser
  **20–30%** (bebidas = 70–80%).
- 30–35 ml/kg/dia é a regra clínica usada para necessidade hídrica de
  adultos (fonte primária não aberta — citada em material secundário).

Proposta de cálculo (aguarda aprovação dos números):
`água total = max(peso_kg × 35 ml, 2,0 L mulher | 2,5 L homem)` e
**meta de bebida no app = 80% da água total** (o app registra o que se bebe,
não a água da comida). Ex.: homem 70 kg → 2,5 L total → 2,0 L para beber;
mulher 60 kg → 2,1 L total → 1,68 L para beber.

## Meta de calorias (modelo descrito pelo usuário em 2026-10-02)

- No perfil a pessoa escolhe **perder, manter ou ganhar** e o ritmo
  (ex.: perder 50 g/dia). O sistema calcula o déficit/superávit diário.
- O "consumo normal do dia" sobe quando ela caminha, corre ou faz exercício.
- **Fechamento do dia:** automático à 00:00 (fuso gravado) ou quando a pessoa
  toca em "fechar dia"; mostra se bateu a meta. O painel mostra o andamento
  o tempo todo.

Proposta técnica (aguarda aprovação):
- `meta do dia = basal × 1,2 − ajuste do objetivo + passos + exercícios`.
  1,2 é o fator "sedentário": o dia a dia sem caminhada nem treino. Caminhada
  entra pelos **passos** contados e treino/corrida pelos **METs** — assim não
  se conta a mesma atividade duas vezes. O campo "nível de atividade" do
  perfil deixa de ser necessário.
- Passos dentro de uma corrida/caminhada gravada não contam de novo.
- Ritmo → calorias: **7.700 kcal por kg** (50 g/dia ≈ 385 kcal/dia). É a
  regra clássica; os modelos dinâmicos (Hall, 2008) mostram que ela
  superestima a perda no longo prazo, por isso a meta é **recalculada a cada
  novo peso registrado**.
- Limites de segurança (dado de saúde, portão): meta nunca abaixo do basal;
  perder no máximo ~1% do peso por semana.
- "Bateu a meta": perder → consumo ≤ meta; ganhar → consumo ≥ meta; manter →
  dentro de ±10% da meta.
- Dia fechado que recebe registro atrasado é recalculado.

## Divisão de macronutrientes da meta diária (proposta, aguarda aprovação)

Isto é a meta do dia, não a análise do prato (o prato usa os gramas da tabela
TACO ou a estimativa da IA).
- Proteína: g/kg (ISSN 2017, doi:10.1186/s12970-017-0177-8: 1,4–2,0 g/kg/dia
  para quem treina; 2,3–3,1 g/kg de massa magra em déficit com musculação).
  Proposta: 1,6 g/kg ao perder ou ganhar, 1,4 g/kg ao manter.
- Gordura: **30% das calorias**.
- Carboidrato: **o restante**.
- Conferência pelas faixas aceitáveis (AMDR, Institute of Medicine): proteína
  10–35%, gordura 20–35%, carboidrato 45–65% das calorias; fora da faixa, o
  app mostra aviso e a pessoa ajusta.

## Não verificado

- Coeficientes das fórmulas acima e do método US Navy (escritos de memória).
- Fonte primária da regra 30–35 ml/kg (só material secundário consultado).
