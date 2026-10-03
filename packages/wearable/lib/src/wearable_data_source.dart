import 'heart_rate_sample.dart';
import 'sleep_session_sample.dart';

/// Fonte de leituras de wearable — o Frankstein nunca fala BLE nem
/// embute o Gadgetbridge (`docs/adr/004a-gadgetbridge.md`, aceita:
/// FEDERATE via Android Health Connect, não fork/WRAP). Esta interface
/// abstrai "de onde vêm as leituras" pra [WearableSyncLogger] não
/// precisar saber.
///
/// Implementação real: `HealthConnectDataSource` em
/// `app/lib/wearables/health_connect.dart`, sobre o canal
/// `rlt/health_connect` (`HealthConnectBridge.kt`). Validação com Health
/// Connect e pulseira de verdade só no aparelho.
abstract class WearableDataSource {
  Future<List<HeartRateSample>> readHeartRate({required DateTime from, required DateTime to});
  Future<List<SleepSessionSample>> readSleepSessions({required DateTime from, required DateTime to});
}

/// Fonte de fixture — só para teste, mesmo papel que `FixtureBarcodeDecoder`
/// tem em `packages/nutrition` (F6): dados fabricados, registrados
/// explicitamente na hora de construir, sem pretender ser Health Connect
/// real.
class FixtureWearableDataSource implements WearableDataSource {
  final List<HeartRateSample> heartRateSamples;
  final List<SleepSessionSample> sleepSessionSamples;

  FixtureWearableDataSource({
    this.heartRateSamples = const [],
    this.sleepSessionSamples = const [],
  });

  @override
  Future<List<HeartRateSample>> readHeartRate({required DateTime from, required DateTime to}) async {
    return heartRateSamples
        .where((s) => !s.recordedAt.isBefore(from) && !s.recordedAt.isAfter(to))
        .toList();
  }

  @override
  Future<List<SleepSessionSample>> readSleepSessions({required DateTime from, required DateTime to}) async {
    return sleepSessionSamples
        .where((s) => !s.startedAt.isBefore(from) && !s.startedAt.isAfter(to))
        .toList();
  }
}
