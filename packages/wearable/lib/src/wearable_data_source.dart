import 'heart_rate_sample.dart';
import 'sleep_session_sample.dart';

/// Fonte de leituras de wearable — o Frankstein nunca fala BLE nem
/// embute o Gadgetbridge (`docs/adr/004a-gadgetbridge.md`, aceita:
/// FEDERATE via Android Health Connect, não fork/WRAP). Esta interface
/// abstrai "de onde vêm as leituras" pra [WearableSyncLogger] não
/// precisar saber — mesmo padrão de honestidade de hardware já usado em
/// `StepSensor` (F4) e `BarcodeDecoder` (F6): a implementação real fica
/// pra quando houver Android SDK/device com Health Connect e Gadgetbridge
/// de verdade instalados, o que este ambiente não tem.
///
/// **Implementação real, não feita neste ciclo:** um
/// `HealthConnectWearableDataSource` sobre o plugin Flutter que envolve a
/// API nativa do Health Connect — exige Android SDK, permissões em
/// runtime e um Health Connect de verdade com o Gadgetbridge escrevendo
/// nele pra validar. Registrar isso aqui sem poder provar seria "feito"
/// sem prova (`CLAUDE.md`, regra 1).
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
