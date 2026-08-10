/// Uma série executada de verdade — vira um `HealthEvent` tipo `set_log`
/// (`docs/ARQUITETURA.md:32`), granular por propósito: cada série é
/// consultável por conta própria (progressão/recorde por exercício ao
/// longo do tempo), não só dentro do resumo da sessão.
class SetEntry {
  final String exerciseId;
  final String exerciseName;
  final int setNumber;
  final int reps;
  final double loadKg;

  /// RPE (esforço percebido, 1-10) — opcional, `docs/PRODUTO.md:28`.
  final double? rpe;

  SetEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.setNumber,
    required this.reps,
    required this.loadKg,
    this.rpe,
  }) {
    if (setNumber <= 0) throw ArgumentError('setNumber precisa ser positivo');
    if (reps <= 0) throw ArgumentError('reps precisa ser positivo');
    if (loadKg < 0) throw ArgumentError('loadKg não pode ser negativo');
    if (rpe != null && (rpe! < 1 || rpe! > 10)) {
      throw ArgumentError('rpe precisa estar entre 1 e 10');
    }
  }
}

/// Entrada de uma sessão de treino já concluída — o que [WorkoutLogger]
/// recebe pra gravar. Não é o `HealthEvent` em si (esse é gerado por
/// `WorkoutLogger.logSession`, tipo `workout_session` + um `set_log` por
/// item de [sets]).
class WorkoutSessionInput {
  final String? planId;
  final List<SetEntry> sets;
  final String? notes;

  WorkoutSessionInput({
    this.planId,
    required this.sets,
    this.notes,
  }) {
    if (sets.isEmpty) {
      throw ArgumentError('WorkoutSessionInput precisa de ao menos uma série');
    }
  }
}
