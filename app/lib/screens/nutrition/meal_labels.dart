// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_nutrition/nutrition.dart';

String mealTypeLabel(MealType t) => switch (t) {
      MealType.breakfast => 'Café da manhã',
      MealType.lunch => 'Almoço',
      MealType.dinner => 'Jantar',
      MealType.snack => 'Lanche',
    };

/// Refeição sugerida pelo horário (prompt do design: "refeição pelo
/// horário" — 08:00 → café da manhã). A pessoa sempre pode trocar.
MealType mealTypeForTime(DateTime local) {
  final h = local.hour;
  if (h >= 5 && h < 11) return MealType.breakfast;
  if (h >= 11 && h < 15) return MealType.lunch;
  if (h >= 18 && h < 23) return MealType.dinner;
  return MealType.snack;
}
