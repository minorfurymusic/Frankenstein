# Ficha de reconhecimento — Gadgetbridge

> Método: leitura via navegador (LICENSE, README.md, app/build.gradle) + página do
> repositório. **Não houve clone nem build.** O ambiente remoto do Claude Code tem
> `codeberg.org` bloqueado pelo proxy.

## Identificação
- URL: https://codeberg.org/Freeyourgadget/Gadgetbridge
- Commit avaliado: `24ab57aa32` — "Add Voice notifications for WF-1000XM4"
- Data do último commit: ~8 horas antes da leitura (04/08/2026)
- Versão declarada: `versionName 0.92.2`, `versionCode 251`
- Atividade: **muito vivo** — 16.839 commits, 249 tags, 135 branches, 1.3k issues
  abertas, 1.8k estrelas, 609 forks, 227 MiB
- Atenção: o espelho em github.com/Freeyourgadget/Gadgetbridge está **obsoleto**.
  O próprio README aponta o Codeberg como host oficial.

## Licença

**AGPL-3.0** (GNU Affero General Public License, versão 3, 19/11/2007), lida
literalmente do arquivo `LICENSE`.

O README traz uma seção "Code Licenses" com **licenças distintas por subdiretório**:

| Caminho | Origem | Licença |
|---|---|---|
| (todo o resto) | Gadgetbridge | **AGPLv3** |
| `app/src/main/java/net/osmand/`, `app/src/main/aidl/net/osmand/` | OsmAnd | GPLv3 |
| `app/src/main/java/org/bouncycastle` | Bouncy Castle | MIT |
| `app/src/main/java/com/android/nQuant` | nQuant.android | Apache |
| `app/src/main/java/org/concentus` | Concentus | BSD-3 |
| `GBDaoGenerator/src/de/greenrobot` | greenDAO (fork do projeto) | GPLv3 |
| `.../util/SearchPreferenceHighlighter.java` | SearchPreference | MIT |

**Consequência:** a AGPL-3.0 governa o conjunto. Qualquer trabalho que **linke ou
combine** código do Gadgetbridge fica sob AGPL-3.0. As sublicenças permissivas
(MIT, Apache, BSD-3) não afrouxam isso; a GPLv3 do OsmAnd e do greenDAO é
compatível com a AGPLv3 (a própria AGPL §13 autoriza a combinação), mas não a
enfraquece.

## Técnico
- Linguagens: Java + Kotlin. Gradle em DSL Groovy.
- Toolchain: Java 21 (`toolchain.languageVersion`), `jvmTarget = JVM_17`,
  source/target compatibility 17.
- SDK: `compileSdk 36` (minor 1), `buildToolsVersion 36.1.0`, `targetSdk 34`,
  `minSdk 23` (Android 6.0).
- Namespace/applicationId: `nodomain.freeyourgadget.gadgetbridge`
- Sabores: `mainline` (padrão) e `banglejs`.
- Tipos de build: `release`, `nightly`, `nopebble` — todos com minify.
- **`buildConfigField "boolean", "INTERNET_ACCESS", "false"` no sabor mainline.**
  O app é compilado sem acesso à internet por decisão de arquitetura. O sabor
  `banglejs` inverte isso para `true`.
- **O build depende de geração de código e do próprio git:**
  `preBuild.dependsOn(":GBDaoGenerator:genSources")`,
  `preBuild.dependsOn(":FitCodeGenerator:genFit")`,
  `preBuild.dependsOn(tasks.buildGitChangelog)` — o changelog é montado a partir de
  `git log`, e o `versionCode` a partir de `git rev-list HEAD --count`.
  **Copiar arquivos soltos não produz um build funcional.**
- Dependências relevantes: greenDAO (ORM/entidades), protobuf-lite, mapsforge
  (mapas), MPAndroidChart, okhttp, msgpack, cbor, logback-android, Nordic DFU
  (firmware), androidsvg, jsoup, guava, **androidx.health.connect.client**.
- **Nenhum Firebase, Play Services, SDK de anúncio ou rastreador.** Coerente com a
  distribuição via F-Droid.
- Compila hoje? **NÃO TENTADO** — não houve clone. Não afirmar nada sobre build.

## Plataformas
**Android apenas.** Sem iOS, sem desktop. `minSdk 23` cobre praticamente todo o
parque brasileiro em uso.

## Superfície reaproveitável
- **A joia:** as implementações de protocolo BLE por fabricante (Amazfit/Mi Band,
  Pebble, Fossil, Casio, Garmin, Huawei, Bangle.js, Sony, dezenas de outros).
  Reescrever isso é inviável — é a razão de o projeto ter 16 mil commits.
- Modelo de dados de atividade via entidades greenDAO.
- Integração com Android Health Connect (direção a confirmar).
- Exportação de log e de dados.

## Recomendação de absorção

**FEDERATE via Android Health Connect** — não WRAP.

Justificativa:
1. **Licença.** Embutir o Gadgetbridge força AGPL-3.0 sobre o Frankstein inteiro.
   Não linkar mantém a decisão do ADR-5 em aberto.
2. **Complexidade de build.** Dois geradores de código, dependência do git no
   build, 227 MiB, sabores e tipos de build próprios. Entra como peso morto no
   monorepo.
3. **Manutenção.** O projeto recebe commits diários e suporte a aparelhos novos o
   tempo todo. Acompanhando por fork, você herda o trabalho de rebase para sempre;
   por Health Connect, você herda as melhorias de graça.
4. **Experiência do usuário.** Quem já usa pulseira provavelmente já tem o
   Gadgetbridge instalado.

Custo estimado: **P** (se o Health Connect resolver) ou **G** (se for preciso fork).

## PERGUNTA QUE DECIDE O RUMO — resolver antes do ADR-4

A dependência `androidx.health.connect.client` prova que existe integração, **não
prova a direção**. É preciso confirmar, na documentação do projeto ou no código:

> O Gadgetbridge **escreve** passos, frequência cardíaca e sono no Health Connect,
> ou apenas **lê** de lá?

- Se **escreve**: rota FEDERATE confirmada. O Frankstein lê o Health Connect e
  nunca toca no código do Gadgetbridge. Melhor cenário do projeto inteiro.
- Se **só lê**: as alternativas passam a ser exportação de arquivo, ou fork com
  toda a carga de AGPL e manutenção. Vira portão de decisão.

## Riscos
1. **Contaminação de licença** ao copiar qualquer trecho sem ADR — inclusive
   "só para consultar como faz". Risco alto, dano permanente.
2. **iOS descoberto.** Gadgetbridge é Android-only; no iOS o módulo de wearable
   não existe. Provável recurso: HealthKit. Registrar em `docs/PLATFORM-PARITY.md`.
3. **Health Connect exige aparelho e versão de Android compatíveis** — pode
   excluir parte do público-alvo do perfil C.
4. **Esta ficha não teve build.** Toda afirmação técnica veio de leitura de
   arquivo, não de execução. Reavaliar quando o clone for possível.
