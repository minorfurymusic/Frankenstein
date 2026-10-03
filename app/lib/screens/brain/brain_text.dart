import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../widgets/health_area.dart';

/// Como um cartão de proposta mostra uma ferramenta de escrita: área de
/// destino, título, detalhe e onde fica salvo depois de confirmado.
class ProposalView {
  final HealthArea area;
  final String title;
  final String? detail;
  final String savedIn;
  const ProposalView(this.area, this.title, this.detail, this.savedIn);
}

ProposalView describeProposal(AppDependencies deps, String tool, Map<String, dynamic> p) {
  String n(Object? v, {int d = 0}) => v is num ? formatNumber(v, decimals: d) : '$v';
  switch (tool) {
    case 'log_water':
      return ProposalView(HealthArea.water, 'Água — ${n(p['amount_ml'])} ml', 'hoje, agora', 'Nutrição › Água');
    case 'log_meal':
      final items = (p['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      var kcal = 0.0;
      final names = <String>[];
      for (final i in items) {
        final food = deps.foodRepository.findById('${i['food_id']}');
        final grams = (i['grams'] as num).toDouble();
        names.add('${food?.name ?? i['food_id']} ${n(grams)} g');
        if (food != null) kcal += food.energyKcalPer100g * grams / 100;
      }
      final type = MealType.values.where((t) => t.name == p['meal_type']).firstOrNull;
      final label = type == null ? 'Refeição' : _mealLabel(type);
      return ProposalView(HealthArea.meal, '$label — ${names.join(', ')}', '${n(kcal)} kcal', 'Nutrição › $label');
    case 'log_workout_session':
      final sets = (p['sets'] as List? ?? const []).cast<Map<String, dynamic>>();
      return ProposalView(
        HealthArea.workout,
        'Treino — ${sets.length} ${sets.length == 1 ? 'série' : 'séries'}',
        sets.map((s) => '${s['exercise_name']} ${n(s['load_kg'], d: 1)} kg × ${s['reps']}').join(' · '),
        'Exercícios › Academia',
      );
    case 'add_medication':
      return ProposalView(HealthArea.medication, '${p['name']} ${n(p['dose_amount'])} ${p['dose_unit']}',
          'Horários: ${(p['times'] as List? ?? const []).join(', ')}', 'Saúde › Remédios');
    case 'log_medication_dose':
      return ProposalView(HealthArea.medication, 'Remédio ${p['status'] == 'skipped' ? 'pulado' : 'tomado'} — ${p['name']}',
          p['dose_amount'] == null ? null : '${n(p['dose_amount'])} ${p['dose_unit'] ?? ''}', 'Saúde › Remédios');
    case 'log_symptom':
      return ProposalView(HealthArea.symptom, 'Sintoma — ${p['name']}',
          p['intensity'] == null ? null : 'Intensidade ${p['intensity']} de 10', 'Saúde › Histórico médico');
    case 'log_vital_sign':
      return ProposalView(HealthArea.vitalSign, 'Sinal vital — ${p['kind']}', '$p', 'Saúde › Sinais vitais');
    case 'log_body_measurement':
      return ProposalView(HealthArea.body, 'Medida — ${p['kind']}', '$p', 'Saúde › Corpo');
    default:
      return ProposalView(HealthArea.body, tool, '$p', 'RLT');
  }
}

String _mealLabel(MealType t) => switch (t) {
      MealType.breakfast => 'Café da manhã',
      MealType.lunch => 'Almoço',
      MealType.dinner => 'Jantar',
      MealType.snack => 'Lanche',
    };

/// Resposta legível de uma ferramenta de leitura (modo básico, sem IA).
String describeReadResult(String tool, Map<String, dynamic> data) {
  String n(Object? v, {int d = 0}) => v is num ? formatNumber(v, decimals: d) : '$v';
  switch (tool) {
    case 'get_daily_summary':
      final steps = data['steps'] as Map;
      final meals = data['meals'] as Map;
      final water = data['water'] as Map;
      final workouts = data['workouts'] as Map;
      final runs = data['runs'] as Map;
      return 'Resumo de hoje: ${n(steps['total'])} passos, ${n(meals['total_energy_kcal'])} kcal em '
          '${meals['count']} ${meals['count'] == 1 ? 'refeição' : 'refeições'}, ${n(water['total_amount_ml'])} ml de água, '
          '${workouts['count']} ${workouts['count'] == 1 ? 'treino' : 'treinos'} e '
          '${n((runs['total_distance_meters'] as num) / 1000, d: 1)} km de corrida/caminhada.';
    case 'get_steps':
      return 'Hoje: ${n(data['total_steps'])} passos.';
    case 'search_food':
      final results = (data['results'] as List? ?? const []).cast<Map<String, dynamic>>();
      if (results.isEmpty) return 'Não achei esse alimento no catálogo.';
      return 'Encontrei:\n${results.take(8).map((r) => '• ${r['name']} — ${n(r['energy_kcal_100g'])} kcal/100 g (${r['id']})').join('\n')}';
    case 'get_workout_plan':
      final exercises = (data['exercises'] as List? ?? const []).cast<Map<String, dynamic>>();
      return '${data['name'] ?? 'Plano'}:\n${exercises.map((e) => '• ${e['exercise_name']} ${e['target_sets']}×${e['target_reps']}').join('\n')}';
    case 'get_run_summary':
      return 'Corrida: ${n((data['distance_meters'] as num? ?? 0) / 1000, d: 2)} km em '
          '${n((data['duration_seconds'] as num? ?? 0) / 60)} min.';
    default:
      return '$data';
  }
}

String describeOutcome(AppDependencies deps, PipelineResult r) {
  switch (r.outcome) {
    case PipelineOutcome.unresolved:
      return 'Não entendi. No modo básico eu entendo comandos como "registrar água 500ml" ou "resumo de hoje". '
          'Para texto livre, fotos e voz, ative a IA em Conta › Cérebro.';
    case PipelineOutcome.rejected:
      return 'Não consegui montar esse registro: ${r.validationErrors!.join('; ')}';
    case PipelineOutcome.abortedByUser:
      return 'Ok, não registrei nada.';
    case PipelineOutcome.executed:
      final t = r.toolResult!;
      if (!t.success) return 'Não deu certo: ${t.error}';
      final spec = deps.registry.specFor(r.toolName!);
      if (spec.write) return 'Pronto, salvo.';
      return describeReadResult(r.toolName!, t.data ?? const {});
  }
}
