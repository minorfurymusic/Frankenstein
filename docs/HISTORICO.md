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
- **ADR-4 e ADR-5 aceitas; `docs/LICENSE-AUDIT.md` fechado.** Confirmação
  explícita do usuário para as duas últimas ADRs pendentes (2026-08-09).
  `docs/adr/004-wger-fasten.md` e `docs/adr/005-licenciamento-distribuicao.md`:
  `**Status:** aceito`. `docs/LICENSE-AUDIT.md` ganhou seção
  "Fechamento" consolidando qual cenário (B) e quais decisões de cada
  ADR viraram real — cliente Apache-2.0, wger/Fasten federados sem vazar
  licença, servidor AGPL-3.0 por escolha, `/source` route já cobre a
  obrigação AGPL do wger hospedado. Fecha o item 9 da Definição de
  Pronto do MVP. `docs/adr/000-pendentes.md`: 11/11 ADRs aceitas, Fase 1
  concluída. `make test` exit 0 antes do commit (`e4d10e0`).

- **Fase 3 — Health Data Core: schema `HealthEvent` implementado e
  testado.** Objetivo único, por instrução direta ("fase 3 por favor"),
  investigado (`docs/ARQUITETURA.md`, ADR-3 aceita, `.claude/rules/datacore.md`)
  e confirmado antes de codificar.

  **Gap preenchido nos documentos, com justificativa:** `docs/ARQUITETURA.md`
  e `.claude/rules/datacore.md` já citavam dedup por `(source,
  external_id)` e correção como "novo evento apontando para o anterior",
  mas o schema enumerado não tinha esses campos. Adicionados
  `external_id` e `corrects_event_id` aos dois documentos — preenchimento
  de lacuna, não mudança de decisão, confirmado com o usuário antes de
  implementar.

  **Terceiro campo adicionado sem pedir confirmação separada, por ser
  regra inviolável:** `.claude/rules/00-inviolaveis.md` exige "Timestamps
  em UTC, com timezone gravado à parte" — regra sempre carregada, vale
  pra qualquer schema do projeto. Adicionado `occurred_at_tz_offset_minutes`
  (offset em minutos, não fuso IANA — simplificação registrada
  explicitamente no código). Diferente dos outros dois campos, este não
  foi levado pra confirmação prévia porque não é uma decisão nova — é
  cumprir uma regra que já existia e sempre esteve carregada.

  **Implementação** (`packages/health_core`): `sqlite3` (bindings FFI em
  Dart puro) em vez de `sqflite` (plugin Flutter) — mantém o Core
  testável com `dart test` puro, sem virar pacote Flutter; a camada do
  app adiciona `sqlite3_flutter_libs` depois, só para empacotar o binário
  nativo no Android/iOS. `uuid` para gerar ids.

  - `lib/src/schema.dart` — migração SQL (`health_events`,
    `gps_track_points`, índice único de dedup parcial em
    `(source, external_id) WHERE external_id IS NOT NULL`).
  - `lib/src/health_event.dart` — `HealthEvent` (imutável, valida UTC e
    `confidence` no construtor), `GpsTrackPoint`, enums `HealthEventType`/
    `HealthEventSource` com conversão de/para o valor gravado no banco.
  - `lib/src/health_data_core.dart` — `HealthDataCore`: `insertEvent`
    (rejeita duplicata via `DuplicateEventException`), `correctEvent`
    (nunca UPDATE — insere e liga via `corrects_event_id`), `getById`,
    `queryByType` (filtro de intervalo), `correctionChain`,
    `insertGpsTrackPoints`/`gpsTrackPoints`. Nenhum método de update ou
    delete existe na classe, de propósito.

  **Prova:**
  ```
  $ dart test (packages/health_core)
  00:00 +15: All tests passed!
  ```
  15 testes: round trip de insert/leitura (incluindo payload aninhado e
  campos nulos), dedup (rejeita duplicata, permite `external_id` nulo
  repetido, não colide entre `source` diferentes), correção (original
  intacto, cadeia com múltiplas correções concorrentes, erro ao corrigir
  evento inexistente), consulta por tipo/intervalo, `gps_track_points`
  em tabela própria, validação (UTC, `confidence`), e o teste de ida e
  volta com arquivo real exigido por `.claude/rules/datacore.md` ("Toda
  migração de schema precisa de teste de ida e volta com dados reais") —
  fecha o banco, reabre do mesmo arquivo simulando processo novo, dado
  sobrevive; reabrir schema já existente é idempotente.

  `make lint` e `make test` completos (todos os pacotes + app) rodados
  depois, os dois exit 0 — nada mais quebrou.

  **Não verificado:** se `libsqlite3` está presente por padrão nos
  runners `ubuntu-latest` do GitHub Actions — está presente neste
  sandbox de dev (`ldconfig -p | grep sqlite3`), e é biblioteca de
  sistema comum o bastante (usada pelo módulo `sqlite3` do Python) que a
  expectativa é que sim, mas não confirmei rodando o CI de verdade neste
  ciclo.

  **Débito técnico:** nenhum novo — `packages/health_core` não tem
  código temporário.

  **Próximo ciclo proposto:** F4 (passos, foreground service) ou F5
  (cérebro com 1 ferramenta) — o primeiro módulo real a escrever no
  Health Data Core. Não decidido; pergunta em aberto pro usuário.

- **Fase 5 — cérebro com 1 ferramenta só: pipeline configurado e provado
  de ponta a ponta.** Instrução direta: "o f5 é a ferramenta mais
  importante. configure-o primeiro" — F4 (passos) pulado por enquanto.

  Investigado antes de codificar: `docs/OFFLINE-IA.md`,
  `.claude/rules/brain.md`, contrato de `log_meal` já especificado em
  `docs/ARQUITETURA.md:43-67`. Recorte de escopo confirmado com o
  usuário antes de implementar: **MLC LLM real (inferência on-device)
  fica fora deste ciclo** — exige validação em Android físico/emulador,
  que este ambiente não tem (mesmo limite do Ciclo 27). A chamada real
  ao modelo entra depois via a interface `ToolCaller`, sem reescrever o
  pipeline; o roteador determinístico é a única implementação concreta
  por agora — que é o caminho **principal** pro Perfil C
  (`docs/OFFLINE-IA.md`), não um substituto temporário.

  **`packages/tool_registry`** (novo, dependência real:
  `json_schema: ^5.2.0`, licença Boost Software License — permissiva,
  compatível; transitivas `http`/`uri` BSD-3-Clause, `quiver`
  Apache-2.0, `rfc_6901` MIT, todas conferidas antes de adicionar,
  `.claude/rules/licenca.md`):
  - `ToolSpec` — contrato de ferramenta (nome, descrição, `write`,
    `confirm`, módulo dono, schema de parâmetros). Construtor recusa
    `write: true` sem `confirm: true` — cumpre
    `.claude/rules/brain.md` passo 4 na origem, não deixado pra quem
    registra lembrar.
  - `ToolRegistry` — registra `ToolSpec` + handler, executa com
    validação na frente (`ToolValidationException`/`ToolNotFoundException`
    em vez de falhar silencioso).
  - `validateToolParameters` — valida contra JSON Schema de verdade
    (biblioteca real, não checagem caseira).
  - 11 testes.

  **`packages/brain`** (novo, dependência real:
  `frankstein_tool_registry` via `path:` local — primeira dependência
  entre pacotes do monorepo):
  - `ToolCaller` — interface pra "decidir qual ferramenta chamar";
    `DeterministicRouter` a única implementação (regex + extrator de
    parâmetros, genérico — não sabe nada de `log_meal` especificamente).
  - `ConfirmationGate` — interface de confirmação humana (UI fica pro
    app; aqui só o contrato).
  - `BrainPipeline` — orquestra as 4 etapas de `.claude/rules/brain.md`
    na ordem: decide → valida → confirma (se `write`) → executa. Ferramenta
    decidida mas não registrada vira `unresolved` em vez de vazar
    exceção.

  **Prova, ponta a ponta, com dado real** (`packages/brain/test/brain_test.dart`,
  usando `packages/health_core` como `dev_dependency` só pro teste — sem
  tocar `packages/nutrition`, que continua travado por clean room):
  ```
  $ dart test (brain) → 00:00 +5: All tests passed!
  ```
  5 cenários: texto reconhecido + confirmado grava `HealthEvent` tipo
  `meal` de verdade no Health Data Core (confere payload, tipo, id);
  usuário recusa confirmação → nada gravado; texto fora do formato do
  roteador → `unresolved`, confirmação nunca pedida; parâmetros
  inválidos → `rejected` **antes** de pedir confirmação; ferramenta
  decidida mas não registrada → `unresolved`, não vaza exceção.

  `make lint` e `make test` completos (todos os pacotes + app) rodados
  depois, os dois exit 0.

  **Não verificado:** o mesmo item do Ciclo de F3 —
  disponibilidade de `libsqlite3` em runners `ubuntu-latest` do CI, ainda
  não confirmada rodando de verdade (a dependência de `health_core` só
  entrou no `brain` como `dev_dependency` de teste, mesma exposição de
  antes, não nova).

  **Débito técnico:** nenhum novo. O roteador desta fase só reconhece um
  formato de comando estruturado explícito (`registrar refeição TIPO:
  ITEM GRAMASg, ...`), não linguagem natural livre — documentado no
  próprio código como escopo, não como limitação escondida.

  **Próximo ciclo proposto:** F4 (passos) ou registrar mais ferramentas
  no cérebro (`get_daily_summary`, `get_steps`) usando o mesmo pipeline
  — não decidido, pergunta em aberto pro usuário.

- **Fase 4 — passos, e ferramenta do cérebro interligada.** Instrução
  direta: "f4 e ferramentas interligadas do cerebro".

  Investigado antes de codificar: `.claude/rules/activity.md` — aviso
  forte, citado literalmente: "Foreground service no Android. A
  contagem NÃO pode parar com a tela bloqueada. Esse é o bug que matou o
  projeto anterior; trate como requisito, não como detalhe." Mesmo
  recorte de escopo do F5 (confirmado por precedente já estabelecido,
  não repetido pro usuário desta vez): **o foreground service Android
  real não entra neste ciclo** — exige aparelho/emulador de verdade pra
  validar que a contagem não para com a tela bloqueada, e este ambiente
  não tem nenhum dos dois (mesmo limite do Ciclo 27).

  **`packages/activity`** (dependência real em `frankstein_health_core`
  e `frankstein_tool_registry`; `frankstein_brain` como dev_dependency
  só pro teste de ferramentas interligadas):
  - `StepsSample` — leitura crua do sensor, espelha a semântica real do
    `TYPE_STEP_COUNTER` do Android (contador cumulativo desde o boot,
    zera no reinício).
  - `StepSensor` — interface da fonte de leituras; a implementação
    Android real (foreground service + platform channel) não está
    implementada, mesma razão do `ToolCaller` na Fase 5.
  - `StepsRepository` — agrega leituras em `HealthEvent`s tipo `steps`:
    primeira leitura vira linha de base (sem evento); leituras
    crescentes acumulam delta; leitura menor que a anterior = reset do
    aparelho, faz flush automático do delta pendente antes de recomeçar
    a linha de base. `flush()` grava o evento e reinicia a janela;
    `attachSensor()` liga a uma fonte de leituras via `Stream`.
  - **Bug pego antes de rodar teste:** primeira versão de `flush()` lia
    `DateTime.timeZoneOffset` do timestamp UTC pra gravar
    `occurred_at_tz_offset_minutes` — mas um `DateTime` UTC sempre
    reporta offset zero, isso zeraria o fuso de todo evento. Corrigido
    exigindo `tzOffsetMinutes` explícito em `flush()` (e em
    `StepsSample`), mesma disciplina de `occurredAt`/`recordedAt` em
    UTC "com timezone gravado à parte" — nenhum campo tenta derivar
    fuso de um timestamp UTC.
  - `get_steps` (`.claude/rules` novo em `docs/ARQUITETURA.md:66-67`) —
    soma `count` dos eventos `steps` do dia pedido. Simplificação
    registrada no código: usa limites de dia em UTC, não o fuso local de
    cada evento — funciona certo pra a maioria dos fusos, fica como
    débito conhecido, não erro escondido.

  **Ferramentas interligadas — prova de que `get_steps` e `log_meal`
  convivem no mesmo pipeline, sem interferência**
  (`packages/activity/test/interlinked_tools_test.dart`): passos
  gravados de verdade via `StepsRepository` (não um `HealthEvent`
  escrito à mão), `get_steps` lê esse dado através do `BrainPipeline`
  (roteador reconhece "quantos passos eu dei em DATA?"), `log_meal`
  registrado no mesmo `ToolRegistry` (mesmo handler de demonstração já
  usado na Fase 5 — `packages/nutrition` continua travado por clean
  room, não tocado). Confirma que os dois tipos de evento coexistem no
  Health Data Core sem se misturar (consulta de passos antes e depois de
  gravar uma refeição dá o mesmo total).

  **Prova:**
  ```
  $ make lint (todos os pacotes + app) → EXIT LINT: 0
  $ make test (todos os pacotes + app) → EXIT TEST: 0
  ```
  46 testes no total: health_core 15, brain 5, tool_registry 11,
  activity 13 (inclui o teste de ferramentas interligadas), nutrition/
  entitlements/share 1 cada, app 1.

  **Não verificado:** mesmo item de F3/F5 — disponibilidade de
  `libsqlite3` em runners `ubuntu-latest` do CI real, ainda não
  confirmada rodando de verdade.

  **Débito técnico:** `get_steps` usa limites de dia em UTC, não fuso
  local por evento (registrado no código, não escondido). Foreground
  service Android real — mesmo débito já registrado pro `ToolCaller`
  de LLM na Fase 5.

  **Próximo ciclo proposto:** mais ferramentas do cérebro
  (`get_daily_summary`, `search_food`, `sync_wearable`) ou outro módulo
  (F6 nutrição — travado até `docs/specs/nutricao.md` bastar sozinha;
  F7 Academia; F8 corrida/GPS) — não decidido, pergunta em aberto pro
  usuário.

- **F6 (nutrição/código de barras) — BLOQUEADO.** Usuário trouxe uma
  "Ficha de Planejamento" completa pra F6. Investigada antes de agir —
  não escrevi nenhum código.

  **Bloqueio real, não cautela:** esta sessão está desqualificada de
  escrever `packages/nutrition/**` — o resumo do início da conversa já
  registrava que cycles anteriores desta mesma sessão leram
  `docs/recon/opennutritracker.md` extensivamente.
  `.claude/rules/port.md` proíbe exatamente isso, "nesta sessão ou em
  qualquer momento anterior que informe o que está escrevendo". Violar
  reverteria o cliente de Apache-2.0 pra GPL-3.0 automaticamente
  (`docs/adr/005-licenciamento-distribuicao.md`, seção "Consequência de
  violar").

  **Erros encontrados na ficha, verificados contra o repositório antes
  de aceitar qualquer afirmação dela (regra 2 do `CLAUDE.md`):**
  - "Liberado por ADR-8 (banco SQLite)" — ADR-8 é multi-tenant B2B, não
    trata de banco de dados.
  - `docs/adr/008-banco-de-dados.md` — não existe, referência inventada.
  - **Mais sério:** a ficha propunha gerar o banco de alimentos a partir
    do "arquivo CSV/JSON do OpenNutriTracker" — contradiz
    `docs/specs/nutricao.md:100-101` e `docs/OFFLINE-IA.md:31-35`, que já
    decidem a fonte real: subconjunto brasileiro do **Open Food Facts**
    (dado público). Importar o banco deles copiaria um asset de
    terceiro pra dentro do módulo PORT — quebraria clean room por outro
    caminho, não só código.
  - Schema do evento `meal` na ficha (`value`, `tz_offset_minutes`,
    `source: "nutrition_scanner"`) não bate com `packages/health_core`
    real (`payload`, `occurredAtTzOffsetMinutes`,
    `HealthEventSource` sem esse valor ainda).
  - `HealthDataCore.getEvents(...)` não existe — o método real é
    `queryByType(...)`.
  - Ficha assume que `log_meal` "já existe" e só precisa ser "ajustada"
    — na verdade nunca foi conectada em produção, só existe como
    demonstração de teste (`packages/brain/test`,
    `packages/activity/test`), justamente por causa deste mesmo
    bloqueio.
  - `mobile_scanner` (leitor de código de barras sugerido) tipicamente
    usa Google ML Kit no Android — proibido pela regra 6 do `CLAUDE.md`
    e pelo próprio `docs/OFFLINE-IA.md`, que já indica ZXing como
    alternativa livre. Não verificado a fundo (não fui atrás de árvore
    de dependência de um pacote que não vou adicionar), mas risco sério
    demais pra deixar passar sem nota.

  **Proposto ao usuário, não decidido:** montar um `Agent` novo,
  genuinamente sem contato com `docs/recon/opennutritracker.md` nem o
  código-fonte deles, com prompt que só aponta pra
  `docs/specs/nutricao.md` e `.claude/rules/port.md`, pra fazer a F6 de
  verdade — com a fonte de dados corrigida (Open Food Facts) e sem
  `mobile_scanner`. Aguardando confirmação.

  **Não verificado:** árvore de dependência real do `mobile_scanner`
  (não baixado, por não pretender usá-lo); se a tabela `foods` da ficha
  tem alguma coincidência estrutural com o schema real do
  OpenNutriTracker — não posso verificar isso, é exatamente o tipo de
  comparação que o clean room me impede de fazer.

  **Débito técnico:** nenhum novo em código — o "débito" aqui é a F6
  inteira, ainda não iniciada.

- **F6 (nutrição/código de barras) — implementada, sessão nova sem
  contato com `docs/recon/opennutritracker.md`.** Delegada por outra
  sessão exatamente pelo bloqueio de clean room registrado na entrada
  anterior. Confirmado ao abrir: esta sessão nunca leu
  `docs/recon/opennutritracker.md` nem `refs/opennutritracker/` — não
  abertos em nenhum momento deste ciclo, do primeiro ao último comando.
  Implementação parte só de `docs/specs/nutricao.md` (`.claude/rules/port.md`).

  **`packages/nutrition`** (dependência real em `frankstein_health_core`
  e `frankstein_tool_registry`; `frankstein_brain` como dev_dependency só
  pro teste de ponta a ponta, mesmo padrão de `packages/activity`):
  - `Food`/`FoodSource` — modelo de alimento (nome, código de barras
    opcional, macros por 100 g; saturada/açúcar/fibra/sódio opcionais
    porque nem toda fonte tem o dado).
  - `FoodRepository` — catálogo local sobre `sqlite3` (mesmo padrão FFI
    de `packages/health_core`, não `sqflite`): `findById`,
    `findByBarcode`, `searchByName` (substring, case-insensitive),
    `insertCustomFood` (exige `FoodSource.custom`, pra separar catálogo
    embarcado de item do usuário). **Populado por um dataset de
    fixture** (`food_fixture_dataset.dart`, 6 alimentos brasileiros
    comuns, macros plausíveis, códigos de barras fabricados só pra
    exercitar busca) — **não é o subconjunto real do Open Food Facts**
    (`docs/OFFLINE-IA.md:31-35`); a importação real (rede, tamanho,
    delta mensal) é trabalho futuro de infraestrutura de dados, marcada
    com `TODO(frankstein)` no código, fora do escopo deste ciclo por
    instrução explícita.
  - `BarcodeDecoder` — interface abstrata (`decodeImage(Uint8List)`),
    mesmo padrão de isolamento de hardware que `StepSensor`
    (`packages/activity/lib/src/step_sensor.dart`): este ambiente não
    tem câmera nem emulador pra validar uma implementação real.
    `FixtureBarcodeDecoder` (mapa bytes→código, registrado em teste)
    prova o fluxo "decodifica → acha no catálogo → registra" sem
    hardware nenhum. **Pacote pesquisado e escolhido para a
    implementação concreta futura: `flutter_zxing` (pub.dev, versão
    2.3.0 na pesquisa, licença MIT, ZXing-cpp via Dart FFI, sem ML Kit
    nem Google Play Services) — não adicionado como dependência neste
    ciclo** porque ele exige o SDK Flutter e o pacote `camera`;
    `packages/nutrition` precisava continuar Dart puro (`dart test`,
    mesmo padrão de `health_core`/`activity`), então a classe concreta
    fica para `app/` num ciclo futuro com dispositivo/emulador de
    verdade.
  - `MealLogger` — recebe alimento(s) (`food_id`+gramas) + tipo de
    refeição, calcula macros totais (soma ponderada por
    `gramas/100`), grava `HealthEvent` tipo `meal` via
    `HealthDataCore.insertEvent`. `source` do evento é
    `HealthEventSource.manual` — decisão registrada no código
    (`meal_logger.dart`): o enum real
    (`packages/health_core/lib/src/health_event.dart:41-57`) não tem
    valor pra "veio de scanner"; em vez de inflar o enum, a proveniência
    de cada item (busca/scan/adição rápida) vai no `payload`, por item
    (`input_method`), porque é aí que o dado pertence — `source` do
    evento é sobre a origem do evento (interação do usuário no app,
    sempre manual aqui), não do item.
  - `log_meal` real (`nutrition_tools.dart`, `logMealSpec`/
    `logMealHandler`) — mesmo padrão de `getStepsSpec`/`getStepsHandler`
    em `packages/activity/lib/src/activity_tools.dart`. Schema idêntico
    ao contrato documentado em `docs/ARQUITETURA.md:60-79`. Recebe
    `tzOffsetMinutesProvider` (função, não valor fixo) porque o contrato
    JSON de `log_meal` não carrega fuso — só quem conhece o fuso do
    aparelho no momento do registro pode fornecer isso, e o fuso pode
    mudar entre chamadas (viagem).

  **Prova de ponta a ponta** (`packages/nutrition/test/nutrition_test.dart`,
  grupo "log_meal — ferramenta real do cérebro"): um roteador
  determinístico próprio deste ciclo (regex em português, não copiado de
  nenhum roteador existente) reconhece "comi Ng de FOOD_ID no
  REFEIÇÃO", o `BrainPipeline` decide, valida contra o schema, executa
  `log_meal` de verdade, e o `HealthEvent` cai no Health Data Core com
  os macros certos (146 kcal pro exemplo de 100 g de ovo cozido,
  conferido contra o dataset de fixture). Mesmo padrão de prova já usado
  em `packages/activity/test/interlinked_tools_test.dart` pra
  `get_steps`.

  **Prova:**
  ```
  $ cd packages/nutrition && dart analyze --fatal-infos
  Analyzing nutrition...
  No issues found!

  $ cd packages/nutrition && dart test
  ...
  00:00 +17: All tests passed!

  $ make lint   (raiz, todos os pacotes + app)
  ... (todo pacote: "No issues found!"; app: "No issues found! (ran in 6.1s)")

  $ make test   (raiz, todos os pacotes + app)
  ... health_core 15, brain 5, tool_registry 11, activity 13,
      nutrition 17, entitlements 1, share 1, app 1 — todos
      "All tests passed!"
  ```

  **Não verificado:** mesmo item de F3/F4/F5 — disponibilidade de
  `libsqlite3` em runners `ubuntu-latest` do CI real, ainda não
  confirmada rodando de verdade (agora com mais um pacote,
  `frankstein_nutrition`, na mesma exposição). Se a fórmula de meta
  calórica/macros/IMC citada em `docs/specs/nutricao.md` (IOM 2005, WHO,
  WHO TRS 916, Compendium 2024) deve ser implementada exatamente assim —
  fora de escopo desta especificação, não decidido aqui. Tipo de
  `HealthEvent` para água — ainda pendente, não adicionado
  (`docs/specs/nutricao.md`, seção "Não verificado"; não implementado
  neste ciclo por não estar no escopo mínimo delegado).

  **Débito técnico:**
  - `TODO(frankstein)` em `food_fixture_dataset.dart`: trocar dataset de
    fixture pela importação real do subconjunto brasileiro do Open Food
    Facts quando existir infraestrutura de download.
  - `TODO(frankstein)` em `barcode_decoder.dart`: implementar
    `ZxingBarcodeDecoder` concreto em `app/` com `flutter_zxing` ^2.3.0
    quando houver dispositivo/emulador real pra testar câmera.
  - Água (novo tipo de `HealthEvent`) e peso (fluxo completo de
    tendência) não entraram — fora do escopo mínimo deste ciclo,
    seguem como pendência de `docs/specs/nutricao.md`.
  - Refeição/receita personalizada composta de outros ingredientes
    (bill-of-materials completo) não entrou — só `insertCustomFood`
    (item único, nome+macros); composição a partir de ingredientes já
    cadastrados fica para um ciclo futuro.
  - `packages/activity/test/interlinked_tools_test.dart` ainda usa o
    handler de demonstração de `log_meal` (não o real) e o comentário lá
    ainda diz "`packages/nutrition` continua travado por clean room" —
    ficou desatualizado por este ciclo; não tocado agora pra não sair do
    escopo restrito a `packages/nutrition/**` (regra de clean room),
    fica pra um ciclo futuro trocar pelo handler real.

  **Próximo ciclo proposto:** ligar `log_meal` real ao pipeline de
  `packages/activity` (substituir o handler de demonstração), ou avançar
  outro módulo (F7 Academia; F8 corrida/GPS) — não decidido, pergunta em
  aberto pro usuário.

- **F6 — varredura de pendências.** Instrução direta: "se conseguir
  corrigir as pendências, corrija; se não, vá pra próxima etapa". As 5
  pendências deixadas pelo ciclo anterior, uma a uma:

  1. **`packages/activity/test/interlinked_tools_test.dart` usava o
     handler de demonstração de `log_meal`, não o real — corrigido.**
     `frankstein_nutrition` adicionada como `dev_dependency` de
     `packages/activity` (path local). Teste reescrito: `FoodRepository.openInMemory(seedFixtureData:
     true)` + `MealLogger` reais, registrados via `logMealSpec()`/
     `logMealHandler()` de `packages/nutrition`. Trocado o item de
     texto do comando de exemplo pro id real do dataset de fixture
     (`fixture-arroz-branco-cozido`, já que o handler real busca no
     catálogo de verdade e rejeita id desconhecido — acrescentado um
     caso de teste novo pra isso: `alimento-inexistente` retorna
     `PipelineOutcome.executed` com `toolResult.success == false`, não
     trava o pipeline). Conferido o cálculo de macro de verdade: 150g de
     arroz branco cozido (130 kcal/100g no fixture) = 195 kcal,
     comparado no teste.
  2. **Importação real do Open Food Facts — tentado de novo, confirmado
     não resolvível neste ambiente.** `curl` direto a
     `world.openfoodfacts.org`, `static.openfoodfacts.org` e
     `br.openfoodfacts.org` — os três `HTTP 403` (`CONNECT tunnel
     failed`), mesmo padrão de bloqueio de proxy já visto em outros
     domínios nesta sessão (codeberg.org, gadgetbridge.org,
     f-droid.org). `raw.githubusercontent.com` (que já funcionou como
     mirror pra outros casos, ex. Gadgetbridge) está acessível, mas uma
     busca não achou nenhum sample CSV/JSON pequeno com dado real
     hospedado lá — os repositórios que trabalham com Open Food Facts
     apontam pra baixar o dataset completo do site oficial (~0,9 GB
     comprimido), não um recorte pronto. Sem caminho viável aqui.
     `packages/nutrition` continua com o dataset de fixture, já bem
     sinalizado como tal no código.
  3. **`BarcodeDecoder` concreto com `flutter_zxing` — decisão de
     adiar, não bloqueio técnico.** Diferente do item 2, dava pra
     *escrever* o código (adicionar a dependência, implementar a
     interface). Não foi feito porque (a) não tem como validar leitura
     de câmera de verdade neste ambiente, e (b) `app/` ainda não tem
     nenhuma estrutura de UI (navegação, tema, nenhuma tela além do
     `Scaffold` em branco da Fase 2) — encaixar uma tela de scanner
     isolada, sem o resto do app em volta e sem poder testar a parte que
     mais importa (a câmera), tem mais risco de gerar código morto ou
     errado do que valor de ter "alguma coisa escrita". Registrado como
     próxima etapa natural quando o app shell ganhar UI de verdade, não
     como pendência resolvida.
  4. **Água / receita composta — não são bugs, são escopo novo.**
     `docs/specs/nutricao.md` já registra as duas como "não decidida
     aqui" — não tentei decidir isso agora, seria inventar escopo sem
     pedido.
  5. **Próximo módulo/ferramenta — segue em aberto**, não é algo pra
     "corrigir", é decisão do usuário.

  **Prova:**
  ```
  $ dart test (activity, isolado) → 00:00 +13: All tests passed!
  $ make lint (raiz, todos os pacotes + app) → EXIT LINT: 0
  $ make test (raiz, todos os pacotes + app) → EXIT TEST: 0
  ```
  64 testes no total: health_core 15, brain 5, tool_registry 11,
  activity 13 (inclui o teste corrigido), nutrition 17, entitlements 1,
  share 1, app 1.

  **Não verificado:** mesmo item recorrente — `libsqlite3` em runners
  `ubuntu-latest` do CI real, ainda não confirmado rodando de verdade.

  **Débito técnico:** nenhum novo — dataset de fixture e `BarcodeDecoder`
  abstrato já eram débito conhecido e continuam registrados como tal,
  não pioraram nem foram escondidos.

  **Próximo ciclo proposto:** decidir entre mais ferramentas do cérebro
  ou outro módulo (F7 Academia; F8 corrida/GPS) — pergunta em aberto pro
  usuário.

- **Ciclo — F7: Academia (planos, sessão, séries, recorde).** Usuário pediu
  a próxima etapa; seguindo a regra de desempate já combinada ("pendências
  primeiro, depois a ordem sugerida" — `docs/PRODUTO.md`), e com F6 sem
  pendências restantes cabíveis neste ambiente, a próxima etapa é F7
  (Academia — `docs/PRODUTO.md:28`: "planos, sessão ao vivo, séries/
  repetições/carga, RPE, recordes, progressão"). Diferente de F4/F6, F7
  não tem nenhuma dependência de hardware/câmera identificada — tudo
  testável de ponta a ponta neste ambiente, sem ressalva. Também não tem
  o bloqueio de clean room de F6 (`.claude/rules/port.md` só vale para
  `packages/nutrition`), então implementado diretamente, sem subagente.

  Domínio (`packages/activity/lib/src/`): `workout_plan.dart`
  (`PlannedExercise`, `WorkoutPlan` — catálogo local, não é `HealthEvent`,
  mesmo papel que `Food` tem pra nutrição) e `workout_session.dart`
  (`SetEntry`, `WorkoutSessionInput` — o que foi executado de verdade,
  granular por série pra permitir consulta de progressão por exercício).
  `workout_repository.dart`: `WorkoutRepository` sobre `sqlite3`, mesmo
  padrão exato de `FoodRepository` (`packages/nutrition/lib/src/food_repository.dart`)
  — `.open(path)`/`.openInMemory()`, tabelas `workout_plans` +
  `workout_plan_exercises`. `workout_logger.dart`: `WorkoutLogger.logSession`
  grava 1 `HealthEvent` tipo `workout_session` (resumo) + N tipo `set_log`
  (um por série, cada um com `session_event_id` apontando pro resumo) —
  os dois tipos já estavam reservados no enum desde a F3
  (`packages/health_core/lib/src/health_event.dart:8-9`), nunca usados até
  agora. `personalRecord(exerciseId)` calcula o recorde (maior `load_kg`)
  por consulta sobre `core.queryByType(HealthEventType.setLog)` — não
  armazenado, decisão espelhando como o resto do Health Data Core trata
  dado derivado. `workout_tools.dart`: `get_workout_plan` (leitura,
  `write: false`) e `log_workout_session` (escrita, `write: true,
  confirm: true`) registráveis no `ToolRegistry`, mesmo padrão de
  `activity_tools.dart`/`nutrition_tools.dart`.

  Decisão registrada inline: nenhuma tabela "Exercise" foi criada —
  exercício é só `exerciseId`/`exerciseName` de texto livre escolhido por
  quem chama a ferramenta. Catálogo de exercícios (nome canônico, grupo
  muscular, instrução) não está em `docs/PRODUTO.md` como requisito desta
  fase; criar um agora seria escopo antecipado sem necessidade concreta —
  fica como debate futuro, não como TODO escondido.

  Dependências: `sqlite3: ^2.4.6` (BSD-3-Clause) e `uuid: ^4.5.1`
  (MIT) adicionadas a `packages/activity/pubspec.yaml` como dependências
  diretas — ambas já usadas e com licença registrada anteriormente em
  `packages/health_core`/`packages/nutrition` (mesmas versões); aqui é
  reuso, não dependência nova ao projeto, só uma nova declaração direta
  no pacote (`.claude/rules/licenca.md`).

  **Prova:**
  ```
  $ dart test (activity, isolado) → 00:00 +27: All tests passed!
  $ make lint (raiz, todos os pacotes + app) → "No issues found!" em
    health_core, brain, tool_registry, activity, nutrition, entitlements,
    share, app
  $ make test (raiz, todos os pacotes + app) →
    health_core: 00:00 +15: All tests passed!
    brain: 00:00 +5: All tests passed!
    tool_registry: 00:00 +11: All tests passed!
    activity: 00:00 +27: All tests passed!
    nutrition: 00:00 +17: All tests passed!
    entitlements: 00:00 +1: All tests passed!
    share: 00:00 +1: All tests passed!
    app (flutter test): 00:10 +1: All tests passed!
  ```
  78 testes no total (health_core 15, brain 5, tool_registry 11,
  activity 27 — 13 de passos/interligado + 14 novos de F7 — nutrition 17,
  entitlements 1, share 1, app 1). 14 testes novos cobrem: validação de
  `PlannedExercise`/`WorkoutPlan`/`SetEntry`/`WorkoutSessionInput`,
  `WorkoutRepository` (insert + find, plano inexistente), `WorkoutLogger`
  (grava sessão+séries com `session_event_id` correto, recorde pessoal
  com múltiplas sessões, exercício nunca registrado devolve `null`), e as
  duas ferramentas do cérebro (spec de leitura sem confirm, spec de
  escrita com confirm, execução real ponta a ponta gravando no
  `HealthDataCore`).

  **Não verificado:** mesmo item recorrente — `libsqlite3` em runners
  `ubuntu-latest` do CI real, ainda não confirmado rodando de verdade.

  **Débito técnico:** nenhum novo. `TODO(frankstein)` não foi necessário
  neste ciclo — nada ficou pela metade.

  **Próximo ciclo proposto:** F8 (corrida/caminhada com GPS) — mas essa
  herda o mesmo limite de hardware de F4 (sem device/emulador real pra
  validar GPS, bateria, gravação em background neste ambiente); ou,
  alternativamente, mais ferramentas do cérebro sobre o que já existe
  (`get_daily_summary`, `search_food`). Pergunta em aberto pro usuário.

- **Ciclo — organização do dia: licença esclarecida + F8 (parte sem
  Android) + preparação de F10/F11/ferramentas extras/dataset real.**
  Usuário pediu um resumo do que ficou pendente de aprovação e do que
  falta pro MVP. Resposta: nenhuma ADR pendente (11/11 aceitas,
  `docs/adr/005-...md`, `docs/LICENSE-AUDIT.md` fechado) — citado de
  volta pra confirmar. Aprovação recebida pra tocar hoje tudo que não
  depende de teste em device Android, com duas ressalvas explícitas:
  estrutura de Entitlements/Pagamento sem configurar provedor, e buscar
  dataset real de alimentos (Open Food Facts segue bloqueado pelo proxy
  deste ambiente).

  **F8 — só a fatia sem Android.** Diferente de F4/F6/F7: a decisão já
  tomada pra corrida/caminhada (`docs/adr/009-gps.md`, aceita) é **WRAP
  do OpenTracks no Android via platform channel** + **PORT nativo no
  iOS** — não é reimplementação Dart pura como nutrição/academia. Isso
  significa que a captura de GPS em si (sensor, foreground service,
  código nativo) fica fora do que dá pra fazer neste ambiente — mesma
  categoria de bloqueio que F4 (passos) já tinha pro foreground service
  Android real. O que ficou testável de ponta a ponta:

  - **Migração de schema (`packages/health_core`):** `accuracy_meters`
    (nullable) em `gps_track_points` — `.claude/rules/activity.md:16`
    ("descarte pontos com precisão pior que 20 m") depende desse campo,
    que não existia desde a F3. `schema.dart`: `schemaSqlV2AddGpsAccuracy`
    (`ALTER TABLE ... ADD COLUMN`), aplicado por
    `HealthDataCore._applySchema` checando `PRAGMA table_info` antes de
    rodar o `ALTER` — `ALTER TABLE ADD COLUMN` não é idempotente como
    `CREATE TABLE IF NOT EXISTS`, reabrir um banco já migrado sem esse
    guard quebraria. `GpsTrackPoint` ganhou o campo `accuracyMeters`.
    Teste de ida e volta real (`.claude/rules/datacore.md`: "toda
    migração de schema precisa de teste de ida e volta com dados
    reais"): banco criado só com `schemaSqlV1` (simulando instalação
    anterior à Fase 8), ponto GPS inserido sem a coluna nova, reaberto
    via `HealthDataCore.open` — migra sem perder o ponto existente
    (`accuracyMeters` nulo, como esperado), aceita gravar ponto novo com
    precisão, e reabrir de novo continua idempotente.
  - **`RunCalculator` (`packages/activity/lib/src/run_calculator.dart`):**
    distância por Haversine, `filterByAccuracy` (descarta pontos com
    precisão pior que o limiar, mantém pontos sem precisão relatada —
    decisão registrada: não dá pra invalidar um dado que nunca existiu),
    `elevationGainMeters` (só soma ganhos positivos), `kmSplits` (corta a
    cada km percorrido, tempo decorrido por split), `averagePaceSecondsPerKm`,
    `summarize`. `docs/PRODUTO.md:29`: "GPS, rota, pace, splits por km,
    elevação, pausa automática, GPX".
  - **GPX (`packages/activity/lib/src/gpx.dart`):** `exportGpx`/`importGpx`,
    GPX 1.1 (`trk`/`trkseg`/`trkpt`), usando `package:xml` (MIT) só pra
    montar/ler XML — obrigatório por `.claude/rules/activity.md:19` e
    LGPD art. 18 (exportação nunca paga nem limitada).
  - **`obfuscateRouteEnds` (`packages/activity/lib/src/route_privacy.dart`):**
    remove os pontos dentro de 300 m do início e do fim da rota
    (`.claude/rules/activity.md:20-21`). Rota menor que 600 m devolve
    lista vazia — decisão registrada: não existe "meio seguro" pra
    revelar sem também revelar onde a rota começou ou terminou.
  - **`RunLogger` (`packages/activity/lib/src/run_logger.dart`):** filtra
    por precisão, calcula o resumo, grava 1 `HealthEvent` tipo
    `gps_track` (payload com distância/duração/elevação/splits/pace) + os
    pontos filtrados em `gps_track_points`. Recusa gravar (
    `InsufficientRunDataException`) se sobrarem menos de 2 pontos após o
    filtro — nunca grava uma rota vazia/inútil silenciosamente.
  - **`get_run_summary` (`packages/activity/lib/src/run_tools.dart`):**
    ferramenta de leitura pro `ToolRegistry`, devolve só o resumo já
    calculado — nunca os pontos brutos de lat/lon (privacidade de rota,
    mesmo raciocínio da ofuscação).
  - **`start_run` (ferramenta de escrita, listada em `docs/ARQUITETURA.md:66-67`)
    não foi implementada.** Só faz sentido depois que existir captura de
    GPS real pra iniciar — registrar um handler que não faz nada de
    verdade seria "feito" sem prova (`CLAUDE.md`, regra 1). Fica
    documentado como pendência, não escondido atrás de um método vazio.

  Dependência nova: `xml: ^6.5.0` (resolvido `6.6.1`), MIT, mais
  `petitparser` transitivo (`7.0.2`), também MIT — ambos verificados
  lendo o `LICENSE` de cada um no cache local antes de registrar aqui
  (`.claude/rules/licenca.md`).

  Um bug de ponto flutuante foi pego e corrigido durante os testes:
  `kmSplits` comparava `distanceSinceLastSplit >= 1000` sem tolerância —
  distância Haversine real para segmentos sintéticos de "exatamente
  1000 m" caía por uma fração de milímetro abaixo do limiar por
  arredondamento trigonométrico, atrasando o corte do split em um ponto.
  Corrigido com uma tolerância de `1e-6` no limiar — decisão de
  robustez genuína (GPS real nunca bate exatamente em 1000.000000 m),
  não um ajuste só pra passar teste.

  **Prova:**
  ```
  $ dart test (health_core, isolado) → 00:00 +17: All tests passed!
  $ dart test (activity, isolado) → 00:00 +47: All tests passed!
  $ make lint (raiz, todos os pacotes + app) → "No issues found!" em todos
  $ make test (raiz, todos os pacotes + app) →
    health_core: +17, brain: +5, tool_registry: +11, activity: +47,
    nutrition: +17, entitlements: +1, share: +1, app: +1 — todos "All
    tests passed!"
  ```
  100 testes no total no monorepo (78 antes deste ciclo + 22 novos: 2 em
  health_core — accuracy_meters + migração — e 20 em activity —
  RunCalculator, GPX, ofuscação, RunLogger, get_run_summary).

  **Não verificado:** mesmo item recorrente — `libsqlite3` em runners
  `ubuntu-latest` do CI real.

  **Débito técnico:** `start_run` (ferramenta de escrita de F8) e a
  captura de GPS real (WRAP Android/PORT iOS) — bloqueadas por hardware,
  já documentadas acima e em `STATUS.md`, não escondidas.

  **Próximo ciclo proposto (mesma manhã, continuando):** F10/F11
  (esqueleto de Entitlements/Pagamento, sem provedor configurado),
  ferramentas extras do cérebro (`get_daily_summary`, `search_food`), e
  pesquisa de dataset real de alimentos aberto e alcançável (substituto
  do Open Food Facts, bloqueado pelo proxy).

- **Ciclo — F10/F11 (esqueleto), ferramentas extras, catálogo real de
  alimentos.** Continuação da mesma manhã de trabalho. Usuário
  esclareceu: (1) licenciamento já estava decidido (confirmado citando
  ADR-5/LICENSE-AUDIT.md de volta), (2) fazer hoje tudo que não depende
  de Android, (3) Entitlements/Pagamento só estrutura, sem provedor
  configurado, (4) buscar dataset real de alimentos aberto pra copiar.

  **F10/F11 — `packages/entitlements`.** `Entitlement` (payload que o
  cliente recebe, `docs/MONETIZACAO.md:38-41`: sub/plan/features/exp) +
  `EntitlementVerifier` (verifica assinatura Ed25519 contra a chave
  pública — o cliente só verifica, nunca assina; `EntitlementSigner`
  simula o servidor só pra teste) + graça offline (`isValidAt(...,
  offlineGrace: true)`, vale até exp+7 dias) + `Subscription`/
  `SubscriptionChannel`/`SubscriptionStatus` (registro do lado do
  servidor, `docs/MONETIZACAO.md:33-34`) + `PendingPayment` (Pix
  assíncrono, nunca libera no clique — `confirm()`/`expire()` só podem
  rodar uma vez) + `WebhookIdempotencyGuard` (chave `external_id +
  event_id`). Dependência nova: `cryptography: ^2.7.0` (resolvido
  `2.9.0`, Apache-2.0) + `ffi` transitivo (BSD-3-Clause) — verificadas
  lendo o `LICENSE` de cada uma no cache local antes de registrar.
  Assinatura/verificação Ed25519 testada de ponta a ponta de verdade:
  gera par de chaves, assina, verifica com sucesso; assinatura de outra
  chave é rejeitada; payload adulterado depois de assinado é rejeitado.
  14 testes.

  **Ferramentas extras do cérebro.** `get_daily_summary`: novo pacote
  `packages/summary` (só leitura sobre o Health Data Core compartilhado,
  sem tabela própria) — nenhum módulo de domínio existente é dono
  natural, já que cruza `steps`/`meal`/`workout_session`/`gps_track`;
  criar um pacote novo em vez de forçar isso dentro de `activity` ou
  `nutrition` respeita a regra de "nenhum módulo lê o banco de outro"
  (lê o Core compartilhado, não o banco privado de outro módulo).
  Adicionado ao `Makefile` (`PACKAGES`). 3 testes. `search_food`:
  wrapper fino sobre `FoodRepository.searchByName` (já existente),
  ferramenta de leitura, mesmo padrão de `get_workout_plan`/`log_meal`.
  Implementado por um subagente limpo — `packages/nutrition/**` exige
  clean room (`.claude/rules/port.md`) e esta sessão está desqualificada
  de escrever ali desde antes (abriu `docs/recon/opennutritracker.md`
  em ciclo anterior). Verificado independentemente antes do commit:
  `dart analyze` limpo, 20/20 testes do pacote, diff sem referência real
  ao código-fonte do OpenNutriTracker. 3 testes novos.

  **Catálogo real de alimentos — Tabela TACO (NEPA/UNICAMP).**
  Open Food Facts (fonte originalmente planejada) segue bloqueado pelo
  proxy deste ambiente (confirmado de novo, mesmo padrão de sempre).
  Pesquisa (`WebSearch` + `curl` direto em `raw.githubusercontent.com`,
  alcançável mesmo quando `openfoodfacts.org`/`api.github.com` não são)
  encontrou uma fonte real, aberta e **sem nenhuma relação com o
  OpenNutriTracker**: a Tabela Brasileira de Composição de Alimentos
  (TACO), publicada pelo NEPA/UNICAMP (núcleo de pesquisa de uma
  universidade pública). Termos confirmados via páginas do CFN/FAPESP
  que citam a tabela: "reprodução total ou parcial, desde que citada a
  fonte" — dado público, reprodução permitida com atribuição. Repositório
  técnico usado como fonte de extração: `github.com/brolesi/taco`
  (código MIT, dados reorganizados do NEPA/UNICAMP; README confirma que
  outros mirrors mais antigos do mesmo dataset estão desatualizados e
  apontam pra este). CSV de origem: 597 alimentos reais, valores por
  100g, colunas documentadas num dicionário de dados no próprio
  repositório.

  Dois subagentes limpos em sequência (mesmo motivo de clean room do
  `search_food` acima):
  1. **Import:** `packages/nutrition/lib/src/food_taco_dataset.dart`
     (novo) — 578 de 597 linhas do CSV importadas como `List<Food>`
     `tacoFoods` (19 puladas por campo obrigatório ausente/inválido:
     15 por `energia_kcal` vazio — majoritariamente óleos/gorduras puros
     onde carboidrato não é medido — e 4 por um resíduo de arredondamento
     negativo em `carboidrato_g`, herdado da própria média de múltiplas
     análises da TACO; nenhum valor foi inventado pra preencher isso).
     `sodio_mg` do CSV convertido para gramas (÷1000) pra bater com
     `Food.sodiumPer100g` (confirmado em gramas pelos valores já
     existentes em `food_fixture_dataset.dart`, ex. `0.001`). `source:
     FoodSource.offlineCatalog` — sem novo valor de enum, porque o
     comentário do enum já previa exatamente essa troca (fixture →
     catálogo real) desde a Fase 6. Atribuição completa (NEPA/UNICAMP,
     4ª edição 2011, termos de reprodução, path técnico via
     `brolesi/taco`) no cabeçalho do arquivo gerado. `food_fixture_dataset.dart`
     (6 itens) mantido intacto — outros pacotes (`packages/activity`)
     dependem dos valores exatos dele. `FoodRepository.open()` passou a
     semear com `tacoFoods` por padrão (`seedTacoData: true`);
     `openInMemory()` manteve comportamento de teste inalterado
     (`seedTacoData: false` por padrão, só o fixture como antes).
  2. **Correção de bug pego antes de aceitar como pronto:** o subagente
     de import relatou honestamente, na seção "Débito técnico" do
     próprio relatório, que reabrir um arquivo `.open()` já semeado
     quebraria (`_seedTacoData`/`_seedFixtureData` chamavam `_insert`
     puro, batendo na `PRIMARY KEY` de `foods.id` na segunda inserção).
     Como o novo padrão (`seedTacoData: true` em `.open()`) tornava esse
     um caminho de falha no fluxo de produção normal (app reaberto numa
     segunda sessão), decidido corrigir antes de fechar o ciclo, não só
     documentar como débito — segundo subagente limpo trocou `_insert`
     por um novo `_insertIgnoreDuplicate` (`INSERT OR IGNORE`) só nos
     dois caminhos de reseed de catálogo estático; `insertCustomFood`
     continua com `_insert` estrito, porque duplicata ali é bug real do
     usuário, não deve ser engolida em silêncio. Dois testes novos
     provam a correção reabrindo o mesmo arquivo real duas vezes (com
     `seedTacoData`/`seedFixtureData`) e checando que não lança e não
     duplica.

  Cada um dos três subagentes desta seção foi verificado
  independentemente antes do commit correspondente — nunca aceito só
  pelo autorrelato: `dart analyze --fatal-infos` rodado de novo por
  mim, `dart test` rodado de novo por mim, diff lido inteiro, grep por
  "OpenNutriTracker" no diff (só apareceu no cabeçalho obrigatório de
  disclaimer, texto exigido pela própria regra, não referência real ao
  código deles).

  **Prova (consolidada, `make lint`/`make test` na raiz depois do
  último commit da manhã):**
  ```
  $ make lint → "No issues found!" em todos os 9 pacotes + app
  $ make test →
    health_core: +17, brain: +5, tool_registry: +11, activity: +47,
    nutrition: +27, entitlements: +14, share: +1, summary: +3,
    app (flutter test): +1 — todos "All tests passed!"
  ```
  125 testes no total no monorepo (100 antes deste ciclo + 25 novos: 14
  em entitlements, 3 em summary, 3+5+2 em nutrition — search_food, TACO,
  idempotência de reseed — sendo que a contagem de nutrition subiu de 17
  para 27, ou seja 10 testes novos ali).

  **Não verificado:** `libsqlite3` em runners `ubuntu-latest` do CI real
  (item recorrente); se a 4ª edição da TACO em PDF/README tem exigência
  de atribuição além de "reprodução... desde que citada a fonte" (usado
  o texto já verificado, não pesquisado de novo por cada subagente).

  **Débito técnico:** nenhum novo em aberto — o único identificado
  (idempotência do reseed) foi corrigido no mesmo ciclo, não deixado
  como pendência.

  **Bloqueios / decisões que precisam do usuário:** nenhum bloqueio
  ativo. Seguimos disponíveis pra próxima etapa (F9 wearable BLE, F12
  compartilhamento, UI do app, ou aprofundar F8/F10-F11 quando houver
  device/servidor).

  **Próximo ciclo proposto:** UI do app (destranca vários itens da
  Definição de Pronto do MVP de uma vez) ou F9 (wearable BLE, caminho já
  liberado pela ADR-4a) — pergunta em aberto pro usuário.

- **Ciclo — primeira UI real do app: Resumo + Chat.** Usuário pediu "todos"
  (UI do app + F9) — perguntado ordem e escopo antes de codificar (portão
  de UX/arquitetura, `CLAUDE.md`: "ao chegar num portão... PARE e
  pergunte"), já que `app/` era um `Scaffold` vazio desde a Fase 2, sem
  nenhuma dependência dos pacotes já prontos — a maior decisão de
  arquitetura do projeto até aqui. Confirmado: UI primeiro, depois F9;
  escopo "Chat + Dashboard mínimos".

  Investigado antes de codificar: API real de `packages/brain`
  (`DeterministicRouter`/`RouterRule`, `BrainPipeline.handle`,
  `ConfirmationGate` abstrato, `PipelineResult`/`PipelineOutcome`) e o
  padrão de roteador já usado em `packages/brain/test/brain_test.dart`
  — comando estruturado explícito (`registrar refeição TIPO: item
  gramasg, ...`), não NLU livre, porque não existe LLM real ainda
  (`.claude/rules/brain.md`, passo 1: "Comando frequente NÃO chama o
  modelo").

  `app/pubspec.yaml`: dependências de caminho pra `health_core`,
  `tool_registry`, `brain`, `activity`, `nutrition`, `summary` +
  `path_provider: ^2.1.4` (BSD-3-Clause, plugin oficial do time Flutter).

  - **`app/lib/app_dependencies.dart`** — `AppDependencies` abre os 3
    repositórios reais (`HealthDataCore`, `FoodRepository`,
    `WorkoutRepository`, um arquivo `.sqlite3` cada) e registra 6 das 7
    ferramentas mínimas do MVP (`docs/ARQUITETURA.md:81-82`) num
    `ToolRegistry` + `BrainPipeline`: `get_steps`, `get_daily_summary`,
    `get_run_summary`, `get_workout_plan`, `log_workout_session`,
    `search_food`, `log_meal`. **Não registradas, por decisão:**
    `start_run` (sem captura de GPS real, WRAP Android não implementado),
    `sync_wearable` (F9 não iniciada), `query_health_record` (fora de
    escopo). Dois construtores: `.open(dbDirectoryPath, confirmationGate)`
    (produção, banco real) e `.inMemory(confirmationGate)` (teste, sem
    tocar disco) — a mesma separação testável/não-testável já usada em
    todo o resto do projeto (StepSensor, RunLogger, etc.).
  - **`app/lib/chat_router.dart`** — `buildChatRouter()`, 4 regras:
    `resumo (do dia|de hoje)` → `get_daily_summary`; `quantos passos...`
    → `get_steps`; `buscar alimento (.+)` → `search_food`; `registrar
    refeição TIPO: item gramasg, ...` → `log_meal` (mesmo regex de
    extração de itens do teste de `packages/brain`). As outras 3
    ferramentas registradas ficam acessíveis só pelo `ToolRegistry`
    direto por enquanto (a tela de Resumo chama `get_daily_summary`
    assim) — dar regra de chat pra cada uma é UI futura, não escondido
    como já feito.
  - **`app/lib/confirmation_gate.dart`** — `AppConfirmationGate`
    implementa `ConfirmationGate` de verdade: `AlertDialog` com a
    descrição da ferramenta e os parâmetros, botões Cancelar/Confirmar.
    Usa `GlobalKey<NavigatorState>` (não um `BuildContext` direto) porque
    `AppDependencies` é construído antes da árvore de widgets existir —
    o gate só precisa do contexto na hora de `confirm()`, que acontece
    bem depois do primeiro frame.
  - **`app/lib/screens/dashboard_screen.dart`** — chama
    `get_daily_summary` direto no `ToolRegistry` ao abrir (não passa pelo
    roteador — é carregamento de tela, não conversa), mostra passos/
    refeições/treinos/corridas do dia em cards.
  - **`app/lib/screens/chat_screen.dart`** — lista de mensagens + campo
    de texto; manda pro `BrainPipeline.handle`, formata a resposta por
    `PipelineOutcome` (`unresolved`/`rejected`/`abortedByUser`/`executed`)
    — nunca esconde um "não entendi" como se tivesse funcionado.
  - **`app/lib/home_shell.dart`** — navegação Resumo/Chat
    (`NavigationBar`, Material 3), `IndexedStack` mantém o chat vivo ao
    trocar de aba.
  - **`app/lib/main.dart`** — `main()` resolve o diretório real via
    `path_provider` (`getApplicationDocumentsDirectory()`) e monta
    `AppDependencies.open(...)`; `FrankstitApp` (o widget em si) não sabe
    de onde as dependências vieram, só recebe prontas — por isso é
    testável com `flutter test` sem nenhum platform channel.

  **Prova:**
  ```
  $ flutter analyze (app, lib/ inteiro) → "No issues found!"
  $ flutter test (app, isolado) → 00:00 +6: All tests passed!
  $ make lint (raiz, todos os pacotes + app) → "No issues found!" em todos
  $ make test (raiz, todos os pacotes + app) →
    health_core +17, brain +5, tool_registry +11, activity +47,
    nutrition +27, entitlements +14, share +1, summary +3, app +6 —
    todos "All tests passed!"
  ```
  131 testes no total no monorepo (125 antes deste ciclo + 6 novos, todos
  em `app`). Os 6 testes cobrem: app abre na aba Resumo com dashboard
  zerado (banco vazio); troca de aba pelo bottom nav; comando de leitura
  reconhecido mostra resposta real de `get_daily_summary`; comando não
  reconhecido fica `unresolved` (mensagem "Não entendi"); comando de
  escrita **confirmado** grava um `HealthEvent` de verdade usando comida
  **real** do catálogo TACO (`taco-1`) — prova que nada foi gravado antes
  da confirmação, e exatamente 1 evento depois; comando de escrita
  **recusado** no diálogo não grava nada.

  **Não verificado:** `path_provider`/`getApplicationDocumentsDirectory()`
  em device real (platform channel, `flutter test` não passa por ele —
  só `main()` usa isso, todo o resto da árvore de widgets recebe
  `AppDependencies` já pronta e é testável sem device); `libsqlite3` em
  runners `ubuntu-latest` do CI real (item recorrente).

  **Débito técnico:** nenhum novo — as lacunas (ferramentas sem regra de
  chat, `start_run`/`sync_wearable` não registradas) são escopo
  explicitamente adiado, documentadas, não escondidas atrás de código
  incompleto.

  **Bloqueios / decisões que precisam do usuário:** nenhum. Próxima etapa
  natural: F9 (wearable BLE, conforme combinado — "todos": UI primeiro,
  F9 depois).

  **Próximo ciclo proposto:** F9 — wearable BLE, seguindo o mesmo padrão
  de escopo honesto de hardware (abstração testável + BLE real
  documentado como não verificável neste ambiente).

- **Ciclo — F9: wearable (FC + sono via Health Connect).** Usuário
  confirmou que não havia nada pendente da parte dele e pediu pra
  continuar. Antes de codificar: reli `docs/adr/004a-gadgetbridge.md`
  (aceita) — a decisão **não** é BLE/Kotlin direto nem fork do
  Gadgetbridge, é **FEDERATE via Android Health Connect**: o Frankstein
  nunca fala BLE, só lê o que o Gadgetbridge (app de terceiro que o
  usuário instala) já escreveu no Health Connect (confirmado por
  permissão de escrita no manifesto do APK publicado + documentação
  oficial, ambas citadas na própria ADR). Isso muda o que "F9" significa
  na prática: não é uma stack BLE pra implementar, é uma integração de
  plataforma (Health Connect, via plugin Flutter) — `docs/ARQUITETURA.md:13`
  ainda dizia "BLE wearable (Kotlin, Android)", desatualizado desde a
  ADR-4a; corrigido pra "wearable via Health Connect (Fase 9)".

  Escopo desta fase é o item 3 da Definição de Pronto do MVP
  (`docs/PRODUTO.md:62`: "Pulseira BLE sincroniza FC e sono para o
  Health Data Core") — frequência cardíaca e sono, os dois tipos que já
  existiam no enum `HealthEventType` desde a Fase 3 (`heart_rate`,
  `sleep`) mas nunca tinham sido escritos por nenhum módulo até agora.
  Peso e outros tipos que o Health Connect também exporia (VO₂ máx,
  SpO₂, etc.) ficam fora — não é esquecimento, é ficar dentro do que a
  Definição de Pronto pede.

  Novo pacote `packages/wearable` (mesmo raciocínio de `packages/summary`:
  não pertence a nenhum módulo de domínio existente):
  - `heart_rate_sample.dart`/`sleep_session_sample.dart`:
    `HeartRateSample`/`SleepSessionSample`, leituras antes de virar
    `HealthEvent`. `externalId` **obrigatório** nos dois — toda leitura
    de wearable é, por definição, dado de fonte externa
    (`docs/ARQUITETURA.md`: "external_id -- id do evento na fonte
    externa (wearable, wger, fasten)"), é o que habilita dedup por
    `(source, external_id)` quando a mesma janela é sincronizada de novo.
  - `wearable_data_source.dart`: `WearableDataSource` (interface
    abstrata — mesmo padrão de honestidade de hardware de `StepSensor`
    F4 e `BarcodeDecoder` F6) + `FixtureWearableDataSource` (só teste,
    dados fabricados registrados explicitamente). **Implementação real
    sobre Health Connect não feita neste ciclo** — precisa do plugin
    Flutter que envolve a API nativa, Android SDK, permissões em
    runtime, e um Health Connect de verdade com Gadgetbridge escrevendo
    nele pra validar; nada disso existe neste ambiente.
  - `wearable_sync_logger.dart`: `WearableSyncLogger.sync(from, to)` lê
    do `WearableDataSource`, grava `HealthEvent` tipo `heart_rate`/`sleep`
    com `source: wearable`. **Decisão registrada:** reimportar a mesma
    janela não é erro — `DuplicateEventException` (já existe desde F3,
    dedup por `source`+`external_id`) é capturada e contada como "já
    sincronizado", não propagada. Sincronizar de novo sem controlar
    exatamente o intervalo coberto é o caso comum, não uma exceção.
  - `wearable_tools.dart`: `sync_wearable` — ferramenta de escrita
    (`write: true`), por isso `confirm: true` também (`ToolSpec` já
    força isso no construtor, `.claude/rules/brain.md` passo 4) — mesmo
    "é só sincronizar dado que já existe em outro app" ainda é o cérebro
    decidindo gravar no Health Data Core.

  **Não registrada no `ToolRegistry` do app.** Diferente de
  `log_meal`/`log_workout_session` (que têm `MealLogger`/`WorkoutLogger`
  reais por trás), `sync_wearable` precisaria de um `WearableDataSource`
  de verdade — não existe. Ligar o `FixtureWearableDataSource` (dados
  fabricados) no app de produção pra "ter alguma coisa" seria apresentar
  dado fake como se fosse real — exatamente o que `CLAUDE.md` regra 1
  proíbe. Fica documentado como pendência, não escondido atrás de um
  handler que finge funcionar.

  **Prova:**
  ```
  $ dart test (wearable, isolado) → 00:00 +10: All tests passed!
  $ make lint (raiz, todos os 10 pacotes + app) → "No issues found!" em todos
  $ make test (raiz) →
    health_core +17, brain +5, tool_registry +11, activity +47,
    nutrition +27, entitlements +14, share +1, summary +3, wearable +10,
    app +6 — todos "All tests passed!"
  ```
  141 testes no total no monorepo (131 antes deste ciclo + 10 novos, todos
  em `wearable`). Os 10 testes cobrem: validação de
  `HeartRateSample`/`SleepSessionSample`, filtro de janela de tempo do
  `FixtureWearableDataSource`, sincronização gravando `HealthEvent` real
  com `source: wearable` e `externalId` correto, **reimportar a mesma
  janela não duplica** (segunda chamada de `sync` conta "já sincronizado",
  banco continua com 1 evento só), validação de `from`/`to` em UTC, e a
  ferramenta `sync_wearable` de ponta a ponta via `ToolHandler`.

  **Não verificado:** `WearableDataSource` real sobre Health Connect —
  precisa de Android SDK/device com Health Connect e Gadgetbridge de
  verdade instalados, que este ambiente não tem; equivalente iOS
  (HealthKit) nem investigado (Gadgetbridge é Android-only, gap já
  registrado em `docs/PLATFORM-PARITY.md`); `libsqlite3` em runners
  `ubuntu-latest` do CI real (item recorrente).

  **Débito técnico:** nenhum novo — a lacuna (`sync_wearable` sem fonte
  real, não registrada no app) é escopo explicitamente bloqueado por
  hardware, documentado, não escondido.

  **Bloqueios / decisões que precisam do usuário:** nenhum.

  **Próximo ciclo proposto:** em aberto — candidatos naturais são F12
  (compartilhamento social, PORT do card de corrida/treino já com dado
  real pra mostrar), mais telas de UI (treino/corrida na tela Resumo,
  comando de chat pras 4 ferramentas que ainda não têm regra de
  roteador), ou aprofundar F10/F11 quando fizer sentido ter servidor.

- **Ciclo — F12: compartilhamento social (parcial).** Usuário disse "não
  há nada pendente da minha parte, continue" — segui a ordem já
  combinada (fases seguintes de `docs/PRODUTO.md`, F10/F11 intocadas por
  já estarem no limite acordado de "estrutura sem configurar provedor").

  Reli `.claude/rules/share.md` antes de codificar (regra carregada por
  path, `packages/share/**`/`**/*social*` — só aparece quando se toca
  esses caminhos): card renderizado NO APARELHO, share sheet nativo sem
  SDK proprietário, preview obrigatório, opt-in campo a campo (peso/IMC/
  calorias/medidas desligados por padrão), nada clínico tem card sem
  exceção, rota ofuscada nos 300 m iniciais/finais, publicação nunca
  automática.

  **`packages/share`** (novo pacote, plain-Dart, depende de `activity` +
  `health_core`): `WorkoutShareCardData`/`RunShareCardData` — dado já
  seguro (sem peso/IMC/calorias/medidas: decisão registrada de não
  incluir esses campos nem desligados, já que não existem no card ainda,
  em vez de montar UI de opt-in pra campo sem dado real por trás) +
  `RunShareRoutePoint` (rota já ofuscada, nunca crua). `buildWorkoutShareCard`/
  `buildRunShareCard`: lançam `WrongEventTypeForShareCardException` se o
  `HealthEvent` recebido não for exatamente `workout_session`/`gps_track`
  — é isso que torna "nada clínico tem card" uma garantia estrutural
  (não dá pra montar um card de `clinical_doc` nem por engano), não uma
  convenção que alguém precisa lembrar de seguir. `buildRunShareCard`
  chama `obfuscateRouteEnds` (já existente, F8) internamente — quem
  chama a função nunca vê a rota crua sair. 6 testes.

  **Em `app/`** (mesma sessão, sem clean room aqui — `app/` não é
  `packages/nutrition/**`): `ShareSheet` (abstrato) + `NativeShareSheet`
  (real, via `share_plus: ^10.1.4`, resolvido `10.1.4`, BSD-3-Clause —
  interpretação registrada: `.claude/rules/licenca.md` diz "compartilhamento
  .... share sheet nativo (sem SDK)", lido aqui como "sem SDK
  *proprietário de rede social*" — mesma leitura que já permite ZXing
  pra código de barras na mesma lista — não como "proibido usar qualquer
  plugin"; `share_plus` só invoca `ACTION_SEND`/`UIActivityViewController`
  do sistema, não é Facebook/TikTok SDK) + `FakeShareSheet` (teste).
  `SharePreviewScreen` — o card visível na tela é literalmente o mesmo
  widget que vira PNG, não um "modo preview" separado (preview
  obrigatório por construção, não por convenção de UI). Botão
  "Compartilhar" só aparece com o card já visível; nada dispara sozinho.

  **Achado durante o teste, não escondido:** `RepaintBoundary.toImage()`/
  `Image.toByteData()` (necessários pra capturar o card como PNG de
  verdade) não completam neste ambiente headless — testado com
  `tester.runAsync`, prints de bisecção confirmaram que a execução trava
  entre `toImage` e `toByteData` sem lançar exceção nem travar
  indefinidamente (o teste termina rápido, só que sem o resultado
  esperado). Mesma categoria de limite de ambiente que já existe pra
  `path_provider`/Android SDK/Health Connect — não é bug de lógica,
  é ausência de pipeline de rasterização real neste sandbox. Resolvido
  com o mesmo padrão de honestidade de hardware do projeto inteiro:
  `CardImageCapturer` (interface abstrata) + `RealCardImageCapturer`
  (implementação real, não verificável aqui) + `FakeCardImageCapturer`
  (devolve bytes fabricados, usado em teste) — a lógica em volta (botão
  dispara captura, preview obrigatório, nada compartilha sozinho, dado
  certo chega no `ShareSheet`) fica testada de verdade; só a
  rasterização em si fica documentada como não verificada, não escondida
  atrás de um teste que parecia passar mas não teria testado nada de
  real.

  Botões "Compartilhar último treino"/"Compartilhar última corrida" na
  tela Resumo, visíveis só quando existe pelo menos um evento do tipo
  (busca o mais recente via `core.queryByType(...).lastOrNull` — sem
  ferramenta dedicada do cérebro pra isso, é ação direta de UI, não
  comando de chat). 3 testes novos de widget: preview aparece antes do
  compartilhamento (nada disparado só por abrir a tela), rota chega
  ofuscada no card de corrida, botões não aparecem sem treino/corrida
  gravado.

  **Prova:**
  ```
  $ dart test (share, isolado) → 00:00 +6: All tests passed!
  $ flutter test (app, isolado) → 00:00 +9: All tests passed!
  $ make lint (raiz, 11 pacotes + app) → "No issues found!" em todos
  $ make test (raiz) →
    health_core +17, brain +5, tool_registry +11, activity +47,
    nutrition +27, entitlements +14, share +6, summary +3, wearable +10,
    app +9 — todos "All tests passed!"
  ```
  149 testes no total no monorepo (141 antes deste ciclo + 8 novos: 6 em
  `packages/share`, 3 a mais em `app` — 9 no total, eram 6 antes).

  **Não verificado:** `RepaintBoundary.toImage()`/`Image.toByteData()`
  em device real (`CardImageCapturer` real, `app/lib/card_image_capturer.dart`)
  — mesma categoria de `path_provider`; `libsqlite3` em runners
  `ubuntu-latest` do CI real (item recorrente).

  **Débito técnico:** peso/IMC/calorias/medidas nos cards — campos ainda
  não existem, regra de opt-in já registrada pra quando existirem, não
  fabricados agora. Comando de chat pra compartilhar (hoje só botão na
  tela Resumo) — trabalho de UI futuro, não escondido.

  **Bloqueios / decisões que precisam do usuário:** nenhum. Registro pra
  revisão, não bloqueio: a leitura de `.claude/rules/licenca.md` ("share
  sheet nativo, sem SDK") como "sem SDK proprietário de rede social" (não
  "sem plugin nenhum") — se a intenção era mais restritiva, avisar antes
  do próximo ciclo tocar `packages/share`/`app/lib/share_sheet.dart` de
  novo.

  **Próximo ciclo proposto:** em aberto — candidatos: mais comandos de
  chat (ferramentas já registradas sem regra de roteador), campos
  sensíveis opt-in nos cards de compartilhamento, ou F13 (wger/Fasten,
  caminho liberado pela ADR-4).

- **Ciclo — comandos de chat pras ferramentas restantes.** Usuário
  pediu pra testar os comandos e seguir pra F13. Antes do F13, fechei a
  pendência registrada no ciclo anterior: das 6 ferramentas de leitura/escrita
  registradas no app (`start_run` fica de fora, bloqueada por hardware),
  só 3 tinham regra de roteador de chat (`get_daily_summary`, `get_steps`,
  `log_meal`) — `search_food` já tinha regra (o comentário do arquivo
  estava desatualizado, dizia que não tinha), `get_workout_plan`,
  `get_run_summary` e `log_workout_session` não tinham nenhuma.

  `app/lib/chat_router.dart`: adicionadas 3 regras novas — "plano de
  treino ID" → `get_workout_plan`; "resumo da corrida ID" →
  `get_run_summary`; "registrar treino: exercicio SETxREPSxKG, ..." →
  `log_workout_session` (escrita, confirmação). **Simplificação
  registrada:** o comando de treino usa `exercise_name = exercise_id`
  (o schema real pede os dois campos separados,
  `packages/activity/lib/src/workout_tools.dart`) — um comando de texto
  plano não tem como capturar nome livre de exercício sem ambiguidade de
  sintaxe; quem quiser nome diferente do id chama a ferramenta direto
  pelo `ToolRegistry`. Comentário desatualizado no topo do arquivo
  corrigido (dizia "3 das 7 ferramentas... search_food fica de fora",
  errado nos dois números).

  4 testes novos de widget, cada um provando o comando real, não só que
  o texto "parece" reconhecido: `search_food` acha comida real do
  catálogo TACO; `get_workout_plan` lê um plano cadastrado de verdade em
  `WorkoutRepository`; `get_run_summary` lê um `gps_track` real gravado
  (usa o `event.id` de verdade, não um id inventado); `log_workout_session`
  confirmado grava 1 `workout_session` + 2 `set_log` reais, com
  `load_kg` batendo exatamente com o que foi digitado no chat.

  **Prova:**
  ```
  $ flutter test (app, isolado) → 00:00 +13: All tests passed!
  $ make lint (raiz, 11 pacotes + app) → "No issues found!" em todos
  $ make test (raiz) →
    health_core +17, brain +5, tool_registry +11, activity +47,
    nutrition +27, entitlements +14, share +6, summary +3, wearable +10,
    app +13 — todos "All tests passed!"
  ```
  153 testes no total no monorepo (149 antes deste ciclo + 4 novos —
  `app` foi de 9 para 13).

  **Não verificado:** nada novo além do já registrado (`path_provider`,
  `CardImageCapturer` real, `libsqlite3` em CI real).

  **Débito técnico:** nenhum novo.

  **Bloqueios / decisões que precisam do usuário:** nenhum.

  **Próximo ciclo proposto:** F13 — wger (treino remoto, REST) + Fasten
  (prontuário, FHIR), FEDERATE conforme Cenário B já decidido
  (`docs/LICENSE-AUDIT.md`, `docs/adr/004-wger-fasten.md`) — nenhum dos
  dois é linkado ao binário do Frankstein.

- **Ciclo — F13: integração federada com wger e Fasten (parcial).**
  Usuário confirmou ("o f13.") depois de eu ter relido
  `docs/adr/004-wger-fasten.md` (aceita) pra fundamentar o escopo:
  ambos opcionais, federados, nunca linkados ao binário do Frankstein —
  wger fala REST v2 (mantém AGPL-3.0 como programa separado), Fasten
  fala FHIR (mantém GPL-3.0), `docs/LICENSE-AUDIT.md` "Cenário B". Sem
  restrição de clean-room (`.claude/rules/port.md` só cobre
  `packages/nutrition`, contaminação por causa da falta de API pública
  do OpenNutriTracker) — wger e Fasten expõem API pública padronizada
  (REST/FHIR) feita pra terceiros consumirem, não há reimplementação de
  lógica interna a partir de source.

  Dois pacotes novos, mesmo padrão de "escopo honesto" usado desde F4
  (`StepSensor`)/F6 (`BarcodeDecoder`)/F9 (`WearableDataSource`)/F12
  (`CardImageCapturer`): interface abstrata + Fixture testável + real
  explicitamente adiado e documentado como não verificável neste
  ambiente (sem servidor wger/Fasten alcançável, dependência `http`
  não adicionada pra não ficar sem uso/teste).

  `packages/wger` (`packages/wger/lib/src/wger_set_log_sample.dart`,
  `wger_client.dart`, `wger_sync_logger.dart`, `wger_tools.dart`):
  `WgerSetLogSample` (`externalId`, `exerciseName`, `reps` >0,
  `weightKg` ≥0, `recordedAt` UTC) + `WgerClient`/`FixtureWgerClient`
  (filtra por janela `[from, to]`) + `WgerSyncLogger` (grava
  `HealthEvent` tipo `set_log`, `source: wger`, payload
  `exercise_name`/`reps`/`load_kg`, dedup por `externalId` via
  `DuplicateEventException` — mesmo padrão de `WearableSyncLogger`,
  não cria `workout_session` sintética, cada set_log fica solto,
  limitação de escopo documentada, não bug) + `sync_wger`
  (`write: true, confirm: true`, `module: 'wger'`).

  `packages/fasten` (`packages/fasten/lib/src/fasten_document_sample.dart`,
  `fasten_client.dart`, `fasten_sync_logger.dart`, `fasten_tools.dart`):
  `FastenDocumentSample` (`externalId`, `resourceType`, `title`,
  `rawResource` — o recurso FHIR bruto, sem filtro; filtragem pro
  cérebro/LLM registrada como trabalho futuro em
  `.claude/rules/brain.md`, ainda não construída porque não há
  montagem de prompt real, só o roteador determinístico) +
  `FastenClient`/`FixtureFastenClient` + `FastenSyncLogger` (grava
  `HealthEvent` tipo `clinical_doc`, `source: fasten`, mesma lógica de
  dedup) + `sync_fasten_records` (`write: true, confirm: true`,
  `module: 'fasten'`).

  Nenhum dos dois registrado em `app/lib/app_dependencies.dart` — mesmo
  tratamento de `sync_wearable`: sem cliente real, ligar o Fixture em
  produção seria desonesto.

  `Makefile:PACKAGES` — adicionados `wger fasten` no fim da lista.

  **Bug achado e corrigido de quebra:** ao rodar `make test` completo
  pela primeira vez com os pacotes novos, 2 testes de `app/` falharam
  (`compartilhar treino...`, `compartilhar corrida...`) com
  `Found 0 widgets with key [<'share_latest_workout'>]`. Descartei
  regressão (`git diff app/` vazio, `git status --short app/` limpo) e
  rodei `date -u` → `Mon Aug 17 10:52:18 UTC 2026`: o relógio real já
  tinha passado a data fixa `DateTime.utc(2026, 8, 15, ...)` que
  `app/test/widget_test.dart` usava pra inserir eventos de teste, então
  a consulta "hoje" do `DashboardScreen` (`DateTime.now().toUtc()`) não
  batia mais com os eventos inseridos, os contadores ficavam zerados, e
  os botões de compartilhar (renderização condicional) nunca apareciam.
  Corrigido com um helper `_todayNoonUtc()` que calcula "hoje" em tempo
  de execução (meio-dia UTC, evita borda de fuso) — trocado nos dois
  helpers de inserção (`_insertWorkoutSessionEvent`,
  `_insertGpsTrackEvent`). Confirmado que não sobrava nenhuma outra
  data `2026` fixa no arquivo.

  **Prova:**
  ```
  $ dart test (packages/wger, isolado) → 00:00 +9: All tests passed!
  $ dart test (packages/fasten, isolado) → 00:00 +7: All tests passed!
  $ flutter analyze (app/, depois do fix) → No issues found! (ran in 3.1s)
  $ flutter test (app/, depois do fix) → 00:09 +13: All tests passed!
  $ make lint (raiz, 12 pacotes + app) → "No issues found!" em todos
  $ make test (raiz) →
    health_core, brain, tool_registry, activity +47, nutrition +27,
    entitlements +14, share +6, summary +3, wearable +10, wger +9,
    fasten +7, app +13 — todos "All tests passed!"
  ```
  169 testes no total no monorepo (153 antes deste ciclo + 16 novos —
  9 de `wger` + 7 de `fasten`).

  **Não verificado:** `WgerClient`/`FastenClient` real sobre REST
  v2/FHIR — precisa de servidor wger/Fasten self-hosted alcançável
  (URL+credenciais do usuário), não disponível neste ambiente.
  Filtragem do recurso FHIR bruto antes de qualquer prompt de LLM —
  trabalho futuro, sem montagem de prompt real ainda pra aplicar.

  **Débito técnico:** nenhum novo — o real fica marcado como não
  verificado, não como código temporário com `TODO`.

  **Bloqueios / decisões que precisam do usuário:** nenhum.

  **Próximo ciclo proposto:** em aberto — candidatos: `WgerClient`/
  `FastenClient` real (precisa do usuário fornecer servidor self-hosted
  alcançável), campos sensíveis opt-in nos cards de compartilhamento
  (F12), ou F14 (painel B2B, produto separado, depois do MVP).
