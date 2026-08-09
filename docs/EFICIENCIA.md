# EFICIÊNCIA — custo real de contexto do projeto

**Ciclo 32 — relatório de eficiência. Não implementa nada.**
**Data:** 2026-08-06

## Metodologia

Nada aqui é estimado de memória. Toda contagem veio de um script Python
(`/tmp/.../scratchpad/analyze*.py`, descartável, não faz parte do repo) que
leu o transcript literal desta sessão —
`/root/.claude/projects/-home-user-Frankenstein/c8fc46bd-63a4-505d-8716-5cda94ccdb42.jsonl`,
2.414 linhas — e contou, por chamada de ferramenta: nome do arquivo, tamanho
em caracteres do resultado, comando executado. A sessão cobre os 29 ciclos
registrados em `STATUS.md` até aqui (Ciclo 0 ao Ciclo 29), então os números
abaixo são o custo real desses 29 ciclos, não uma amostra.

Totais brutos da sessão: 271 chamadas Bash, 149 Edit, 110 Read, 47 Write,
14 WebFetch, 9 WebSearch, 14 chamadas MCP do GitHub Actions. Soma de
caracteres retornados por ferramentas: **820.005** (~205 mil tokens a
~4 caracteres/token — só em resultado de ferramenta, sem contar texto do
modelo, `thinking`, nem o carregamento de `CLAUDE.md`/regras a cada turno).

## Tamanho dos arquivos carregados automaticamente

| Arquivo | Linhas | Quando carrega |
|---|---|---|
| `CLAUDE.md` | 75 | toda sessão, sobrevive a `/compact` |
| `.claude/rules/00-inviolaveis.md` | 11 | toda sessão (sem `paths:`) |
| `.claude/rules/activity.md` | 23 | só ao mexer em `packages/activity/**` |
| `.claude/rules/brain.md` | 27 | só ao mexer em `packages/brain/**` |
| `.claude/rules/datacore.md` | 20 | só ao mexer em `packages/health_core/**` |
| `.claude/rules/licenca.md` | 32 | só ao mexer em área de licença |
| `.claude/rules/monetizacao.md` | 22 | só ao mexer em `packages/entitlements/**` |
| `.claude/rules/port.md` | 66 | só ao mexer em `packages/nutrition/**` |
| `.claude/rules/share.md` | 14 | só ao mexer em `packages/share/**` |
| **`STATUS.md`** | **624** | **toda sessão/ciclo, por instrução do `CLAUDE.md`** |

**Achado central:** `CLAUDE.md` (75 linhas) e o conjunto de `.claude/rules/*`
que carrega sempre (`00-inviolaveis.md`, 11 linhas) somam **86 linhas** e
já estão dimensionados de propósito — o próprio kit original (`COMECE-AQUI.md`,
removido na reorganização do Ciclo 0, mas ainda no histórico do git) dizia
"`CLAUDE.md` carrega toda sessão e sobrevive ao `/compact`. Por isso é
curto." Isso funcionou. **`STATUS.md`, sozinho, já é 7,3x maior que
`CLAUDE.md` e todas as regras somadas — e é o único arquivo desta lista sem
teto.**

## Documentos mais relidos (`Read`, contagem de chamadas)

| Arquivo | Leituras |
|---|---|
| `STATUS.md` | **31** (+ 21 chamadas `tail` via Bash — ver seção própria) |
| `docs/adr/000-pendentes.md` | 7 |
| `docs/adr/005-licenciamento-distribuicao.md` | 5 |
| `docs/adr/008-multitenant-b2b-consentimento.md` | 4 |
| `docs/PRODUTO.md` | 3 |
| `docs/adr/001-shell-multiplataforma.md` | 3 |
| (todos os outros) | 1–2 cada |

`STATUS.md` foi lido/consultado **mais que o dobro** do segundo colocado
somado. As ADRs re-lidas (000, 005, 008, 001) foram todas ADRs que passaram
por múltiplas revisões neste projeto — reler antes de editar de novo é
esperado, não é desperdício: cada revisão aconteceu em ciclo diferente, com
mudança de conteúdo real entre uma leitura e outra. **Não encontrei
evidência de releitura do mesmo trecho, sem mudança no meio, dentro do
mesmo ciclo** — a suspeita de "releitura por hábito" não se confirmou para
as ADRs.

`STATUS.md` também foi o arquivo mais editado: **96 chamadas `Edit`** — mais
que todos os outros arquivos do projeto somados (as próximas,
`docs/adr/000-pendentes.md` e `docs/adr/008-...md`, tiveram 7 e 6).

## Investigação específica — `STATUS.md`

### Crescimento

| Commit (ordem) | Data | Linhas |
|---|---|---|
| #1 | 2026-08-04 09:57 | 38 |
| #5 | 2026-08-04 13:45 | 73 |
| #10 | 2026-08-04 13:53 | 120 |
| #15 | 2026-08-05 10:26 | 195 |
| #20 | 2026-08-05 10:32 | 240 |
| #25 | 2026-08-05 16:58 | 291 |
| #30 | 2026-08-05 18:05 | 380 |
| último (34) | 2026-08-06 | **624** |

Crescimento aproximadamente linear em 34 commits que tocaram o arquivo,
~17 linhas/commit em média — mas os últimos ciclos (27–29) sozinhos
acrescentaram ~240 linhas (380→624) por causa de prova literal de CI colada
por completo. **Sem limite superior desenhado.** Extrapolando o ritmo atual
(não o médio, o recente — mais realista para ciclos de código com CI),
`STATUS.md` passa de 1.000 linhas por volta do Ciclo 40–45.

### Proporção estado-atual vs. histórico

```
Linhas 1–71   (Fase/Ciclo atual/Progresso/Decisões/Débito)  =  71 linhas (~11%)
Linha 83      (## Histórico de ciclos)
Linhas 83–624 (histórico de todos os ciclos)                 = 542 linhas (~89%)
```

**89% do arquivo é histórico que só interessa para auditoria — não para
saber "o que fazer agora".** O `CLAUDE.md` manda ler `STATUS.md` no
ORIENTAR de todo ciclo justamente para saber o objetivo/estado atual — que
mora nos 11% do início. Os outros 89% só são necessários quando alguém
precisa reconstruir o "porquê" de uma decisão antiga, o que é raro e pode
ser sob demanda.

### Custo de leitura medido

Nesta sessão, as 31 chamadas `Read` em `STATUS.md` somaram **48.261
caracteres**. As 21 chamadas `tail -N STATUS.md` via Bash (ver próxima
seção) somaram mais alguns milhares. Uma leitura completa do arquivo hoje
(624 linhas, 40.112 bytes) custa ~10 mil tokens. Se só as 71 linhas de
estado precisassem ser lidas por ciclo, o custo cairia para ~1.300 tokens
— **queda de ~87%** por leitura completa, e essa proporção só piora a favor
da mudança conforme o histórico cresce (o "estado atual" tem tamanho
limitado por natureza; o histórico, não).

## Onde houve leitura/execução desnecessária

### 1. Reler arquivo logo depois de editar (100% evitável)

21 chamadas Bash da forma `tail -N STATUS.md` aconteceram logo após um
`Edit` no mesmo arquivo, no mesmo turno — para "conferir" uma edição que o
próprio `Edit` já teria recusado se tivesse falhado. Instrução que já
existe (fora deste projeto, no comportamento padrão) diz explicitamente
para não fazer isso; não foi seguida de forma consistente aqui. Custo
somado pequeno por chamada, mas 100% dispensável e recorrente — apareceu
em quase todo ciclo que editou `STATUS.md`.

### 2. Chamadas ao GitHub Actions mais caras que o necessário

No Ciclo 27 (acompanhar o CI até ficar verde), usei três ferramentas
diferentes para a mesma pergunta ("o run terminou? passou?"):

| Ferramenta | Chamadas | Tamanho por chamada | Total |
|---|---|---|---|
| `actions_list` (`list_workflow_runs`) | 3 | 14.446 / 28.303 / 42.185 | 84.934 |
| `actions_get` (`get_workflow_run`) | 5 | ~13.856–13.907 | 69.412 |
| `actions_list` (`list_workflow_jobs`) | 5 | 2.226–2.696 | 12.545 |

`list_workflow_jobs` devolve **mais informação útil** (status de cada
step: `flutter doctor`, `lint`, `test`, `build`, com timestamp) por **~15%
do tamanho** de `get_workflow_run`/`list_workflow_runs` — o motivo é que
esses dois ecoam o objeto completo do repositório do GitHub (URLs de
`blobs`, `branches`, `collaborators`, `teams`, etc. — nenhuma dessas
informações foi usada nem uma vez) a cada chamada. Usei os três porque fui
aprendendo durante o próprio ciclo qual dava a informação certa — na
prática, `list_workflow_jobs` sozinho teria bastado para todo o
acompanhamento. **~154 mil caracteres (≈38 mil tokens) foram gastos em
`actions_list`(runs)/`actions_get` que `list_workflow_jobs` teria coberto
por ~12 mil.**

### 3. Saída longa colada sem necessidade — um incidente identificado

A sincronização da branch designada com `main` (Ciclo 29) usou
`git merge --ff-only`, que — como a branch estava parada desde o Ciclo 0 —
imprimiu a lista completa de ~200 arquivos alterados (25.414 caracteres).
Só precisava da confirmação de que o fast-forward funcionou; `--quiet` ou
redirecionar para `wc -l`/`tail` teria bastado. **Caso único nesta sessão**,
não um padrão recorrente — registrado porque é o maior resultado de Bash
de toda a sessão, mas não vale tratar como problema sistêmico: só acontece
de novo se outra branch ficar igualmente desatualizada, o que a própria
correção deste ciclo já evita.

### 4. Varredura em `refs/` — achado negativo

Investiguei especificamente comandos `find`/`grep -r` dentro de `refs/`
(onde estão os 6 repositórios de terceiros clonados). Todos os que
encontrei usavam `-maxdepth` e padrões `-iregex` específicos para caçar
arquivos de licença (`LICENSE`, `COPYING`, `NOTICE`) — nenhuma varredura
irrestrita de árvore inteira. Maior resultado: 4.664 caracteres. **Não é
uma fonte de desperdício neste projeto até agora** — registro isso para não
inventar um problema que os dados não mostram.

## Propostas

### Grupo A — aplico sozinho, sem tocar `CLAUDE.md`/`.claude/rules/`

Ordenadas por economia estimada, maior primeiro.

1. **Ao acompanhar CI do GitHub Actions, usar só `list_workflow_jobs`**
   (nunca `get_workflow_run`/`list_workflow_runs` para status de um run já
   conhecido) — essas duas só servem para descobrir o ID do run mais
   recente, uma vez, com `per_page=1`. Economia observada: ~85–90% do
   custo de acompanhar um CI (154K → ~15K caracteres no caso medido). É o
   padrão que mais se repete daqui pra frente, porque todo ciclo que faz
   push com CI vai precisar disso.
2. **Nunca reler um arquivo logo depois de editá-lo "para confirmar".** O
   `Edit`/`Write` já falha com erro se o conteúdo não bater — não há nada
   a confirmar. Elimina as ~21 chamadas `tail`/`cat` pós-edit observadas
   nesta sessão, 100% do custo delas, recorrente a cada ciclo que edita
   `STATUS.md` ou qualquer ADR.
3. **Ler `STATUS.md` por partes (`offset`/`limit`) em vez de por
   completo**, quando só preciso do estado atual (linhas 1–71) ou do
   último ciclo (`tail`/offset perto do fim) — já pratiquei isso em 37 das
   110 leituras totais desta sessão (Read com offset), formalizar como
   padrão até o Grupo B (item 1) ser aprovado. Mitigação imediata parcial
   do mesmo problema que o Grupo B resolve de vez.
4. **Suprimir saída verbosa de comandos git quando só preciso confirmar
   sucesso/estado** (`-q`, `--stat=1`, ou pipe para `tail`/`wc -l`) em
   qualquer operação de merge/checkout que possa tocar muitos arquivos de
   uma vez — situacional, menor prioridade que os itens acima porque só
   aconteceu uma vez nesta sessão, mas fácil de aplicar sem custo.

### Grupo B — toca `CLAUDE.md` ou `.claude/rules/`, precisa da sua aprovação

1. **Mover `## Histórico de ciclos` de `STATUS.md` para `docs/HISTORICO.md`,
   deixando em `STATUS.md` só Fase/Ciclo atual/Progresso/Decisões/Débito
   técnico** (as atuais linhas 1–71, ~11% do arquivo hoje). Maior economia
   de todas as propostas deste relatório — reduz o custo da leitura que o
   `CLAUDE.md` manda fazer **todo ciclo** de ~10 mil tokens hoje (crescendo
   sem teto) para ~1.300 tokens (crescimento lento, limitado ao que cabe
   em "estado atual"). Exige mudar a frase `CLAUDE.md:27` ("Leia
   `STATUS.md`") para mencionar que o histórico detalhado mora em
   `docs/HISTORICO.md` e só precisa ser aberto sob demanda — por isso é
   Grupo B, não B por acaso: é literalmente editar `CLAUDE.md`. Verifiquei
   que nenhum hook (`.claude/hooks/*.sh`) faz parsing programático de
   `STATUS.md` — só `CLAUDE.md:27` e `.claude/commands/ciclo.md:4`
   referenciam o arquivo, e ambos são instrução em prosa, não parsing.
   Mudança mecânica seria: cortar a partir de `## Histórico de ciclos`,
   colar em `docs/HISTORICO.md` com um cabeçalho novo, deixar em
   `STATUS.md` uma linha apontando para lá.

Nenhuma outra mudança em `CLAUDE.md`/`.claude/rules/` parece justificada
pelos dados: `CLAUDE.md` (75 linhas) e o conjunto de regras que carrega
sempre (11 linhas) já estão pequenos por desenho e não apareceram como
fonte de custo nesta investigação — não vou propor mexer neles.

## Resultado — Grupo A e Grupo B aplicados (2026-08-06)

**Grupo B aplicado.** `## Histórico de ciclos` cortado de `STATUS.md` e
colado em `docs/HISTORICO.md` novo. `CLAUDE.md:27` editado (mínimo
necessário — uma frase) para apontar pro histórico separado, com
aprovação explícita do usuário para essa mudança específica.

Medição antes/depois, literal:

| Arquivo | Antes | Depois |
|---|---|---|
| `STATUS.md` | 765 linhas | **73 linhas** |
| `docs/HISTORICO.md` | (não existia) | 678 linhas |
| `CLAUDE.md` | 75 linhas | 77 linhas (+2, a frase nova) |

**Redução de ~90,5% em `STATUS.md`** — mais forte que a estimativa de
~87% feita antes de aplicar (a estimativa foi feita em cima de uma versão
de 624 linhas; a real, no momento de aplicar, já tinha crescido para 765).
Confirma a tese: sem teto, o histórico cresce mais rápido do que dá pra
prever de um ciclo pro outro. Também aproveitado para remover do
`STATUS.md` uma seção ("Fechamento do Ciclo 27") que já estava duplicada
dentro do próprio histórico — não fazia parte do Grupo B original, mas é
o mesmo princípio (não repetir no "estado atual" o que já está no
histórico).

**Grupo A adotado como prática, não como mudança de arquivo** — as 4
propostas são comportamento, não código: preferir `list_workflow_jobs` a
`get_workflow_run`/`list_workflow_runs` no polling de CI; nunca reler
arquivo logo após editar; ler `STATUS.md` (e outros grandes) por partes
quando só uma seção interessa; suprimir saída verbosa de operações git
que só precisam confirmar sucesso. Sem uma nova sessão inteira pra medir
"antes/depois" de comportamento (diferente de tamanho de arquivo, que dá
pra medir na hora), a confirmação real desses quatro fica para a próxima
leitura de manutenção deste arquivo — ver seção abaixo.

## Manutenção

**A cada 5 ciclos, no passo ORIENTAR, reler este arquivo por completo.**
Verificar:
- As medidas do Grupo A ainda estão sendo seguidas (ou viraram hábito e
  regrediram)?
- Se o Grupo B foi aplicado, os números de economia se confirmaram na
  prática (comparar tamanho de `STATUS.md` antes/depois, contagem de
  leituras)?
- Novos padrões de desperdício surgiram que não existiam nesta medição
  (ferramentas novas, arquivos novos que cresceram)?

Acrescentar os achados novos como uma seção datada abaixo desta, sem apagar
o histórico de medições anteriores — este arquivo é o único lugar do
projeto onde acumular histórico é o objetivo, não o problema.

Este arquivo pode ser editado livremente por qualquer ciclo futuro. As
propostas do Grupo B, mesmo depois de aprovadas e aplicadas, não autorizam
edições futuras em `CLAUDE.md`/`.claude/rules/` por conta própria — cada
mudança nova nesses arquivos continua exigindo aprovação explícita, mesmo
que seja "só mais uma otimização parecida com a de antes".
