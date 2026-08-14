/// Migração inicial do Health Data Core (`docs/ARQUITETURA.md`,
/// `.claude/rules/datacore.md`). Append-only: nenhuma coluna aqui é
/// pensada para UPDATE destrutivo.
const String schemaSqlV1 = '''
CREATE TABLE IF NOT EXISTS health_events (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  source TEXT NOT NULL,
  occurred_at TEXT NOT NULL,
  occurred_at_tz_offset_minutes INTEGER NOT NULL,
  recorded_at TEXT NOT NULL,
  payload TEXT NOT NULL,
  confidence REAL NOT NULL,
  device_id TEXT,
  external_id TEXT,
  corrects_event_id TEXT REFERENCES health_events(id)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_health_events_dedup
  ON health_events(source, external_id)
  WHERE external_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_health_events_type_occurred
  ON health_events(type, occurred_at);

CREATE INDEX IF NOT EXISTS idx_health_events_corrects
  ON health_events(corrects_event_id);

CREATE TABLE IF NOT EXISTS gps_track_points (
  id TEXT PRIMARY KEY,
  event_id TEXT NOT NULL REFERENCES health_events(id),
  seq INTEGER NOT NULL,
  latitude REAL NOT NULL,
  longitude REAL NOT NULL,
  elevation_meters REAL,
  recorded_at TEXT NOT NULL,
  UNIQUE(event_id, seq)
);

CREATE INDEX IF NOT EXISTS idx_gps_track_points_event
  ON gps_track_points(event_id);
''';

/// Schema atual — apontar sempre para a versão mais recente. Migrações
/// futuras entram como `schemaSqlV2`, etc., nunca reescrevendo esta.
const String schemaSql = schemaSqlV1;

/// Migração V2 (Fase 8, corrida/caminhada): `accuracy_meters` em
/// `gps_track_points` — precisão reportada pelo GPS no momento da leitura,
/// necessária pro filtro de ruído de `.claude/rules/activity.md:16`
/// ("descarte pontos com precisão pior que 20 m"). `ALTER TABLE ADD
/// COLUMN` não é idempotente como `CREATE TABLE IF NOT EXISTS` — quem
/// aplica isso (`HealthDataCore._applySchema`) precisa checar
/// `PRAGMA table_info` antes de rodar, pra não falhar num banco já
/// migrado.
const String schemaSqlV2AddGpsAccuracy =
    'ALTER TABLE gps_track_points ADD COLUMN accuracy_meters REAL;';
