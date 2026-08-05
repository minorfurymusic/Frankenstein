# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.

**Fase:** 1 concluída (11/11 ADRs registradas, 1 aceita + 10 propostas) →
**aguardando você** para revisar as propostas antes da Fase 2 começar.
**Ciclo atual:** 19 (último desta sequência autônoma)
**Próximo objetivo, quando você confirmar:** revisão humana das 10 ADRs
propostas — nenhum código de aplicativo começa antes disso. `CLAUDE.md`
ainda diz "Fase 0... Nenhum código de aplicativo ainda" e eu não mudo isso
sozinho.

## Progresso

| Fase | Item | Status |
|---|---|---|
| 0 | Ficha MLC LLM | pronta (`docs/recon/mlc-llm.md`) |
| 0 | Ficha OpenTracks | pronta (`docs/recon/opentracks.md`) |
| 0 | Ficha Gadgetbridge | pronta (`docs/recon/gadgetbridge.md`) — **ressalva:** produzida fora deste ambiente, por leitura no navegador (codeberg.org bloqueado pelo proxy); sem clone, sem build |
| 0 | Ficha FoodYou | pronta (`docs/recon/foodyou.md`) |
| 0 | Ficha OpenNutriTracker | pronta (`docs/recon/opennutritracker.md`) |
| 0 | Ficha wger | pronta (`docs/recon/wger.md`) |
| 0 | Ficha Fasten Health | pronta (`docs/recon/fasten-health.md`) |
| 0 | docs/LICENSE-AUDIT.md | pronta (`docs/LICENSE-AUDIT.md`) |
| 0 | docs/VIABILITY.md | pronta (`docs/VIABILITY.md`) |
| 1 | ADR-6 (sem anúncios) | **aceito** (`docs/adr/006-sem-anuncios.md`) |
| 1 | ADR-1 (shell/multiplataforma) | **proposto** (`docs/adr/001-shell-multiplataforma.md`) |
| 1 | ADR-9 (GPS) | **proposto** (`docs/adr/009-gps.md`) |
| 1 | ADR-10 (substitutos livres) | **proposto** (`docs/adr/010-substitutos-livres.md`) |
| 1 | ADR-3 (fonte da verdade/sync) | **proposto** (`docs/adr/003-fonte-verdade-sync.md`) |
| 1 | ADR-4 (wger/Fasten) | **proposto** (`docs/adr/004-wger-fasten.md`) |
| 1 | ADR-4a (Gadgetbridge) | **proposto** (`docs/adr/004a-gadgetbridge.md`) |
| 1 | ADR-2 (modelo LLM) | **proposto** (`docs/adr/002-modelo-llm.md`) |
| 1 | ADR-7 (canais/pagamento) | **proposto** (`docs/adr/007-canais-distribuicao-pagamento.md`) |
| 1 | ADR-8 (multi-tenant B2B/consentimento) | **proposto** (`docs/adr/008-multitenant-b2b-consentimento.md`) |
| 1 | ADR-5 (licenciamento) | **proposto** (`docs/adr/005-licenciamento-distribuicao.md`) — sintetiza ADR-1/4/4a/7/10 |
| 1 | **11/11 ADRs registradas** | 1 aceita (ADR-6), 10 propostas — nenhuma decidida sozinha |

## Decisões já tomadas (não reabrir sem motivo novo)

- Código aberto, copyleft aceito.
- **Sem anúncios em nenhuma superfície.** Sistema de anúncios foi cancelado.
- Offline-first: a IA roda no aparelho do usuário.
- Grátis = tudo que roda no aparelho. Pago = tudo que consome servidor.
- Monetização: assinatura R$20/US$10 + B2B para profissionais de saúde.
- Escopo inclui módulo de academia (planos, treino, corrida/caminhada com GPS)
  e compartilhamento social (Instagram, TikTok, Facebook).

## Débito técnico

- Licenças dos 6 submódulos de `3rdparty/` do MLC LLM (`argparse`,
  `tokenizers-cpp`, `googletest`, `tvm`/`relax`, `stb`, `xgrammar`) não
  avaliadas — clone raso não trouxe o conteúdo. Bloqueia fechamento do ADR-5
  para este repositório.

## Histórico de ciclos

- **Ciclo 0 — organizar estrutura de diretórios do kit inicial.** O kit havia
  sido desempacotado com todos os arquivos soltos na raiz do repositório, sem
  a estrutura que `CLAUDE.md`/`COMECE-AQUI.md` pressupõem. Movidos para
  `docs/`, `docs/adr/`, `docs/recon/`, `.claude/rules/`, `.claude/commands/`
  e `scripts/`. Adicionado `.gitignore` (ausente). Nenhuma ficha de
  reconhecimento foi criada; ciclo 1 (`docs/recon/mlc-llm.md`) continua
  pendente.
- **Ciclo 0.6 — alinhar troca Flutter Steps Tracker → OpenTracks.** O papel de
  "corrida, caminhada e GPS" passou de Flutter Steps Tracker para OpenTracks
  em `docs/PRODUTO.md` e nesta tabela de progresso. `scripts/clone-refs.sh`:
  entrada renomeada para `opentracks` (minúsculas), comentário de cabeçalho
  atualizado, clone de um repositório não aborta mais os demais (erros
  acumulados e resumidos no fim, `exit 1` se algum falhar), hash curto do
  HEAD impresso após cada clone bem-sucedido. Registrado em `docs/PRODUTO.md`
  que o pedômetro do celular não vem de nenhum dos 7 — é código próprio.
  Clone ainda não executado; licença do OpenTracks (permissiva vs. copyleft)
  segue não verificada até a ficha de reconhecimento.
- **Ciclo 1 — ficha de reconhecimento do MLC LLM.** Criado
  `docs/recon/mlc-llm.md`: commit `2f78caa4`, licença Apache-2.0 lida
  literalmente de `LICENSE`/`NOTICE`. Build não tentado (submódulos
  `3rdparty/` vazios por clone raso; build real exige TVM + LLVM + backend
  de GPU, fora de escopo). Achado: `docs/recon/_MODELO.md` é o template de
  ADR, não de ficha — registrado em "Débito técnico".
- **Ciclo 2 — ficha de reconhecimento do OpenTracks.** Criado
  `docs/recon/opentracks.md`: commit `3c23a9f5`, licença Apache-2.0
  (permissiva pura — único caso assim no conjunto até agora, relevante para
  ADR-5). Stack confirmada: Android/Java puro (não Flutter). Build
  tentado (`./gradlew tasks`): Gradle 9.0.0 baixou ok, falhou resolvendo o
  Android Gradle Plugin — `dl.google.com` bloqueado pelo proxy do ambiente
  (403), e não há Android SDK instalado.
- **Ciclo 3 — ficha de reconhecimento do FoodYou.** Criado
  `docs/recon/foodyou.md`: commit `00637df9`, licença GPL-3.0 lida
  literalmente de `LICENSE`. Stack real é Kotlin Multiplatform (600 `.kt`),
  não "Android/Compose" como `docs/PRODUTO.md` descrevia — não corrigido
  neste ciclo, anotado para o próximo que tocar aquele arquivo. Build
  tentado (`./gradlew tasks`): mesma causa raiz do OpenTracks —
  `dl.google.com` bloqueado pelo proxy, plugin `com.android.application`
  não resolvido.
- **Ciclo 4 — ficha de reconhecimento do OpenNutriTracker.** Criado
  `docs/recon/opennutritracker.md`: commit `9ab14fe3`, licença GPL-3.0
  lida literalmente de `LICENSE`, bate com o badge do README. Stack
  confirmada: Flutter/Dart, 451 arquivos `.dart` — único Flutter confirmado
  entre os 5 avaliados até agora. Build não tentado: `flutter`/`dart` não
  estão instalados neste ambiente.
- **Ciclo 5 — ficha de reconhecimento do wger.** Criado `docs/recon/wger.md`:
  commit `b1714bc5`, licença AGPL-3.0 lida literalmente de `LICENSE.txt` —
  regime mais restritivo confirmado até agora (cobre uso via rede, não só
  distribuição; relevante se `docs/B2B.md` previr wger hospedado).
  Divergência registrada: fontes estáticas em
  `wger/core/static/fonts/LICENSE.txt` são Apache-2.0; `licenses.json` não
  é licença do repo, é catálogo de licenças de conteúdo (exercícios) do
  próprio produto. Build tentado: `uv sync --python 3.12` instalou tudo
  sem erro; `manage.py check` parou por falta de `DJANGO_DB_ENGINE`
  (configuração de ambiente ausente, não defeito de build).
- **Ciclo 6 — ficha de reconhecimento do Fasten Health.** Criado
  `docs/recon/fasten-health.md`: commit `36d92446`, licença GPL-3.0 lida
  literalmente de `LICENSE.md`. Nuance registrada: "Fasten Connect" é
  produto proprietário separado, fora deste repositório e fora das 7.
  Stack: Go (backend) + Angular 14 (frontend). Build tentado (`go build
  ./...`): maioria das dependências resolvida via `proxy.golang.org`, mas
  falhou em `fasten-sources@v0.6.25` — módulo não publicado em proxy,
  precisa de `git ls-remote` direto no GitHub, bloqueado pela política de
  autenticação/rede do ambiente. Frontend Angular não testado neste ciclo.
  **As 6 fichas planejadas estão prontas.** Gadgetbridge seguia BLOQUEADA
  (codeberg.org barrado pelo proxy) e não contava para as 7 — por isso
  `docs/LICENSE-AUDIT.md` não foi escrito neste ciclo.
- **Ciclo 7 (prep) — ficha do Gadgetbridge fora do ambiente.** Criado
  `docs/recon/gadgetbridge.md` com conteúdo produzido fora deste ambiente,
  por leitura no navegador (LICENSE, README, `app/build.gradle`) — sem
  clone, sem build, porque `codeberg.org` continua bloqueado pelo proxy
  daqui. Commit avaliado `24ab57aa32`. Licença **AGPL-3.0**, a mais
  restritiva do conjunto, com licenças divergentes por subdiretório
  (OsmAnd GPLv3, Bouncy Castle MIT, nQuant Apache, Concentus BSD-3,
  greenDAO GPLv3, SearchPreference MIT). Recomendação registrada na ficha:
  FEDERATE via Android Health Connect, não WRAP — decisão de licença e de
  manutenção, não deste ciclo (fica para ADR-4/ADR-5). Ficha marcada
  PRONTA com a ressalva de que não houve clone nem build; nenhuma
  afirmação técnica dela foi verificada por execução.
- **Ciclo 7 — `docs/LICENSE-AUDIT.md`.** Acrescentado ADR-4a a
  `docs/adr/000-pendentes.md` (Gadgetbridge: FEDERATE via Health Connect ou
  fork sob AGPL?). Investigação em `gadgetbridge.org`: bloqueado pelo proxy
  deste ambiente (mesmo padrão do codeberg.org, ao contrário do assumido);
  achado via `WebSearch` (duas fontes convergentes) registrado em
  `docs/recon/gadgetbridge.md`: Gadgetbridge **escreve** no Health Connect,
  com ressalva de que a fonte é busca indexada, não leitura direta.
  Criado `docs/LICENSE-AUDIT.md`: matriz das 7 licenças com sublicenças por
  subdiretório, e os dois cenários pedidos (A: tudo linkado — resultado
  AGPL-3.0, obriga `/source` no painel B2B, App Store é risco histórico não
  resolvido; B: Gadgetbridge/wger/Fasten federados — cliente ainda
  GPL-3.0 por causa de FoodYou/OpenNutriTracker, obrigação de fonte do B2B
  sobre o wger é conservadoramente já coberta por `docs/B2B.md:31-33`, mas
  se estende ao resto do painel B2B é interpretação legal em aberto, não
  fato verificável — marcado como tal). `gnu.org/licenses/*` bloqueou
  `WebFetch` (403 do próprio site, não do proxy); afirmações de
  compatibilidade de licença vêm de `WebSearch`, não de leitura primária —
  registrado como ressalva de método no próprio documento.

> A partir daqui a sessão está rodando autônoma (loop dinâmico), autorizada
> pelo usuário a decidir sozinha o que for rotineiro/procedural até
> 05:00 America/Sao_Paulo de 2026-08-05, mas mantendo os PORTÕES do
> CLAUDE.md (licença, custo, arquitetura, UX, dado de saúde): nesses
> pontos, ADRs entram como "proposto", nunca "aceito", sem confirmação.

- **Ciclo 8 — `docs/VIABILITY.md`.** Síntese das 7 fichas + `LICENSE-AUDIT.md`
  em recomendações de MVP por repositório (nenhuma marcada como decisão
  final). Achado que fica para o usuário decidir, não decidido aqui:
  FoodYou e OpenNutriTracker se sobrepõem (os dois são diário
  alimentar/macros) — recomendação é usar OpenNutriTracker no MVP e tratar
  FoodYou como HARVEST opcional ou descarte, mas `docs/PRODUTO.md` não foi
  editado para refletir isso. Risco de produto registrado: o item 3 da
  Definição de Pronto (wearable) depende do usuário ter o Gadgetbridge (ou
  similar) instalado à parte, já que a rota recomendada é FEDERATE via
  Health Connect, não embutir o código. wger e Fasten confirmados como
  pós-MVP (F13), federados, consistente com `docs/ARQUITETURA.md` e
  `docs/MONETIZACAO.md`.

> O loop dinâmico (`ScheduleWakeup`) agendado ao fim do Ciclo 8 não
> continuou sozinho — nenhum commit novo apareceu entre 2026-08-04T23:39Z e
> a checagem do usuário em 2026-08-05T09:03Z (06:03 em São Paulo, já depois
> das 05:00 combinadas). Causa não determinada de dentro da sessão — não
> invento explicação. A partir do Ciclo 9 a continuação é conduzida com o
> usuário presente na conversa, não por agendamento.

- **Ciclo 9 — consertar `docs/recon/_MODELO.md` e formalizar ADR-6.**
  `docs/recon/_MODELO.md` (que continha o template de ADR, débito técnico
  do Ciclo 1) movido para `docs/adr/_MODELO.md`, onde pertence. Escrito um
  template correto de ficha de repositório em `docs/recon/_MODELO.md`,
  refletindo a estrutura já usada nas 7 fichas prontas. `docs/adr/006-sem-anuncios.md`
  criado com **Status: aceito** — não é decisão nova, só formaliza o que já
  estava em `CLAUDE.md`, `STATUS.md` ("Decisões já tomadas"),
  `docs/MONETIZACAO.md:3-4` e `.claude/rules/monetizacao.md:12`, e cita o
  motivo de licença confirmado em `docs/LICENSE-AUDIT.md` (4 dos 7
  repositórios são copyleft, incompatível com SDK de anúncio proprietário).
  `docs/adr/000-pendentes.md` atualizado. Fase 0 declarada concluída — as 7
  fichas, `LICENSE-AUDIT.md` e `VIABILITY.md` estão prontos.
- **Ciclo 10 — ADR-1, proposto.** `docs/adr/001-shell-multiplataforma.md`:
  formaliza Flutter como shell único (já implícito em
  `docs/ARQUITETURA.md:6` e `.claude/rules/brain.md:2-5`, não decisão
  nova). Tabela de compatibilidade por repositório a partir das 7 fichas:
  OpenNutriTracker nativo, MLC LLM e OpenTracks via WRAP/platform channel,
  FoodYou sem rota natural (reforça `docs/VIABILITY.md`), Gadgetbridge/wger/
  Fasten fora do shell (federados). Dois gaps de iOS expostos e não
  resolvidos: OpenTracks (Android-only, sem equivalente Flutter) e
  Gadgetbridge/Health Connect (não existe no iOS, precisa HealthKit,
  não investigado). Proponho `docs/PLATFORM-PARITY.md` como ciclo futuro
  para registrar isso — não criado agora. **Status: proposto**, não aceito
  — é portão de arquitetura.
- **Ciclo 11 — ADR-9, proposto.** `docs/adr/009-gps.md`: testa as regras
  já escritas em `.claude/rules/activity.md` contra a ficha do OpenTracks
  e a ADR-1 (WRAP no Android via platform channel, PORT nativo no iOS).
  Regras técnicas mantidas sem alteração (precisão 20 m, gravação
  incremental, teto de bateria 8%/h, ofuscação de 300 m). Pendências
  expostas: `docs/PERF.md` não existe, comportamento de background
  location no iOS não investigado. **Status: proposto** — dado de
  saúde/localização é portão explícito do `CLAUDE.md`.
- **Ciclo 12 — ADR-10, proposto.** `docs/adr/010-substitutos-livres.md`:
  formaliza a lista já existente em `.claude/rules/licenca.md`
  (ZXing/Tesseract/MapLibre-osmdroid/notificação local/share sheet nativo).
  Registrado honestamente o que **não** foi verificado: só a ficha do
  Gadgetbridge checou ausência explícita de Firebase/Play Services/SDK de
  anúncio; as outras 6 não tiveram auditoria de dependência transitiva
  contra essa lista (MLC LLM/OpenTracks/FoodYou nem build completo
  tiveram). Proposto um ciclo de auditoria de dependência antes da Fase 2.
- **Ciclo 13 — ADR-3, proposto.** `docs/adr/003-fonte-verdade-sync.md`:
  SQLite local continua fonte de verdade mesmo com sync ativado (Premium);
  servidor é relay de replicação do log de eventos, nunca autoridade —
  compatível com o degrau GRÁTIS ser sem conta/sem servidor
  (`docs/MONETIZACAO.md`). Reaproveita o modelo append-only/dedup já
  decidido em `docs/ARQUITETURA.md` em vez de propor um novo. Não
  verificado, registrado como pendência: conflito de correções
  concorrentes entre dois aparelhos offline; custo de servidor do relay
  (não li `docs/CUSTOS.md` neste ciclo, fora da área tocada).
- **Ciclo 14 — ADR-4, proposto.** `docs/adr/004-wger-fasten.md`: achado —
  o módulo próprio "Academia" (`docs/PRODUTO.md:27-30`, escrito do zero) se
  sobrepõe ao papel do wger, mesmo padrão de redundância que o Ciclo 8
  achou entre FoodYou/OpenNutriTracker. Decisão proposta: wger opcional
  (catálogo estendido/B2B, não substitui a Academia própria), Fasten
  opcional (sem substituto próprio, função exclusiva de prontuário B2B).
  Nenhum dos dois obrigatório para o MVP. Não verificado: se a API do wger
  permite federar só o catálogo sem hospedar o app inteiro; UX de dois
  sistemas de treino coexistindo, deixado para ciclo de UX.
- **Ciclo 15 — ADR-4a formalizada.** `docs/adr/004a-gadgetbridge.md`:
  propõe FEDERATE via Health Connect, citando o achado do Ciclo 7
  (Gadgetbridge escreve no Health Connect). **Condição explícita para
  aceitar, não só para propor:** a fonte é busca indexada, não leitura
  direta do manifesto/código — antes de F9 depender disso, confirmar lendo
  o `AndroidManifest.xml`/código de sync direto, fora deste ambiente.
- **Ciclo 16 — ADR-2, proposto.** `docs/adr/002-modelo-llm.md`: formaliza
  a especificação já detalhada em `docs/OFFLINE-IA.md` (perfis A/B/C,
  RAM/modelo/download, regras operacionais) como decisão, usando MLC LLM
  via `mlc4j`/`MLCSwift` (WRAP, ADR-1). Nenhum número de RAM/desempenho foi
  medido de verdade — build do MLC LLM nunca tentado (Ciclo 1). Condicionada
  a ADR-1 e parcialmente a ADR-5 (licenças de submódulo do MLC LLM ainda
  pendentes).
- **Ciclo 17 — ADR-7, proposto.** `docs/adr/007-canais-distribuicao-pagamento.md`:
  `docs/MONETIZACAO.md:56` pedia para confirmar regras vigentes das lojas
  e citar fonte — pesquisei via `WebSearch`. Achado: Google Play e Apple
  App Store abriram checkout externo por decisão judicial em 2026 (EUA/UK/EEE
  confirmado; Brasil está no programa de billing alternativo mais antigo,
  mas a onda de link externo específica só tem prazo confirmado até
  09/2027 numa das fontes; Apple só confirmado para EUA/UE, não Brasil).
  Decisão proposta: Web como canal preferencial de pagamento, mas o uso de
  link externo dentro do fluxo da loja só entra quando confirmado para o
  Brasil especificamente — não por suposição. Ressalva de método: só
  `WebSearch`, não leitura primária da documentação oficial.
- **Ciclo 18 — ADR-8, proposto.** `docs/adr/008-multitenant-b2b-consentimento.md`:
  formaliza o modelo Organization/Seat/CareLink já especificado em
  `docs/B2B.md`, conectado à ADR-3 (CareLink concede escopo sobre o mesmo
  HealthEvent log, não duplica dado). Lacuna técnica exposta e não
  decidida: isolamento de dados entre Organizations (banco separado vs.
  escopo compartilhado por organization_id) — falta dado de custo/escala.
- **Ciclo 19 — ADR-5, proposto, e Fase 1 encerrada.**
  `docs/adr/005-licenciamento-distribuicao.md` sintetiza ADR-1/4/4a/7/10:
  cliente GPL-3.0 (forçado por OpenNutriTracker linkado via WRAP, ADR-1),
  componentes de servidor autorais AGPL-3.0 **por escolha de princípio**
  ("copyleft aceito" já em `STATUS.md`), não por obrigação legal estrita
  na configuração federada (wger/Fasten opcionais, ADR-4). Distribuição
  multi-canal conforme ADR-7. `docs/adr/000-pendentes.md` reescrito como
  índice das 11 ADRs (10 propostas + ADR-6 aceita), com link para cada
  arquivo. **Fase 1 concluída.** Fase 2 (código de aplicativo) não começa
  sozinha — `CLAUDE.md` ainda declara Fase 0/nenhum código, e as 10 ADRs
  propostas precisam da sua revisão antes de qualquer uma virar "aceita".
