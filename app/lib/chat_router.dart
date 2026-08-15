import 'package:frankstein_brain/brain.dart';

/// Roteador determinístico do app — comandos estruturados explícitos,
/// mesmo padrão de `packages/brain/test/brain_test.dart` (não é
/// entendimento de linguagem natural livre; frases fora do formato ficam
/// `unresolved`, sem LLM implementado nesta fase — `.claude/rules/brain.md`,
/// passo 1: "Comando frequente NÃO chama o modelo").
///
/// Cobre 3 das 7 ferramentas registradas (`app_dependencies.dart`): duas
/// de leitura (`get_daily_summary`, `get_steps`) e uma de escrita
/// (`log_meal`, prova o fluxo de confirmação de ponta a ponta). As
/// demais (`search_food`, `get_workout_plan`, `log_workout_session`,
/// `get_run_summary`) ficam acessíveis pelo `ToolRegistry` direto (ex.:
/// a tela de resumo chama `get_daily_summary` sem passar pelo chat) —
/// dar regra de chat pra cada uma é trabalho de UI futuro, não escopo
/// deste ciclo.
DeterministicRouter buildChatRouter() {
  final logMealItemPattern = RegExp(r'([a-z0-9\-]+)\s+(\d+(?:\.\d+)?)g');
  final logMealPattern = RegExp(
    r'^registrar refeição (breakfast|lunch|dinner|snack): (.+)$',
    caseSensitive: false,
  );

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
