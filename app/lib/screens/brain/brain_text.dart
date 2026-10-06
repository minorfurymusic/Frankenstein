import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../widgets/health_area.dart';
import '../health/documents_screens.dart' show formatMarkerValue;

/// Como um cartão de proposta mostra uma ferramenta de escrita: área de
/// destino, título, detalhe e onde fica salvo depois de confirmado.
class ProposalView {
  final HealthArea area;
  final String title;
  final String? detail;
  final String savedIn;

  /// Quando a pessoa disse ("hoje, 09:00"); sem hora dita, vale agora.
  final String? when;

  /// Valores estimados pela IA — o cartão marca e deixa editar.
  final bool estimated;
  const ProposalView(this.area, this.title, this.detail, this.savedIn, {this.when, this.estimated = false});
}

/// "hoje, 09:00", "ontem, 21:30" ou "03/10, 08:00" — no fuso do aparelho.
String? whenLabel(Object? atUtc, {DateTime? now}) {
  if (atUtc is! String) return null;
  final at = DateTime.tryParse(atUtc)?.toLocal();
  if (at == null) return null;
  final today = now ?? DateTime.now();
  final d0 = DateTime(today.year, today.month, today.day);
  final d = DateTime(at.year, at.month, at.day);
  final diff = d0.difference(d).inDays;
  String two(int v) => v.toString().padLeft(2, '0');
  final day = switch (diff) {
    0 => 'hoje',
    1 => 'ontem',
    _ => '${two(at.day)}/${two(at.month)}',
  };
  return '$day, ${two(at.hour)}:${two(at.minute)}';
}

const _bodyLabels = {
  'weight': 'Peso',
  'body_fat': 'Gordura corporal',
  'waist': 'Cintura',
  'hip': 'Quadril',
  'chest': 'Peito',
  'neck': 'Pescoço',
  'arm': 'Braço',
  'thigh': 'Coxa',
  'calf': 'Panturrilha',
};

ProposalView describeProposal(AppDependencies deps, String tool, Map<String, dynamic> p) {
  String n(Object? v, {int d = 0}) => v is num ? formatNumber(v, decimals: d) : '$v';
  final when = whenLabel(p['at']);
  switch (tool) {
    case 'log_water':
      return ProposalView(HealthArea.water, 'Água — ${n(p['amount_ml'])} ml', null, 'Nutrição › Água', when: when ?? 'hoje, agora');
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
      final label = _mealLabelOf(p['meal_type']);
      return ProposalView(HealthArea.meal, '$label — ${names.join(', ')}', '${n(kcal)} kcal', 'Nutrição › $label', when: when);
    case 'log_estimated_meal':
      final items = (p['items'] as List? ?? const []).cast<Map<String, dynamic>>();
      final kcal = items.fold<double>(0, (s, i) => s + (i['kcal'] as num).toDouble());
      final label = _mealLabelOf(p['meal_type']);
      return ProposalView(
        HealthArea.meal,
        '$label — ${items.map((i) => '${i['name']} ${n(i['grams'])} g').join(', ')}',
        '≈ ${n(kcal)} kcal (estimativa)',
        'Nutrição › $label',
        when: when,
        estimated: true,
      );
    case 'log_workout_session':
      final sets = (p['sets'] as List? ?? const []).cast<Map<String, dynamic>>();
      return ProposalView(
        HealthArea.workout,
        'Treino — ${sets.length} ${sets.length == 1 ? 'série' : 'séries'}',
        sets.map((s) => '${s['exercise_name']} ${n(s['load_kg'], d: 1)} kg × ${s['reps']}').join(' · '),
        'Exercícios › Academia',
        when: when,
      );
    case 'add_medication':
      return ProposalView(HealthArea.medication, '${p['name']} ${n(p['dose_amount'])} ${p['dose_unit']}',
          'Horários: ${(p['times'] as List? ?? const []).join(', ')}', 'Saúde › Remédios');
    case 'log_medication_dose':
      final med = p['medication_id'] == null ? null : deps.medicationRepository.findById('${p['medication_id']}');
      final name = p['name'] ?? med?.name ?? 'remédio';
      final amount = p['dose_amount'] ?? med?.doseAmount;
      final unit = p['dose_unit'] ?? med?.doseUnit;
      return ProposalView(HealthArea.medication, 'Remédio ${p['status'] == 'skipped' ? 'pulado' : 'tomado'} — $name',
          amount == null ? null : '${n(amount, d: amount is num && amount % 1 != 0 ? 1 : 0)} ${unit ?? ''}'.trim(), 'Saúde › Remédios',
          when: when ?? 'hoje, agora');
    case 'log_symptom':
      return ProposalView(HealthArea.symptom, 'Sintoma — ${p['name']}',
          p['intensity'] == null ? null : 'Intensidade ${p['intensity']} de 10', 'Saúde › Histórico médico',
          when: when ?? 'hoje, agora');
    case 'log_vital_sign':
      final title = switch (p['kind']) {
        'blood_pressure' => 'Pressão — ${n(p['systolic_mmhg'])}/${n(p['diastolic_mmhg'])} mmHg',
        'glucose' => 'Glicemia — ${n(p['glucose_mg_dl'])} mg/dL',
        'temperature' => 'Temperatura — ${n(p['celsius'], d: 1)} °C',
        'spo2' => 'Saturação — ${n(p['spo2_percent'])}%',
        'heart_rate' => 'Frequência cardíaca — ${n(p['bpm'])} bpm',
        _ => 'Sinal vital — ${p['kind']}',
      };
      return ProposalView(HealthArea.vitalSign, title, p['glucose_context'] as String?, 'Saúde › Sinais vitais',
          when: when ?? 'hoje, agora');
    case 'log_body_measurement':
      final kind = '${p['kind']}';
      final unit = switch (kind) { 'weight' => 'kg', 'body_fat' => '%', _ => 'cm' };
      final v = p['value'];
      return ProposalView(HealthArea.body, '${_bodyLabels[kind] ?? kind} — ${n(v, d: v is num && v % 1 != 0 ? 1 : 0)} $unit', null,
          'Saúde › Corpo',
          when: when ?? 'hoje, agora');
    default:
      return ProposalView(HealthArea.body, tool, '$p', 'RLT');
  }
}

String _mealLabelOf(Object? wire) {
  final type = MealType.values.where((t) => t.name == wire).firstOrNull;
  return type == null ? 'Refeição' : _mealLabel(type);
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
    case 'get_medication_agenda':
      final doses = (data['doses'] as List? ?? const []).cast<Map<String, dynamic>>();
      if (doses.isEmpty) return 'Nenhum remédio na agenda de hoje.';
      String status(Object? s) => switch (s) { 'taken' => 'tomado', 'skipped' => 'pulado', _ => 'pendente' };
      return 'Remédios de hoje:\n${doses.map((d) => '• ${d['time']} ${d['name']} ${n(d['dose_amount'])} ${d['dose_unit']} — ${status(d['status'])}').join('\n')}';
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

String _day(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Resumo da receita lida, para o Cérebro.
String describePrescriptionReading(PrescriptionReading r) {
  if (r.medicines.isEmpty) return 'Não achei remédios nesta receita. Você pode revisar e preencher à mão.';
  final who = [
    r.doctor ?? 'médico não identificado',
    if (r.date != null) _day(r.date!),
  ].join(', ');
  final count = r.medicines.length == 1 ? '1 remédio' : '${r.medicines.length} remédios';
  final valid = r.validUntil == null ? '' : ' Válida até ${_day(r.validUntil!)}.';
  return 'Receita de $who: $count — ${r.medicines.map((m) => m.name).join('; ')}.$valid';
}

/// Resumo do exame lido, para o Cérebro: os valores como estão no laudo,
/// sem dizer se estão altos ou baixos.
String describeExamReading(ExamReading r) {
  if (r.markers.isEmpty) return 'Não achei valores numéricos neste exame. Você pode revisar e preencher à mão.';
  final head = [r.title ?? 'Exame', if (r.date != null) _day(r.date!)].join(' de ');
  final count = r.markers.length == 1 ? '1 valor lido' : '${r.markers.length} valores lidos';
  final sample = r.markers.take(3).map((m) => '${m.name} ${formatMarkerValue(m.value)} ${m.unit}'.trim()).join(', ');
  return '$head: $count ($sample${r.markers.length > 3 ? '…' : ''}).';
}
