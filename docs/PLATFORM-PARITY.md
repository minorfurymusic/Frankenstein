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

**Fonte:** `docs/adr/004a-gadgetbridge.md` — a rota proposta (FEDERATE)
depende do Android Health Connect, que é um componente do AOSP
(`docs/recon/gadgetbridge.md` cita isso na integração) — não existe
equivalente no iOS por definição, é infraestrutura específica do Android.

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
