// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'dart:convert';

import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_profile/profile.dart';

/// Ingrediente de uma receita própria: alimento do catálogo + gramas.
class RecipeIngredient {
  final String foodId;
  final double grams;
  const RecipeIngredient(this.foodId, this.grams);

  Map<String, dynamic> toJson() => {'food_id': foodId, 'grams': grams};
  factory RecipeIngredient.fromJson(Map<String, dynamic> m) =>
      RecipeIngredient(m['food_id'] as String, (m['grams'] as num).toDouble());
}

class Recipe {
  final String foodId; // o alimento próprio que representa a receita
  final String name;
  final double totalGrams;
  final int servings;
  final List<RecipeIngredient> ingredients;
  const Recipe({
    required this.foodId,
    required this.name,
    required this.totalGrams,
    required this.servings,
    required this.ingredients,
  });

  double get servingGrams => totalGrams / servings;

  Map<String, dynamic> toJson() => {
        'food_id': foodId,
        'name': name,
        'total_grams': totalGrams,
        'servings': servings,
        'ingredients': [for (final i in ingredients) i.toJson()],
      };

  factory Recipe.fromJson(Map<String, dynamic> m) => Recipe(
        foodId: m['food_id'] as String,
        name: m['name'] as String,
        totalGrams: (m['total_grams'] as num).toDouble(),
        servings: (m['servings'] as num).toInt(),
        ingredients: [for (final i in (m['ingredients'] as List)) RecipeIngredient.fromJson(i as Map<String, dynamic>)],
      );
}

/// Preferências e restrições de dieta (prancheta DietaMetas). Ficam no
/// aparelho; servem de contexto para a IA quando ela existir — o app não
/// esconde alimento por causa delas.
class DietPreferences {
  final Set<String> tags; // 'vegetariano', 'vegano', 'sem_lactose', 'sem_gluten'
  final String allergies;
  final String dislikes;
  const DietPreferences({this.tags = const {}, this.allergies = '', this.dislikes = ''});

  static const labels = {
    'vegetariano': 'Vegetariano',
    'vegano': 'Vegano',
    'sem_lactose': 'Sem lactose',
    'sem_gluten': 'Sem glúten',
  };

  Map<String, dynamic> toJson() => {'tags': tags.toList()..sort(), 'allergies': allergies, 'dislikes': dislikes};
  factory DietPreferences.fromJson(Map<String, dynamic> m) => DietPreferences(
        tags: {for (final t in (m['tags'] as List? ?? const [])) t as String},
        allergies: m['allergies'] as String? ?? '',
        dislikes: m['dislikes'] as String? ?? '',
      );
}

/// O que a aba Nutrição guarda além dos eventos `meal`: favoritos, itens
/// próprios (adição rápida e receitas) e preferências. Recentes saem dos
/// próprios eventos `meal`.
class NutritionStore {
  final FoodRepository foods;
  final ProfileRepository settings;
  final HealthDataCore core;

  NutritionStore({required this.foods, required this.settings, required this.core});

  List<String> _list(String key) =>
      [for (final v in (jsonDecode(settings.getSetting(key) ?? '[]') as List)) v as String];
  void _saveList(String key, List<String> values) => settings.setSetting(key, jsonEncode(values));

  // ---------- Recentes ----------

  /// Alimentos registrados nos últimos [days] dias, do mais recente para o
  /// mais antigo, sem repetir.
  List<Food> recentFoods({int days = 60, int limit = 20}) {
    final now = DateTime.now().toUtc();
    final events = core.queryByType(HealthEventType.meal, from: now.subtract(Duration(days: days)), to: now.add(const Duration(days: 1)));
    final seen = <String>{};
    final out = <Food>[];
    for (final e in events.reversed) {
      for (final item in (e.payload['items'] as List? ?? const [])) {
        final id = (item as Map<String, dynamic>)['food_id'] as String?;
        if (id == null || !seen.add(id)) continue;
        final food = foods.findById(id);
        if (food != null) out.add(food);
        if (out.length >= limit) return out;
      }
    }
    return out;
  }

  // ---------- Favoritos ----------

  bool isFavorite(String foodId) => _list('favorite_foods').contains(foodId);

  void toggleFavorite(String foodId) {
    final list = _list('favorite_foods');
    list.contains(foodId) ? list.remove(foodId) : list.insert(0, foodId);
    _saveList('favorite_foods', list);
  }

  List<Food> favoriteFoods() => [for (final id in _list('favorite_foods')) ?foods.findById(id)];

  // ---------- Itens próprios ----------

  List<Food> myItems() => [for (final id in _list('my_items')) ?foods.findById(id)];

  void _addMyItem(String foodId) => _saveList('my_items', [foodId, ..._list('my_items').where((i) => i != foodId)]);

  /// Adição rápida (`docs/specs/nutricao.md`, "Adição rápida"): nome + kcal
  /// (macros opcionais) de **uma porção**. Vira alimento próprio cuja
  /// "porção de 100 g" é a porção informada — registrar 100 g = 1 porção.
  Food createQuickItem({
    required String name,
    required double kcal,
    double protein = 0,
    double carbs = 0,
    double fat = 0,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('dê um nome ao item');
    if (kcal <= 0) throw ArgumentError('calorias precisam ser maiores que zero');
    final food = Food(
      id: 'custom-${HealthDataCore.newId()}',
      name: name.trim(),
      source: FoodSource.custom,
      energyKcalPer100g: kcal,
      proteinPer100g: protein,
      carbohydratesPer100g: carbs,
      fatPer100g: fat,
    );
    foods.insertCustomFood(food);
    _addMyItem(food.id);
    return food;
  }

  /// Item próprio com código de barras (quando o código não está no
  /// catálogo): valores por 100 g, como no rótulo.
  Food createBarcodeItem({
    required String barcode,
    required String name,
    required double kcalPer100g,
    double proteinPer100g = 0,
    double carbsPer100g = 0,
    double fatPer100g = 0,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('dê um nome ao item');
    final food = Food(
      id: 'custom-${HealthDataCore.newId()}',
      barcode: barcode.trim(),
      name: name.trim(),
      source: FoodSource.custom,
      energyKcalPer100g: kcalPer100g,
      proteinPer100g: proteinPer100g,
      carbohydratesPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
    );
    foods.insertCustomFood(food);
    _addMyItem(food.id);
    return food;
  }

  // ---------- Receitas próprias ----------

  List<Recipe> recipes() {
    final raw = settings.getSetting('recipes');
    if (raw == null) return const [];
    return [for (final r in jsonDecode(raw) as List) Recipe.fromJson(r as Map<String, dynamic>)];
  }

  Recipe? recipeFor(String foodId) {
    for (final r in recipes()) {
      if (r.foodId == foodId) return r;
    }
    return null;
  }

  /// Monta a receita a partir dos ingredientes (`docs/specs/nutricao.md`,
  /// "Refeição/receita personalizada") e grava um alimento próprio com os
  /// valores por 100 g da receita pronta.
  Recipe createRecipe({required String name, required List<RecipeIngredient> ingredients, int servings = 1}) {
    if (name.trim().isEmpty) throw ArgumentError('dê um nome à receita');
    if (ingredients.isEmpty) throw ArgumentError('a receita precisa de pelo menos um ingrediente');
    if (servings <= 0) throw ArgumentError('porções precisam ser pelo menos 1');
    double total = 0, kcal = 0, p = 0, c = 0, f = 0, fiber = 0;
    var hasFiber = false;
    for (final i in ingredients) {
      final food = foods.findById(i.foodId);
      if (food == null) throw ArgumentError('ingrediente não encontrado: ${i.foodId}');
      if (i.grams <= 0) throw ArgumentError('quantidade do ingrediente precisa ser maior que zero');
      final factor = i.grams / 100;
      total += i.grams;
      kcal += food.energyKcalPer100g * factor;
      p += food.proteinPer100g * factor;
      c += food.carbohydratesPer100g * factor;
      f += food.fatPer100g * factor;
      if (food.fiberPer100g != null) {
        fiber += food.fiberPer100g! * factor;
        hasFiber = true;
      }
    }
    final per100 = 100 / total;
    final food = Food(
      id: 'recipe-${HealthDataCore.newId()}',
      name: name.trim(),
      source: FoodSource.custom,
      energyKcalPer100g: kcal * per100,
      proteinPer100g: p * per100,
      carbohydratesPer100g: c * per100,
      fatPer100g: f * per100,
      fiberPer100g: hasFiber ? fiber * per100 : null,
    );
    foods.insertCustomFood(food);
    final recipe = Recipe(foodId: food.id, name: food.name, totalGrams: total, servings: servings, ingredients: ingredients);
    settings.setSetting('recipes', jsonEncode([recipe.toJson(), for (final r in recipes()) r.toJson()]));
    return recipe;
  }

  // ---------- Preferências ----------

  DietPreferences dietPreferences() {
    final raw = settings.getSetting('diet_preferences');
    return raw == null ? const DietPreferences() : DietPreferences.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  void saveDietPreferences(DietPreferences p) => settings.setSetting('diet_preferences', jsonEncode(p.toJson()));

  // ---------- Fechar o dia ----------

  /// Dias que a pessoa fechou à mão ("fechar dia"). Os anteriores a hoje
  /// contam como fechados automaticamente (00:00) — o resultado é sempre
  /// recalculado dos registros, então registro atrasado atualiza o dia.
  bool isClosedManually(DateTime day) => _list('closed_days').contains(_key(day));

  void closeDay(DateTime day) {
    final list = _list('closed_days');
    if (!list.contains(_key(day))) _saveList('closed_days', [...list, _key(day)]);
  }

  String _key(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
