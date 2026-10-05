import 'dart:convert';

import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_profile/profile.dart';

/// De onde veio o plano de refeições.
enum MealPlanSource {
  manual('Montado por você'),
  imported('Do seu profissional'),
  ai('Sugestão da IA');

  final String label;
  const MealPlanSource(this.label);
}

class MealPlanItem {
  final String description;
  final double? kcal;
  final double? proteinGrams;
  final double? carbsGrams;
  final double? fatGrams;

  MealPlanItem({required this.description, this.kcal, this.proteinGrams, this.carbsGrams, this.fatGrams}) {
    if (description.trim().isEmpty) throw ArgumentError('descreva o item');
  }

  Map<String, Object?> toJson() => {
        'description': description.trim(),
        'kcal': kcal,
        'protein_g': proteinGrams,
        'carbs_g': carbsGrams,
        'fat_g': fatGrams,
      };

  factory MealPlanItem.fromJson(Map<String, dynamic> m) => MealPlanItem(
        description: m['description'] as String,
        kcal: (m['kcal'] as num?)?.toDouble(),
        proteinGrams: (m['protein_g'] as num?)?.toDouble(),
        carbsGrams: (m['carbs_g'] as num?)?.toDouble(),
        fatGrams: (m['fat_g'] as num?)?.toDouble(),
      );
}

class MealPlanMeal {
  final MealType mealType;
  final String? time;
  final List<MealPlanItem> items;
  const MealPlanMeal({required this.mealType, this.time, this.items = const []});

  double get kcal => items.fold(0, (s, i) => s + (i.kcal ?? 0));

  Map<String, Object?> toJson() => {
        'meal_type': mealType.wireValue,
        'time': time,
        'items': [for (final i in items) i.toJson()],
      };

  factory MealPlanMeal.fromJson(Map<String, dynamic> m) => MealPlanMeal(
        mealType: MealType.fromWireValue(m['meal_type'] as String),
        time: m['time'] as String?,
        items: [for (final i in (m['items'] as List? ?? const [])) MealPlanItem.fromJson(i as Map<String, dynamic>)],
      );
}

/// Plano de refeições de um dia-tipo (pedido do usuário, 2026-10-05):
/// montado pela pessoa, importado do profissional (a IA lê a foto/PDF) ou
/// sugerido pela IA a partir das metas e preferências. Valores de calorias
/// vindos da IA são estimativa.
class MealPlan {
  final String name;
  final MealPlanSource source;
  final DateTime createdAt;
  final String? notes;

  /// Calorias/macros estimadas pela IA (importação ou sugestão).
  final bool estimated;

  /// Foto/PDF do plano do profissional, na pasta privada do app.
  final List<String> attachments;
  final List<MealPlanMeal> meals;

  MealPlan({
    required this.name,
    required this.source,
    required this.createdAt,
    this.notes,
    this.estimated = false,
    this.attachments = const [],
    this.meals = const [],
  }) {
    if (name.trim().isEmpty) throw ArgumentError('dê um nome ao plano');
  }

  double get kcal => meals.fold(0, (s, m) => s + m.kcal);

  List<MealPlanMeal> mealsOf(MealType t) => [for (final m in meals) if (m.mealType == t) m];

  Map<String, Object?> toJson() => {
        'name': name.trim(),
        'source': source.name,
        'created_at': createdAt.toUtc().toIso8601String(),
        'notes': notes,
        'estimated': estimated,
        'attachments': attachments,
        'meals': [for (final m in meals) m.toJson()],
      };

  factory MealPlan.fromJson(Map<String, dynamic> m) => MealPlan(
        name: m['name'] as String,
        source: MealPlanSource.values.byName(m['source'] as String),
        createdAt: DateTime.parse(m['created_at'] as String),
        notes: m['notes'] as String?,
        estimated: m['estimated'] as bool? ?? false,
        attachments: [for (final a in (m['attachments'] as List? ?? const [])) a as String],
        meals: [for (final x in (m['meals'] as List? ?? const [])) MealPlanMeal.fromJson(x as Map<String, dynamic>)],
      );

  /// Rascunho da IA → plano (a pessoa ainda revisa antes de salvar).
  factory MealPlan.fromDraft(MealPlanDraft d, {required MealPlanSource source, required String fallbackName, List<String> attachments = const []}) =>
      MealPlan(
        name: d.name ?? fallbackName,
        source: source,
        createdAt: DateTime.now(),
        notes: d.notes,
        estimated: true,
        attachments: attachments,
        meals: [
          for (final m in d.meals)
            MealPlanMeal(
              mealType: MealType.fromWireValue(m.mealType),
              time: m.time,
              items: [
                for (final i in m.items)
                  MealPlanItem(
                    description: i.description,
                    kcal: i.kcal,
                    proteinGrams: i.proteinGrams,
                    carbsGrams: i.carbsGrams,
                    fatGrams: i.fatGrams,
                  ),
              ],
            ),
        ],
      );
}

/// Guarda o plano no aparelho (tabela de configurações do perfil).
class MealPlanStore {
  final ProfileRepository settings;
  MealPlanStore(this.settings);

  MealPlan? load() {
    final raw = settings.getSetting('meal_plan');
    if (raw == null || raw.isEmpty) return null;
    return MealPlan.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void save(MealPlan p) => settings.setSetting('meal_plan', jsonEncode(p.toJson()));
  void delete() => settings.setSetting('meal_plan', null);
}
