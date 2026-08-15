import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_wearable/wearable.dart';
import 'package:test/test.dart';

void main() {
  group('HeartRateSample/SleepSessionSample — validação', () {
    test('HeartRateSample rejeita recordedAt fora de UTC', () {
      expect(
        () => HeartRateSample(
          externalId: 'hc-1',
          bpm: 70,
          recordedAt: DateTime(2026, 8, 15),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('HeartRateSample rejeita bpm <= 0', () {
      expect(
        () => HeartRateSample(
          externalId: 'hc-1',
          bpm: 0,
          recordedAt: DateTime.utc(2026, 8, 15),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('SleepSessionSample rejeita endedAt antes de startedAt', () {
      expect(
        () => SleepSessionSample(
          externalId: 'hc-sleep-1',
          startedAt: DateTime.utc(2026, 8, 15, 23, 0),
          endedAt: DateTime.utc(2026, 8, 15, 22, 0),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('SleepSessionSample.duration calcula corretamente', () {
      final sample = SleepSessionSample(
        externalId: 'hc-sleep-1',
        startedAt: DateTime.utc(2026, 8, 15, 23, 0),
        endedAt: DateTime.utc(2026, 8, 16, 6, 30),
        tzOffsetMinutes: -180,
      );
      expect(sample.duration, const Duration(hours: 7, minutes: 30));
    });
  });

  group('FixtureWearableDataSource', () {
    test('filtra leituras fora do intervalo [from, to]', () async {
      final source = FixtureWearableDataSource(
        heartRateSamples: [
          HeartRateSample(externalId: 'a', bpm: 60, recordedAt: DateTime.utc(2026, 8, 1), tzOffsetMinutes: -180),
          HeartRateSample(externalId: 'b', bpm: 65, recordedAt: DateTime.utc(2026, 8, 15), tzOffsetMinutes: -180),
        ],
      );

      final results = await source.readHeartRate(
        from: DateTime.utc(2026, 8, 10),
        to: DateTime.utc(2026, 8, 20),
      );
      expect(results, hasLength(1));
      expect(results.single.externalId, 'b');
    });
  });

  group('WearableSyncLogger', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('sincroniza FC e sono novos, gravando HealthEvent com source wearable', () async {
      final dataSource = FixtureWearableDataSource(
        heartRateSamples: [
          HeartRateSample(externalId: 'hc-hr-1', bpm: 72, recordedAt: DateTime.utc(2026, 8, 15, 8, 0), tzOffsetMinutes: -180),
        ],
        sleepSessionSamples: [
          SleepSessionSample(
            externalId: 'hc-sleep-1',
            startedAt: DateTime.utc(2026, 8, 14, 23, 0),
            endedAt: DateTime.utc(2026, 8, 15, 6, 30),
            tzOffsetMinutes: -180,
          ),
        ],
      );
      final logger = WearableSyncLogger(core: core, dataSource: dataSource);

      final result = await logger.sync(from: DateTime.utc(2026, 8, 14), to: DateTime.utc(2026, 8, 16));

      expect(result.heartRateSynced, 1);
      expect(result.heartRateAlreadySynced, 0);
      expect(result.sleepSynced, 1);
      expect(result.sleepAlreadySynced, 0);

      final hrEvents = core.queryByType(HealthEventType.heartRate);
      expect(hrEvents, hasLength(1));
      expect(hrEvents.single.source, HealthEventSource.wearable);
      expect(hrEvents.single.externalId, 'hc-hr-1');
      expect(hrEvents.single.payload['bpm'], 72);

      final sleepEvents = core.queryByType(HealthEventType.sleep);
      expect(sleepEvents, hasLength(1));
      expect(sleepEvents.single.payload['duration_minutes'], 450);
    });

    test('sincronizar a mesma janela de novo não duplica — dedup por (source, external_id)', () async {
      final dataSource = FixtureWearableDataSource(
        heartRateSamples: [
          HeartRateSample(externalId: 'hc-hr-1', bpm: 72, recordedAt: DateTime.utc(2026, 8, 15, 8, 0), tzOffsetMinutes: -180),
        ],
      );
      final logger = WearableSyncLogger(core: core, dataSource: dataSource);

      final first = await logger.sync(from: DateTime.utc(2026, 8, 14), to: DateTime.utc(2026, 8, 16));
      expect(first.heartRateSynced, 1);
      expect(first.heartRateAlreadySynced, 0);

      final second = await logger.sync(from: DateTime.utc(2026, 8, 14), to: DateTime.utc(2026, 8, 16));
      expect(second.heartRateSynced, 0);
      expect(second.heartRateAlreadySynced, 1);

      expect(core.queryByType(HealthEventType.heartRate), hasLength(1));
    });

    test('rejeita from/to fora de UTC', () {
      final logger = WearableSyncLogger(core: core, dataSource: FixtureWearableDataSource());
      expect(
        () => logger.sync(from: DateTime(2026, 8, 14), to: DateTime.utc(2026, 8, 16)),
        throwsArgumentError,
      );
    });
  });

  group('sync_wearable — ferramenta do cérebro', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('syncWearableSpec é ferramenta de escrita com confirmação', () {
      final spec = syncWearableSpec();
      expect(spec.write, isTrue);
      expect(spec.confirm, isTrue);
      expect(spec.module, 'wearable');
    });

    test('execução real via handler grava eventos e devolve contagens', () async {
      final dataSource = FixtureWearableDataSource(
        heartRateSamples: [
          HeartRateSample(externalId: 'hc-hr-1', bpm: 58, recordedAt: DateTime.utc(2026, 8, 15, 7, 0), tzOffsetMinutes: -180),
          HeartRateSample(externalId: 'hc-hr-2', bpm: 61, recordedAt: DateTime.utc(2026, 8, 15, 7, 5), tzOffsetMinutes: -180),
        ],
      );
      final logger = WearableSyncLogger(core: core, dataSource: dataSource);
      final handler = syncWearableHandler(logger);

      final result = await handler({
        'from': '2026-08-14T00:00:00Z',
        'to': '2026-08-16T00:00:00Z',
      });

      expect(result.success, isTrue);
      expect(result.data!['heart_rate_synced'], 2);
      expect(result.data!['sleep_synced'], 0);
      expect(core.queryByType(HealthEventType.heartRate), hasLength(2));
    });
  });
}
