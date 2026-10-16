import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

HealthEvent _water(double ml, {DateTime? at}) => HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.water,
      source: HealthEventSource.manual,
      occurredAt: at ?? DateTime.utc(2026, 10, 16, 12),
      occurredAtTzOffsetMinutes: -180,
      recordedAt: DateTime.utc(2026, 10, 16, 12),
      payload: {'amount_ml': ml},
      confidence: 1,
    );

void main() {
  late HealthDataCore core;
  setUp(() => core = HealthDataCore.openInMemory());
  tearDown(() => core.close());

  test('editar: a consulta mostra só a versão nova; o original continua no banco', () {
    final e = _water(500);
    core.insertEvent(e);
    core.editEvent(e.id, payload: {'amount_ml': 300}, at: DateTime.utc(2026, 10, 16, 13));
    final now = core.queryByType(HealthEventType.water);
    expect(now.single.payload['amount_ml'], 300);
    expect(now.single.rootId, e.id);
    expect(core.queryAllVersions(HealthEventType.water), hasLength(2));

    // Editar de novo (pela versão nova ou pelo original) mantém uma só.
    core.editEvent(now.single.id, payload: {'amount_ml': 250}, at: DateTime.utc(2026, 10, 16, 14));
    expect(core.queryByType(HealthEventType.water).single.payload['amount_ml'], 250);
  });

  test('excluir: some da consulta, sem apagar nada; os outros ficam', () {
    final a = _water(500);
    final b = _water(200);
    core.insertEvent(a);
    core.insertEvent(b);
    core.deleteEvent(a.id, at: DateTime.utc(2026, 10, 16, 13));
    expect(core.queryByType(HealthEventType.water).map((e) => e.id), [b.id]);
    expect(core.queryAllVersions(HealthEventType.water), hasLength(3));
    expect(core.getById(a.id), isNotNull);
  });

  test('editado para outro horário entra no filtro pelo horário novo', () {
    final e = _water(500, at: DateTime.utc(2026, 10, 15, 12));
    core.insertEvent(e);
    core.editEvent(e.id, payload: {'amount_ml': 500}, occurredAt: DateTime.utc(2026, 10, 16, 12));
    expect(core.queryByType(HealthEventType.water, from: DateTime.utc(2026, 10, 15), to: DateTime.utc(2026, 10, 15, 23, 59)), isEmpty);
    expect(core.queryByType(HealthEventType.water, from: DateTime.utc(2026, 10, 16), to: DateTime.utc(2026, 10, 16, 23, 59)), hasLength(1));
  });
}
