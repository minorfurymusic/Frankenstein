import 'package:frankstein_health_core/health_core.dart';

import 'wger_client.dart';

/// Quantas séries entraram/já existiam numa chamada de
/// [WgerSyncLogger.sync] — "já existia" não é erro, é o caso comum de
/// ressincronizar a mesma janela (mesmo raciocínio de
/// `packages/wearable/lib/src/wearable_sync_logger.dart`'s `WearableSyncResult`).
class WgerSyncResult {
  final int synced;
  final int alreadySynced;
  WgerSyncResult({required this.synced, required this.alreadySynced});
}

/// Sincroniza séries de treino do wger pro Health Data Core
/// (`docs/adr/004-wger-fasten.md`, aceita: wger opcional, federado, papel
/// de catálogo estendido — não substitui a Academia própria de F7). Cada
/// série vira um `HealthEvent` tipo `set_log` com
/// `source: HealthEventSource.wger` e `externalId` igual ao id do
/// registro no wger — é esse par que deduplica reimportação da mesma
/// janela.
///
/// **Sem `workout_session` sintético:** diferente do `set_log` gravado
/// por `packages/activity` (F7), que sempre tem uma sessão-mãe, o wger
/// agrupa séries por dia/sessão de um jeito que este ciclo não modela —
/// cada série sincronizada fica solta, sem `session_event_id` no
/// payload. Consultas de recorde por exercício (`queryByType(setLog)`)
/// continuam funcionando; agrupar por sessão do wger fica como trabalho
/// futuro, não fingido aqui.
class WgerSyncLogger {
  final HealthDataCore core;
  final WgerClient client;

  WgerSyncLogger({required this.core, required this.client});

  Future<WgerSyncResult> sync({required DateTime from, required DateTime to}) async {
    if (!from.isUtc || !to.isUtc) {
      throw ArgumentError('from/to precisam estar em UTC');
    }

    var synced = 0;
    var alreadySynced = 0;
    for (final sample in await client.fetchSetLogs(from: from, to: to)) {
      final event = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.setLog,
        source: HealthEventSource.wger,
        occurredAt: sample.recordedAt,
        occurredAtTzOffsetMinutes: sample.tzOffsetMinutes,
        recordedAt: DateTime.now().toUtc(),
        payload: {
          'exercise_name': sample.exerciseName,
          'reps': sample.reps,
          'load_kg': sample.weightKg,
        },
        confidence: 1.0,
        externalId: sample.externalId,
      );
      try {
        core.insertEvent(event);
        synced++;
      } on DuplicateEventException {
        alreadySynced++;
      }
    }

    return WgerSyncResult(synced: synced, alreadySynced: alreadySynced);
  }
}
