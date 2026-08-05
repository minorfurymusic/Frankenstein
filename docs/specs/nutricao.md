# Especificação funcional — Módulo de Nutrição

> **Fonte desta especificação:** `docs/recon/opennutritracker.md` (ficha de
> reconhecimento) e o comportamento **anunciado publicamente** pelo
> OpenNutriTracker — `README.md` do repositório (features, telas descritas
> em prosa, screenshots) e `docs/PRODUTO.md`. **Não veio do código-fonte
> Dart dele.** Onde o README cita um schema de exportação específico
> (`docs/export-format.md` do repositório, nomes de campo JSON), esta
> especificação **não copia esse schema** — descreve a necessidade
> funcional em termos do `HealthEvent` que já é o modelo de dados do
> Frankstein (`docs/ARQUITETURA.md`), com vocabulário próprio.
>
> Este documento é a fonte de verdade para a implementação do módulo de
> nutrição. `.claude/rules/port.md` proíbe o `packages/nutrition/**` de
> nascer do código do OpenNutriTracker — nasce daqui.

## Objetivo

Cobrir o item 2 da Definição de Pronto do MVP (`docs/PRODUTO.md:61`):
"Refeição registrada por código de barras, com macros no dashboard" — e a
fase F6 ("Nutrição + código de barras"). Diário alimentar offline: o
usuário registra o que come, vê calorias e macronutrientes contra uma
meta, sem conta e sem servidor no caminho padrão (grátis = roda no
aparelho, `STATUS.md`).

## Telas

1. **Hoje / Resumo do dia.** Anel de progresso de calorias restantes no
   dia, barras ou anéis secundários para carboidrato/gordura/proteína
   contra a meta de cada um, e um resumo da atividade do dia (passos,
   treino) vindo do Health Data Core — não duplicado aqui, só exibido.
2. **Adicionar alimento.** Três caminhos para a mesma ação: busca por
   nome, escaneamento de código de barras, ou "adição rápida" (nome +
   kcal, sem precisar buscar) para quem já sabe o valor de cabeça. Itens
   registrados recentemente aparecem prontos para adicionar de novo com
   um toque, porque a maioria das refeições se repete.
3. **Detalhe do alimento.** Tabela nutricional completa do item
   selecionado antes de confirmar o registro — não só calorias: carboidrato,
   gordura (incluindo saturada), proteína, açúcar, fibra, e, quando a
   fonte de dados tiver, o painel estendido de micronutrientes.
4. **Diário.** Visão de calendário; cada dia marcado por como foi (dentro
   ou fora da meta); ao selecionar um dia, calorias e macros daquele dia
   agrupados por refeição (café da manhã, almoço, jantar, lanche).
5. **Tendências.** Sequência de dias registrados (streak), gráfico de
   calorias contra a linha da meta, médias de macro por período (7/30/90
   dias ou histórico completo), consumo de água, e peso contra a meta com
   estimativa de quando deve chegar lá no ritmo atual.
6. **Perfil / Você.** Altura, peso, idade, nível de atividade, meta de
   peso e ritmo semanal desejado — os insumos do cálculo de meta
   calórica. Cálculo de IMC exibido aqui.

## Fluxos principais

- **Registrar refeição por busca:** buscar → escolher resultado → ver
  detalhe nutricional → ajustar quantidade/unidade → escolher a refeição
  do dia (café da manhã/almoço/jantar/lanche) → confirmar. Gera um
  `HealthEvent` do tipo `meal`.
- **Registrar por código de barras:** abrir a câmera → ler o código →
  cair na mesma tela de detalhe nutricional do fluxo de busca (união dos
  fluxos depois do primeiro passo, não uma tela separada) → mesmo caminho
  de confirmação. Entrada manual do código como alternativa quando a
  câmera não lê.
- **Adição rápida:** nome + kcal (macros opcionais) → confirma direto,
  sem passar pelas telas de busca/detalhe — pensado para quando o usuário
  já sabe o valor e não quer navegar.
- **Refeição/receita personalizada:** compor um item a partir de outros
  já cadastrados (ingredientes), com nome, foto e código de barras
  próprios, para reuso — sem depender de busca externa toda vez que a
  mesma refeição caseira se repete.
- **Meta calórica e de macros:** calculada a partir de altura, peso,
  idade, sexo/dados relevantes e nível de atividade informados no
  perfil — **a fórmula exata é decisão de implementação, não desta
  especificação**, mas precisa ser um método publicado e citável (o
  OpenNutriTracker cita IOM 2005 para meta calórica, WHO para IMC, WHO
  TRS 916 para macros, e o Compendium de 2024 para gasto por atividade —
  são padrões científicos públicos, não propriedade do app; quem
  implementar deve escolher e citar a própria fonte, verificada, não
  assumir que é a mesma sem conferir).
- **Peso:** captura no onboarding e sob demanda; tendência contra meta;
  opção de afunilar a meta calórica conforme o peso se aproxima do alvo.
- **Água:** registro rápido de consumo com incrementos predefinidos e
  meta editável.

## Modelo de dados (em termos do `HealthEvent` do Frankstein)

Não é o schema do OpenNutriTracker. É o que o módulo de nutrição precisa
gravar no Health Data Core já definido em `docs/ARQUITETURA.md` e
`.claude/rules/datacore.md`:

- **`HealthEvent.type = "meal"`**
  - `payload` precisa conter, no mínimo: identidade do alimento (nome;
    código de barras quando veio de scan; fonte do dado — busca local,
    catálogo offline, ou item personalizado), quantidade + unidade,
    categoria da refeição (café da manhã/almoço/jantar/lanche),
    macronutrientes por porção (calorias, carboidrato, gordura, proteína;
    idealmente também saturada, açúcar, fibra), e micronutrientes quando
    a fonte tiver.
  - `occurred_at`: quando a refeição foi consumida (não quando foi
    registrada — os dois podem diferir se o registro for retroativo).
  - `source`: de onde veio o dado nutricional (catálogo offline
    embarcado — ver `docs/OFFLINE-IA.md:31-35`, subconjunto brasileiro do
    Open Food Facts —, ou item personalizado do usuário).
- **Peso e água** são séries temporais simples (valor + timestamp), tipos
  próprios de `HealthEvent` a definir na implementação (`weight` já está
  na lista de tipos em `docs/ARQUITETURA.md:32`; água não está listada
  ainda — pendência a resolver na implementação, não decidida aqui).
- **Receitas/refeições personalizadas** não são um `HealthEvent` — são
  catálogo local reutilizável (referenciado por eventos `meal`, não um
  evento em si), na mesma lógica de "catálogo" que `docs/ARQUITETURA.md`
  já usa para a base de alimentos.

## Fora de escopo desta especificação

- Fórmulas de cálculo exatas (meta calórica, macros, IMC) — citadas como
  categoria de exigência (método científico publicado), não especificadas
  aqui número a número.
- Layout visual, paleta, animação — isso é UX, não funcional.
- Integração com o roteador do cérebro (`.claude/rules/brain.md`) — a
  ferramenta `log_meal` já está esboçada em `docs/ARQUITETURA.md:47-63`;
  esta especificação cobre a tela/fluxo manual, não a chamada por
  linguagem natural.
- Sincronização entre aparelhos — regida por ADR-3, não por este módulo.

## Não verificado

- Se o app deve usar exatamente os mesmos padrões científicos que o
  OpenNutriTracker cita (IOM 2005, WHO, WHO TRS 916, Compendium 2024) ou
  outros — são públicos e citáveis por qualquer implementação, a escolha
  final é de quem implementar, não desta especificação.
- Tipo de `HealthEvent` para água — não existe ainda na lista de
  `docs/ARQUITETURA.md:32`, precisa ser adicionado na implementação.
