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
+-- SENSORES: pedômetro (Flutter) | BLE wearable (Kotlin, Android)
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
  id           uuid
  type         steps | heart_rate | sleep | meal | weight |
               workout_session | set_log | gps_track | clinical_doc
  source       pedometer | wearable | manual | wger | fasten | llm
  occurred_at  timestamp UTC
  recorded_at  timestamp
  payload      json (tipado por 'type')
  confidence   float
  device_id    string?
```

Append-only. Deduplicação por (source, external_id). Correção gera novo evento.

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
