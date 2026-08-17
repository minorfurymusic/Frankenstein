import 'package:frankstein_health_core/health_core.dart';

import 'fasten_client.dart';

/// Quantos documentos entraram/já existiam numa chamada de
/// [FastenSyncLogger.sync] — "já existia" não é erro, mesmo raciocínio
/// de `WgerSyncResult`/`WearableSyncResult`.
class FastenSyncResult {
  final int synced;
  final int alreadySynced;
  FastenSyncResult({required this.synced, required this.alreadySynced});
}

/// Sincroniza documentos clínicos do Fasten Health pro Health Data Core
/// (`docs/adr/004-wger-fasten.md`, aceita: Fasten opcional, federado, sem
/// substituto próprio — função exclusiva de prontuário/B2B, fora do MVP
/// grátis; persona "Médico" em `docs/B2B.md`). Cada documento vira um
/// `HealthEvent` tipo `clinical_doc` com `source: HealthEventSource.fasten`
/// e `externalId` igual ao id do recurso FHIR — dedup por `(source,
/// external_id)`.
class FastenSyncLogger {
  final HealthDataCore core;
  final FastenClient client;

  FastenSyncLogger({required this.core, required this.client});

  Future<FastenSyncResult> sync({required DateTime from, required DateTime to}) async {
    if (!from.isUtc || !to.isUtc) {
      throw ArgumentError('from/to precisam estar em UTC');
    }

    var synced = 0;
    var alreadySynced = 0;
    for (final sample in await client.fetchDocuments(from: from, to: to)) {
      final event = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.clinicalDoc,
        source: HealthEventSource.fasten,
        occurredAt: sample.recordedAt,
        occurredAtTzOffsetMinutes: sample.tzOffsetMinutes,
        recordedAt: DateTime.now().toUtc(),
        payload: {
          'resource_type': sample.resourceType,
          'title': sample.title,
          'raw_resource': sample.rawResource,
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

    return FastenSyncResult(synced: synced, alreadySynced: alreadySynced);
  }
}
