import 'dart:io';

import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

HealthEvent _stepsEvent({
  String? id,
  String? externalId,
  String? correctsEventId,
  DateTime? occurredAt,
  DateTime? recordedAt,
}) {
  return HealthEvent(
    id: id ?? HealthDataCore.newId(),
    type: HealthEventType.steps,
    source: HealthEventSource.pedometer,
    occurredAt: occurredAt ?? DateTime.utc(2026, 8, 9, 12, 0, 0),
    occurredAtTzOffsetMinutes: -180, // America/Sao_Paulo, sem DST
    recordedAt: recordedAt ?? DateTime.utc(2026, 8, 9, 12, 0, 5),
    payload: const {'count': 1234},
    confidence: 0.95,
    deviceId: 'device-abc',
    externalId: externalId,
    correctsEventId: correctsEventId,
  );
}

void main() {
  group('HealthDataCore — insert e leitura (round trip)', () {
    test('insere um evento real e lê de volta com todos os campos intactos',
        () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final event = _stepsEvent(externalId: 'ext-001');
      core.insertEvent(event);

      final back = core.getById(event.id);
      expect(back, isNotNull);
      expect(back!.id, event.id);
      expect(back.type, HealthEventType.steps);
      expect(back.source, HealthEventSource.pedometer);
      expect(back.occurredAt, event.occurredAt);
      expect(back.occurredAtTzOffsetMinutes, -180);
      expect(back.recordedAt, event.recordedAt);
      expect(back.payload, {'count': 1234});
      expect(back.confidence, 0.95);
      expect(back.deviceId, 'device-abc');
      expect(back.externalId, 'ext-001');
      expect(back.correctsEventId, isNull);
    });

    test('payload com estrutura aninhada sobrevive ao round trip via JSON',
        () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final event = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.meal,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 8, 9, 12, 30),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 9, 12, 31),
        payload: const {
          'items': [
            {'food_id': 'arroz-branco', 'grams': 150.0},
            {'food_id': 'feijao-carioca', 'grams': 100.0},
          ],
          'meal_type': 'lunch',
        },
        confidence: 1.0,
      );
      core.insertEvent(event);

      final back = core.getById(event.id)!;
      expect(back.payload['meal_type'], 'lunch');
      expect((back.payload['items'] as List).length, 2);
      expect((back.payload['items'] as List)[0], {
        'food_id': 'arroz-branco',
        'grams': 150.0,
      });
    });

    test('evento sem external_id/device_id grava e lê nulos corretamente',
        () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final event = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.weight,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 8, 9),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 9),
        payload: const {'kg': 70.5},
        confidence: 1.0,
      );
      core.insertEvent(event);

      final back = core.getById(event.id)!;
      expect(back.deviceId, isNull);
      expect(back.externalId, isNull);
    });
  });

  group('HealthDataCore — deduplicação (source, external_id)', () {
    test('rejeita segundo insert com mesmo (source, external_id)', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      core.insertEvent(_stepsEvent(externalId: 'wearable-sync-42'));
      expect(
        () => core.insertEvent(
          _stepsEvent(externalId: 'wearable-sync-42'),
        ),
        throwsA(isA<DuplicateEventException>()),
      );
    });

    test('permite múltiplos eventos com external_id nulo (dedup não se aplica)',
        () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      core.insertEvent(_stepsEvent());
      core.insertEvent(_stepsEvent());
      final all = core.queryByType(HealthEventType.steps);
      expect(all, hasLength(2));
    });

    test('mesmo external_id em source diferente não colide', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      core.insertEvent(_stepsEvent(externalId: 'evt-1'));
      final fromWger = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.workoutSession,
        source: HealthEventSource.wger,
        occurredAt: DateTime.utc(2026, 8, 9),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 9),
        payload: const {},
        confidence: 1.0,
        externalId: 'evt-1',
      );
      expect(() => core.insertEvent(fromWger), returnsNormally);
    });
  });

  group('HealthDataCore — correção (append-only, nunca UPDATE)', () {
    test('correctEvent cria evento novo, original continua intacto', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final original = _stepsEvent();
      core.insertEvent(original);

      final correction = _stepsEvent(
        correctsEventId: original.id,
        occurredAt: original.occurredAt,
        recordedAt: DateTime.utc(2026, 8, 9, 13, 0),
      );
      core.correctEvent(previousEventId: original.id, correction: correction);

      final stillOriginal = core.getById(original.id)!;
      expect(stillOriginal.payload, {'count': 1234});

      final chain = core.correctionChain(original.id);
      expect(chain, hasLength(2));
      expect(chain[0].id, original.id);
      expect(chain[0].correctsEventId, isNull);
      expect(chain[1].id, correction.id);
      expect(chain[1].correctsEventId, original.id);
    });

    test('duas correções concorrentes do mesmo evento ficam as duas na cadeia',
        () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final original = _stepsEvent();
      core.insertEvent(original);

      final correctionA = _stepsEvent(
        correctsEventId: original.id,
        recordedAt: DateTime.utc(2026, 8, 9, 13, 0),
      );
      final correctionB = _stepsEvent(
        correctsEventId: original.id,
        recordedAt: DateTime.utc(2026, 8, 9, 13, 0, 1),
      );
      core.correctEvent(previousEventId: original.id, correction: correctionA);
      core.correctEvent(previousEventId: original.id, correction: correctionB);

      final chain = core.correctionChain(original.id);
      expect(chain, hasLength(3));
      expect(chain.map((e) => e.id),
          [original.id, correctionA.id, correctionB.id]);
    });

    test('corrigir evento inexistente lança EventNotFoundException', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      expect(
        () => core.correctEvent(
          previousEventId: 'nao-existe',
          correction: _stepsEvent(correctsEventId: 'nao-existe'),
        ),
        throwsA(isA<EventNotFoundException>()),
      );
    });
  });

  group('HealthDataCore — consulta por tipo e intervalo', () {
    test('queryByType filtra por occurred_at e ordena crescente', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final d1 = DateTime.utc(2026, 8, 1);
      final d2 = DateTime.utc(2026, 8, 5);
      final d3 = DateTime.utc(2026, 8, 9);
      core.insertEvent(_stepsEvent(occurredAt: d3));
      core.insertEvent(_stepsEvent(occurredAt: d1));
      core.insertEvent(_stepsEvent(occurredAt: d2));

      final results = core.queryByType(
        HealthEventType.steps,
        from: DateTime.utc(2026, 8, 2),
        to: DateTime.utc(2026, 8, 9),
      );
      expect(results.map((e) => e.occurredAt), [d2, d3]);
    });

    test('não retorna eventos de outro tipo', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      core.insertEvent(_stepsEvent());
      core.insertEvent(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.weight,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 8, 9),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 9),
        payload: const {'kg': 70.0},
        confidence: 1.0,
      ));

      expect(core.queryByType(HealthEventType.weight), hasLength(1));
      expect(core.queryByType(HealthEventType.steps), hasLength(1));
    });
  });

  group('HealthDataCore — gps_track_points em tabela própria', () {
    test('insere e lê pontos de rota em ordem de seq', () {
      final core = HealthDataCore.openInMemory();
      addTearDown(core.close);

      final track = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.gpsTrack,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 8, 9, 7, 0),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 9, 7, 30),
        payload: const {'distance_meters': 5000.0},
        confidence: 1.0,
      );
      core.insertEvent(track);

      core.insertGpsTrackPoints([
        GpsTrackPoint(
          eventId: track.id,
          seq: 1,
          latitude: -23.5505,
          longitude: -46.6333,
          elevationMeters: 760.0,
          recordedAt: DateTime.utc(2026, 8, 9, 7, 0),
        ),
        GpsTrackPoint(
          eventId: track.id,
          seq: 0,
          latitude: -23.5500,
          longitude: -46.6330,
          recordedAt: DateTime.utc(2026, 8, 9, 6, 59, 50),
        ),
      ]);

      final points = core.gpsTrackPoints(track.id);
      expect(points, hasLength(2));
      expect(points[0].seq, 0);
      expect(points[0].elevationMeters, isNull);
      expect(points[1].seq, 1);
      expect(points[1].elevationMeters, 760.0);
    });
  });

  group('HealthEvent — validação', () {
    test('rejeita occurredAt fora de UTC', () {
      expect(
        () => HealthEvent(
          id: HealthDataCore.newId(),
          type: HealthEventType.steps,
          source: HealthEventSource.manual,
          occurredAt: DateTime(2026, 8, 9), // local, não UTC
          occurredAtTzOffsetMinutes: -180,
          recordedAt: DateTime.utc(2026, 8, 9),
          payload: const {},
          confidence: 1.0,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita confidence fora de [0, 1]', () {
      expect(
        () => _stepsEvent().let((e) => HealthEvent(
              id: e.id,
              type: e.type,
              source: e.source,
              occurredAt: e.occurredAt,
              occurredAtTzOffsetMinutes: e.occurredAtTzOffsetMinutes,
              recordedAt: e.recordedAt,
              payload: e.payload,
              confidence: 1.5,
            )),
        throwsArgumentError,
      );
    });
  });

  group('HealthDataCore — teste de ida e volta do schema, com arquivo real',
      () {
    test(
        'dado gravado sobrevive ao fechar e reabrir o banco a partir do mesmo arquivo',
        () {
      final dir = Directory.systemTemp.createTempSync('health_core_test_');
      final dbPath = '${dir.path}/health_core.sqlite3';
      addTearDown(() => dir.deleteSync(recursive: true));

      final eventId = HealthDataCore.newId();
      final writer = HealthDataCore.open(dbPath);
      writer.insertEvent(_stepsEvent(id: eventId, externalId: 'roundtrip-1'));
      writer.close();

      // Reabre do zero, simulando um novo processo (app reiniciado) lendo
      // o mesmo arquivo de banco — é o teste de ida e volta que
      // `.claude/rules/datacore.md` exige pra toda migração de schema.
      final reader = HealthDataCore.open(dbPath);
      addTearDown(reader.close);

      final back = reader.getById(eventId);
      expect(back, isNotNull);
      expect(back!.payload, {'count': 1234});
      expect(back.externalId, 'roundtrip-1');

      // O schema pode ser aplicado de novo (CREATE TABLE IF NOT EXISTS)
      // sem perder dado nem duplicar índice — é o outro lado do "ida e
      // volta": reabrir um banco existente é idempotente.
      expect(() => HealthDataCore.open(dbPath).close(), returnsNormally);
    });
  });
}

extension _Let<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
