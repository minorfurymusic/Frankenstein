import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_summary/summary.dart';
import 'package:test/test.dart';

HealthEvent _event({
  required HealthEventType type,
  required Map<String, dynamic> payload,
  required DateTime occurredAt,
}) {
  return HealthEvent(
    id: HealthDataCore.newId(),
    type: type,
    source: HealthEventSource.manual,
    occurredAt: occurredAt,
    occurredAtTzOffsetMinutes: -180,
    recordedAt: occurredAt,
    payload: payload,
    confidence: 1.0,
  );
}

void main() {
  group('get_daily_summary', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('getDailySummarySpec é ferramenta de leitura', () {
      final spec = getDailySummarySpec();
      expect(spec.write, isFalse);
      expect(spec.confirm, isFalse);
      expect(spec.module, 'summary');
    });

    test('junta passos, refeições, treino e corrida do dia pedido, ignora outros dias', () async {
      final day = DateTime.utc(2026, 8, 10);
      final outroDia = DateTime.utc(2026, 8, 11);

      core.insertEvent(_event(
        type: HealthEventType.steps,
        payload: {'count': 3000},
        occurredAt: day.add(const Duration(hours: 8)),
      ));
      core.insertEvent(_event(
        type: HealthEventType.steps,
        payload: {'count': 2500},
        occurredAt: day.add(const Duration(hours: 18)),
      ));
      core.insertEvent(_event(
        type: HealthEventType.meal,
        payload: {
          'meal_type': 'lunch',
          'items': [],
          'totals': {'energy_kcal': 650.0, 'carbohydrates_g': 80.0, 'fat_g': 20.0, 'protein_g': 30.0},
        },
        occurredAt: day.add(const Duration(hours: 12)),
      ));
      core.insertEvent(_event(
        type: HealthEventType.workoutSession,
        payload: {'sets_count': 12, 'exercise_ids': ['supino-reto']},
        occurredAt: day.add(const Duration(hours: 19)),
      ));
      core.insertEvent(_event(
        type: HealthEventType.water,
        payload: {'amount_ml': 250.0},
        occurredAt: day.add(const Duration(hours: 9)),
      ));
      core.insertEvent(_event(
        type: HealthEventType.water,
        payload: {'amount_ml': 300.0},
        occurredAt: day.add(const Duration(hours: 15)),
      ));
      core.insertEvent(_event(
        type: HealthEventType.gpsTrack,
        payload: {'distance_meters': 5200.0, 'duration_seconds': 1800},
        occurredAt: day.add(const Duration(hours: 7)),
      ));

      // Ruído de outro dia — não pode entrar no resumo.
      core.insertEvent(_event(
        type: HealthEventType.steps,
        payload: {'count': 9999},
        occurredAt: outroDia.add(const Duration(hours: 8)),
      ));

      final result = await getDailySummaryHandler(core)({'date': '2026-08-10'});

      expect(result.success, isTrue);
      final data = result.data!;
      expect((data['steps'] as Map)['total'], 5500);
      expect((data['steps'] as Map)['events_counted'], 2);
      expect((data['meals'] as Map)['count'], 1);
      expect((data['meals'] as Map)['total_energy_kcal'], 650.0);
      expect((data['water'] as Map)['count'], 2);
      expect((data['water'] as Map)['total_amount_ml'], 550.0);
      expect((data['workouts'] as Map)['count'], 1);
      expect((data['workouts'] as Map)['total_sets'], 12);
      expect((data['runs'] as Map)['count'], 1);
      expect((data['runs'] as Map)['total_distance_meters'], 5200.0);
    });

    test('dia sem nenhum evento devolve zeros, não erro', () async {
      final result = await getDailySummaryHandler(core)({'date': '2026-08-10'});
      expect(result.success, isTrue);
      expect((result.data!['steps'] as Map)['total'], 0);
      expect((result.data!['meals'] as Map)['count'], 0);
      expect((result.data!['water'] as Map)['count'], 0);
    });
  });
}
