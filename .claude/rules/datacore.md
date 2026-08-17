---
paths:
  - "packages/health_core/**"
  - "**/*health_event*"
  - "**/migrations/**"
---
# Regras do Health Data Core

Todos os módulos escrevem no mesmo formato. Nenhum módulo lê o banco de outro.

HealthEvent: id, type, source, occurred_at (UTC), recorded_at, payload (json),
confidence, device_id, external_id (nullable), corrects_event_id (nullable).
Tipos: steps | heart_rate | sleep | meal | weight | water | workout_session |
set_log | gps_track | clinical_doc.

- Append-only. Correção = novo evento com corrects_event_id apontando para o
  anterior. Nunca UPDATE destrutivo.
- Deduplicação por (source, external_id), quando external_id não é nulo.
- Unidades SI. Timezone gravado à parte do timestamp.
- gps_track.points em tabela própria, com simplificação para exibição.
- Toda migração de schema precisa de teste de ida e volta com dados reais.
