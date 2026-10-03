/// Pulseira/relógio via Health Connect (Fase 9, `docs/adr/004a-gadgetbridge.md`
/// aceita: FEDERATE, não WRAP/fork — o Frankstein nunca fala BLE nem
/// embute o Gadgetbridge, só lê o que ele já escreveu no Android Health
/// Connect).
///
/// `HeartRateSample`/`SleepSessionSample` (leituras, com `externalId`
/// obrigatório pra dedup; sono com fases), `WearableDataSource` (interface —
/// implementação real sobre o Health Connect no app,
/// `app/lib/wearables/health_connect.dart`),
/// `WearableSyncLogger` (grava no Health Data Core, deduplicando
/// reimportação da mesma janela) e `sync_wearable` (ferramenta do
/// cérebro).
library;

export 'src/heart_rate_sample.dart';
export 'src/sleep_session_sample.dart';
export 'src/wearable_data_source.dart';
export 'src/wearable_sync_logger.dart';
export 'src/wearable_tools.dart';
