# HISTÓRICO — Frankstein

> Log completo de todos os ciclos de execução do projeto, em ordem
> cronológica. Movido para cá em 2026-08-06 (Grupo B de `docs/EFICIENCIA.md`)
> — `STATUS.md` ficou grande demais pra ser lido todo ciclo (624 linhas,
> 89% histórico). `STATUS.md` continua sendo a fonte de verdade do
> **estado atual**; este arquivo é para reconstruir o "porquê" de uma
> decisão antiga, sob demanda — não precisa ser lido no ORIENTAR de todo
> ciclo.

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
- **Ciclo A — hooks de PreToolUse/PostToolUse (`.claude/settings.json` +
  `.claude/hooks/`).** Schema confirmado em code.claude.com/docs/en/hooks
  antes de escrever. Três bloqueios: (1) commit sem `make test` no ciclo;
  (2) dependência da lista proibida de `.claude/rules/licenca.md`, via
  instalador de pacote ou edição de manifesto; (3) escrita em `packages/`
  ou `server/` antes de ADR-1/2/3 aceitas. Testado disparando cada
  condição ao vivo nesta sessão — saída literal de cada bloqueio colada no
  chat. Dois bugs achados e corrigidos durante o teste: regex de fronteira
  não tratava `;` colado (`make test;`), e o schema real de `PostToolUse`
  desta implementação usa `tool_response.stdout/stderr`, não `tool_error`
  como a documentação pública descreve — lógica ajustada para não
  depender de um sinal de sucesso/falha que não existe no input real.
  Commit `707bcda`.
- **Ciclo B — licenças dos 6 submódulos do MLC LLM.**
  `git -C refs/mlc-llm submodule update --init --depth 1`. `tvm` (o maior,
  fork `mlc-ai/relax.git`) ficou quebrado na 1ª tentativa (working tree
  vazio, index com "deleted" em massa — provável interrupção no meio do
  checkout); resolvido isolando e repetindo com `--force`, 2ª tentativa
  limpa. Os outros 5 vieram completos de primeira. Todas as 6 licenças
  lidas literalmente: `argparse` MIT, `googletest` BSD-3-Clause, `stb`
  MIT/Unlicense, `tokenizers-cpp` Apache-2.0, `tvm` Apache-2.0 (+ 6
  licenças vendorizadas em `tvm/licenses/`, todas permissivas também),
  `xgrammar` Apache-2.0. **Não muda a conclusão de `docs/LICENSE-AUDIT.md`**
  — aviso explícito conforme pedido, já que nenhuma é copyleft.
  `docs/recon/mlc-llm.md`, `docs/LICENSE-AUDIT.md`, ADR-2 e ADR-5
  atualizados para remover essa ressalva. Build continua não tentado
  (submódulos agora presentes não muda isso — falta toolchain LLVM/GPU).
- **Ciclo C — `docs/PLATFORM-PARITY.md`.** Consolida os dois gaps de iOS
  já conhecidos (não investiga nada novo): OpenTracks é Android-only, sem
  equivalente Flutter (`docs/recon/opentracks.md`) — no iOS precisa de
  PORT ou de aceitar a ausência do recurso, nenhuma das duas decidida;
  Health Connect não existe no iOS, HealthKit é o candidato óbvio
  (`docs/ARQUITETURA.md:74`) mas **não foi investigado** em nenhum ciclo —
  registrado como "Não verificado", não deduzido. `docs/adr/001-shell-multiplataforma.md`
  atualizada para apontar pro documento em vez de reclamar que ele não
  existe.
- **Ciclo 24 — revisão da ADR-5/ADR-7 e aceite de 5 ADRs.** Três erros
  corrigidos na ADR-5, apontados em revisão:
  (1) a opção de PORT do OpenNutriTracker tinha sido descartada citando a
  regra 3 do `CLAUDE.md` por engano — `docs/VIABILITY.md` decidiu **qual**
  repositório usar (OpenNutriTracker x FoodYou), nunca **como** absorvê-lo;
  reaberta. (2) "aberto" e "copyleft" estavam tratados como sinônimos —
  Apache-2.0 é aberto e não é copyleft; distinção registrada explicitamente
  na ADR. (3) a ADR-5 herdava o conflito GPL-3.0 × Termos da App Store
  enquanto a ADR-7 mantinha a App Store como canal, sem ninguém bater as
  duas pontas — resolvido: OpenNutriTracker entra por **PORT**
  (reimplementação informada, não cópia de código), não por link/VENDOR,
  então o cliente fica **Apache-2.0** inteiro (MLC LLM + OpenTracks já
  eram Apache-2.0) e o conflito de licença com a App Store deixa de
  existir para o cliente — iOS e App Store continuam no plano. Servidor
  autoral segue AGPL-3.0 por escolha (ADR-3/ADR-8), separado do cliente.
  Consequência nova registrada: AGPL no servidor permite que clientes B2B
  se auto-hospedem e deixem de pagar — tensão real com
  `docs/MONETIZACAO.md`, não resolvida, só sinalizada.
  `docs/VIABILITY.md` corrigida (linha do OpenNutriTracker contradizia a
  nova decisão).
  ADR-7 ganhou a **Opção 4** (nenhuma interface de pagamento no app,
  assinatura só no site, app só lê o entitlement assinado) — elimina a
  maior parte da incerteza regulatória sobre o Brasil que a revisão
  anterior carregava; decisão passou a ser Opção 4 agora + Opção 1 como
  evolução condicional, não decidida.
  **ADR-1, 2, 3, 9 e 10 marcadas como aceitas**, por instrução direta —
  linguagem interna de cada uma ("proposto, não aceito") corrigida para
  refletir isso, inclusive cross-references entre elas (ex.: ADR-9 citava
  "ADR-1, ainda proposto"). ADR-4, 4a, 5, 7 e 8 continuam propostas.
- **Ciclo 25 — PORT vira regra verificável.** `docs/specs/nutricao.md`
  criado: especificação funcional do módulo de nutrição (telas, fluxos,
  cálculos, modelo de dados em termos do `HealthEvent` do Frankstein) —
  derivada do `README.md`/documentação pública do OpenNutriTracker
  (features anunciadas) e de `docs/PRODUTO.md`, não do código-fonte Dart
  dele; schema de exportação específico do repositório (nomes de campo
  JSON) explicitamente não copiado. `.claude/rules/port.md` criado, com
  `paths: packages/nutrition/**`: proíbe copiar código/estrutura/nomes/
  comentários do OpenNutriTracker, exige que a implementação parta da
  especificação (não do repo), exige declaração de originalidade no
  cabeçalho de cada arquivo, e reduz `docs/recon/opennutritracker.md` a
  referência de "o quê", nunca de "como". `docs/adr/005-licenciamento-distribuicao.md`
  atualizada com a condição: se essas regras forem violadas, o cliente
  vira GPL-3.0 automaticamente, sem precisar reabrir a ADR.
- **Ciclo 26 — ADR-7 aceita (revisão 3); ADR-5 revisão 3.**
  ADR-7: definido o elo que faltava — entitlement chega ao app por e-mail
  + código de uso único trocado numa única chamada de rede explícita
  (tela "Já assinei", sem preço, sem menção de compra), sem conflitar com
  o "sem cadastro" do degrau grátis (`docs/MONETIZACAO.md:9` — o fluxo só
  existe pra quem já paga). "Proibido qualquer menção" trocado por regra
  utilizável: app pode dizer que um recurso não está no plano atual, sem
  preço/link/onde comprar — registrado como limite conservador escolhido,
  não leitura confirmada de política de loja. **Status: aceito.**
  ADR-5: três correções. (a) Consequência nova: Apache-2.0 permite
  terceiro fechar o cliente e redistribuir sem devolver nada — oposto do
  copyleft. (b) Fundamentação invertida — motivo principal passa a ser
  não herdar dependência de manutenção de repositório de terceiro
  (independente de licença de loja); o conflito GPL×App Store (precedente
  de 2010, já listado como não verificado) vira bônus, não pilar. (c)
  Clean room decidido como obrigatório, não mais "detalhe de
  implementação" — e vazamento fechado: `docs/recon/opennutritracker.md`
  foi escrita lendo código-fonte, então sai da lista de referências
  válidas para implementação; `docs/specs/nutricao.md` vira a única
  fonte. `.claude/rules/port.md` atualizada para reforçar isso, não só a
  ADR em texto. **Status: continua proposto.**
- **Ciclo 27 — Fase 2, esqueleto do monorepo. PARCIAL, bloqueio de
  infraestrutura documentado.** Instalado Flutter 3.35.5 stable (SDK
  baixado de `storage.googleapis.com`, liberado). `app/` criado via
  `flutter create` — `lib/main.dart` reescrito pra tela em branco
  (`Scaffold(body: SizedBox.shrink())`), teste ajustado. 7 pacotes vazios
  em `packages/` (`health_core`, `brain`, `tool_registry`, `activity`,
  `nutrition`, `entitlements`, `share`), cada um espelhando um `.claude/rules/*.md`
  ou camada de `docs/ARQUITETURA.md` já existente — nenhum invenção nova
  de estrutura. `Makefile` reescrito com `build`/`test`/`lint` reais
  (não mais erro proposital). CI em `.github/workflows/ci.yml`.

  **Tentativa de SDK Android:** `dl.google.com` bloqueado pelo proxy
  (mesma causa já registrada nas fichas de OpenTracks/FoodYou na Fase 0),
  confirmado de novo por `curl` direto e pelos pacotes `.deb`
  "instaladores" do Android SDK que existem no apt deste ambiente (também
  falham no mesmo `wget` a `dl.google.com`). Sem `/dev/kvm` — nenhum
  emulador Android roda aqui de jeito nenhum, independente do SDK.
  **Não insisti uma 3ª vez** (regra do `CLAUDE.md`) — três evidências
  independentes já bastam.

  **Prova real, colada literal:**
  ```
  $ make lint
  [... dart analyze de cada um dos 7 pacotes + flutter analyze do app ...]
  No issues found!  (repetido por pacote/app)
  EXIT LINT: 0

  $ make test
  [... dart test de cada um dos 7 pacotes + flutter test do app ...]
  All tests passed!  (repetido por pacote/app)
  EXIT TEST: 0

  $ make build
     [!] No Android SDK found. Try setting the ANDROID_HOME environment variable.
  make: *** [Makefile:10: build] Error 1
  EXIT BUILD: 2
  ```
  Saída completa de cada comando está no chat do ciclo, não resumida aqui.

  **"O app abre":** não no emulador Android (impossível neste sandbox).
  Prova alternativa real: `flutter build linux --debug` compilou de
  verdade, e o binário rodou sob `xvfb-run` (Dart VM service subiu,
  processo ficou ativo até eu matar pelo timeout, sem crash) — evidência
  de que o Flutter/Dart do app está correto, só a plataforma Android
  específica que está bloqueada aqui.

  **Não verificado (na hora):** se `make build`/`make test`/`make lint`
  passam num ambiente com Android SDK de verdade — inferido da
  documentação do runner, não executado ainda. **Resolvido no fechamento
  abaixo.**

  ---

  **Fechamento (mesmo ciclo, depois de checar o CI de verdade):** o
  push deste commit falhou no CI na primeira tentativa (run
  `31053024984`, `conclusion: "failure"`). Log do job
  (`get_job_logs`, job `92464353766`):
  ```
  error - test/health_core_test.dart:1:8 - Target of URI doesn't exist:
  'package:test/test.dart'
  ```
  Causa real: o `Makefile` original nunca rodava `dart pub get`/`flutter
  pub get` — só "funcionava" neste sandbox porque eu já tinha rodado
  `pub get` manualmente em cada pacote antes de testar o Makefile,
  mascarando a falta do passo. Checkout limpo (CI) não tem `.dart_tool/`
  resolvido, então `dart analyze`/`dart test` quebram na primeira linha.

  **Fix, commit `386b711`:** alvo `bootstrap` novo no `Makefile`,
  dependência de `build`/`test`/`lint`, roda `pub get` em todos os 7
  pacotes + `app` antes de qualquer outro passo. Confirmado local
  simulando checkout limpo (removi todos os `.dart_tool/` e rodei `make
  lint`/`make test` de novo — ambos voltaram a passar). CI também ganhou
  um passo pra aceitar as licenças do Android SDK (`yes | flutter doctor
  --android-licenses`), achado do mesmo log (`Some Android licenses not
  accepted` — bloquearia `make build` mesmo com SDK presente).

  **Prova literal do CI verde (dois runs, mesmo commit `386b711`):**
  ```
  Run 31055829550 — branch main
  GET /repos/minorfurymusic/Frankenstein/actions/runs/31055829550
  status: "completed"   conclusion: "success"

  steps (job 92473001242):
    flutter doctor                       success  23:18:33 → 23:18:45
    aceitar licenças do Android SDK      success  23:18:45 → 23:18:46
    lint                                 success  23:18:46 → 23:19:08
    test                                 success  23:19:08 → 23:20:01
    build                                success  23:20:01 → 23:23:08

  Run 31056058975 — branch claude/frankstein-kit-setup-px5suj
  GET /repos/minorfurymusic/Frankenstein/actions/runs/31056058975
  status: "completed"   conclusion: "success"

  steps (job 92473694636):
    flutter doctor                       success  23:22:28 → 23:22:38
    aceitar licenças do Android SDK      success  23:22:38 → 23:22:40
    lint                                 success  23:22:40 → 23:23:02
    test                                 success  23:23:02 → 23:23:56
    build                                success  23:23:56 → 23:27:02
  ```

  **Achado à parte, corrigido neste fechamento:** a branch designada
  `claude/frankstein-kit-setup-px5suj` estava parada no commit `d4348b6`
  (Ciclo 0) — todo o trabalho de Fase 0/1/2 tinha sido empurrado só para
  `main`, violando a instrução de desenvolver na branch designada. Como
  `d4348b6` é ancestral direto de `main` (nenhum histórico divergente),
  corrigido com fast-forward (`git merge --ff-only main`) e push — sem
  reescrever nada, sem perder trabalho.

  **Status final do Ciclo 27: CONCLUÍDO.** Critério de aceite (`make
  build`, `make test`, `make lint` passam, app abre) satisfeito com prova
  literal — em CI real, não neste sandbox (sandbox não tem SDK Android
  nem `/dev/kvm`, limite de ambiente registrado e não insistido pela
  regra dos 3 attempts do `CLAUDE.md`).
- **Ciclo 28 — ler `docs/CUSTOS.md` por completo e revisar a ADR-8.**
  Objetivo único: resolver a pendência explícita deixada na ADR-8
  (Opção 3, isolamento de banco entre `Organization`s) — proibido decidir
  isso sem número de custo/escala na mão, por instrução direta.

  `docs/CUSTOS.md` lido por completo (arquivo inteiro, 51 linhas, sem
  resumir de memória). Fatos usados na decisão: VPS mínima (Hetzner
  CX/CAX) ~EUR 5,50–6,00/mês com 20 TB de banda inclusos
  (`docs/CUSTOS.md:24`); custo de servidor não escala por usuário/tenant,
  escala por tráfego e por item explicitamente listado como "nunca
  grátis" (`docs/CUSTOS.md:14-16`, onde "instância hospedada de
  Fasten/wger" já aparece como exemplo desse padrão); cenário de 1.000
  usuários gratuitos fica em ~US$23–30/mês dominado por Apple+MEI, não
  por infraestrutura (`docs/CUSTOS.md:29-38`).

  `docs/adr/008-multitenant-b2b-consentimento.md` revisado (revisão 1):
  Opção 3 quebrada em 3a (instância dedicada por Organization — custo que
  escala por tenant, categoria já listada como "nunca grátis"), 3b
  (banco compartilhado, só coluna `organization_id`) e 3c (banco
  compartilhado, schema separado por Organization). Decisão: **3c**. O
  argumento não é custo — 3c e 3b custam o mesmo em dinheiro, porque o
  custo de servidor é dominado por tráfego, não por schema — é risco:
  esta é "a combinação mais sensível do projeto" (dado clínico, LGPD,
  terceiro lendo), e um `WHERE organization_id = ?` esquecido é o tipo de
  bug que vaza dado entre clínicas sem sinal visível. Schema separado
  torna essa classe de bug estruturalmente mais difícil de escrever por
  acidente, sem custar mais caro. 3a fica registrado como upgrade futuro
  possível, não padrão — contradiria "web, multi-tenant" já especificado
  em `docs/B2B.md:27`.

  `docs/adr/000-pendentes.md` e `STATUS.md` atualizados para refletir a
  revisão 1. Ao final do ciclo, status ficou como **proposto** — portão
  duplo (LGPD + arquitetura), decisão de aceitar não foi tomada neste
  ciclo. **Atualização (Ciclo 29):** você confirmou explicitamente
  ("Sim, aceita") depois de ver a ADR — status corrigido para **aceito**
  neste arquivo e em `docs/adr/008-multitenant-b2b-consentimento.md` e
  `docs/adr/000-pendentes.md`.

  **Não verificado:** requisito específico da LGPD para retenção/conteúdo
  do log de acesso por terceiro (já registrado como pendência antes desta
  revisão, não mudou); em que ponto de escala 3c deixaria de bastar e um
  cliente exigiria 3a — sem gatilho numérico definido.

  **Débito técnico:** nenhum novo.

- **Ciclo 29 — ADR-8 aceita; sincronizar `main`; tentar confirmação de
  primeira mão da ADR-4a.** Três coisas nesta ordem, por instrução direta.

  **1. `main` sincronizado com a branch designada.** `main` estava um
  commit atrás (`386b711`) da `claude/frankstein-kit-setup-px5suj`
  (`8a34c86`) desde o fechamento do Ciclo 27. `386b711` é ancestral
  direto de `8a34c86` — fast-forward puro (`git merge --ff-only`), sem
  divergência, sem reescrever nada. As duas branches ficaram idênticas em
  `8a34c86`.

  **2. ADR-8 aceita.** Você confirmou explicitamente depois de eu
  perguntar se "Perfeito a ADR8" contava como aceite formal (o projeto
  exige confirmação explícita, "perfeito" sozinho é elogio, não decisão
  registrável). Resposta: "Sim, aceita". `docs/adr/008-multitenant-b2b-consentimento.md`,
  `docs/adr/000-pendentes.md` e `STATUS.md` atualizados — **8/11 ADRs
  aceitas** agora (ADR-1, 2, 3, 6, 7, 8, 9, 10), 3 propostas (ADR-4, 4a, 5).

  **3. Tentativa de confirmação de primeira mão da ADR-4a (Gadgetbridge).**
  Você delegou a escolha entre ADR-4 e ADR-4a — escolhi ADR-4a por
  bloquear a fase mais cedo (F9, contra F13 da ADR-4). A própria ADR-4a
  exige leitura direta do manifesto/código do Gadgetbridge antes de
  aceitar — nunca cumprida (rede bloqueada desde o Ciclo 0). Tentei de
  novo: `codeberg.org`, `gadgetbridge.org` e `f-droid.org` continuam
  bloqueados (`HTTP 403`, `CONNECT tunnel failed`, três domínios
  testados). Achei um mirror no GitHub que **não** está bloqueado
  (`raw.githubusercontent.com`) e li de verdade — prova literal:
  ```
  $ curl raw.githubusercontent.com/.../AndroidManifest.xml | grep -in health
  (nenhum resultado)
  $ curl raw.githubusercontent.com/.../build.gradle | grep -in health
  (nenhum resultado)
  $ curl raw.githubusercontent.com/.../CHANGELOG.md | grep -in "health connect"
  (nenhum resultado, 2480 linhas)
  ```
  Contradiz o achado do Ciclo 7 — até que descobri, pela própria página do
  GitHub, que esse mirror está **arquivado desde 2026-02-24** ("Gadgetbridge
  is now hosted on codeberg.org"). É leitura de primeira mão real, só que
  de um snapshot congelado, não do `master` de hoje. `WebSearch` de novo
  achou algo mais específico que o achado original: PR `#4481` ("Health
  Connect Integration"), issue `#3121`, e um release note "0.89.0: Two big
  new features" — consistente com a feature ter sido mergeada depois do
  arquivamento do mirror, o que explicaria a ausência no snapshot.

  **Status final: ADR-4a continua proposta.** A condição que ela mesma
  exige (leitura direta do código atual) não foi cumprida — mais evidência
  indireta convergente não é a mesma coisa que primeira mão. Registrado
  por completo em `docs/adr/004a-gadgetbridge.md`, seção "Achado (Ciclo 29)".

  **Não verificado:** direção real de escrita do Gadgetbridge no `master`
  atual do codeberg; se/quando a PR `#4481` foi mergeada.

  **Débito técnico:** nenhum novo.

  **Bloqueio:** preciso de você para destravar a ADR-4a — a rede deste
  ambiente não alcança nenhuma das três fontes primárias (codeberg,
  gadgetbridge.org, F-Droid). Se puder colar o `AndroidManifest.xml`
  atual do Gadgetbridge (ou confirmar se a PR `#4481` foi mergeada e
  quando), a ADR sai do impasse. Ou, se preferir, posso seguir para a
  ADR-4 (wger/Fasten) enquanto isso fica em aberto.
- **Ciclo 32 — relatório de eficiência (`docs/EFICIENCIA.md`). Não
  implementa nada.** Objetivo único por instrução direta: medir o custo
  real de contexto do projeto, não estimar.

  Metodologia: script Python lendo o transcript literal desta sessão
  (`/root/.claude/projects/.../c8fc46bd-....jsonl`, 2.414 linhas, 29
  ciclos) — contagem de chamadas de ferramenta, tamanho de resultado por
  chamada, arquivo por arquivo. Nada estimado de memória.

  **Achados principais** (números completos em `docs/EFICIENCIA.md`):
  - `STATUS.md` (624 linhas hoje) é 7,3x maior que `CLAUDE.md` + regras
    que carregam sempre somados (86 linhas). Cresceu de 38 para 624
    linhas em 34 commits, sem teto desenhado. 89% do arquivo é histórico
    de ciclos antigos, só 11% é estado atual.
  - `STATUS.md` foi o arquivo mais lido (31x `Read` + 21x `tail` via
    Bash) e mais editado (96x `Edit`) de toda a sessão, por larga margem.
  - No Ciclo 27, acompanhar o CI via `get_workflow_run`/`list_workflow_runs`
    custou ~154 mil caracteres; `list_workflow_jobs` (mesma informação,
    mais detalhada) teria custado ~12 mil — ~90% de diferença.
  - 21 chamadas Bash `tail` logo depois de `Edit` no mesmo arquivo, no
    mesmo turno — 100% evitável, o `Edit` já garante que a escrita
    funcionou.
  - Investigado e **descartado como problema**: varredura de `refs/`
    (todos os comandos encontrados eram escopados com `-maxdepth`/regex
    específico) e releitura de ADRs (cada releitura correspondeu a uma
    revisão real, em ciclo diferente, não a hábito).

  **Propostas** — 4 no Grupo A (aplico sozinho: preferir
  `list_workflow_jobs` no polling de CI; nunca reler arquivo pós-edit;
  ler `STATUS.md` por partes até o Grupo B ser decidido; suprimir saída
  verbosa de merges grandes) e 1 no Grupo B (mover `## Histórico de
  ciclos` para `docs/HISTORICO.md`, deixando `STATUS.md` só com o estado
  atual — maior economia estimada de todas, mas edita `CLAUDE.md:27`,
  por isso precisa da sua aprovação antes).

  **Nada foi aplicado neste ciclo**, por instrução explícita. Seção
  "Manutenção" acrescentada ao fim de `docs/EFICIENCIA.md`: reler o
  arquivo a cada 5 ciclos, no ORIENTAR, e acrescentar achados novos sem
  apagar os antigos.

  **Não verificado:** se as propostas do Grupo A, uma vez aplicadas,
  realmente produzem a economia estimada aqui — é medição prevista para o
  próximo ciclo (antes/depois), não confirmada ainda.

  **Débito técnico:** nenhum novo.

- **Ciclo 30 (numeração sua — cronologicamente depois do Ciclo 32 nesta
  sessão) — fechar a ADR-4a como aceita.** Objetivo único: registrar a
  confirmação de primeira mão que faltava desde a revisão original,
  trazida por você.

  `docs/adr/004a-gadgetbridge.md` (revisão 2): status **aceito**. Achado
  novo registrado por completo — permissões extraídas do APK publicado do
  Gadgetbridge, via página do F-Droid (`nodomain.freeyourgadget.gadgetbridge`):
  `android.permission.health.WRITE_STEPS`, `WRITE_SLEEP`,
  `WRITE_RESTING_HEART_RATE`, `WRITE_WEIGHT`, `WRITE_VO2_MAX`,
  `WRITE_TOTAL_CALORIES_BURNED`. Documentação oficial
  (`gadgetbridge.org/basics/integrations/health-connect/`) confirma o
  alcance (passos, distância, FC, SpO₂, glicose, VFC, temperatura, FC de
  repouso, sono, peso, VO₂ máx, exercício) e a direção (Gadgetbridge é
  provedor de dado, não consumidor) — recurso da versão 0.89.0, bate com
  o achado indireto do Ciclo 29 (PR `#4481`, release "two big new
  features").

  **Ressalva registrada na própria ADR:** eu não abri `f-droid.org` nem
  `gadgetbridge.org` — tentei nos Ciclos 0 e 29, os três domínios
  primários continuam bloqueados pela rede deste ambiente. A confirmação
  vem de você, fora deste ambiente, do mesmo jeito que
  `docs/recon/gadgetbridge.md` já tinha sido produzida. Registrado assim
  por honestidade de processo (regra 2 do `CLAUDE.md`), não porque a
  evidência seja fraca — permissão declarada no manifesto do APK
  publicado é evidência de primeira mão de verdade, só que de outra
  pessoa, não minha.

  Dois detalhes novos registrados: (1) dado do Health Connect fica no
  aparelho, sem envio a servidor externo nem ao Google — consequência
  nova, coerente com offline-first; (2) Health Connect só é nativo a
  partir do Android 14 — em Android 13 ou anterior o usuário precisa do
  app proprietário da Play Store. Isso foi para `docs/PLATFORM-PARITY.md`
  (Gap 2), **não** para os perfis A/B/C da ADR-2 — aqueles são por RAM
  para o LLM, este é por versão do Android, eixo diferente. Não forcei o
  encaixe; registrei como pendência se você quiser um conceito novo de
  "perfil de dispositivo" que combine os dois eixos.

  `docs/adr/000-pendentes.md` e `STATUS.md` atualizados — **9/11 ADRs
  aceitas** agora (ADR-1, 2, 3, 4a, 6, 7, 8, 9, 10), 2 propostas
  (ADR-4, 5).

  **Não verificado:** equivalente iOS (HealthKit) — fora do escopo desta
  ADR, já registrado como gap aberto em `docs/PLATFORM-PARITY.md`.

  **Débito técnico:** nenhum novo.

- **Ciclo 31 (numeração sua) — ADR-4 (wger/Fasten), revisando.** Objetivo
  único: fechar ou revisar. Conferi as citações de linha já existentes na
  ADR (`docs/PRODUTO.md`, `docs/MONETIZACAO.md`, `docs/ARQUITETURA.md`) —
  todas batem com o conteúdo atual, sem deriva.

  A decisão em si (wger opcional/catálogo estendido, não substitui
  Academia própria; Fasten opcional, sem substituto) já estava bem
  fundamentada. O que faltava: a consequência de licença citava
  `docs/LICENSE-AUDIT.md` genericamente, sem apontar que o documento já
  tem uma seção específica ("Cenário B — federados por rede/app separado")
  cobrindo exatamente esse caso. Revisão 1 cita essa seção linha a linha
  e soma com a decisão da ADR-5 (revisão 3): o cliente Frankstein é
  Apache-2.0 — nenhum módulo o empurra para GPL/AGPL (OpenNutriTracker
  entra por PORT, FoodYou nunca foi adotado). Acrescentada também a
  consequência do `/source` route (`docs/B2B.md:31-33`) já cobrir a
  obrigação AGPL do wger hospedado, caso vire produto Premium.

  **Erro cometido e corrigido no mesmo ciclo, antes de qualquer commit:**
  escrevi um rascunho intermediário dizendo que "o cliente seria GPL-3.0
  por causa de FoodYou/OpenNutriTracker" — errado em dois pontos (ADR-5
  decidiu Apache-2.0, e FoodYou nunca foi adotado). Verifiquei
  `docs/VIABILITY.md` e `docs/adr/005-...md` antes de finalizar e
  corrigi. Registrado aqui por transparência, não ficou na ADR.

  **Status final: ADR-4 continua proposta.** Portão duplo (arquitetura +
  monetização) — não me cabe aceitar sozinho, mesmo com a análise mais
  forte agora. Pedido explicitamente ao usuário.

  **Não verificado (sem mudança):** API de catálogo do wger reutilizável
  isoladamente; UX de dois sistemas de treino coexistindo — ambos já
  registrados como fora do escopo desta ADR.

  **Débito técnico:** nenhum novo.
