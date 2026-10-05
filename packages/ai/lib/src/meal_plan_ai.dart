import 'gemini_client.dart';

/// Item do plano: o que comer, como escrito (ex.: "2 ovos mexidos"), com
/// calorias e macros quando conhecidas — sempre estimativa da IA.
class PlanItemDraft {
  final String description;
  final double? kcal;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;
  const PlanItemDraft({required this.description, this.kcal, this.proteinGrams, this.carbsGrams, this.fatGrams});
}

class PlanMealDraft {
  /// `breakfast`, `lunch`, `dinner` ou `snack` (as refeições do app).
  final String mealType;

  /// "07:30", quando o plano diz.
  final String? time;
  final List<PlanItemDraft> items;
  const PlanMealDraft({required this.mealType, this.time, this.items = const []});
}

class MealPlanDraft {
  final String? name;
  final String? notes;
  final List<PlanMealDraft> meals;
  const MealPlanDraft({this.name, this.notes, this.meals = const []});
}

const mealPlanSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'name': {'type': 'string'},
    'notes': {'type': 'string'},
    'meals': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'meal_type': {
            'type': 'string',
            'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
          },
          'time': {'type': 'string', 'description': 'HH:MM, se o plano disser.'},
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'description': {'type': 'string'},
                'kcal': {'type': 'number'},
                'protein_g': {'type': 'number'},
                'carbs_g': {'type': 'number'},
                'fat_g': {'type': 'number'},
              },
              'required': ['description'],
            },
          },
        },
        'required': ['meal_type', 'items'],
      },
    },
  },
  'required': ['meals'],
};

const mealPlanImportInstruction = '''
Você transcreve um plano alimentar (cardápio) feito por um profissional, enviado em foto ou PDF, para um app de saúde pessoal.
Regras:
- Copie as refeições e os itens como estão no documento, com as quantidades escritas (ex.: "2 colheres de sopa de arroz"). Não mude, não troque e não acrescente alimentos.
- meal_type: café da manhã = breakfast; almoço = lunch; jantar = dinner; lanches, colação, ceia = snack.
- Se o plano der opções ("ou"), mantenha numa mesma descrição.
- kcal, protein_g, carbs_g e fat_g: se o documento trouxer, copie; se não trouxer, faça uma estimativa razoável para a quantidade escrita (o app marca como estimativa).
- Não dê orientação de saúde nem comente o plano. Notas do profissional vão em notes, sem mudar o sentido.
''';

const mealPlanSuggestInstruction = '''
Você monta uma SUGESTÃO de cardápio de um dia para um app de saúde pessoal no Brasil. É uma sugestão: um ponto de partida que a pessoa revisa e ajusta.
Regras:
- Use as metas do dia informadas (calorias e macronutrientes) como alvo aproximado da soma do dia.
- Respeite as preferências e restrições informadas. NUNCA inclua alimento citado como alergia ou como "não gosta".
- Use comida comum no Brasil, simples de achar e de preparar, com quantidades caseiras (ex.: "4 colheres de sopa de arroz").
- Não inclua suplementos, remédios, chás medicinais nem jejum.
- meal_type: breakfast, lunch, dinner e snack (pode haver mais de um snack).
- Preencha kcal, protein_g, carbs_g e fat_g de cada item (estimativa).
- name: um nome curto para o cardápio. notes: uma frase dizendo que é uma sugestão e que a pessoa pode ajustar.
''';

double? _num(Object? v) {
  if (v is! num) return null;
  final d = v.toDouble();
  return d.isFinite && d >= 0 ? d : null;
}

MealPlanDraft parseMealPlan(Map<String, dynamic> json) {
  final meals = <PlanMealDraft>[];
  for (final raw in (json['meals'] as List? ?? const [])) {
    final m = raw as Map<String, dynamic>;
    final items = <PlanItemDraft>[];
    for (final i in (m['items'] as List? ?? const [])) {
      final it = i as Map<String, dynamic>;
      final d = (it['description'] as String).trim();
      if (d.isEmpty) continue;
      items.add(PlanItemDraft(
        description: d,
        kcal: _num(it['kcal']),
        proteinGrams: _num(it['protein_g']),
        carbsGrams: _num(it['carbs_g']),
        fatGrams: _num(it['fat_g']),
      ));
    }
    if (items.isEmpty) continue;
    final time = (m['time'] as String?)?.trim();
    meals.add(PlanMealDraft(
      mealType: m['meal_type'] as String,
      time: time != null && RegExp(r'^\d{1,2}:\d{2}$').hasMatch(time) ? time : null,
      items: items,
    ));
  }
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  return MealPlanDraft(name: text(json['name']), notes: text(json['notes']), meals: meals);
}

/// Lê o plano do profissional (fotos e/ou PDF anexados pela pessoa).
Future<MealPlanDraft> readMealPlan(GeminiClient client, List<AiPart> files) async {
  final json = await client.generateJson(
    system: mealPlanImportInstruction,
    parts: [...files, const AiPart.text('Transcreva este plano alimentar.')],
    schema: mealPlanSchema,
  );
  return parseMealPlan(json);
}

/// Pede uma sugestão de cardápio. Vai só o mínimo: metas do dia e
/// preferências — nada de nome, histórico ou dado clínico.
Future<MealPlanDraft> suggestMealPlan(
  GeminiClient client, {
  required double caloriesKcal,
  required double proteinGrams,
  required double carbsGrams,
  required double fatGrams,
  double? fiberGrams,
  Set<String> preferences = const {},
  String allergies = '',
  String dislikes = '',
}) async {
  String f(double v) => v.round().toString();
  final prompt = StringBuffer()
    ..writeln('Metas do dia: ${f(caloriesKcal)} kcal; proteína ${f(proteinGrams)} g; carboidrato ${f(carbsGrams)} g; '
        'gordura ${f(fatGrams)} g${fiberGrams == null ? '' : '; fibra ${f(fiberGrams)} g'}.')
    ..writeln('Preferências: ${preferences.isEmpty ? 'nenhuma' : (preferences.toList()..sort()).join(', ')}.')
    ..writeln('Alergias alimentares: ${allergies.trim().isEmpty ? 'nenhuma informada' : allergies.trim()}.')
    ..writeln('Não gosta de: ${dislikes.trim().isEmpty ? 'nada informado' : dislikes.trim()}.');
  final json = await client.generateJson(
    system: mealPlanSuggestInstruction,
    parts: [AiPart.text(prompt.toString())],
    schema: mealPlanSchema,
  );
  return parseMealPlan(json);
}
