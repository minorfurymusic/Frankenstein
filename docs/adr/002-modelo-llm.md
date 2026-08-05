# ADR-2 — Modelo LLM, quantização, RAM mínima, perfis A/B/C

**Status:** aceito
**Data:** 2026-08-05

## Contexto

`docs/OFFLINE-IA.md` já especifica os perfis A/B/C em detalhe — RAM,
tamanho de modelo, download, comportamento — e as regras de implementação
(nunca no APK, download sob demanda, descarregar da RAM em segundo
plano/GPS, teto térmico, medir em `docs/PERF.md`). Isso não é uma decisão
em aberto, é uma especificação já escrita. O que esta ADR faz é formalizar
essa especificação como decisão de arquitetura e testá-la contra o que a
ficha de reconhecimento do MLC LLM (`docs/recon/mlc-llm.md`, Ciclo 1)
encontrou: bindings nativos `android/mlc4j` e `ios/MLCSwift` já existem no
projeto upstream, exatamente no formato que `.claude/rules/brain.md` e
ADR-1 (proposto) assumem para WRAP via platform channel — mas build nunca
foi tentado (submódulos `3rdparty/` vazios por clone raso), então nenhum
número de `docs/OFFLINE-IA.md` (RAM de pico, tokens/s) foi medido de
verdade, só herdado da documentação upstream do MLC LLM.

## Opções consideradas

1. **Adotar a especificação de `docs/OFFLINE-IA.md` como está**, usando
   MLC LLM (via `mlc4j`/`MLCSwift`, WRAP conforme ADR-1) como motor de
   inferência para os perfis A e B, roteador determinístico como caminho
   principal do perfil C.
2. **Reavaliar o motor de inferência** (outro runtime além do MLC LLM) —
   não avaliei alternativa nenhuma neste ciclo; a Fase 0 escolheu o MLC
   LLM como um dos 7 repositórios antes desta ADR existir, e trocar de
   motor agora reabriria uma decisão de escopo que não é desta ADR.
3. **Adiar a definição de perfis até ter números reais de RAM/desempenho
   medidos em aparelho** — mais cauteloso, mas trava o F5 (`docs/PRODUTO.md:47`)
   indefinidamente. A opção 1 não impede medir depois; só formaliza a
   especificação como ponto de partida testável.

## Decisão

**Opção 1.** A especificação de `docs/OFFLINE-IA.md` vale como está:

- Perfil A (≥8 GB RAM): modelo 3B q4f16_1, download ~1,7–2,2 GB.
- Perfil B (6 GB): modelo 1,5B q4f16_1, download ~0,9–1,1 GB.
- Perfil C (≤4 GB): nenhum modelo — só roteador determinístico + templates,
  tratado como caminho principal, não degradado.
- Motor: MLC LLM, via bindings nativos já existentes (`mlc4j` Android,
  `MLCSwift` iOS), integrados por WRAP conforme ADR-1 (proposto).
- Regras operacionais de `docs/OFFLINE-IA.md:17-24` mantidas sem alteração:
  modelo nunca no APK/AAB, download sob demanda com hash verificado,
  descarregar da RAM em segundo plano/GPS, teto térmico com degradação
  para o roteador.

**Isto está aceito** (2026-08-05). Dependia de ADR-1 (shell/WRAP), agora
aceita — condição satisfeita. O motor (MLC LLM, Apache-2.0) e os perfis
A/B/C não dependem do resultado da ADR-5 (ainda em revisão): MLC LLM é
Apache-2.0 em qualquer cenário de licenciamento do cliente considerado
lá, então esta decisão fica de pé independente de como a ADR-5 fechar.

## Consequências

- **Fica mais fácil:** não é preciso desenhar os perfis do zero — a
  especificação já existe e é detalhada o suficiente para implementar.
  Os bindings nativos do MLC LLM já resolvem a integração Android/iOS sem
  reescrever a camada de inferência.
- **Fica mais difícil:** **nenhum número de `docs/OFFLINE-IA.md` foi
  medido neste reconhecimento** — RAM de pico, tokens/s, tamanho real por
  quantização são os que o próprio MLC LLM documenta, não medições do
  Frankstein. `docs/recon/mlc-llm.md` registra que o build não foi
  tentado (submódulos vazios, toolchain pesado fora de escopo). Antes do
  F5 fechar, isso precisa ser medido em aparelho real e publicado em
  `docs/PERF.md` (que ainda não existe — mesma pendência já registrada em
  ADR-9).
- **Passa a ser proibido:** declarar "compila" ou "roda em X tokens/s" sem
  a saída literal do teste — mesma regra de `CLAUDE.md` que rege todo o
  projeto, reforçada aqui porque é o ponto onde a tentação de inventar
  número é maior.

## Não verificado

- ~~As 6 licenças de submódulo do MLC LLM continuam pendentes~~ —
  **resolvido no Ciclo B** (2026-08-05): todas permissivas, ver
  `docs/recon/mlc-llm.md`. Não muda a decisão proposta nesta ADR.
- RAM de pico e desempenho real por perfil — zero medição própria feita
  (submódulos agora presentes, mas build continua não tentado — ver
  `docs/recon/mlc-llm.md`, seção Build).
- Se o subconjunto brasileiro do Open Food Facts (`docs/OFFLINE-IA.md:31-35`)
  tem alguma relação com o motor de inferência ou é módulo separado — não
  investiguei, é escopo de nutrição, não desta ADR.
