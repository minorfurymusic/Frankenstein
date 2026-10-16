# ADR-21 — Gasto da musculação pela carga e pelas repetições (altera ADR-15)

**Status:** aceito (decisão explícita do usuário, 2026-10-16)
**Data:** 2026-10-16

## Contexto

O gasto do treino de academia era MET 3,5 × peso × **tempo com a tela do
treino aberta**. No teste no aparelho, um treino lançado em 1,5 min deu
6 kcal; o mesmo treino com o app aberto 2 h daria 300; 25 kg ou 120 kg no
supino davam o mesmo. O usuário pediu (2026-10-16): carga e repetições como
base, tempo padrão por série, descanso não mudando a conta, fórmula geral +
fórmulas específicas por exercício, e **carga total** digitada com o peso do
equipamento somado sem avisar.

## Fontes lidas

- Reis VM et al. (2017), PLOS ONE 12(7):e0181311, CC BY 4.0 — texto e
  Tabelas 1 e 2 lidos (Europe PMC). 8 exercícios em máquina, 12–24 % e
  80 % de 1RM, cadência 4 s/repetição, 58 homens treinados (78,67 kg).
  Gasto (kcal/min, aeróbio + anaeróbio durante o exercício) sobe em linha
  reta com a carga.
- Knausenberger A et al. (2014), Central European Journal of Sport Sciences
  and Medicine 8 — resumo lido (DOAJ): do custo total de uma série, 18 %
  aeróbio durante, 31 % anaeróbio, **51 % na recuperação (EPOC)**.

## Decisão

Por série: `kcal = (a × peso/78,67 + b × carga − repouso) × (reps × 4 s) ÷ 0,49`

- `a`, `b`: reta de mínimos quadrados dos 5 pontos de Reis 2017 por
  exercício (R² ≥ 0,99): supino reto (2,36; 0,120), supino 45° (2,70;
  0,205), agachamento (4,20; 0,332), leg press (2,38; 0,072), extensora
  (2,86; 0,191), puxada (2,14; 0,100), rosca (1,77; 0,220), tríceps polia
  (1,93; 0,242).
- **Geral** (exercícios sem estudo): média das 8 retas (2,54; 0,185).
- `repouso` = 3,5 ml/kg/min × 5 kcal/L — gasto acima do repouso (ADR-15).
- `÷ 0,49` = recuperação (Knausenberger 2014). Por isso o descanso real
  não muda a conta.
- **Carga total digitada**; barra olímpica (20 kg) somada sem aviso em
  supino reto/inclinado, agachamento, terra, remada curvada e stiff.
- Peso do corpo (carga 0): MET de funcional moderado (6,0, ADR-15) × peso ×
  (repetições × 4 s + 60 s).
- O relógio continua: duração do treino e **kcal por hora** no resumo;
  esteira e "outras atividades" seguem por tempo (MET).

## Consequências

- Mais carga e mais repetições gastam mais; lançar tudo de uma vez ou
  esquecer o app aberto não muda o gasto.
- **Limites (estimativa, marcada como tal):** estudo com homens treinados
  em máquina; a reta geral é aproximação (as retas variam 4,6× entre
  exercícios); a barra de 20 kg pode não ser a da academia da pessoa.
- Código: `packages/activity/lib/src/strength_energy.dart`.
