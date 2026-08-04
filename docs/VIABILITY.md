# Viabilidade — o que entra no MVP, o que fica, o que sai

Síntese das 7 fichas (`docs/recon/*.md`) e de `docs/LICENSE-AUDIT.md`. Isto é
recomendação para embasar ADRs, não decisão de ADR — nada aqui vira
"aceito" sem você confirmar. Onde a recomendação muda o escopo que já está
em `docs/PRODUTO.md`, digo isso explicitamente em vez de editar o escopo
por trás.

## Por repositório

| Repositório | Recomendação | Padrão de absorção sugerido | Licença | Risco principal | Fonte |
|---|---|---|---|---|---|
| MLC LLM | **DENTRO DO MVP** — é o F5, item 4 da Definição de Pronto | WRAP (`mlc4j`/`MLCSwift` como módulo nativo, platform channel) | Apache-2.0 core; **6 submódulos não avaliados** | Build nunca tentado neste reconhecimento; RAM real por perfil A/B/C não medida | `docs/recon/mlc-llm.md` |
| OpenTracks | **DENTRO DO MVP** (Android) — item 6 da Definição de Pronto | WRAP no Android (Java, Gradle, confirmado). iOS **não coberto** — precisa de PORT ou fallback, decisão de ADR-1 | Apache-2.0, permissivo puro | Nenhum de licença. Build não completou aqui (Maven do Google bloqueado neste ambiente, não é falha do projeto) | `docs/recon/opentracks.md` |
| Gadgetbridge | **DENTRO DO MVP, com dependência externa** — item 3 da Definição de Pronto | FEDERATE via Android Health Connect (recomendado na própria ficha) | **AGPL-3.0**, a mais restritiva do conjunto | Ver "Risco de MVP" abaixo — a leitura via Health Connect depende do usuário ter o Gadgetbridge (ou outro escritor de Health Connect) instalado à parte | `docs/recon/gadgetbridge.md` |
| FoodYou | **AVALIAR — sobreposição com OpenNutriTracker** (ver seção própria) | Se mantido: HARVEST (dado/regra, não código) por causa do GPL-3.0 e por ser Kotlin Multiplatform, não Flutter | GPL-3.0 | Sobreposição funcional; stack diferente do que `docs/PRODUTO.md` assumia | `docs/recon/foodyou.md` |
| OpenNutriTracker | **DENTRO DO MVP** — cobre item 2 da Definição de Pronto (código de barras) e é Flutter, mesma stack hipotética do shell | WRAP/VENDOR se o shell for Flutter (ADR-1); PORT se não for | GPL-3.0 | Nenhum específico além do copyleft já aceito | `docs/recon/opennutritracker.md` |
| wger | **DEPOIS DO MVP** — já é F13 em `docs/PRODUTO.md`, e "wger hospedado" já é item Premium em `docs/MONETIZACAO.md` | FEDERATE via REST (já descrito em `docs/ARQUITETURA.md:16`) | **AGPL-3.0** | Painel B2B em servidor precisa da rota `/source` (já decidido, `docs/B2B.md:31-33`) se hospedar o wger | `docs/recon/wger.md` |
| Fasten Health | **DEPOIS DO MVP** — F13, e "conector de prontuário" já é item Premium em `docs/MONETIZACAO.md` | FEDERATE via FHIR (já descrito em `docs/ARQUITETURA.md:16`) | GPL-3.0 | Build não completou aqui (dependência `fasten-sources` não resolvida, bloqueio de rede deste ambiente, não do projeto) | `docs/recon/fasten-health.md` |

## Achado que precisa da sua decisão — FoodYou x OpenNutriTracker

`docs/PRODUTO.md` lista os dois como papéis diferentes ("Diário alimentar
offline" vs. "Calorias, macros, código de barras"), mas as fichas mostram
que os dois **fazem a mesma coisa**: diário alimentar com macros. A
Definição de Pronto (`docs/PRODUTO.md:61`) pede especificamente "registrado
por código de barras" — isso está confirmado no papel do OpenNutriTracker,
não confirmei se o FoodYou também escaneia código de barras (não abri essa
parte do código dele).

**Minha recomendação, não decisão:** usar o OpenNutriTracker como base do
MVP (Flutter — mesma stack hipotética do shell; código de barras já no
papel dele) e tratar o FoodYou como HARVEST opcional mais tarde (ideias de
UX/dados), ou descartar. Isso reduziria os "7 insumos" efetivamente usados
no MVP para 6. Não editei `docs/PRODUTO.md` para refletir isso — é mudança
de escopo, e escopo é decisão sua, não "permissão que você não precisa
tomar".

## Risco de MVP — item 3 (wearable) depende de app externo

A rota recomendada para o Gadgetbridge é FEDERATE via Health Connect —
certa para licença (evita AGPL-3.0 sobre o Frankstein) e para manutenção
(você não acompanha 16 mil commits por conta própria). Mas isso significa
que o item 3 da Definição de Pronto ("Pulseira BLE sincroniza FC e sono
para o Health Data Core") **não é entregável só com código do Frankstein**
— depende do usuário já ter o Gadgetbridge (ou outro app que escreva no
Health Connect) instalado. Não é um problema de licença, é um problema de
produto: o critério de aceite do MVP pode precisar de uma nota
explicando essa dependência, ou de um fluxo de onboarding que oriente a
instalação do Gadgetbridge. Fica registrado aqui; não editei o critério de
aceite em `docs/PRODUTO.md`.

## O que confirma ou corrige `docs/PRODUTO.md`

- OpenTracks: stack confirmada "Android (Java), Gradle" — a ficha já
  sinalizava isso, ainda não aplicado à tabela de `docs/PRODUTO.md`.
- FoodYou: stack real é Kotlin Multiplatform, não "Android/Compose".
- As fases F0-F12 (núcleo do MVP) não usam wger nem Fasten — consistente
  com F13 estar fora delas. Nenhuma fase precisa mudar de posição por
  causa do que as fichas encontraram.
- `docs/PRODUTO.md:68` já lista `docs/LICENSE-AUDIT.md` fechado como
  item 9 da Definição de Pronto — está pronto (`docs/LICENSE-AUDIT.md`,
  Ciclo 7), com as ressalvas que o próprio documento registra (submódulos
  do MLC LLM, e a leitura do Gadgetbridge sem clone).

## ADRs que este ciclo alimenta (nenhum decidido aqui)

- **ADR-1** (shell/multiplataforma): a escolha de shell decide se
  OpenTracks/FoodYou/OpenNutriTracker entram por WRAP (nativo) ou exigem
  ponte — e decide o fallback de iOS para OpenTracks (Android-only) e
  Gadgetbridge (Android-only, Health Connect não existe da mesma forma no
  iOS — `docs/ARQUITETURA.md:73-74` já aponta HealthKit como fallback
  provável).
- **ADR-4** (wger/Fasten obrigatório?): esta ficha reforça que os dois já
  estão posicionados como pós-MVP (F13) e federados, não linkados — o que
  resta decidir é se ficam mesmo obrigatórios no B2B ou viram opcionais.
- **ADR-4a** (Gadgetbridge FEDERATE ou fork): achado do Ciclo 7 (escreve no
  Health Connect, com ressalva de fonte) aponta para FEDERATE. Ainda
  "proposto", não "aceito" — a ressalva de fonte (busca indexada, não
  leitura direta) pesa contra fechar isso sem confirmação de primeira mão.
- **ADR-5** (licenciamento): `docs/LICENSE-AUDIT.md` já dá o mapa dos dois
  cenários. Este documento não adiciona fato novo a ADR-5, só reforça que
  o Cenário B (federação) é o que já está architeturalmente descrito em
  `docs/ARQUITETURA.md`.

## Não verificado

- Se o FoodYou também tem código de barras (não abri essa parte do
  código).
- Onboarding/UX para o caso do usuário não ter Gadgetbridge instalado.
- Estimativa de esforço/tempo por padrão de absorção — não é dado que eu
  tenha, seria inventar.
