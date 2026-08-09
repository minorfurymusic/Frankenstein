# Paridade de plataforma — o que degrada no iOS

Citado em `docs/ARQUITETURA.md:73-74` e em `docs/adr/001-shell-multiplataforma.md`
("Pendência que esta ADR expõe, não resolve") — não existia até este ciclo.
Registra só os gaps **já conhecidos** pelas fichas de reconhecimento e pelas
ADRs propostas até aqui. Não é uma auditoria nova de iOS — é a consolidação
do que já foi encontrado, num lugar só.

## Gap 1 — OpenTracks (corrida, caminhada, GPS): Android-only

**Fonte:** `docs/recon/opentracks.md` — stack confirmada abrindo o
repositório é Android nativo, 100% Java, Gradle. Nenhum equivalente
Flutter ou multiplataforma foi encontrado para o mesmo papel.

**Consequência já registrada em `docs/adr/001-shell-multiplataforma.md`:**
no Android, o módulo de corrida/caminhada entra por WRAP (platform channel
chamando o código Java do OpenTracks). No iOS **não há esse caminho** —
as opções, nenhuma delas decidida ainda, são:

1. **PORT** — reimplementar GPS/rota/pace/splits nativamente para iOS
   (CoreLocation), seguindo as mesmas regras já escritas em
   `docs/adr/009-gps.md`/`.claude/rules/activity.md` (precisão, gravação
   incremental, teto de bateria, ofuscação de rota).
2. **Lançar sem esse módulo no iOS** — reduz a Definição de Pronto do MVP
   (`docs/PRODUTO.md`, item 6) pra "só Android" nesse recurso específico,
   documentado explicitamente em vez de descoberto tarde.

Nenhuma das duas foi escolhida — fica registrado aqui como pendência, não
como decisão.

## Gap 2 — Gadgetbridge / wearable: Health Connect não existe no iOS

**Fonte:** `docs/adr/004a-gadgetbridge.md` (aceita no Ciclo 30) — a rota
FEDERATE depende do Android Health Connect, que é um componente do AOSP
(`docs/recon/gadgetbridge.md` cita isso na integração) — não existe
equivalente no iOS por definição, é infraestrutura específica do Android.

**Sub-gap dentro do próprio Android, registrado no Ciclo 30:** Health
Connect só é nativo (parte do sistema) a partir do **Android 14**. Em
Android 13 ou anterior, o usuário precisa instalar o app proprietário
Health Connect da Play Store para o mesmo caminho funcionar — dependência
proprietária que não é do Frankstein (nenhum código proprietário entra no
projeto), mas do **aparelho do usuário**, condicionada à versão do Android
dele.

## Perfil de dispositivo — dois eixos, não um só (registrado no Ciclo 31)

Confirmado com o usuário: isso vira um eixo novo, separado dos perfis
A/B/C da `docs/adr/002-modelo-llm.md:41-43` (que são só por RAM, pro LLM
local). Não altero a ADR-2 — ela continua definindo os três perfis de RAM
como já aceito. Este documento só registra o **segundo eixo**,
independente do primeiro, e junta os dois numa tabela de referência:

| Eixo | Determina | Valores | Fonte |
|---|---|---|---|
| **RAM** (perfil LLM) | qual modelo local roda, se algum | A (≥8 GB) / B (6 GB) / C (≤4 GB, sem modelo) | `docs/adr/002-modelo-llm.md:41-43` |
| **Versão do Android** (perfil Health Connect) | se o Health Connect é nativo ou exige app da Play Store | ≥14 (nativo) / ≤13 (app proprietário externo) | `docs/adr/004a-gadgetbridge.md`, este documento |

Os dois eixos são **independentes** — um aparelho com pouca RAM pode estar
em Android 14 (Health Connect nativo, sem LLM local), e um aparelho com
bastante RAM pode estar preso num Android antigo (LLM local completo,
Health Connect via app externo). Não force os dois numa letra só: um
aparelho descrito como "perfil B, Android 13" já é suficiente — não
precisa de um novo "perfil B13" ou similar. Combinar os dois numa única
classificação nova só se justificaria se algum ciclo futuro encontrar um
terceiro eixo que dependa da combinação dos dois ao mesmo tempo (nenhum
encontrado até agora).

**Consequência:** no iOS, a fonte de dados de wearable não pode ser
Health Connect. `docs/ARQUITETURA.md:74` já aponta o candidato óbvio:
**HealthKit** (framework nativo da Apple, papel equivalente ao Health
Connect no ecossistema iOS) — mas isso **não foi investigado** em nenhum
ciclo até agora. Não sei se:

- O Gadgetbridge (ou qualquer app de terceiro no ecossistema iOS que
  sincronize pulseiras) escreve no HealthKit do mesmo jeito que a ADR-4a
  encontrou para o Health Connect no Android.
- Existe um app equivalente ao Gadgetbridge no iOS — o próprio
  Gadgetbridge é Android-only (confirmado em `docs/recon/gadgetbridge.md`,
  seção Plataformas).

**Consequência de produto, já registrada em `docs/VIABILITY.md`:** o item
3 da Definição de Pronto do MVP ("Pulseira BLE sincroniza FC e sono")
depende de infraestrutura de terceiro mesmo no Android (o usuário precisa
ter o Gadgetbridge instalado). No iOS, essa dependência de terceiro fica
sem candidato conhecido — não é "mais difícil", é **sem solução
identificada ainda**.

## Não coberto por este documento

- Nenhum dos outros 5 repositórios (MLC LLM, FoodYou, OpenNutriTracker,
  wger, Fasten Health) tem gap de iOS registrado nas fichas — MLC LLM
  tem binding iOS nativo (`ios/MLCSwift`, `docs/recon/mlc-llm.md`),
  OpenNutriTracker é Flutter com pasta `ios/` própria
  (`docs/recon/opennutritracker.md`), wger e Fasten são federados por API
  (não rodam no aparelho, `docs/ARQUITETURA.md:16`) — sem gap de
  plataforma por definição. Isso não significa que o iOS desses módulos
  foi testado — só que nenhuma ficha encontrou um bloqueio estrutural
  como os dois acima.
- Comportamento de background/foreground no iOS para GPS e passos
  (permissões "Always"/"While Using", limites de execução em segundo
  plano) — mencionado como pendência em `docs/adr/009-gps.md`, não
  investigado aqui.
- Paridade de UI/UX entre Android e iOS — fora do escopo deste documento,
  que é sobre o que **falta tecnicamente**, não sobre design.

## Não verificado

Tudo que envolve HealthKit especificamente — nenhuma ficha de
reconhecimento tocou nisso, porque nenhum dos 7 repositórios escolhidos
é um projeto iOS de wearable. Investigar isso é trabalho novo, não uma
releitura do que já existe.
