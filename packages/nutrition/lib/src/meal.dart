// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

/// Categoria da refeição — `docs/ARQUITETURA.md:73` (contrato da
/// ferramenta `log_meal`) e `docs/specs/nutricao.md` ("café da manhã,
/// almoço, jantar, lanche").
enum MealType {
  breakfast,
  lunch,
  dinner,
  snack;

  String get wireValue => name;

  static MealType fromWireValue(String value) => MealType.values.firstWhere(
        (t) => t.name == value,
        orElse: () => throw ArgumentError('MealType desconhecido: $value'),
      );
}

/// Como o item chegou a esta refeição — não faz parte do contrato JSON de
/// `log_meal` (`docs/ARQUITETURA.md:60-79`, que só exige `food_id`+`grams`
/// por item), mas o payload gravado no [HealthEvent] guarda essa
/// informação quando disponível, porque `docs/specs/nutricao.md` lista os
/// três caminhos ("busca por nome, escaneamento de código de barras, ou
/// 'adição rápida'") como parte do comportamento esperado do módulo.
enum MealItemInputMethod {
  search,
  barcode,
  quickAdd,

  /// Quem chamou (ex.: a ferramenta do cérebro, que só recebe `food_id`)
  /// não informou o caminho — não é um bug, é a ausência legítima desse
  /// dado nesse caminho de entrada.
  unspecified;

  String get wireValue => switch (this) {
        MealItemInputMethod.search => 'search',
        MealItemInputMethod.barcode => 'barcode',
        MealItemInputMethod.quickAdd => 'quick_add',
        MealItemInputMethod.unspecified => 'unspecified',
      };
}

/// Um item de entrada para [MealLogger.logMeal] — referência a um `Food`
/// já cadastrado (catálogo ou personalizado) por [foodId], mais a
/// quantidade em gramas.
class MealItemInput {
  final String foodId;
  final double grams;
  final MealItemInputMethod inputMethod;

  MealItemInput({
    required this.foodId,
    required this.grams,
    this.inputMethod = MealItemInputMethod.unspecified,
  }) {
    if (grams <= 0) {
      throw ArgumentError('grams precisa ser positivo (item $foodId)');
    }
  }
}
