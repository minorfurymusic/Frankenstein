# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.
>
> Histórico completo de ciclos: `docs/HISTORICO.md`. Este arquivo só guarda o
> estado **atual** — consulte o histórico sob demanda, não por hábito.

**Fase:** **F3, F4, F5, F6, F7, (parcial) F8, (parcial) F9, (parcial)
F12 e (parcial) F13 concluídas + primeira UI real do app.** Health Data
Core, passos, o pipeline do cérebro, nutrição (**catálogo real** —
Tabela TACO, 578 itens), academia, corrida/caminhada (parte sem Android
real), wearable (FC/sono via Health Connect, parte sem Health Connect
real), compartilhamento social (cards de treino/corrida, parte sem
rasterização real do engine), integração federada com wger/Fasten
(parte sem servidor real). Esqueleto de Entitlements/Pagamento (F10/F11,
sem provedor configurado). Seis ferramentas novas do cérebro
(`get_daily_summary`, `search_food`, `sync_wearable`, `sync_wger`,
`sync_fasten_records`, e o fluxo de compartilhamento embora `share_card`
não seja uma tool do cérebro em si). `app/` deixou de ser tela em
branco: navegação Resumo/Chat de verdade, ligada aos pacotes reais, com
compartilhamento de treino/corrida funcionando de ponta a ponta. Detalhe
completo em `docs/HISTORICO.md`.

**Ciclo mais recente (2026-10-05): peso desejado.** Decisão do usuário na
ADR-17: campo opcional em Conta › Perfil que comanda o objetivo — acima do
peso desejado por mais de 1 kg perde, abaixo ganha, dentro de ±1 kg mantém
(passa sozinho para manutenção ao chegar). Calorias, proteína e "meta do
dia cumprida" usam o objetivo efetivo (`Profile.effectiveObjective`,
`DailyGoals.objective`). Perfil mostra o objetivo atual, a previsão pelo
ritmo ("~N semanas, por volta de dd/mm — estimativa") e o IMC do peso
desejado (só informação, nada travado). Corpo e Nutrição › Tendências
ganharam a linha do peso desejado e o resumo; Metas mostra de onde veio
o objetivo. Coluna `target_weight_kg` com migração testada; entra na
exportação.

**Ciclo anterior (2026-10-05): IA com a chave Gemini e leitura de exame.**
Provedor decidido pelo usuário (ADR-11 revisão 1): Gemini, com a chave
dele. Novo pacote `packages/ai` (REST direto, sem SDK; endereço e campos
conferidos no código do SDK oficial): resposta em JSON validada por JSON
Schema, no máximo 2 tentativas, erros traduzidos (chave recusada, limite,
sem rede, bloqueado, arquivo grande). Chave cifrada pelo Android Keystore
(`SecureStore.kt`), fora do banco, apagada com "Apagar chave" e "Apagar
todos os dados". Backup automático do Android desligado (levaria os dados
de saúde para a nuvem do Google sem ação da pessoa). Conta › Cérebro (IA)
no layout: testar e salvar a chave, apagar, modelo (padrão
`gemini-flash-latest`), o que é enviado, consentimento. Consentimento
antes do primeiro envio (prancheta CerebroConsentimento). **Exame:** ao
anexar foto ou PDF, com a IA ativa, o app lê nome, data, categoria e
valores (unidade e faixa do laudo, ADR-16) e preenche o formulário como
"Valores lidos — Estimativa"; nada é salvo sem "Salvar". Sem chave,
aparece o convite para ativar; digitar continua possível. Não verificado
com a API real (rede de desenvolvimento bloqueia o Google). Corrigido de
carona: a agenda de remédios só via o "tomei" marcado até 2 dias depois da
dose; agora vê marcações feitas a qualquer momento.

**Ciclo anterior (2026-10-03): corrida e caminhada com GPS.** Gravador
próprio (ADR-9 revisão 1): `RunRecorderService.kt` (serviço em primeiro
plano, `LocationManager` do Android, sem Play Services) grava cada ponto na
hora em `run_current.jsonl`; se o app/processo cair, o Android recria o
serviço e continua num trecho novo, e o histórico oferece salvar a
gravação interrompida. Pausa manual e automática (parado ~8 s com sinal
bom) abrem trechos; o caminho pausado não conta. `RunCalculator` agora
soma distância/tempo/parciais só dentro do trecho e tira saltos
impossíveis (> 12 m/s) antes do ritmo; `RunLogger` grava o tipo (corrida
ou caminhada) e o início de cada trecho no payload. Telas: Iniciar (tipo,
permissão de localização, GPS do celular, pausa automática), Ao vivo
(tempo ativo, km, ritmo atual dos últimos 30 s, ritmo médio, sinal do
GPS, pausar/retomar, terminar → salvar/descartar) e o resumo com o traço
da rota (sem mapa de fundo). Permissões mostra a localização real. Só
localização "enquanto usa" — nada em segundo plano. A notificação dos
passos passou a usar `NotificationCompat` (o construtor anterior não existe
no Android 7, onde o app instala) e diz "RLT". Não verificado no aparelho;
bateria (< 8%/hora) só se mede lá (`docs/PERF.md` ainda não existe).

**Ciclo anterior (2026-10-03): valores de exame.** Decisão do usuário
registrada na ADR-16 (valor e faixa de referência na unidade do próprio
laudo — exceção à regra de SI só para exames) e revisão 1 da ADR-9
(gravador de GPS próprio, sem OpenTracks). Exame ganhou "Valores do exame"
(nome, valor, unidade do laudo, faixa do laboratório; `ExamMarker`, coluna
`markers` com migração testada de banco antigo), "Marcadores acompanhados"
na lista (último valor e direção desde o anterior) e a tela do marcador
(última/anterior, gráfico por 6 meses/1 ano/tudo, faixa do laboratório,
medições, aviso de que fora da faixa não é diagnóstico; nunca rotula
alto/baixo/normal). Valores entram na exportação. A leitura automática da
foto/PDF preenche este mesmo formulário quando a IA (ADR-11) tiver
provedor.

**Ciclo anterior (2026-10-03): meta de sono e foto da receita própria.**
Meta de sono editável em Conta › Metas (`GoalOverrides.sleepMinutes`,
padrão 8 h da prancheta Sono), usada no gráfico da semana. Receita própria
ganhou "Adicionar foto" (câmera ou galeria, pasta privada do app),
miniatura na lista e entra no `.zip` da exportação. Dois TODOs que já não
valiam saíram (lembrete do remédio já é notificação de verdade; leitor
ZXing já existe).

**Ciclo anterior (2026-10-03): pulseira pelo Health Connect.** ADR-4a
(FEDERATE) virou código: `HealthConnectBridge.kt` só **lê** sono (com
fases) e frequência cardíaca, canal `rlt/health_connect`; Dart
`HealthConnectDataSource` + `WearableSync` (`app/lib/wearables/`)
gravam via `WearableSyncLogger` (dedup por `external_id`; 30 dias na
primeira leitura, depois desde a última com 2 dias de sobreposição).
Conta › Dispositivos (conectar, dados lidos, sincronizar, abrir o Health
Connect, desconectar; "instalar" quando falta), Sono no layout (última
noite com fases, semana contra "Meta 8 h" da prancheta), Permissões com o
estado real, Privacidade explica a leitura (o Health Connect abre essa tela
pelo `VIEW_PERMISSION_USAGE`/rationale). Lê ao abrir o app se conectado.
Bibliotecas Android: `androidx.health.connect:connect-client` 1.1.0
(Apache-2.0; AndroidX, coroutines, Guava, protobuf-lite — sem Play
Services; pede API 26, então `tools:overrideLibrary` e nada roda abaixo
da API 28, onde o Health Connect existe) e `kotlinx-coroutines-android`
1.8.1 (Apache-2.0). Passos continuam do sensor do celular (não lê passos do
Health Connect, para não contar em dobro). Não verificado no aparelho; o
Kotlin só compila na CI.

**Ciclo anterior (2026-10-03): receitas médicas e exames.**
Foto (câmera ou galeria) ou PDF guardados na pasta privada do app
(`rlt_documentos/`), com cadastro em `HealthDocumentRepository`
(`packages/health_records`, tabela própria no banco de remédios, como o
histórico médico): receita com quem receitou, especialidade, data,
validade (mostra "Válida até"/"Vencida em") e remédios vinculados; exame
com nome, categoria (sangue, imagem, urina, outros) e data, com filtro.
Tela cheia com pinça para ampliar; PDF desenhado pelo `PdfRenderer` do
próprio Android (`PdfPages.kt`, sem biblioteca de PDF). Exportação virou
`.zip` (`dados.json` + `arquivos/`); "apagar tudo" apaga também a pasta.
Bibliotecas: `image_picker` 1.2.2 e `file_selector` 1.1.0 (BSD-3, Flutter),
`archive` 4.3.0 (MIT). O manifesto remove o marcador do Google Play
Services que o `image_picker_android` declara (seletor de fotos
retroportado). **Fora deste ciclo, depende de decisão:** valores lidos do
exame e gráfico por marcador (unidade como está no papel × regra de SI;
leitura automática depende da IA, ADR-11). Não verificado no aparelho.

**Ciclo anterior (2026-10-03): código de barras pela câmera.**
`flutter_zxing` 2.2.1 (MIT; leitor zxing-cpp embutido, Apache-2.0/BSD-3,
compilado no APK — sem serviço do Google), que traz `camera` 0.11.4 /
`camera_android_camerax` 0.6.30 (BSD-3; AndroidX CameraX e Guava,
Apache-2.0), `image_picker` (BSD-3, não usado — galeria desligada),
`image` 4.10.1, `archive` 4.3.0 e `posix` 6.5.2 (MIT). Só lê EAN/UPC;
a imagem não é gravada nem enviada; "Digitar o código" continua. O
manifesto remove microfone e armazenamento que o plugin de câmera
declararia. Fora do Android (testes) vai direto para a digitação. Não
verificado no aparelho; o APK só é montado na CI (aqui não há Android SDK).

**Ciclo anterior (2026-10-03): lembretes no celular.** Kotlin próprio
(`Reminders.kt`: AlarmManager `setAndAllowWhileIdle` + notificação do
Android, reagenda no boot), sem biblioteca nova — o plugin
flutter_local_notifications foi descartado porque exige embutir
`desugar_jdk_libs`, cuja licença não deu para confirmar daqui. Dart planeja
7 dias (remédios com lembrete ligado, água a cada N h das 8h às 22h,
treino) e replaneja quando os dados mudam e a cada abertura. Permissão de
notificação pedida só ao ligar um lembrete. Não verificado no aparelho.

**Ciclo anterior (2026-10-03): histórico médico.** Condições e
diagnósticos informados, alergias, cirurgias, vacinas e consultas
(`MedicalHistoryRepository` em `packages/health_records`, tabela própria —
cadastro, não `HealthEvent`), com formulário, edição, apagar e exportação.
App: 92 testes; health_records: 25.

**Ciclo anterior (2026-10-03): primeiro uso.** Boas-vindas,
privacidade, perfil (ou "depois"), metas sugeridas calculadas, permissão de
passos explicada antes de pedir (com "agora não"), IA opcional. Aparece só
sem perfil e sem ter concluído antes (APK antigo com perfil não vê). No
primeiro uso a permissão de passos não é mais pedida na abertura — só no
passo dela. Login Google entra na rodada de testes (ADR-13). App: 91 testes.

**Ciclo anterior (2026-10-03): telas restantes da Conta.** Privacidade
e dados (exportar tudo em JSON pelo compartilhamento — grátis, sem limite;
apagar tudo com "APAGAR" digitado, que apaga os arquivos do banco sem
mexer na regra "só acrescenta"), Excluir conta (mesmo fluxo; conta Google
entra com o login), Permissões (estado real dos passos; as outras dizem
"ainda não usada"), Dispositivos, Assinatura (plano Grátis, lista Premium
da ADR-14, sem preço) e Cérebro (IA) (modo básico, o que é enviado e o que
nunca vai). App: 88 testes.

**Ciclo anterior (2026-10-03): Cérebro com cartões de proposta.** O
chat virou o Cérebro: cada comando de escrita aparece como cartão de
proposta na conversa (confirmar/descartar; "Salvo em …"), respostas de
leitura em português legível, exemplos clicáveis, aviso de modo básico,
"nova conversa". Roteador aceita refeição em português (café da manhã,
almoço, jantar, lanche) e usa a data local. IA em nuvem (ADR-11) segue
pendente da escolha de provedor. App: 83 testes.

**Ciclo anterior (2026-10-03): Início no layout novo + resumo no dia
local.** Início: saudação, dia anterior/calendário, sequência de dias
registrando, metas do dia (anel, macros, água, passos, exercício —
referência OMS de 30 min/dia), remédios de hoje com tomei/pulei, sono da
última noite, linha do tempo de tudo do dia, 6 atalhos rápidos, estados de
dia vazio e passos sem permissão. Lembretes (remédio/água/treino, escolhas
salvas; o aviso no celular entra nas integrações). `get_daily_summary`
corrigido para o dia local (teste de regressão das 22:00). Painel antigo e
telas de registro antigas removidos; testes de compartilhar migrados para
Exercícios. App: 79 testes.

**Ciclo anterior (2026-10-03): aba Exercícios.** Hoje (anel de
passos, minutos ativos, calorias gastas, distância, próximo treino em
rodízio, atividades do dia), Passos (estado do sensor, semana/mês),
Academia (planos criar/editar/apagar, biblioteca com 35 exercícios e
filtro por grupo, histórico, recordes, progressão por exercício), Treino ao
vivo (séries com carga/reps/RPE, descanso de 90 s, finalizar grava com
duração), Corrida e caminhada (histórico, resumo, parciais, exportar GPX,
compartilhar), Outras atividades (10 tipos × 3 intensidades). O gasto dos
exercícios agora entra na meta do dia (ADR-15). Em construção: gravação ao
vivo pelo GPS e mapa (integrações). App: 77 testes; activity: 52.

**Ciclo anterior (2026-10-03): aba Nutrição + metas revistas.** Metas:
proteína por objetivo e treino (RDA 0,8 / Leidy 1,2 / ISSN 1,6–2,0; +0,4
"quero mais proteína"), fibra 14 g/1.000 kcal (mín. 25 g), **sem trava**
abaixo do gasto em repouso (decisão do usuário). Nutrição: Hoje (anel,
macros, fibra, água +200/+300/+500, refeições do dia, fechar o dia),
Adicionar alimento (busca TACO, código de barras digitado, adição rápida,
recentes/favoritos/meus itens), Detalhe com tabela nutricional, Diário
(calendário dentro/fora da meta), Tendências (sequência, médias, gráficos),
Dieta e metas (restrições), Receitas próprias. Em construção: câmera do
código de barras, foto do prato, galeria (câmera/IA), plano de refeições,
peso desejado. App: 73 testes.

**Ciclo anterior (2026-10-02): perfil e metas.** Pacote novo
`packages/profile` (perfil, ajustes manuais, preferências; calculadora da
ADR-15 com coeficientes conferidos, 18 testes com valores calculados à
mão). Telas Conta › Perfil, Metas (meta do dia + "de onde veio o número" +
ajuste manual) e Preferências (tema claro/escuro/sistema guardado). Corpo
mostra IMC (faixas OMS) e cintura/altura. `app/lib/data/day_read_model.dart`
soma o dia **local** de cada evento. **Achado:** `get_daily_summary`
(`packages/summary/lib/src/daily_summary_tools.dart`) soma o dia UTC — no
Brasil, o que acontece depois das 21:00 cai no dia seguinte; as telas novas
já usam o dia local, a ferramenta será corrigida no ciclo do Início.

**Ciclo anterior (2026-10-02): aba Saúde.** Tela inicial (resumos +
seções + aviso fixo), Remédios (agenda de hoje com tomei/pulei gravando
`medication_dose`, adesão de 30 dias, ativos/encerrados, cadastro/edição,
encerrar tratamento), Histórico médico (diário de sintomas + formulário),
Sinais vitais (5 tipos, gráfico 7/30/90 dias, registro manual), Corpo (peso,
% gordura, 7 medidas, gráfico), Sono (noites da pulseira). Formulários
gravam direto pelos loggers no toque em "Salvar" (o toque é a confirmação;
o cartão do pipeline é para o que a IA propõe). Leitura em
`app/lib/data/health_read_model.dart` (SI → unidade clínica). Ainda em
construção: Receitas e Exames (precisam de câmera/arquivo), condições/
consultas (dado novo), IMC e cintura/altura (precisam da altura do Perfil),
lembrete de remédio (notificação local). `make test`: app 57 testes.

**Ciclo anterior (2026-10-02): base visual do RLT.** Tema claro/escuro
com os tokens do layout (`app/lib/theme/`), Figtree embutida (OFL 1.1,
instâncias estáticas 400–800 geradas por `tool/fonts/make_figtree_instances.sh`,
licença em Conta > Sobre), componentes da prancheta Componentes
(`app/lib/widgets/`: cartão de proposta em 4 estados, cartão de remédio,
anel, barra de macro, linha do tempo, selos, aviso de saúde, estados
vazio/sem permissão/sem internet/carregando, campo de mensagem com voz,
barra de 5 abas com Cérebro no centro), shell de 5 abas + Conta pelo avatar,
nome "RLT" no Android. Saúde/Nutrição/Exercícios ainda dizem "em construção"
(próximo ciclo). Antes, no mesmo dia: ADR-15 ganhou água por kg com piso
EFSA por sexo, o modelo de meta de calorias descrito pelo usuário e a
proposta de divisão de macros (números aguardam aprovação). CI do commit
`98a3af1` (runs `37037454729`/`37037452301`): `conclusion: success`, APK no
artefato `frankstein-debug-apk`. Fórmulas da ADR-15 aprovadas (sem teto de
ritmo de perda). `applicationId` = `br.com.rlt.app` (site rlt.com.br).
**Pendente do usuário:** ícone do app (vai mandar depois).

**Ciclo anterior (2026-10-02): revisão do layout do Claude Design.**
Sem código. Layout salvo em `docs/design/rlt-layout/` (81 pranchetas +
`canvas.json`), revisão em `docs/design/REVISAO-LAYOUT.md`: todas as seções
do prompt cobertas; nenhuma violação de regra (preço, anúncio, login extra,
diagnóstico, publicação automática, iOS). Uma divergência de monetização:
"Relatórios para levar à consulta" e "Mais espaço para fotos e exames"
aparecem como Premium sem estar em `docs/MONETIZACAO.md`. **Decidido no
mesmo dia:** ADR-14 (relatório é Premium; "mais espaço" removido), ADR-15
(fórmulas de saúde aprovadas, coeficientes a conferir na fonte antes de
codificar), ADR-13 atualizada (login entra no início da rodada de testes;
servidor em aberto), `CLAUDE.md` atualizado (IA em nuvem, fase atual).

**Ciclo anterior (2026-10-02): camada de dados da aba Saúde.** Pacote
novo `packages/health_records`: remédios (catálogo editável + agenda
calculada por dia + doses tomadas/puladas como eventos `medication_dose`,
inclusive dose avulsa sem cadastro), sintomas, sinais vitais (pressão,
glicemia, temperatura, saturação; FC manual na série `heart_rate`) e corpo
(peso, circunferências, % de gordura). Banco em SI, conversão pra unidade
clínica em `units.dart`. 6 ferramentas do cérebro registradas no app
(`add_medication`, `log_medication_dose`, `get_medication_agenda`,
`log_symptom`, `log_vital_sign`, `log_body_measurement`). 4 tipos novos de
`HealthEvent`. Hook `.claude/hooks/lib.sh` ajustado (autorizado) pra
entender ADR substituída. Sem tela ainda — aguarda o layout do Claude
Design. Sem regra de chat ainda pra essas ferramentas (a IA em nuvem é que
vai chamá-las). `make lint` 13/13, `make test` 13/13 suítes, 214 testes.

**Ciclo anterior a esse (2026-10-02): decisões de produto + prompt de design.**
Sem código. ADR-11 (IA em nuvem com chave do usuário, substitui ADR-2),
ADR-12 (Android apenas, nome RLT), `.claude/rules/brain.md` reescrita pra
ADR-11, `docs/PRODUTO.md`/`docs/OFFLINE-IA.md`/`docs/MONETIZACAO.md`
apontando pra nova decisão, e `docs/design/PROMPT-CLAUDE-DESIGN.md` (todas as
telas e funções, pro Claude Design). CI do contador de passos (run
`32064428426`, commit `cb4b362`) confirmou `conclusion: success` — o Kotlin
compila; o APK desse run expirou (retenção de 14 dias). Contador de passos
continua sem teste em aparelho. **Aguardando:** layout do Claude Design;
aprovação das fórmulas de saúde.

**Ciclo anterior: contador de passos real — primeiro código Kotlin
do projeto.** Foreground service Android (`StepCounterService.kt`)
ouvindo `TYPE_STEP_COUNTER`, com notificação persistente e
`START_STICKY` — cumpre `.claude/rules/activity.md` ("a contagem NÃO
pode parar com a tela bloqueada, esse é o bug que matou o projeto
anterior"). `MainActivity.kt`: `MethodChannel`/`EventChannel` (start/
stop do service, permissão `ACTIVITY_RECOGNITION` em runtime, leitura
sob demanda). `app/lib/step_sensor_android.dart` implementa `StepSensor`
(interface que já existia desde F4, nunca implementada) sem tocar
`StepsRepository`. `app/lib/step_tracking_controller.dart` decide a
política de "quando persistir" que `StepsRepository` deliberadamente não
decide — flush a cada 5 min + ao pausar o app — e expõe
`StepTrackingStatus` (`unknown`/`unsupportedPlatform`/`noSensor`/
`permissionDenied`/`active`) que o card de Passos do dashboard reflete
ao vivo. 8 testes novos usando platform channel mockado
(`TestDefaultBinaryMessengerBinding`) — a única coisa que fica **não
verificada** é o sensor disparando de verdade e o service sobrevivendo
à tela bloqueada num device real (sem `adb`/device neste ambiente; CI
só confirma que o Kotlin compila). Nova dependência:
`androidx.core:core-ktx 1.13.1` (Apache-2.0, AndroidX oficial, não é
Play Services/GMS/Firebase — `.claude/rules/licenca.md`).

**Ciclo anterior: dashboard mínimo funcional — água, refeição e
treino registráveis por toque, sem digitar comando de chat.** Primeiro
teste real em Android confirmou o app abrindo (fix do
`sqlite3_flutter_libs`) mas revelou o dashboard "morto": das 4 métricas,
só Refeições/Treinos tinham qualquer jeito de gravar dado, e só via
comando de chat digitado (regex exata). Layout final do dashboard
desenhado de uma vez (5 cards: Passos, Água, Refeições, Treinos,
Corridas) pra não precisar redesenhar a cada função nova — Passos e
Corridas ficam com placeholder honesto ("sem sensor real ainda"/"requer
GPS real") porque dependem de trabalho de plataforma nativa Android,
fora deste ciclo. Água/Refeições/Treinos ganharam ação "+" real:
- **Tipo `water` novo** (`packages/health_core`, `docs/ARQUITETURA.md:31-32`,
  `.claude/rules/datacore.md`) — fechava pendência registrada desde
  `docs/specs/nutricao.md`. `packages/nutrition`: `WaterLogger`/
  `log_water` (escrita com confirmação, payload `{amount_ml}`, mesmo
  padrão de `MealLogger`/`log_meal`).
- `get_daily_summary` soma água do dia (`packages/summary`).
- `app/lib/screens/log_meal_screen.dart` (busca real no catálogo TACO +
  toque + gramas) e `log_workout_screen.dart` (formulário) — nenhum dos
  dois reimplementa a lógica de escrita: montam o mesmo texto que o
  roteador de chat aceita e mandam pro mesmo `BrainPipeline.handle`,
  reaproveitando a confirmação humana já existente
  (`.claude/rules/brain.md`, passo 4).
- Diálogo rápido de água inline no dashboard (presets 200/300/500ml +
  quantidade customizada), mesmo caminho de confirmação.
- 3 widget tests novos, ponta a ponta, com dado real gravado no
  `HealthDataCore` (não mock de UI).

**Ciclo anterior: CI publica APK debug como artifact (MVP pra teste
manual).** Sandbox de dev não tem Android SDK (`dl.google.com` bloqueado
pela política de rede do ambiente) — CI (`ubuntu-latest`) já compilava
via `make build`, mas descartava o resultado com o runner.
`.github/workflows/ci.yml`: passo `actions/upload-artifact@v4` publica
`app-debug.apk` (assinatura debug padrão do Flutter, 14 dias de
retenção). Baixar em qualquer run verde da CI, aba "Actions" do
GitHub → run → "Artifacts" → `frankstein-debug-apk`. **Não é canal de
distribuição real** (ADR-7 continua em aberto quanto a isso) — é só
instalação manual pra teste, com "instalar de fontes desconhecidas"
liberado manualmente no aparelho.

**Ciclo anterior: F13 — integração federada com wger e Fasten
(parcial).** `docs/adr/004-wger-fasten.md` (aceita): ambos opcionais,
federados, nunca linkados ao binário do Frankstein — wger fala REST v2
(mantém AGPL-3.0 como programa separado), Fasten fala FHIR (mantém
GPL-3.0). Sem restrição de clean-room (`.claude/rules/port.md` só cobre
`packages/nutrition`) — ambas são APIs públicas padronizadas pra
consumo por terceiros. Dois pacotes novos, mesmo padrão de "escopo
honesto" de F4/F6/F9/F12: `packages/wger` (`WgerSetLogSample`,
`WgerClient`/`FixtureWgerClient`, `WgerSyncLogger` grava `set_log` com
`source: wger`, `sync_wger` — escrita com confirmação) e
`packages/fasten` (`FastenDocumentSample` guarda o recurso FHIR bruto,
`FastenClient`/`FixtureFastenClient`, `FastenSyncLogger` grava
`clinical_doc` com `source: fasten`, `sync_fasten_records` — escrita com
confirmação). Cliente HTTP/FHIR real não escrito — sem servidor
wger/Fasten alcançável neste ambiente, dependência `http` não
adicionada pra não ficar sem teste. Nenhum dos dois registrado em
`app/` (mesmo tratamento de `sync_wearable`: sem cliente real, seria
desonesto ligar o Fixture em produção). De quebra: corrigido um bug
latente em `app/test/widget_test.dart` — datas fixas (`DateTime.utc(2026,
8, 15, ...)`) que quebravam assim que o relógio real passava do dia
fixado (aconteceu neste ciclo, `date -u` mostrou 17/08); trocado por
`_todayNoonUtc()`, calculado em tempo de execução.

**Ciclo anterior: F12 — compartilhamento social (parcial).**
`.claude/rules/share.md`: card renderizado no aparelho, preview
obrigatório, opt-in por campo, nada clínico, rota ofuscada, publicação
nunca automática. Pacote `packages/share`: `WorkoutShareCardData`/
`RunShareCardData` + `buildWorkoutShareCard`/`buildRunShareCard` — **nunca
aceitam `HealthEvent` de tipo clínico** (checagem estrutural, não
convenção), reutilizam `obfuscateRouteEnds` (F8) pra rota. Em `app/`:
`SharePreviewScreen` (o card visível na tela é literalmente o mesmo
widget capturado — preview = o que sai, sem diferença), `ShareSheet`
(real via `share_plus`, BSD-3-Clause — só invoca o share sheet nativo do
SO, não é SDK de rede social), `CardImageCapturer` (abstrai
`RepaintBoundary.toImage()`, que **não completa neste ambiente headless**
— mesma categoria de `path_provider`; a lógica em volta — botão dispara
captura, preview obrigatório, nada compartilha sozinho — é testada com
`FakeCardImageCapturer`, só a rasterização real do engine fica não
verificada). Sem campos sensíveis (peso/IMC/calorias/medidas) ainda —
decisão registrada, não fabricados pra ter uma UI de opt-in sem dado
real por trás.

**Não registradas ainda no app:** `start_run` (precisa de captura de GPS
real), `sync_wearable` (precisa de `WearableDataSource` real sobre
Health Connect), `sync_wger`/`sync_fasten_records` (precisam de cliente
HTTP/FHIR real sobre servidor wger/Fasten alcançável), `query_health_record`
(fora do escopo até agora).

**Pendências ativas (revisado):**
- **Adiado por decisão, não por bloqueio técnico:** `BarcodeDecoder`
  concreto com `flutter_zxing` em `app/` — sem câmera/emulador real pra
  validar.
- `start_run` (F8) e a captura de GPS real (WRAP OpenTracks Android,
  PORT iOS) — próximo item de plataforma nativa, mesma categoria do
  contador de passos (agora implementado); ainda não feito.
- Sensor de passos real disparando de fato e `StepCounterService`
  sobrevivendo à tela bloqueada (`.claude/rules/activity.md`) — código
  implementado e CI confirma que compila, mas só teste manual em device
  (você) confirma que funciona de verdade; primeiro código Kotlin do
  projeto, sem precedente local pra comparar.
- `WearableDataSource` real sobre Health Connect (F9) — precisa do
  plugin Flutter que envolve a API nativa + Android SDK/device com
  Health Connect e Gadgetbridge de verdade instalados
  (`docs/adr/004a-gadgetbridge.md`). Equivalente iOS (HealthKit) nem
  investigado — Gadgetbridge é Android-only.
- `path_provider` e `CardImageCapturer` real (F12) — platform
  channel/pipeline de rasterização real, não verificáveis em
  `flutter test`/sem device. Todo o resto do app é testável e testado
  sem isso.
- `WgerClient`/`FastenClient` real sobre REST v2/FHIR (F13) — precisa de
  servidor wger/Fasten real alcançável (self-hosted, URL+credenciais do
  usuário), não disponível neste ambiente; dependência `http` não
  adicionada pra não entrar sem uso/teste. Filtragem do recurso FHIR
  bruto antes de qualquer prompt de LLM (`.claude/rules/brain.md`) —
  trabalho futuro, ainda não há montagem de prompt real.
- **Resolvido:** água (novo tipo `water` de `HealthEvent`) — `WaterLogger`/
  `log_water`, card no dashboard com registro rápido.
- Refeição/receita composta de ingredientes — pendência ainda em
  `docs/specs/nutricao.md`, não implementada.
- Nenhum provedor de pagamento real configurado (F10/F11 é só
  esqueleto, por decisão) — Play Billing/StoreKit/Stripe/Pix ficam pra
  quando o servidor existir.
- Peso/IMC/calorias/medidas nos cards de compartilhamento (F12) — regra
  de opt-in por campo já registrada em `.claude/rules/share.md`, mas os
  campos em si ainda não existem no card; entram desligados por padrão
  quando entrarem.
- **Resolvido:** todas as 7 ferramentas registradas no app agora têm
  comando de chat (`app/lib/chat_router.dart`) — "buscar alimento X",
  "plano de treino ID", "resumo da corrida ID", "registrar treino:
  exercicio SETxREPSxKG, ...". Testado de ponta a ponta (13 testes de
  widget em `app/test/widget_test.dart`).

**main sincronizado com a branch designada** — verificar se ainda está em
sincronia antes de assumir (checar `git log` das duas antes de reusar
este status sem revalidar).

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
| 0 | docs/LICENSE-AUDIT.md | **fechado** (`docs/LICENSE-AUDIT.md`, seção "Fechamento") — Cenário B adotado, decisões consolidadas |
| 0 | docs/VIABILITY.md | pronta (`docs/VIABILITY.md`) |
| 1 | ADR-1 (shell/multiplataforma) | **aceito** (`docs/adr/001-shell-multiplataforma.md`) |
| 1 | ADR-2 (modelo LLM) | **aceito** (`docs/adr/002-modelo-llm.md`) |
| 1 | ADR-3 (fonte da verdade/sync) | **aceito** (`docs/adr/003-fonte-verdade-sync.md`) |
| 1 | ADR-4 (wger/Fasten) | **aceito, revisão 1** (`docs/adr/004-wger-fasten.md`) |
| 1 | ADR-4a (Gadgetbridge) | **aceito, revisão 2** (`docs/adr/004a-gadgetbridge.md`) |
| 1 | ADR-5 (licenciamento) | **aceito, revisão 4** (`docs/adr/005-licenciamento-distribuicao.md`) — cliente Apache-2.0 via PORT do OpenNutriTracker, clean room obrigatório |
| 1 | ADR-6 (sem anúncios) | **aceito** (`docs/adr/006-sem-anuncios.md`) |
| 1 | ADR-7 (canais/pagamento) | **aceito, revisão 3** (`docs/adr/007-canais-distribuicao-pagamento.md`) |
| 1 | ADR-8 (multi-tenant B2B/consentimento) | **aceito, revisão 1** (`docs/adr/008-multitenant-b2b-consentimento.md`) |
| 1 | ADR-9 (GPS) | **aceito** (`docs/adr/009-gps.md`) |
| 1 | ADR-10 (substitutos livres) | **aceito** (`docs/adr/010-substitutos-livres.md`) |
| 1 | **11/11 ADRs registradas** | **11/11 aceitas** — Fase 1 concluída |
| 2 | Esqueleto do monorepo (F2) | **CONCLUÍDO** — CI verde (`ubuntu-latest`), sandbox de dev sem SDK Android/KVM (limite de ambiente) |
| 3 | Health Data Core (F3) | **CONCLUÍDO** (`packages/health_core`) — `HealthEvent` append-only, dedup, correção, `gps_track_points` |
| 4 | Passos, foreground service (F4) | **CONCLUÍDO** (`packages/activity`, `StepsRepository` + `app/android/.../StepCounterService.kt`, `app/lib/step_sensor_android.dart`, `step_tracking_controller.dart`) — agregação de contador cumulativo, reset de aparelho tratado, foreground service Android real implementado; sensor disparando de fato/serviço sobrevivendo à tela bloqueada não verificável neste ambiente (sem `adb`/device), só CI confirma que compila |
| 5 | Cérebro com 1+ ferramentas (F5) | **pipeline provado com 2 ferramentas reais** (`get_steps`, `log_meal`) coexistindo no mesmo `BrainPipeline`/`ToolRegistry`; LLM on-device real fica pra depois (sem device pra testar aqui) |
| 6 | Nutrição/código de barras (F6) | **CONCLUÍDO** (`packages/nutrition`) — `Food`/`FoodRepository` (sqlite3), `MealLogger`, `BarcodeDecoder` (interface, sem câmera real), `log_meal`/`search_food` reais no `ToolRegistry`; **catálogo real** = Tabela TACO (NEPA/UNICAMP, 578 alimentos) desde este ciclo; `flutter_zxing` concreto fica pra depois |
| 7 | Academia (F7) | **CONCLUÍDO** (`packages/activity`) — `WorkoutPlan`/`WorkoutRepository` (sqlite3), `WorkoutLogger` (`workout_session`+`set_log`, recorde por consulta), `get_workout_plan`/`log_workout_session` reais no `ToolRegistry`; sem dependência de hardware, testado de ponta a ponta |
| 8 | Corrida/caminhada com GPS (F8) | **PARCIAL** (`packages/activity`) — `RunCalculator`, `RunLogger`, GPX, ofuscação de rota, `get_run_summary` concluídos e testados; captura de GPS real (WRAP Android/PORT iOS) e `start_run` bloqueados — sem SDK/device Android/iOS neste ambiente |
| 9 | Wearable BLE (F9) | **PARCIAL** (`packages/wearable`, novo pacote) — `WearableSyncLogger`/`sync_wearable` prontos e testados (FC + sono, dedup por `external_id`); `WearableDataSource` real sobre Health Connect bloqueada — sem Android SDK/device com Gadgetbridge instalado; não registrada no app (sem fonte real pra ligar) |
| 10/11 | Entitlements/Pagamento | **PARCIAL, esqueleto** (`packages/entitlements`) — `Entitlement`/`EntitlementVerifier` (Ed25519 real), `Subscription`, `PendingPayment`, `WebhookIdempotencyGuard`; nenhum provedor configurado, por decisão |
| 12 | Compartilhamento social (F12) | **PARCIAL** (`packages/share`, novo pacote) — `WorkoutShareCardData`/`RunShareCardData`, builders com checagem estrutural anti-clínico, rota ofuscada; em `app/`: `SharePreviewScreen`/`ShareSheet`(`share_plus`)/`CardImageCapturer`, testado de ponta a ponta com `FakeCardImageCapturer`; rasterização real (`RepaintBoundary.toImage`) não verificável neste ambiente headless |
| 13 | wger + Fasten (F13) | **PARCIAL** (`packages/wger`, `packages/fasten`, novos pacotes) — `WgerSyncLogger`/`sync_wger` (grava `set_log`, `source: wger`) e `FastenSyncLogger`/`sync_fasten_records` (grava `clinical_doc`, `source: fasten`) prontos e testados com Fixture; `WgerClient`/`FastenClient` real sobre REST v2/FHIR bloqueados — sem servidor wger/Fasten alcançável; não registrados no app (sem fonte real pra ligar) |
| — | `get_daily_summary`/`sync_wearable` (ferramentas do cérebro) | **CONCLUÍDO** — `get_daily_summary` (`packages/summary`, só leitura, cruza steps/meal/workout_session/gps_track); `sync_wearable` (`packages/wearable`, escrita com confirmação) |
| — | Primeira UI real do app (`app/`) | **PARCIAL** — telas Resumo + Chat, `AppDependencies` ligada aos pacotes reais, 8 ferramentas registradas (falta `start_run`, bloqueada por hardware), **todas com comando de chat** (`app/lib/chat_router.dart`), compartilhamento de treino/corrida (F12); `path_provider`/rasterização real não verificáveis sem device |
| — | Dashboard mínimo funcional (água/refeição/treino por toque) | **CONCLUÍDO** — 5 cards no layout final (`app/lib/screens/dashboard_screen.dart`), `LogMealScreen`/`LogWorkoutScreen`/diálogo de água montam texto e reaproveitam `BrainPipeline.handle` + confirmação existente; card de Passos liga ao sensor real (ver linha F4); Corridas com placeholder honesto até GPS real existir |
| — | Relatório de eficiência (`docs/EFICIENCIA.md`) | Grupo A adotado como prática; Grupo B aplicado (este arquivo) |

## Decisões já tomadas (não reabrir sem motivo novo)

- Código aberto, copyleft aceito.
- **Sem anúncios em nenhuma superfície.** Sistema de anúncios foi cancelado.
- **Nome do produto: RLT — Real Life Track. Android apenas, iOS abandonado**
  (ADR-12, 2026-10-02).
- **Cérebro: IA em nuvem com a chave de API do próprio usuário** (ADR-11,
  2026-10-02, substitui o LLM local da ADR-2). Sem chave = roteador
  determinístico, 100% offline. Com chave = só sob envio explícito, com
  consentimento, e tudo que a IA propõe passa por confirmação antes de gravar.
- **Login com Google obrigatório** (ADR-13, 2026-10-02), sem Play Services.
  Achado: sem Play Services o login no Android depende de domínio + servidor
  nosso pra trocar o código → implementação fica junto com o servidor; a
  alternativa é uma exceção à regra de licença só pro login. Decidir lá.
- **IA registra, não diagnostica nem receita** (reconfirmado 2026-10-02).
- **Navegação: 5 abas** — Início, Saúde, Cérebro, Nutrição, Exercícios
  (`docs/PRODUTO.md`). Layout vem do Claude Design
  (`docs/design/PROMPT-CLAUDE-DESIGN.md`).
- **Estratégia de entrega (2026-10-02):** terminar layout + todas as funções
  antes de uma rodada única de testes no aparelho, em vez de testar etapa por
  etapa. Servidor fica entre as últimas etapas. Pagamento: fazer agora toda a
  parte do app; provedor por último.
- Grátis = tudo que roda no aparelho (inclui IA com a chave do usuário — não
  custa servidor nosso). Pago = tudo que consome servidor.
- Monetização: assinatura R$20/US$10 + B2B para profissionais de saúde.
- Escopo inclui módulo de academia (planos, treino, corrida/caminhada com GPS)
  e compartilhamento social (Instagram, TikTok, Facebook).

## Débito técnico

Nenhum em aberto no momento.
