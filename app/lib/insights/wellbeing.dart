import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';

import '../app_dependencies.dart';
import '../data/day_read_model.dart';
import '../format.dart';
import '../screens/health/mental_health_screen.dart' show mentalSymptoms;

/// Resumos da semana e do mês para a análise "Como estou?" (ADR-25).
/// Calculados no celular; só estas linhas vão à IA — nunca o histórico,
/// exames, documentos ou nomes de remédio.
class WellbeingSnapshot {
  final List<String> lines;
  final bool includesMental;
  const WellbeingSnapshot(this.lines, {this.includesMental = false});

  bool get isEmpty => lines.isEmpty;
  String get text => lines.join('\n');
}

String _n(num v, [int d = 0]) => formatNumber(v, decimals: d);

/// Monta os resumos dos últimos 7 dias, comparando com as 3 semanas
/// anteriores. [includeMental]: humor e sintomas mentais (consentimento
/// próprio, desligado por padrão).
WellbeingSnapshot buildWellbeingSnapshot(AppDependencies deps, {DateTime? now, bool? includeMental}) {
  final today = now ?? DateTime.now();
  final mental = includeMental ?? deps.ai.mentalHealthConsent;
  final day0 = DateTime(today.year, today.month, today.day);
  List<DateTime> range(int from, int count) => [for (var i = from; i < from + count; i++) day0.subtract(Duration(days: i))];
  final week = [for (final d in range(0, 7)) deps.dayRead.totals(d)];
  final before = [for (final d in range(7, 21)) deps.dayRead.totals(d)];
  final lines = <String>[];

  double avg(Iterable<num> v) => v.isEmpty ? 0 : v.fold<double>(0, (s, x) => s + x) / v.length;

  // Comida (só dias com registro, para não puxar a média para baixo).
  final ate = week.where((d) => d.mealCount > 0).toList();
  final ateBefore = before.where((d) => d.mealCount > 0).toList();
  if (ate.isNotEmpty) {
    final goal = deps.goals.goalsFor(day0);
    final kcal = avg(ate.map((d) => d.energyKcal));
    var line = 'Comida: ${ate.length} de 7 dias com registro; média de ${_n(kcal)} kcal/dia';
    if (goal != null) {
      final over = ate.where((d) => d.energyKcal > goal.caloriesKcal * 1.1).length;
      line += ' (meta ${_n(goal.caloriesKcal)} kcal; acima da meta em $over dias)';
    }
    if (ateBefore.isNotEmpty) line += '; nas 3 semanas anteriores, ${_n(avg(ateBefore.map((d) => d.energyKcal)))} kcal/dia';
    lines.add('$line.');
    lines.add('Proteína: média de ${_n(avg(ate.map((d) => d.proteinGrams)))} g/dia'
        '${goal == null ? '' : ' (meta ${_n(goal.proteinGrams)} g)'}.');
    double sugarOf(DayTotals d) => d.meals.fold(0.0, (s, e) {
          final t = e.payload['totals'] as Map<String, dynamic>? ?? const {};
          return s + ((t['sugar_g'] as num?)?.toDouble() ?? 0);
        });
    final sugarDays = ate.where((d) => sugarOf(d) > 0).toList();
    if (sugarDays.isNotEmpty) {
      final sugarBefore = ateBefore.where((d) => sugarOf(d) > 0);
      lines.add('Açúcar (onde foi estimado): média de ${_n(avg(sugarDays.map(sugarOf)))} g/dia'
          '${sugarBefore.isEmpty ? '' : '; antes, ${_n(avg(sugarBefore.map(sugarOf)))} g/dia'}.');
    }
  }

  final water = week.where((d) => d.waterMl > 0);
  if (water.isNotEmpty) lines.add('Água: média de ${_n(avg(water.map((d) => d.waterMl)))} ml/dia em ${water.length} dias.');

  // Peso: primeira e última medida do mês.
  final weights = deps.healthRead.weights(days: 35);
  if (weights.length >= 2) {
    final newest = weights.first;
    final oldest = weights.last;
    final diff = newest.value - oldest.value;
    lines.add('Peso: ${_n(oldest.value, 1)} kg em ${ddmmyyyy(oldest.local)} → ${_n(newest.value, 1)} kg em '
        '${ddmmyyyy(newest.local)} (${diff >= 0 ? '+' : ''}${_n(diff, 1)} kg).');
  } else if (weights.length == 1) {
    lines.add('Peso: ${_n(weights.first.value, 1)} kg (uma medida no mês).');
  }

  // Movimento.
  final steps = avg(week.map((d) => d.steps));
  if (steps > 0) lines.add('Passos: média de ${_n(steps)}/dia; antes, ${_n(avg(before.map((d) => d.steps)))}/dia.');
  final workouts = week.fold<int>(0, (s, d) => s + d.workoutCount);
  final workoutsBefore = before.fold<int>(0, (s, d) => s + d.workoutCount) / 3;
  final km = week.fold<double>(0, (s, d) => s + d.runMeters) / 1000;
  if (workouts > 0 || workoutsBefore > 0 || km > 0) {
    lines.add('Exercício: $workouts treinos de academia na semana (média anterior ${_n(workoutsBefore, 1)}/semana)'
        '${km > 0 ? '; ${_n(km, 1)} km de corrida/caminhada gravada' : ''}.');
  }

  // Sono (da pulseira).
  final sleeps = deps.core.queryByType(HealthEventType.sleep,
      from: day0.toUtc().subtract(const Duration(days: 7)), to: day0.toUtc().add(const Duration(days: 1)));
  final minutes = [for (final e in sleeps) (e.payload['duration_minutes'] as num?)?.toDouble() ?? 0].where((m) => m > 0);
  if (minutes.isNotEmpty) lines.add('Sono: média de ${_n(avg(minutes) / 60, 1)} h por noite em ${minutes.length} noites.');

  // Remédios: só a adesão, sem nomes.
  final meds = deps.healthRead.activeMedications();
  if (meds.isNotEmpty) {
    final expected = meds.fold<int>(0, (s, m) => s + m.timesOfDay.length) * 7;
    final doses = deps.core.queryByType(HealthEventType.medicationDose,
        from: day0.toUtc().subtract(const Duration(days: 7)), to: day0.toUtc().add(const Duration(days: 1)));
    final taken = doses.where((e) => e.payload['status'] == 'taken').length;
    lines.add('Remédios de uso contínuo: $taken de $expected doses marcadas como tomadas na semana.');
  }

  // Sintomas (os mentais só com o consentimento próprio).
  final symptoms = deps.healthRead.symptoms(days: 14);
  final counts = <String, int>{};
  for (final s in symptoms) {
    if (!mental && mentalSymptoms.contains(s.name)) continue;
    counts[s.name] = (counts[s.name] ?? 0) + 1;
  }
  if (counts.isNotEmpty) {
    lines.add('Sintomas registrados em 14 dias: ${counts.entries.map((e) => '${e.key} (${e.value}x)').join(', ')}.');
  }

  if (mental) {
    final moods = deps.healthRead.moods(days: 14);
    if (moods.isNotEmpty) {
      final low = moods.where((m) => m.mood <= 2).length;
      final feelings = <String, int>{};
      for (final m in moods) {
        for (final f in m.feelings) {
          feelings[f] = (feelings[f] ?? 0) + 1;
        }
      }
      final top = (feelings.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(3);
      lines.add('Humor (1 a 5) em 14 dias: média ${_n(avg(moods.map((m) => m.mood)), 1)}; $low registros "mal" ou "muito mal"'
          '${top.isEmpty ? '' : '; sentimentos mais marcados: ${top.map((e) => e.key).join(', ')}'}.');
    }
  }
  return WellbeingSnapshot(lines, includesMental: mental);
}

/// O que a IA devolve para "Como estou?".
class WellbeingReading {
  final String summary;
  final List<String> observations;
  final List<String> suggestions;
  const WellbeingReading({required this.summary, this.observations = const [], this.suggestions = const []});
}

const wellbeingSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'summary': {'type': 'string'},
    'observations': {
      'type': 'array',
      'items': {'type': 'string'},
    },
    'suggestions': {
      'type': 'array',
      'items': {'type': 'string'},
    },
  },
  'required': ['summary'],
};

const wellbeingInstruction = '''
Você é o Cérebro do RLT, um app de saúde pessoal no Brasil. A pessoa pediu "Como estou?". Você recebe só resumos calculados pelo app (médias e tendências), não o histórico.
- summary: 1 ou 2 frases, em português simples e acolhedor, sobre o que os números mostram.
- observations: até 4 relações que os números mostram (ex.: "o peso subiu 1 kg enquanto as calorias ficaram acima da meta em 5 de 7 dias"). Só o que está nos dados; sem inventar.
- suggestions: até 3 próximos passos pequenos e práticos, em forma de pedido que a pessoa pode tocar para conversar (ex.: "Me ajude a trocar o doce da tarde por algo que eu goste").
Regras: nunca diagnostique nem rotule transtorno; nunca indique remédio, dose, suplemento ou dieta nova (troca equivalente dentro do plano existente pode); sem julgar. Se os dados de humor indicarem sofrimento, inclua em summary que conversar com alguém de confiança ou um profissional ajuda. Se faltarem dados, diga o que registrar para a análise melhorar.
''';

Future<WellbeingReading> readWellbeing(GeminiClient client, WellbeingSnapshot snapshot) async {
  final json = await client.generateJson(
    system: wellbeingInstruction,
    parts: [AiPart.text('Resumos da pessoa:\n${snapshot.text}')],
    schema: wellbeingSchema,
  );
  List<String> list(String k) => [
        for (final x in (json[k] as List? ?? const []))
          if (x is String && x.trim().isNotEmpty) x.trim(),
      ];
  return WellbeingReading(
    summary: (json['summary'] as String).trim(),
    observations: list('observations').take(4).toList(),
    suggestions: list('suggestions').take(3).toList(),
  );
}
