# ARQUITETURA — Frankstein

## Camadas

```
APP SHELL (Flutter) — UI única: chat + dashboards
   |
BRAIN LAYER — MLC LLM no aparelho
   roteador determinístico -> LLM com tool-calling -> validador -> confirmação humana
   |
TOOL REGISTRY — contrato único de ferramentas
   |
+-- SENSORES: pedômetro (Flutter) | wearable via Health Connect (Fase 9)
+-- NUTRIÇÃO: refeições + código de barras | base local de alimentos
+-- ATIVIDADE: treino, séries, GPS de corrida
+-- SAÚDE/TREINO REMOTO: wger (REST) | Fasten (FHIR)
   |
HEALTH DATA CORE — SQLite local, fonte da verdade, offline-first
```

## Por que não se funde tudo num binário
São quatro stacks incompatíveis (Flutter, Kotlin/Android, Django, Go) e dois
servidores. A absorção é por camada e por padrão declarado em ADR, não por
cópia de código.

## Health Data Core

```
HealthEvent
  id                 uuid
  type               steps | heart_rate | sleep | meal | weight | water |
                      workout_session | set_log | gps_track | clinical_doc
  source             pedometer | wearable | manual | wger | fasten | llm
  occurred_at        timestamp UTC
  recorded_at        timestamp
  payload            json (tipado por 'type')
  confidence         float
  device_id          string?
  external_id        string?   -- id do evento na fonte externa (wearable,
                                   wger, fasten); par com 'source' formam a
                                   chave de deduplicação. Nulo pra eventos
                                   sem origem externa (manual, llm).
  corrects_event_id  uuid?     -- id do HealthEvent que este evento corrige.
                                   Nulo pra eventos originais.
```

Append-only. Deduplicação por (source, external_id) — só se aplica quando
external_id não é nulo. Correção gera novo evento com corrects_event_id
apontando para o evento corrigido; nunca um UPDATE destrutivo do original.

**Nota (Fase 3, Ciclo de implementação):** `external_id` e
`corrects_event_id` foram adicionados à enumeração explícita do schema
neste ciclo — a regra de dedup e de correção já existiam em prosa desde a
primeira versão deste documento e em `.claude/rules/datacore.md`, mas os
campos que elas dependem não estavam na lista de colunas. Preenchimento
de lacuna, não mudança de decisão.

**Nota (ciclo do dashboard mínimo):** tipo `water` acrescentado —
`docs/specs/nutricao.md:103-106` já previa "peso e água" como séries
temporais simples, mas deixava o nome do tipo como pendência de
implementação ("água não está listada ainda"). Resolvido: `water`,
payload `{amount_ml}`, `source: manual`, sem dedup por `external_id`
(mesmo padrão de `meal`). Implementado em `packages/nutrition`
(`docs/specs/nutricao.md` continua sendo a única fonte de especificação
do módulo, `.claude/rules/port.md`).

## Contrato de ferramenta do cérebro

```json
{
  "name": "log_meal",
  "description": "Registra uma refeição no diário alimentar",
  "write": true,
  "confirm": true,
  "module": "nutrition",
  "parameters": {
    "type": "object",
    "properties": {
      "items": {"type":"array","items":{"type":"object","properties":{
        "food_id":{"type":"string"},"grams":{"type":"number"}},
        "required":["food_id","grams"]}},
      "meal_type": {"enum":["breakfast","lunch","dinner","snack"]},
      "at": {"type":"string","format":"date-time"}
    },
    "required": ["items","meal_type"]
  }
}
```

Ferramentas mínimas do MVP: get_daily_summary, get_steps, log_meal, search_food,
sync_wearable, get_workout_plan, start_run, query_health_record (somente leitura).

## Requisitos não-funcionais
- Offline-first: sem rede, o app funciona por completo.
- Privacidade por padrão: sem analytics, banco criptografado.
- Foreground service no Android para passos e GPS.
- Degradação explícita no iOS documentada em docs/PLATFORM-PARITY.md
  (Gadgetbridge é Android-only; provável fallback para HealthKit).
- pt-BR como idioma primário.
- Orçamento medido e publicado: RAM em inferência, tamanho do APK, bateria/hora.
