# ADR-5 — Licenciamento e modelo de distribuição

**Status:** proposto
**Data:** 2026-08-05 (revisão 3 — fundamentação corrigida, clean room decidido, vazamento da ficha fechado)
**Revisão 4 (2026-08-06):** limpeza pequena — item de "Não verificado" sobre
a direção do Gadgetbridge no Health Connect estava desatualizado (ADR-4a
foi aceita no Ciclo 30). Nenhuma mudança de fundo: a decisão (Opção 3,
PORT, cliente Apache-2.0, clean room obrigatório) já era sólida antes
desta revisão — três rounds de revisão já tinham corrigido fundamentação,
decidido clean room como obrigatório e fechado o vazamento da ficha.

## Nota de revisão 3 (o que mudou nesta volta)

Três correções pedidas:

1. **Consequência que faltava:** Apache-2.0 permite a terceiros fechar o
   código do cliente e redistribuir sem devolver nada — o oposto do que
   copyleft garantiria. Adicionada às Consequências.
2. **Fundamentação invertida:** a revisão 2 apoiava a decisão
   principalmente em evitar o conflito GPL×App Store — que descansa num
   precedente de 2010 (FSF x Apple, GNU Go) que a própria seção "Não
   verificado" já listava como não confirmado hoje. Decisão apoiada em
   fato não verificado como razão principal é fundamentação fraca. O peso
   principal passa para um motivo que não depende disso: não herdar
   dependência de manutenção de um repositório de terceiro. O conflito
   GPL×App Store continua registrado, mas como bônus, não como pilar.
3. **Clean room decidido, não mais "detalhe de implementação".** E um
   vazamento fechado: `docs/recon/opennutritracker.md` foi escrita **lendo
   o código-fonte** do OpenNutriTracker (Ciclo 4 desta sessão — clone
   aberto, `pubspec.yaml`, árvore de `lib/` inspecionada). Tratá-la como
   referência limpa de "o quê" — como a revisão anterior desta ADR e
   `.claude/rules/port.md` faziam — contamina a cadeia: quem lê a ficha
   está a um passo de quem leu o código. `docs/specs/nutricao.md` passa a
   ser a **única** fonte permitida para a implementação. A ficha continua
   valendo para o que já valia desde a Fase 0 — licença, stack, decisão de
   ADR-5/ADR-1 — só não vale mais como referência de comportamento para
   quem implementa.

## Contexto

(sem alteração de fundo da revisão 2) `docs/adr/000-pendentes.md` marca
esta ADR como bloqueando "tudo". ADR-1 (aceita): Flutter shell, MLC LLM e
OpenTracks por WRAP, ambos Apache-2.0. ADR-4/ADR-4a (propostas): wger e
Gadgetbridge federados, fora do cliente. OpenNutriTracker (GPL-3.0) é o
único dos 7 cuja licença é copyleft **e** que `docs/VIABILITY.md`
recomenda dentro do núcleo grátis do MVP — o único ponto onde "linkar ou
reimplementar" muda a licença do cliente inteiro.

## Opções consideradas

1. **Cliente GPL-3.0, via VENDOR/link do código do OpenNutriTracker.**
   Mesmo processo/binário Dart AOT — linkagem de verdade, o app inteiro
   vira GPL-3.0 por força da própria licença.
2. **Cliente GPL-3.0, servidor autoral proprietário.** Continua rejeitada
   — contradiz "Código aberto, copyleft aceito" (`STATUS.md`) sem motivo
   novo; aqui a regra 3 do `CLAUDE.md` se aplica de verdade.
3. **Cliente Apache-2.0, via PORT (reimplementação) do OpenNutriTracker,
   com clean room obrigatório.** O Frankstein escreve seu próprio módulo
   de nutrição a partir de `docs/specs/nutricao.md` — nunca do código nem
   da ficha de reconhecimento. Nenhuma licença copyleft entra no cliente:
   MLC LLM e OpenTracks já são Apache-2.0, o cliente inteiro pode ser
   Apache-2.0.

## A pergunta que a revisão pediu, respondida direto (fundamentação corrigida)

**O OpenNutriTracker entra por cópia de código ou por PORT?**

**PORT, com clean room obrigatório.** Recomendo a opção 3. Motivo, **em
ordem de peso corrigida** — o principal agora é o que não depende de
nenhum fato não verificado:

1. **Motivo principal: não herdar dependência de manutenção de um
   repositório de terceiro.** Se o cliente linka o código do
   OpenNutriTracker, o Frankstein herda o ritmo de release dele, corre o
   risco de mudança incompatível a cada atualização upstream (ou fica
   preso a um commit congelado, perdendo correções), e amarra a evolução
   do módulo de nutrição — que precisa se integrar ao cérebro
   (`.claude/rules/brain.md`, ferramenta `log_meal` já esboçada em
   `docs/ARQUITETURA.md:47-63`) e à UI própria do Frankstein — ao ritmo e
   às decisões de design de um app standalone de terceiros, que não foi
   desenhado para isso. PORT devolve controle total do módulo ao
   Frankstein, sem depender de nada externo continuar existindo,
   mantendo-se compatível, ou aceitando PRs. **Este motivo vale
   independente de qualquer questão de licença de loja.**
2. Apache-2.0 no cliente **continua sendo código aberto** — aberto ≠
   copyleft, distinção já registrada. Não é escolha "menos aberta".
3. `docs/adr/009-gps.md` (aceita) já usou PORT para o equivalente iOS do
   OpenTracks — padrão já aceito neste projeto.
4. **Bônus, não fundamento principal:** reduz o risco histórico de
   conflito GPL×Termos da App Store (`docs/LICENSE-AUDIT.md`, caso FSF x
   Apple/GNU Go, **2010**). A seção "Não verificado" desta própria ADR já
   lista "se o App Store aceita GPL-3.0 hoje na prática" como não
   confirmado — apoiar a decisão principalmente nisso seria construir
   sobre fato não verificado. Registro como consequência favorável, não
   como razão de decidir.
5. Custo: reimplementar é trabalho real, não grátis — o OpenNutriTracker
   foi escolhido originalmente (`docs/PRODUTO.md`) exatamente para evitar
   esse esforço. Troca de custo de engenharia por controle total do
   módulo (motivo 1) e por redução de risco jurídico (motivo 4, bônus) —
   não decidido de graça.

## Clean room — decidido, não mais detalhe de implementação

**Decisão:** obrigatório. Regras concretas, reforçadas em
`.claude/rules/port.md`:

- Quem (qual sessão, qual pessoa) escreve código em
  `packages/nutrition/**` **não pode ter aberto**, na mesma sessão ou
  em qualquer momento anterior que informe o código que está escrevendo:
  o código-fonte do OpenNutriTracker (`refs/opennutritracker/` ou o
  repositório upstream), **nem `docs/recon/opennutritracker.md`** — pelo
  motivo da seção seguinte.
- **Única fonte permitida para a implementação: `docs/specs/nutricao.md`.**
  Se um comportamento não está lá, não existe até alguém atualizar a
  especificação primeiro — e quem atualiza a especificação também não
  deveria estar simultaneamente implementando a partir do código-fonte
  deles no mesmo fôlego; a barreira só funciona se as duas atividades
  ficam separadas.
- Isso não é uma preferência de estilo. `docs/adr/005-licenciamento-distribuicao.md`
  (esta ADR) e `.claude/rules/port.md` tratam violação como o gatilho que
  derruba a licença Apache-2.0 do cliente automaticamente — ver seção
  seguinte.

**Por que a ficha de reconhecimento sai da lista de fontes permitidas:**
`docs/recon/opennutritracker.md` foi escrita depois de clonar o
repositório e abrir `pubspec.yaml`, a árvore de `lib/`, e (para a ficha
de licença) o `LICENSE` — leitura direta do código-fonte, ainda que
superficial. Tratar essa ficha como referência limpa de "o que o módulo
faz" — o que a revisão anterior desta ADR e a primeira versão de
`.claude/rules/port.md` faziam — quebra a barreira do clean room por
definição: a ficha é, ela mesma, um produto de ter lido o código.
`docs/specs/nutricao.md`, em contraste, foi escrita a partir do
`README.md` público do projeto (texto de divulgação, não lógica de
negócio) — mais perto da linha, mas ainda não perfeitamente limpo (ver
"Não verificado"). É a fonte que fica.

## Consequências

- **Fica mais fácil:** o cliente inteiro pode ser Apache-2.0. Nenhuma
  tensão entre licença do cliente e canal de distribuição. O módulo de
  nutrição evolui no ritmo do Frankstein, integrado ao cérebro e à UI
  próprios, sem depender de decisões de design de um app de terceiros.
- **Fica mais difícil:**
  - Custo de engenharia real de reimplementar em vez de linkar — não
    quantificado.
  - **AGPL no servidor permite que clientes B2B se auto-hospedem e
    deixem de pagar** — servidor autoral AGPL-3.0 por escolha obriga a
    oferecer código-fonte a quem interage pela rede; qualquer
    clínica/academia B2B pode rodar a própria instância sem pagar
    hospedagem ao Frankstein. Tensão real com `docs/MONETIZACAO.md`, não
    resolvida aqui.
  - **Nova — o oposto do risco acima: Apache-2.0 no cliente permite que
    terceiros fechem o código e redistribuam sem devolver nada.**
    Qualquer empresa pode pegar o cliente Apache-2.0 do Frankstein,
    modificar, e lançar uma versão proprietária concorrente — sem
    publicar o que mudou, sem contribuir de volta, sem nem citar a
    origem além do aviso de copyright exigido pela licença. Copyleft
    (GPL) impediria isso especificamente; Apache-2.0, por escolha desta
    ADR, não. É o preço de evitar o copyleft no cliente — registrado
    explicitamente, não escondido atrás do "fica mais fácil".
  - Disciplina de clean room tem custo operacional: quem escreve a
    especificação e quem implementa precisam ser separados na prática, o
    que trava paralelismo (não dá pra uma mesma sessão fazer as duas
    coisas ao mesmo tempo sobre o mesmo trecho).
- **Passa a ser proibido:** copiar/portar código do OpenNutriTracker sob
  pretexto de "PORT"; usar `docs/recon/opennutritracker.md` ou o
  código-fonte deles como referência de implementação — regra verificável
  em `.claude/rules/port.md`.

## Resolução da contradição GPL × App Store (mantida como bônus, não como pilar)

Com o cliente Apache-2.0 (opção 3): MLC LLM + OpenTracks + OpenNutriTracker-PORT
= cliente inteiro Apache-2.0, que nunca teve a cláusula de "sem
restrições adicionais" que colidiu com os Termos da App Store no caso
FSF x Apple de 2010. iOS e App Store continuam no plano. **Mas isto não é
mais o motivo principal da decisão** (ver seção de fundamentação acima) —
é consequência favorável de uma decisão tomada por outro motivo. O
servidor autoral segue AGPL-3.0 por escolha, sem afetar distribuição em
loja (servidor não é distribuído em loja nenhuma).

## Decisão

**Opção 3, com clean room obrigatório.** Cliente Apache-2.0.
OpenNutriTracker por PORT a partir de `docs/specs/nutricao.md`, nunca do
código-fonte nem de `docs/recon/opennutritracker.md`. MLC LLM e
OpenTracks continuam WRAP (ADR-1), Apache-2.0, sem alteração. Servidor
autoral AGPL-3.0 por escolha (ADR-3/ADR-8), sem alteração. wger hospedado
expõe fonte via `/source` (`docs/B2B.md:31-33`), sem alteração.
Distribuição multi-canal conforme ADR-7 (aceita).

**Isto está proposto, não aceito.**

## Não verificado

- ~~Licenças dos 6 submódulos do MLC LLM~~ — resolvido no Ciclo B.
- ~~Direção real do Gadgetbridge no Health Connect~~ — resolvido no
  Ciclo 30, ADR-4a aceita (escrita confirmada via permissão do APK/F-Droid
  + documentação oficial).
- Regras de link de pagamento externo para o Brasil — resolvido pela
  ADR-7 (aceita, revisão 3): regra "estado do plano sim, venda não".
- Texto primário da FSF sobre compatibilidade de licença — só `WebSearch`.
- Custo de engenharia de reimplementar (PORT) o módulo de nutrição.
- **`docs/specs/nutricao.md` não é perfeitamente limpa.** Foi escrita a
  partir do `README.md` do OpenNutriTracker — texto de divulgação
  pública, não lógica de negócio, mas ainda assim conteúdo do repositório
  GPL, lido dentro do clone. É mais perto da linha do clean room do que a
  ficha de reconhecimento (que leu código e configuração de build), mas
  "mais perto da linha" não é "na linha". Se quiser blindar mais: alguém
  que nunca abriu `refs/opennutritracker/` de forma alguma poderia
  reescrever `docs/specs/nutricao.md` a partir da descrição desta ADR e
  de conhecimento geral de apps de diário alimentar, sem tocar no
  repositório — não fiz isso aqui, registro como opção mais conservadora
  não tomada.
