import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_wger/wger.dart';
import 'package:test/test.dart';

void main() {
  group('WgerSetLogSample — validação', () {
    test('rejeita recordedAt fora de UTC', () {
      expect(
        () => WgerSetLogSample(
          externalId: 'wger-1',
          exerciseName: 'Supino reto',
          reps: 8,
          weightKg: 70,
          recordedAt: DateTime(2026, 8, 16),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita reps <= 0', () {
      expect(
        () => WgerSetLogSample(
          externalId: 'wger-1',
          exerciseName: 'Supino reto',
          reps: 0,
          weightKg: 70,
          recordedAt: DateTime.utc(2026, 8, 16),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita weightKg negativo', () {
      expect(
        () => WgerSetLogSample(
          externalId: 'wger-1',
          exerciseName: 'Supino reto',
          reps: 8,
          weightKg: -1,
          recordedAt: DateTime.utc(2026, 8, 16),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });
  });

  group('FixtureWgerClient', () {
    test('filtra leituras fora do intervalo [from, to]', () async {
      final client = FixtureWgerClient(setLogs: [
        WgerSetLogSample(
          externalId: 'a',
          exerciseName: 'Agachamento',
          reps: 10,
          weightKg: 60,
          recordedAt: DateTime.utc(2026, 8, 1),
          tzOffsetMinutes: -180,
        ),
        WgerSetLogSample(
          externalId: 'b',
          exerciseName: 'Agachamento',
          reps: 10,
          weightKg: 60,
          recordedAt: DateTime.utc(2026, 8, 16),
          tzOffsetMinutes: -180,
        ),
      ]);

      final results = await client.fetchSetLogs(from: DateTime.utc(2026, 8, 10), to: DateTime.utc(2026, 8, 20));
      expect(results, hasLength(1));
      expect(results.single.externalId, 'b');
    });
  });

  group('WgerSyncLogger', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('sincroniza séries novas, gravando HealthEvent com source wger', () async {
      final client = FixtureWgerClient(setLogs: [
        WgerSetLogSample(
          externalId: 'wger-log-1',
          exerciseName: 'Levantamento terra',
          reps: 5,
          weightKg: 100,
          recordedAt: DateTime.utc(2026, 8, 16, 18, 0),
          tzOffsetMinutes: -180,
        ),
      ]);
      final logger = WgerSyncLogger(core: core, client: client);

      final result = await logger.sync(from: DateTime.utc(2026, 8, 15), to: DateTime.utc(2026, 8, 17));

      expect(result.synced, 1);
      expect(result.alreadySynced, 0);

      final events = core.queryByType(HealthEventType.setLog);
      expect(events, hasLength(1));
      expect(events.single.source, HealthEventSource.wger);
      expect(events.single.externalId, 'wger-log-1');
      expect(events.single.payload['exercise_name'], 'Levantamento terra');
      expect(events.single.payload['load_kg'], 100.0);
    });

    test('sincronizar a mesma janela de novo não duplica — dedup por (source, external_id)', () async {
      final client = FixtureWgerClient(setLogs: [
        WgerSetLogSample(
          externalId: 'wger-log-1',
          exerciseName: 'Levantamento terra',
          reps: 5,
          weightKg: 100,
          recordedAt: DateTime.utc(2026, 8, 16, 18, 0),
          tzOffsetMinutes: -180,
        ),
      ]);
      final logger = WgerSyncLogger(core: core, client: client);

      final first = await logger.sync(from: DateTime.utc(2026, 8, 15), to: DateTime.utc(2026, 8, 17));
      expect(first.synced, 1);

      final second = await logger.sync(from: DateTime.utc(2026, 8, 15), to: DateTime.utc(2026, 8, 17));
      expect(second.synced, 0);
      expect(second.alreadySynced, 1);

      expect(core.queryByType(HealthEventType.setLog), hasLength(1));
    });

    test('rejeita from/to fora de UTC', () {
      final logger = WgerSyncLogger(core: core, client: FixtureWgerClient());
      expect(
        () => logger.sync(from: DateTime(2026, 8, 15), to: DateTime.utc(2026, 8, 17)),
        throwsArgumentError,
      );
    });
  });

  group('sync_wger — ferramenta do cérebro', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('syncWgerSpec é ferramenta de escrita com confirmação', () {
      final spec = syncWgerSpec();
      expect(spec.write, isTrue);
      expect(spec.confirm, isTrue);
      expect(spec.module, 'wger');
    });

    test('execução real via handler grava eventos e devolve contagens', () async {
      final client = FixtureWgerClient(setLogs: [
        WgerSetLogSample(
          externalId: 'wger-log-1',
          exerciseName: 'Remada curvada',
          reps: 10,
          weightKg: 50,
          recordedAt: DateTime.utc(2026, 8, 16, 18, 0),
          tzOffsetMinutes: -180,
        ),
      ]);
      final logger = WgerSyncLogger(core: core, client: client);
      final handler = syncWgerHandler(logger);

      final result = await handler({
        'from': '2026-08-15T00:00:00Z',
        'to': '2026-08-17T00:00:00Z',
      });

      expect(result.success, isTrue);
      expect(result.data!['synced'], 1);
      expect(core.queryByType(HealthEventType.setLog), hasLength(1));
    });
  });
}
