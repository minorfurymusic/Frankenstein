# ADR-1 — Shell do app e estratégia multiplataforma

**Status:** aceito
**Data:** 2026-08-05

## Contexto

`docs/ARQUITETURA.md:6` já desenha "APP SHELL (Flutter) — UI única: chat +
dashboards" no diagrama de camadas, e `.claude/rules/brain.md:2-5` já tem
padrões de path `**/mlc_*.dart` e `**/*brain*.dart` — ou seja, Flutter já é
a suposição de trabalho do projeto, mas nunca foi decidido formalmente por
ADR. As 7 fichas de reconhecimento (`docs/recon/*.md`) trouxeram stacks
confirmadas que testam essa suposição:

| Repositório | Stack confirmada | Compatibilidade com shell Flutter |
|---|---|---|
| OpenNutriTracker | Flutter/Dart | nativa |
| MLC LLM | C++/Python + bindings `android/mlc4j` (Kotlin) e `ios/MLCSwift` (Swift) | bindings feitos para serem chamados de fora, não são Flutter — pedem ponte por platform channel, mas em ambas as plataformas |
| OpenTracks | Android/Java puro (Gradle) | sem equivalente Flutter; só existe caminho Android nativo |
| FoodYou | Kotlin Multiplatform | não é Flutter; overlap funcional com OpenNutriTracker (ver `docs/VIABILITY.md`) |
| Gadgetbridge | Android/Kotlin+Java (não clonado, ficha por leitura de navegador) | recomendação é FEDERATE via Health Connect — não entra no shell de jeito nenhum |
| wger | Python/Django (servidor) | fora do shell, é FEDERATE via REST |
| Fasten Health | Go + Angular (servidor) | fora do shell, é FEDERATE via FHIR |

`docs/ARQUITETURA.md:73-74` já registra que o Gadgetbridge é Android-only e
que o iOS provavelmente cai para HealthKit — mas `docs/PLATFORM-PARITY.md`,
citado ali, **não existe ainda**. O mesmo buraco de paridade se aplica ao
OpenTracks: não há achado de nenhum equivalente Flutter ou multiplataforma
para GPS/corrida entre os 7.

## Opções consideradas

1. **Flutter como shell único**, com módulos nativos Android/iOS
   embutidos via platform channel onde não há equivalente Flutter
   (MLC LLM, OpenTracks no Android). É o que `docs/ARQUITETURA.md` e
   `.claude/rules/brain.md` já pressupõem.
2. **Shells nativos separados** (Kotlin/Compose no Android, Swift/SwiftUI
   no iOS, sem UI compartilhada). Deixaria OpenTracks mais barato de
   integrar no Android (WRAP direto, sem ponte), mas contradiz a "UI
   única" que `docs/ARQUITETURA.md:6` já assume como requisito, e dobra o
   trabalho de UI (duas implementações de cada tela).
3. **Outro framework cross-platform** (React Native, Kotlin Multiplatform
   como shell, etc.). Não avaliei nenhum a fundo neste ciclo — citar como
   opção sem comparação real seria inventar uma análise que não fiz. Só
   registro que ninguém, em nenhum documento lido, propôs isso antes.

## Decisão

**Flutter como shell único** (opção 1) — não é uma decisão nova, é a
formalização do que já está implícito em `docs/ARQUITETURA.md` e
`.claude/rules/brain.md`. Módulos sem equivalente Flutter (MLC LLM via
`mlc4j`/`MLCSwift`, OpenTracks no Android) entram por **WRAP**: platform
channel chamando o código nativo já existente, sem reescrever a lógica.

**Isto está aceito** (2026-08-05, revisão do usuário).

## Consequências

- **Fica mais fácil:** OpenNutriTracker integra quase nativamente (mesma
  stack do shell) — esta ADR não define se isso é por link de código ou
  por reimplementação (PORT); essa escolha específica, com peso de
  licença, foi decidida em `docs/adr/005-licenciamento-distribuicao.md`
  (PORT, cliente Apache-2.0). Os bindings do MLC LLM (`mlc4j`, `MLCSwift`)
  já foram desenhados para serem chamados de fora — o platform channel é
  ponte esperada, não workaround. A UI fica única, como já assumido.
- **Fica mais difícil:**
  - **OpenTracks no iOS não tem caminho.** É Android-only, sem
    equivalente Flutter encontrado nas fichas. Precisa de PORT
    (reimplementar GPS/rota/pace nativamente para iOS) ou de
    `docs/PLATFORM-PARITY.md` documentando a funcionalidade ausente no
    lançamento iOS — nenhuma das duas opções foi decidida aqui.
  - **FoodYou (Kotlin Multiplatform) fica sem rota natural de WRAP** —
    reforça a recomendação de `docs/VIABILITY.md` de preferir
    OpenNutriTracker e tratar FoodYou como HARVEST ou descarte.
  - **Gadgetbridge no iOS não tem Health Connect** — precisa de
    HealthKit como fonte equivalente, ainda não investigado (nenhuma
    ficha cobriu isso, é trabalho novo).
- **Passa a ser proibido:** introduzir uma segunda tecnologia de UI para
  telas do produto principal (ex.: uma tela nativa Compose ou SwiftUI fora
  do platform-channel de dado/sensor) — contradiz a "UI única" já registrada.
  Qualquer plugin Flutter usado nos módulos WRAP segue as mesmas regras de
  licença de `.claude/rules/licenca.md` — nada de plugin que puxe Play
  Services/Firebase/ML Kit por baixo.

## Pendência que esta ADR expõe, não resolve

~~`docs/PLATFORM-PARITY.md`, citado em `docs/ARQUITETURA.md:73`, não
existe.~~ **Criado no Ciclo C** (2026-08-05), consolidando os dois gaps
de iOS encontrados aqui (OpenTracks, Gadgetbridge/Health Connect) — nenhum
dos dois foi resolvido, só documentado num lugar formal.
