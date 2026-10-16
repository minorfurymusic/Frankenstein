import 'gemini_client.dart';

/// Um exercício como está na ficha da academia.
class ReadPlannedExercise {
  final String name;
  final int sets;
  final int reps;

  /// Carga escrita, em kg; `null` quando não há (peso do corpo).
  final double? loadKg;
  const ReadPlannedExercise({required this.name, required this.sets, required this.reps, this.loadKg});
}

/// Ficha de treino lida (ADR-19). Estimativa: a pessoa confere no plano
/// antes de salvar.
class WorkoutPlanReading {
  final String? name;
  final List<ReadPlannedExercise> exercises;
  const WorkoutPlanReading({this.name, this.exercises = const []});
}

const workoutPlanSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'name': {'type': 'string'},
    'exercises': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'sets': {'type': 'integer'},
          'reps': {'type': 'integer'},
          'load_kg': {'type': 'number'},
        },
        'required': ['name', 'sets', 'reps'],
      },
    },
  },
  'required': ['exercises'],
};

const workoutPlanInstruction = '''
Você transcreve uma ficha de treino de academia (foto ou PDF) para um app de saúde pessoal.
- name: o nome escrito na ficha (ex.: "Treino A — peito e tríceps"); se não houver, deixe de fora.
- exercises: cada exercício na ordem da ficha, com o nome em português como escrito, sets (séries), reps (repetições; faixa "8-12" vira 12) e load_kg (carga, só se escrita; libras viram kg).
- Ficha com vários treinos (A, B, C): transcreva todos em sequência, com o nome do treino no começo do nome do exercício ("A — Supino reto").
- Copie, não mude, não troque nem acrescente exercício. Não comente nem dê orientação.
''';

WorkoutPlanReading parseWorkoutPlan(Map<String, dynamic> json) {
  final out = <ReadPlannedExercise>[];
  for (final raw in (json['exercises'] as List? ?? const [])) {
    final e = raw as Map<String, dynamic>;
    final name = e['name'] is String ? (e['name'] as String).trim() : '';
    final sets = e['sets'];
    final reps = e['reps'];
    if (name.isEmpty || sets is! int || reps is! int || sets < 1 || sets > 20 || reps < 1 || reps > 200) continue;
    final load = e['load_kg'];
    out.add(ReadPlannedExercise(
      name: name,
      sets: sets,
      reps: reps,
      loadKg: load is num && load > 0 && load < 1000 ? load.toDouble() : null,
    ));
  }
  final name = json['name'];
  return WorkoutPlanReading(name: name is String && name.trim().isNotEmpty ? name.trim() : null, exercises: out);
}

/// Lê a ficha de treino anexada pela pessoa.
Future<WorkoutPlanReading> readWorkoutPlan(GeminiClient client, List<AiPart> files) async {
  final json = await client.generateJson(
    system: workoutPlanInstruction,
    parts: [...files, const AiPart.text('Transcreva esta ficha de treino.')],
    schema: workoutPlanSchema,
  );
  return parseWorkoutPlan(json);
}
