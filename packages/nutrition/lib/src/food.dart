// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

/// De onde veio o dado nutricional de um [Food]
/// (`docs/specs/nutricao.md`, seção "Modelo de dados": "`source`: de onde
/// veio o dado nutricional (catálogo offline embarcado ... ou item
/// personalizado do usuário)").
enum FoodSource {
  /// Veio do catálogo local embarcado — hoje um dataset de fixture para
  /// teste; o subconjunto brasileiro real do Open Food Facts
  /// (`docs/OFFLINE-IA.md:31-35`) é trabalho futuro de infraestrutura de
  /// dados, fora deste ciclo.
  offlineCatalog,

  /// Item cadastrado pelo próprio usuário — "adição rápida" (nome + kcal)
  /// ou refeição/receita personalizada (`docs/specs/nutricao.md`, fluxo
  /// "Refeição/receita personalizada").
  custom;

  String get wireValue => switch (this) {
        FoodSource.offlineCatalog => 'offline_catalog',
        FoodSource.custom => 'custom',
      };

  static FoodSource fromWireValue(String value) => switch (value) {
        'offline_catalog' => FoodSource.offlineCatalog,
        'custom' => FoodSource.custom,
        _ => throw ArgumentError('FoodSource desconhecido: $value'),
      };
}

/// Um alimento do catálogo local — busca por nome ou por código de
/// barras, macronutrientes por 100 g (`docs/specs/nutricao.md`, tela
/// "Detalhe do alimento").
///
/// Macros obrigatórios são os quatro que a tela de detalhe sempre mostra
/// (calorias, carboidrato, gordura, proteína); saturada/açúcar/fibra são
/// opcionais porque nem toda fonte tem o dado — "idealmente também
/// saturada, açúcar, fibra" (`docs/specs/nutricao.md`). Micronutrientes
/// ficam fora desta primeira versão — nenhuma fonte usada neste ciclo
/// (o dataset de fixture) os tem; ver "Débito técnico" no relatório do
/// ciclo.
class Food {
  final String id;
  final String? barcode;
  final String name;
  final String? brand;
  final FoodSource source;

  final double energyKcalPer100g;
  final double carbohydratesPer100g;
  final double fatPer100g;
  final double proteinPer100g;
  final double? saturatedFatPer100g;
  final double? sugarPer100g;
  final double? fiberPer100g;
  final double? sodiumPer100g;

  Food({
    required this.id,
    required this.name,
    required this.source,
    required this.energyKcalPer100g,
    required this.carbohydratesPer100g,
    required this.fatPer100g,
    required this.proteinPer100g,
    this.barcode,
    this.brand,
    this.saturatedFatPer100g,
    this.sugarPer100g,
    this.fiberPer100g,
    this.sodiumPer100g,
  }) {
    if (energyKcalPer100g < 0 ||
        carbohydratesPer100g < 0 ||
        fatPer100g < 0 ||
        proteinPer100g < 0) {
      throw ArgumentError('macros de $id não podem ser negativos');
    }
  }
}
