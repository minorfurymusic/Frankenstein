/// Um exercício dentro de um [WorkoutPlan] — alvo, não execução real
/// (`docs/PRODUTO.md:28`: "planos, sessão ao vivo, séries/repetições/carga").
/// A execução de verdade vira [SetEntry] via [WorkoutLogger], separada do
/// plano — o plano é só o que foi prescrito.
class PlannedExercise {
  final String exerciseId;
  final String exerciseName;
  final int targetSets;
  final int targetReps;
  final double? targetLoadKg;

  PlannedExercise({
    required this.exerciseId,
    required this.exerciseName,
    required this.targetSets,
    required this.targetReps,
    this.targetLoadKg,
  }) {
    if (targetSets <= 0) throw ArgumentError('targetSets precisa ser positivo');
    if (targetReps <= 0) throw ArgumentError('targetReps precisa ser positivo');
  }
}

/// Um plano de treino — catálogo local, não é `HealthEvent` (mesma lógica
/// de "catálogo reutilizável" que `packages/nutrition` já usa para
/// alimentos: um plano é referenciado por sessões executadas, não é ele
/// mesmo um evento).
class WorkoutPlan {
  final String id;
  final String name;
  final List<PlannedExercise> exercises;

  WorkoutPlan({
    required this.id,
    required this.name,
    required this.exercises,
  }) {
    if (exercises.isEmpty) {
      throw ArgumentError('WorkoutPlan precisa de ao menos um exercício');
    }
  }
}
