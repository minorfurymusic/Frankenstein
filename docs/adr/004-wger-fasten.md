# ADR-4 — wger/Fasten: obrigatório, opcional ou substituído?

**Status:** aceito (confirmação explícita em 2026-08-09)
**Data:** 2026-08-05
**Revisão:** 1 (2026-08-06) — consequência de licença fundamentada com a
análise específica já existente em `docs/LICENSE-AUDIT.md` (Cenário B),
em vez de citação genérica ao documento inteiro.

## Contexto

`docs/PRODUTO.md:56` já coloca "F13 wger + Fasten" como fase separada,
depois do núcleo do MVP (F0-F12), e `docs/MONETIZACAO.md:15-19` já lista
"wger hospedado" e "Conector de prontuário (Fasten/FHIR)" como itens
**Premium**, não grátis. `docs/VIABILITY.md` (Ciclo 8) já recomendou os
dois como "DEPOIS DO MVP", federados via REST/FHIR. O que nenhum documento
resolveu ainda é a pergunta literal do ADR: são obrigatórios (o produto
não funciona sem), opcionais (funcionam se presentes, produto funciona sem)
ou substituídos (por um módulo próprio)?

Achado desta ADR: `docs/PRODUTO.md:27-30` já define um módulo próprio
"**Academia:** planos, sessão ao vivo, séries/repetições/carga, RPE,
recordes, progressão" — que **se sobrepõe** ao papel do wger ("Planos de
treino e dieta, catálogo", `docs/PRODUTO.md:17`). É o mesmo tipo de
sobreposição que o Ciclo 8 encontrou entre FoodYou e OpenNutriTracker, só
que aqui um dos dois lados é um módulo que já está planejado para ser
**escrito do zero**, não um dos 7 repositórios.

## Opções consideradas

1. **wger opcional, papel B2B/catálogo estendido — não substitui a
   Academia própria.** O MVP entrega o módulo Academia próprio (F7, item 5
   da Definição de Pronto); wger entra depois (F13) para quem já usa wger
   ou quer catálogo de exercícios maior, hospedado como serviço Premium.
2. **wger obrigatório, substitui a Academia própria** — descartaria o
   módulo próprio inteiro em favor do wger federado. Rejeitada aqui: exigiria
   rede (mesmo que federada) para uma função que `docs/PRODUTO.md` já
   assume rodar no aparelho ("Grátis = tudo que roda no aparelho",
   `STATUS.md`), e o item 5 da Definição de Pronto do MVP não menciona
   wger, só "plano de treino prescrito, executado".
3. **Fasten opcional, sem substituto próprio** — não existe módulo próprio
   de prontuário/PHR em `docs/PRODUTO.md`. Fasten é a única fonte para essa
   função (persona "Médico" em `docs/B2B.md`), mas continua opcional porque
   é Premium/B2B, não parte do núcleo grátis.
4. **Fasten obrigatório** — rejeitada: nada no MVP (Definição de Pronto,
   `docs/PRODUTO.md:59-68`) depende de prontuário/FHIR.

## Decisão

**wger: opcional**, federado (REST, já descrito em `docs/ARQUITETURA.md:16`),
papel de catálogo estendido e hospedagem para profissionais — **não
substitui** o módulo Academia próprio, que continua sendo escrito do zero
e entregue no MVP (F7). **Fasten: opcional**, federado (FHIR), sem
substituto próprio — função exclusiva de prontuário/B2B, ausente do MVP
grátis.

**Aceito em 2026-08-09.** Tocava arquitetura (ADR-1/ADR-3) e monetização
(o que é Premium) ao mesmo tempo — portão duplo cumprido por confirmação
explícita.

## Consequências

- **Fica mais fácil:** o MVP não depende de nenhum dos dois — reduz risco
  de licença no caminho crítico do lançamento. wger fica livre para
  evoluir independente, sem acoplar o release do app ao dele. Fundamento
  específico (`docs/LICENSE-AUDIT.md`, "Cenário B — federados por
  rede/app separado; sem linkar código", linhas 89–136): federar por
  REST (wger)/FHIR (Fasten) — processo de servidor distinto, chamado por
  API, nunca linkado ao binário do Frankstein — significa que nenhuma das
  duas licenças "vaza" para o cliente. wger continua AGPL-3.0 e Fasten
  continua GPL-3.0 **como programas separados**, cada um com sua própria
  obrigação de fonte, não do Frankstein. Isso soma com a decisão já
  tomada em `docs/adr/005-licenciamento-distribuicao.md:177` (revisão 3,
  **Opção 3**): o cliente Frankstein é **Apache-2.0**, não GPL/AGPL por
  nenhum motivo — OpenNutriTracker entra por PORT (reimplementação a
  partir de `docs/specs/nutricao.md`, não cópia de código), MLC
  LLM/OpenTracks são WRAP sobre Apache-2.0, e FoodYou não foi adotado
  (`docs/VIABILITY.md:16`, "AVALIAR", nunca decidido) — não há nenhum
  outro módulo empurrando o cliente para GPL/AGPL.
- **Fica mais fácil (nova, revisão 1):** se "wger hospedado" (item 4 do
  Premium, `docs/MONETIZACAO.md:15-19`) virar realidade, a obrigação de
  fonte da AGPL §13 recai sobre o **wger como programa**, para quem
  interage com ele pela rede — não sobre o restante do produto. Mitigação
  já decidida em outro lugar, não nova aqui: `docs/B2B.md:31-33` já
  assume a rota `/source` com o tarball da versão em execução, adotando a
  leitura conservadora da AGPL por precaução, independente de qual das
  duas leituras (`docs/LICENSE-AUDIT.md`, item 4 do Cenário B) for a
  correta.
- **Fica mais difícil:** manter dois sistemas de plano de treino
  conceitualmente parecidos (Academia própria + catálogo wger) exige
  decidir como eles convivem na UI sem confundir o usuário — quem vê o
  quê, quando um profissional B2B prescreve via wger e o paciente também
  tem a Academia própria. Não decido isso aqui, é UX (portão próprio).
- **Passa a ser proibido:** apresentar wger/Fasten como parte do produto
  grátis, ou fazer qualquer chamada de rede para eles sem ação explícita
  do usuário (`CLAUDE.md` regra 7) — reforça o que ADR-3 já propôs sobre
  rede não ser automática.

## Não verificado

- Se o wger tem uma API de catálogo de exercícios reutilizável
  separadamente do resto da aplicação (para federar só isso, sem hospedar
  o wger inteiro) — não investiguei a API REST dele a fundo, só confirmei
  que ela existe (`docs/recon/wger.md`, `package.json`/`package-lock.json`
  do frontend, não a documentação da API).
- Como a UX evita a confusão de dois sistemas de treino — fica para uma
  ADR/ciclo de UX, não decidido aqui.
