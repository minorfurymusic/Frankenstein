import 'package:frankstein_health_core/health_core.dart';

import 'wearable_data_source.dart';

/// Quantas leituras entraram/já existiam numa chamada de
/// [WearableSyncLogger.sync]. "Já existia" não é erro — sincronizar a
/// mesma janela duas vezes é o caso comum (`sync_wearable` roda de novo
/// sem o usuário controlar exatamente o intervalo já coberto), e a
/// deduplicação por `(source, external_id)` (`.claude/rules/datacore.md`)
/// já resolve isso no Health Data Core — este resultado só reporta o que
/// aconteceu, não trata reimportação como falha.
class WearableSyncResult {
  final int heartRateSynced;
  final int heartRateAlreadySynced;
  final int sleepSynced;
  final int sleepAlreadySynced;

  WearableSyncResult({
    required this.heartRateSynced,
    required this.heartRateAlreadySynced,
    required this.sleepSynced,
    required this.sleepAlreadySynced,
  });
}

/// Sincroniza frequência cardíaca e sono de um [WearableDataSource] pro
/// Health Data Core (`docs/PRODUTO.md:62`). Toda leitura vira um
/// `HealthEvent` com `source: HealthEventSource.wearable` e
/// `externalId` igual ao id do registro na fonte — é esse par que
/// deduplica reimportação da mesma janela.
class WearableSyncLogger {
  final HealthDataCore core;
  final WearableDataSource dataSource;

  WearableSyncLogger({required this.core, required this.dataSource});

  Future<WearableSyncResult> sync({required DateTime from, required DateTime to}) async {
    if (!from.isUtc || !to.isUtc) {
      throw ArgumentError('from/to precisam estar em UTC');
    }

    var heartRateSynced = 0;
    var heartRateAlreadySynced = 0;
    for (final sample in await dataSource.readHeartRate(from: from, to: to)) {
      final inserted = _insertIfNew(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.heartRate,
        source: HealthEventSource.wearable,
        occurredAt: sample.recordedAt,
        occurredAtTzOffsetMinutes: sample.tzOffsetMinutes,
        recordedAt: DateTime.now().toUtc(),
        payload: {'bpm': sample.bpm},
        confidence: 1.0,
        externalId: sample.externalId,
      ));
      if (inserted) {
        heartRateSynced++;
      } else {
        heartRateAlreadySynced++;
      }
    }

    var sleepSynced = 0;
    var sleepAlreadySynced = 0;
    for (final sample in await dataSource.readSleepSessions(from: from, to: to)) {
      final inserted = _insertIfNew(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.sleep,
        source: HealthEventSource.wearable,
        occurredAt: sample.startedAt,
        occurredAtTzOffsetMinutes: sample.tzOffsetMinutes,
        recordedAt: DateTime.now().toUtc(),
        payload: {
          'started_at': sample.startedAt.toIso8601String(),
          'ended_at': sample.endedAt.toIso8601String(),
          'duration_minutes': sample.duration.inMinutes,
        },
        confidence: 1.0,
        externalId: sample.externalId,
      ));
      if (inserted) {
        sleepSynced++;
      } else {
        sleepAlreadySynced++;
      }
    }

    return WearableSyncResult(
      heartRateSynced: heartRateSynced,
      heartRateAlreadySynced: heartRateAlreadySynced,
      sleepSynced: sleepSynced,
      sleepAlreadySynced: sleepAlreadySynced,
    );
  }

  bool _insertIfNew(HealthEvent event) {
    try {
      core.insertEvent(event);
      return true;
    } on DuplicateEventException {
      return false;
    }
  }
}
