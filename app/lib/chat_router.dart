import 'package:frankstein_brain/brain.dart';

/// Roteador determinístico do app — comandos estruturados explícitos,
/// mesmo padrão de `packages/brain/test/brain_test.dart` (não é
/// entendimento de linguagem natural livre; frases fora do formato ficam
/// `unresolved`, sem LLM implementado nesta fase — `.claude/rules/brain.md`,
/// passo 1: "Comando frequente NÃO chama o modelo").
///
/// Cobre as 8 ferramentas registradas (`app_dependencies.dart`): cinco
/// de leitura (`get_daily_summary`, `get_steps`, `search_food`,
/// `get_workout_plan`, `get_run_summary`) e três de escrita (`log_meal`,
/// `log_workout_session`, `log_water` — as três provam o fluxo de
/// confirmação de ponta a ponta).
///
/// **Simplificação registrada em `log_workout_session`:** o comando de
/// chat usa `exercise_name = exercise_id` (o schema real da ferramenta
/// pede os dois campos separados, `packages/activity/lib/src/workout_tools.dart`)
/// — um atalho de texto plano não tem como capturar um nome livre de
/// exercício sem ambiguidade de sintaxe; quem quiser nome diferente do
/// id ainda pode chamar a ferramenta direto pelo `ToolRegistry`.
DeterministicRouter buildChatRouter() {
  final logMealItemPattern = RegExp(r'([a-z0-9\-]+)\s+(\d+(?:\.\d+)?)g');
  final logMealPattern = RegExp(
    r'^registrar refeição (breakfast|lunch|dinner|snack): (.+)$',
    caseSensitive: false,
  );
  final logWorkoutSetPattern = RegExp(r'([a-z0-9\-]+)\s+(\d+)x(\d+)x(\d+(?:\.\d+)?)');
  final logWorkoutPattern = RegExp(r'^registrar treino: (.+)$', caseSensitive: false);
  final logWaterPattern = RegExp(r'^registrar água (\d+(?:\.\d+)?)\s*ml$', caseSensitive: false);

  return DeterministicRouter([
    RouterRule(
      toolName: 'get_daily_summary',
      pattern: RegExp(r'^resumo (do dia|de hoje)$', caseSensitive: false),
      extractParams: (_) => {'date': _todayIso()},
    ),
    RouterRule(
      toolName: 'get_steps',
      pattern: RegExp(r'^quantos passos( eu dei)?( hoje)?\??$', caseSensitive: false),
      extractParams: (_) => {'date': _todayIso()},
    ),
    RouterRule(
      toolName: 'search_food',
      pattern: RegExp(r'^buscar alimento (.+)$', caseSensitive: false),
      extractParams: (match) => {'query': match.group(1)!.trim()},
    ),
    RouterRule(
      toolName: 'get_workout_plan',
      pattern: RegExp(r'^plano de treino ([a-z0-9\-]+)$', caseSensitive: false),
      extractParams: (match) => {'plan_id': match.group(1)},
    ),
    RouterRule(
      toolName: 'get_run_summary',
      pattern: RegExp(r'^resumo da corrida ([a-z0-9\-]+)$', caseSensitive: false),
      extractParams: (match) => {'event_id': match.group(1)},
    ),
    RouterRule(
      toolName: 'log_meal',
      pattern: logMealPattern,
      extractParams: (match) {
        final mealType = match.group(1)!.toLowerCase();
        final itemsRaw = match.group(2)!;
        final items = logMealItemPattern.allMatches(itemsRaw).map((m) {
          return {'food_id': m.group(1), 'grams': double.parse(m.group(2)!)};
        }).toList();
        return {'items': items, 'meal_type': mealType};
      },
    ),
    RouterRule(
      toolName: 'log_workout_session',
      pattern: logWorkoutPattern,
      extractParams: (match) {
        final setsRaw = match.group(1)!;
        final sets = logWorkoutSetPattern.allMatches(setsRaw).map((m) {
          final exerciseId = m.group(1)!;
          return {
            'exercise_id': exerciseId,
            'exercise_name': exerciseId,
            'set_number': int.parse(m.group(2)!),
            'reps': int.parse(m.group(3)!),
            'load_kg': double.parse(m.group(4)!),
          };
        }).toList();
        return {'sets': sets};
      },
    ),
    RouterRule(
      toolName: 'log_water',
      pattern: logWaterPattern,
      extractParams: (match) => {'amount_ml': double.parse(match.group(1)!)},
    ),
  ]);
}

/// Data de hoje em UTC, formato `YYYY-MM-DD` — mesma simplificação já
/// documentada em `getStepsHandler`/`getDailySummaryHandler` (dia tratado
/// em UTC, não no fuso local de cada evento).
String _todayIso() {
  final now = DateTime.now().toUtc();
  final month = now.month.toString().padLeft(2, '0');
  final day = now.day.toString().padLeft(2, '0');
  return '${now.year}-$month-$day';
}
