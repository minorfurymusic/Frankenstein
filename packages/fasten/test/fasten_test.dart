import 'package:frankstein_fasten/fasten.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

void main() {
  group('FastenDocumentSample — validação', () {
    test('rejeita recordedAt fora de UTC', () {
      expect(
        () => FastenDocumentSample(
          externalId: 'fasten-doc-1',
          resourceType: 'DocumentReference',
          title: 'Exame de sangue',
          rawResource: const {'resourceType': 'DocumentReference'},
          recordedAt: DateTime(2026, 8, 16),
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });
  });

  group('FixtureFastenClient', () {
    test('filtra documentos fora do intervalo [from, to]', () async {
      final client = FixtureFastenClient(documents: [
        FastenDocumentSample(
          externalId: 'a',
          resourceType: 'Observation',
          title: 'Colesterol',
          rawResource: const {},
          recordedAt: DateTime.utc(2026, 8, 1),
          tzOffsetMinutes: -180,
        ),
        FastenDocumentSample(
          externalId: 'b',
          resourceType: 'Observation',
          title: 'Colesterol',
          rawResource: const {},
          recordedAt: DateTime.utc(2026, 8, 16),
          tzOffsetMinutes: -180,
        ),
      ]);

      final results = await client.fetchDocuments(from: DateTime.utc(2026, 8, 10), to: DateTime.utc(2026, 8, 20));
      expect(results, hasLength(1));
      expect(results.single.externalId, 'b');
    });
  });

  group('FastenSyncLogger', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('sincroniza documentos novos, gravando HealthEvent clinical_doc com source fasten', () async {
      final client = FixtureFastenClient(documents: [
        FastenDocumentSample(
          externalId: 'fasten-doc-1',
          resourceType: 'DocumentReference',
          title: 'Hemograma completo',
          rawResource: const {
            'resourceType': 'DocumentReference',
            'status': 'current',
          },
          recordedAt: DateTime.utc(2026, 8, 16, 10, 0),
          tzOffsetMinutes: -180,
        ),
      ]);
      final logger = FastenSyncLogger(core: core, client: client);

      final result = await logger.sync(from: DateTime.utc(2026, 8, 15), to: DateTime.utc(2026, 8, 17));

      expect(result.synced, 1);
      expect(result.alreadySynced, 0);

      final events = core.queryByType(HealthEventType.clinicalDoc);
      expect(events, hasLength(1));
      expect(events.single.source, HealthEventSource.fasten);
      expect(events.single.externalId, 'fasten-doc-1');
      expect(events.single.payload['title'], 'Hemograma completo');
      expect(events.single.payload['resource_type'], 'DocumentReference');
      expect((events.single.payload['raw_resource'] as Map)['status'], 'current');
    });

    test('sincronizar a mesma janela de novo não duplica — dedup por (source, external_id)', () async {
      final client = FixtureFastenClient(documents: [
        FastenDocumentSample(
          externalId: 'fasten-doc-1',
          resourceType: 'Observation',
          title: 'Glicemia',
          rawResource: const {},
          recordedAt: DateTime.utc(2026, 8, 16, 10, 0),
          tzOffsetMinutes: -180,
        ),
      ]);
      final logger = FastenSyncLogger(core: core, client: client);

      final first = await logger.sync(from: DateTime.utc(2026, 8, 15), to: DateTime.utc(2026, 8, 17));
      expect(first.synced, 1);

      final second = await logger.sync(from: DateTime.utc(2026, 8, 15), to: DateTime.utc(2026, 8, 17));
      expect(second.synced, 0);
      expect(second.alreadySynced, 1);

      expect(core.queryByType(HealthEventType.clinicalDoc), hasLength(1));
    });

    test('rejeita from/to fora de UTC', () {
      final logger = FastenSyncLogger(core: core, client: FixtureFastenClient());
      expect(
        () => logger.sync(from: DateTime(2026, 8, 15), to: DateTime.utc(2026, 8, 17)),
        throwsArgumentError,
      );
    });
  });

  group('sync_fasten_records — ferramenta do cérebro', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('syncFastenRecordsSpec é ferramenta de escrita com confirmação', () {
      final spec = syncFastenRecordsSpec();
      expect(spec.write, isTrue);
      expect(spec.confirm, isTrue);
      expect(spec.module, 'fasten');
    });

    test('execução real via handler grava eventos e devolve contagens', () async {
      final client = FixtureFastenClient(documents: [
        FastenDocumentSample(
          externalId: 'fasten-doc-1',
          resourceType: 'Observation',
          title: 'Pressão arterial',
          rawResource: const {},
          recordedAt: DateTime.utc(2026, 8, 16, 10, 0),
          tzOffsetMinutes: -180,
        ),
      ]);
      final logger = FastenSyncLogger(core: core, client: client);
      final handler = syncFastenRecordsHandler(logger);

      final result = await handler({
        'from': '2026-08-15T00:00:00Z',
        'to': '2026-08-17T00:00:00Z',
      });

      expect(result.success, isTrue);
      expect(result.data!['synced'], 1);
      expect(core.queryByType(HealthEventType.clinicalDoc), hasLength(1));
    });
  });
}
