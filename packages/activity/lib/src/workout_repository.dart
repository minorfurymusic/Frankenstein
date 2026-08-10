import 'package:sqlite3/sqlite3.dart';

import 'workout_plan.dart';

const String _workoutPlansSchemaSql = '''
CREATE TABLE IF NOT EXISTS workout_plans (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS workout_plan_exercises (
  id TEXT PRIMARY KEY,
  plan_id TEXT NOT NULL REFERENCES workout_plans(id),
  seq INTEGER NOT NULL,
  exercise_id TEXT NOT NULL,
  exercise_name TEXT NOT NULL,
  target_sets INTEGER NOT NULL,
  target_reps INTEGER NOT NULL,
  target_load_kg REAL
);

CREATE INDEX IF NOT EXISTS idx_workout_plan_exercises_plan_id
  ON workout_plan_exercises(plan_id);
''';

/// Catálogo local de planos de treino — mesmo papel que `FoodRepository`
/// tem para alimentos (`packages/nutrition/lib/src/food_repository.dart`):
/// um plano é referenciado por sessões executadas, não é ele mesmo um
/// `HealthEvent` (`docs/PRODUTO.md:28`).
///
/// Sobre `sqlite3` (bindings FFI Dart puro), mesmo padrão de
/// `packages/health_core/lib/src/health_data_core.dart` — mantém o
/// pacote testável com `dart test` puro.
class WorkoutRepository {
  final Database _db;

  WorkoutRepository._(this._db);

  /// Abre (ou cria) o catálogo no caminho de arquivo dado.
  factory WorkoutRepository.open(String path) {
    final db = sqlite3.open(path);
    db.execute(_workoutPlansSchemaSql);
    return WorkoutRepository._(db);
  }

  /// Catálogo em memória — uso em teste.
  factory WorkoutRepository.openInMemory() {
    final db = sqlite3.openInMemory();
    db.execute(_workoutPlansSchemaSql);
    return WorkoutRepository._(db);
  }

  void close() => _db.dispose();

  void insertPlan(WorkoutPlan plan) {
    _db.execute(
      'INSERT INTO workout_plans (id, name) VALUES (?, ?)',
      [plan.id, plan.name],
    );
    for (var i = 0; i < plan.exercises.length; i++) {
      final exercise = plan.exercises[i];
      _db.execute(
        '''
        INSERT INTO workout_plan_exercises (
          id, plan_id, seq, exercise_id, exercise_name, target_sets,
          target_reps, target_load_kg
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        [
          '${plan.id}-$i',
          plan.id,
          i,
          exercise.exerciseId,
          exercise.exerciseName,
          exercise.targetSets,
          exercise.targetReps,
          exercise.targetLoadKg,
        ],
      );
    }
  }

  WorkoutPlan? findPlanById(String id) {
    final planRows = _db.select('SELECT * FROM workout_plans WHERE id = ?', [id]);
    if (planRows.isEmpty) return null;

    final exerciseRows = _db.select(
      'SELECT * FROM workout_plan_exercises WHERE plan_id = ? ORDER BY seq ASC',
      [id],
    );

    return WorkoutPlan(
      id: planRows.first['id'] as String,
      name: planRows.first['name'] as String,
      exercises: exerciseRows
          .map((r) => PlannedExercise(
                exerciseId: r['exercise_id'] as String,
                exerciseName: r['exercise_name'] as String,
                targetSets: r['target_sets'] as int,
                targetReps: r['target_reps'] as int,
                targetLoadKg: (r['target_load_kg'] as num?)?.toDouble(),
              ))
          .toList(),
    );
  }
}
