import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

void main() {
  test('treino com duração grava duration_seconds no evento', () {
    final core = HealthDataCore.openInMemory();
    addTearDown(core.close);
    final e = WorkoutLogger(core: core).logSession(
      WorkoutSessionInput(
        sets: [SetEntry(exerciseId: 'supino-reto', exerciseName: 'Supino reto', setNumber: 1, reps: 10, loadKg: 40)],
        duration: const Duration(minutes: 45),
      ),
      occurredAt: DateTime.utc(2026, 10, 3, 12),
      occurredAtTzOffsetMinutes: -180,
    );
    expect(e.payload['duration_seconds'], 2700);
  });

  test('outras atividades: MET pela intensidade e duração no evento', () {
    final core = HealthDataCore.openInMemory();
    addTearDown(core.close);
    final e = ActivityLogger(core: core).log(
      activity: OtherActivity.swimming,
      intensity: ActivityIntensity.moderate,
      duration: const Duration(minutes: 30),
      occurredAt: DateTime.utc(2026, 10, 3, 12),
      occurredAtTzOffsetMinutes: -180,
    );
    expect(e.type, HealthEventType.workoutSession);
    expect(e.payload['kind'], 'other_activity');
    expect(e.payload['met'], 8.3);
    expect(e.payload['duration_seconds'], 1800);
    expect(
      () => ActivityLogger(core: core).log(
        activity: OtherActivity.other,
        intensity: ActivityIntensity.light,
        duration: Duration.zero,
        occurredAt: DateTime.utc(2026),
        occurredAtTzOffsetMinutes: 0,
      ),
      throwsArgumentError,
    );
  });

  test('ACSM: 6 km/h caminhando ≈ 3,86 MET; 10 km/h correndo ≈ 10,5 MET', () {
    expect(acsmMetForSpeed(6000 / 60 - 0.01), closeTo((0.1 * 99.99 + 3.5) / 3.5, 1e-9));
    expect(acsmMetForSpeed(10000 / 60), closeTo((0.2 * 166.667 + 3.5) / 3.5, 0.001));
  });

  test('planos: listar, salvar de novo (editar) e apagar', () {
    final repo = WorkoutRepository.openInMemory();
    addTearDown(repo.close);
    PlannedExercise ex(String id) =>
        PlannedExercise(exerciseId: id, exerciseName: findCatalogExercise(id)!.name, targetSets: 3, targetReps: 10);
    repo.savePlan(WorkoutPlan(id: 'b', name: 'Treino B', exercises: [ex('agachamento')]));
    repo.savePlan(WorkoutPlan(id: 'a', name: 'Treino A', exercises: [ex('supino-reto'), ex('remada-baixa')]));
    expect(repo.listPlans().map((p) => p.name), ['Treino A', 'Treino B']);
    repo.savePlan(WorkoutPlan(id: 'a', name: 'Treino A', exercises: [ex('flexao')]));
    expect(repo.findPlanById('a')!.exercises.single.exerciseId, 'flexao');
    repo.deletePlan('b');
    expect(repo.listPlans().single.id, 'a');
  });

  test('catálogo tem ids únicos', () {
    final ids = exerciseCatalog.map((e) => e.id).toList();
    expect(ids.toSet().length, ids.length);
  });
}
