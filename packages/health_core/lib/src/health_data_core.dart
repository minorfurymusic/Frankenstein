import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';
import 'package:uuid/uuid.dart';

import 'health_event.dart';
import 'schema.dart';

/// Lançada quando um insert violaria a deduplicação por
/// `(source, external_id)` (`.claude/rules/datacore.md`).
class DuplicateEventException implements Exception {
  final HealthEventSource source;
  final String externalId;
  DuplicateEventException(this.source, this.externalId);

  @override
  String toString() =>
      'HealthEvent duplicado: source=${source.wireValue} external_id=$externalId já existe';
}

/// Lançada ao tentar corrigir um evento que não existe no Core.
class EventNotFoundException implements Exception {
  final String eventId;
  EventNotFoundException(this.eventId);

  @override
  String toString() => 'HealthEvent não encontrado: $eventId';
}

/// O Health Data Core — SQLite local, fonte da verdade, offline-first
/// (`docs/ARQUITETURA.md`). Append-only: não existe método de update ou
/// delete nesta classe, de propósito — correção é sempre um evento novo.
class HealthDataCore {
  final Database _db;
  static const Uuid _uuid = Uuid();

  HealthDataCore._(this._db);

  /// Abre (ou cria) o banco no caminho de arquivo dado, já com o schema
  /// aplicado.
  factory HealthDataCore.open(String path) {
    final db = sqlite3.open(path);
    _applySchema(db);
    return HealthDataCore._(db);
  }

  /// Banco em memória — uso em teste, nunca em produção (dado de saúde
  /// tem que sobreviver o processo).
  factory HealthDataCore.openInMemory() {
    final db = sqlite3.openInMemory();
    _applySchema(db);
    return HealthDataCore._(db);
  }

  /// Aplica o schema base (idempotente via `CREATE TABLE IF NOT EXISTS`)
  /// e, por cima, cada migração aditiva ainda não aplicada — checada via
  /// `PRAGMA table_info`, porque `ALTER TABLE ADD COLUMN` falha se rodado
  /// duas vezes no mesmo banco (diferente do `CREATE TABLE IF NOT EXISTS`).
  static void _applySchema(Database db) {
    db.execute(schemaSql);
    final columns = db.select('PRAGMA table_info(gps_track_points)');
    final hasAccuracyColumn = columns.any((r) => r['name'] == 'accuracy_meters');
    if (!hasAccuracyColumn) {
      db.execute(schemaSqlV2AddGpsAccuracy);
    }
  }

  void close() => _db.dispose();

  /// Insere um [HealthEvent] novo. Lança [DuplicateEventException] se já
  /// existir um evento com o mesmo `(source, externalId)` — dedup só se
  /// aplica quando `externalId` não é nulo.
  void insertEvent(HealthEvent event) {
    if (event.externalId != null && _findByDedupKey(event.source, event.externalId!) != null) {
      throw DuplicateEventException(event.source, event.externalId!);
    }
    _db.execute(
      '''
      INSERT INTO health_events (
        id, type, source, occurred_at, occurred_at_tz_offset_minutes,
        recorded_at, payload, confidence, device_id, external_id,
        corrects_event_id
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        event.id,
        event.type.wireValue,
        event.source.wireValue,
        event.occurredAt.toIso8601String(),
        event.occurredAtTzOffsetMinutes,
        event.recordedAt.toIso8601String(),
        jsonEncode(event.payload),
        event.confidence,
        event.deviceId,
        event.externalId,
        event.correctsEventId,
      ],
    );
  }

  /// Registra uma correção do evento [previousEventId]: insere
  /// [correction] com `correctsEventId` apontando para ele. Não apaga nem
  /// altera o evento anterior — os dois continuam no Core.
  void correctEvent({
    required String previousEventId,
    required HealthEvent correction,
  }) {
    if (getById(previousEventId) == null) {
      throw EventNotFoundException(previousEventId);
    }
    if (correction.correctsEventId != previousEventId) {
      throw ArgumentError(
          'correction.correctsEventId (${correction.correctsEventId}) precisa ser igual a previousEventId ($previousEventId)');
    }
    insertEvent(correction);
  }

  /// Gera um id novo (uuid v4) — conveniência pra quem monta um
  /// [HealthEvent] antes de inserir.
  static String newId() => _uuid.v4();

  HealthEvent? getById(String id) {
    final rows = _db.select('SELECT * FROM health_events WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  HealthEvent? _findByDedupKey(HealthEventSource source, String externalId) {
    final rows = _db.select(
      'SELECT * FROM health_events WHERE source = ? AND external_id = ?',
      [source.wireValue, externalId],
    );
    if (rows.isEmpty) return null;
    return _rowToEvent(rows.first);
  }

  /// Eventos de um tipo, opcionalmente filtrados por intervalo de
  /// `occurredAt` (UTC, inclusive nas duas pontas). Ordenados por
  /// `occurredAt` crescente.
  List<HealthEvent> queryByType(
    HealthEventType type, {
    DateTime? from,
    DateTime? to,
  }) {
    final where = StringBuffer('WHERE type = ?');
    final args = <Object?>[type.wireValue];
    if (from != null) {
      if (!from.isUtc) throw ArgumentError('from precisa estar em UTC');
      where.write(' AND occurred_at >= ?');
      args.add(from.toIso8601String());
    }
    if (to != null) {
      if (!to.isUtc) throw ArgumentError('to precisa estar em UTC');
      where.write(' AND occurred_at <= ?');
      args.add(to.toIso8601String());
    }
    final rows = _db.select(
      'SELECT * FROM health_events $where ORDER BY occurred_at ASC',
      args,
    );
    return rows.map(_rowToEvent).toList();
  }

  /// A cadeia de correções de um evento: o original seguido de cada
  /// correção, em ordem de `recordedAt`. `originalEventId` precisa ser um
  /// evento que não corrige nenhum outro (a raiz da cadeia).
  List<HealthEvent> correctionChain(String originalEventId) {
    final original = getById(originalEventId);
    if (original == null) throw EventNotFoundException(originalEventId);
    if (original.correctsEventId != null) {
      throw ArgumentError(
          '$originalEventId não é raiz de cadeia — ele mesmo corrige ${original.correctsEventId}');
    }
    final rows = _db.select(
      'SELECT * FROM health_events WHERE corrects_event_id = ? ORDER BY recorded_at ASC',
      [originalEventId],
    );
    return [original, ...rows.map(_rowToEvent)];
  }

  void insertGpsTrackPoints(List<GpsTrackPoint> points) {
    for (final p in points) {
      _db.execute(
        '''
        INSERT INTO gps_track_points (
          id, event_id, seq, latitude, longitude, elevation_meters,
          recorded_at, accuracy_meters
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          _uuid.v4(),
          p.eventId,
          p.seq,
          p.latitude,
          p.longitude,
          p.elevationMeters,
          p.recordedAt.toIso8601String(),
          p.accuracyMeters,
        ],
      );
    }
  }

  List<GpsTrackPoint> gpsTrackPoints(String eventId) {
    final rows = _db.select(
      'SELECT * FROM gps_track_points WHERE event_id = ? ORDER BY seq ASC',
      [eventId],
    );
    return rows
        .map((r) => GpsTrackPoint(
              eventId: r['event_id'] as String,
              seq: r['seq'] as int,
              latitude: (r['latitude'] as num).toDouble(),
              longitude: (r['longitude'] as num).toDouble(),
              elevationMeters: (r['elevation_meters'] as num?)?.toDouble(),
              recordedAt: DateTime.parse(r['recorded_at'] as String),
              accuracyMeters: (r['accuracy_meters'] as num?)?.toDouble(),
            ))
        .toList();
  }

  HealthEvent _rowToEvent(Row r) {
    return HealthEvent(
      id: r['id'] as String,
      type: HealthEventType.fromWireValue(r['type'] as String),
      source: HealthEventSource.fromWireValue(r['source'] as String),
      occurredAt: DateTime.parse(r['occurred_at'] as String),
      occurredAtTzOffsetMinutes: r['occurred_at_tz_offset_minutes'] as int,
      recordedAt: DateTime.parse(r['recorded_at'] as String),
      payload: jsonDecode(r['payload'] as String) as Map<String, dynamic>,
      confidence: (r['confidence'] as num).toDouble(),
      deviceId: r['device_id'] as String?,
      externalId: r['external_id'] as String?,
      correctsEventId: r['corrects_event_id'] as String?,
    );
  }
}
