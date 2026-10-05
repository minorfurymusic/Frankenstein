import 'gemini_client.dart';

/// Um alimento visto na foto do prato, com porção e valores estimados.
class PlateItem {
  final String name;
  final double grams;
  final double kcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final double? fiberGrams;
  const PlateItem({
    required this.name,
    required this.grams,
    required this.kcal,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams,
  });

  /// Mesma comida, outra porção: valores proporcionais.
  PlateItem withGrams(double g) {
    final f = grams <= 0 ? 0.0 : g / grams;
    return PlateItem(
      name: name,
      grams: g,
      kcal: kcal * f,
      proteinGrams: proteinGrams * f,
      carbsGrams: carbsGrams * f,
      fatGrams: fatGrams * f,
      fiberGrams: fiberGrams == null ? null : fiberGrams! * f,
    );
  }
}

class PlateEstimate {
  /// `breakfast`, `lunch`, `dinner`, `snack` — palpite pela comida; o app
  /// usa o que a pessoa escolheu, se escolheu.
  final String? mealType;
  final List<PlateItem> items;
  const PlateEstimate({this.mealType, this.items = const []});

  double get grams => items.fold(0, (s, i) => s + i.grams);
  double get kcal => items.fold(0, (s, i) => s + i.kcal);
}

const plateEstimateSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'meal_type': {
      'type': 'string',
      'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
    },
    'items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'grams': {'type': 'number'},
          'kcal': {'type': 'number'},
          'protein_g': {'type': 'number'},
          'carbs_g': {'type': 'number'},
          'fat_g': {'type': 'number'},
          'fiber_g': {'type': 'number'},
        },
        'required': ['name', 'grams', 'kcal', 'protein_g', 'carbs_g', 'fat_g'],
      },
    },
  },
  'required': ['items'],
};

const plateEstimateInstruction = '''
Você estima o que há num prato de comida, a partir de uma foto, para um app de registro alimentar no Brasil.
Regras:
- Liste cada alimento visível separadamente, com nome comum em português (ex.: "Arroz branco", "Feijão carioca", "Frango grelhado").
- Estime a porção em gramas pelo tamanho no prato. Se o peso total do prato for informado, distribua as porções para que a soma bata com esse peso (sem contar o prato).
- Para cada alimento, estime kcal, protein_g, carbs_g, fat_g e, se souber, fiber_g, para a porção estimada (use valores típicos de tabelas brasileiras, como a TACO).
- meal_type: seu palpite (café da manhã = breakfast, almoço = lunch, jantar = dinner, lanche = snack).
- Se a foto não for de comida, devolva items vazio.
- Não dê conselho de saúde nem comente a refeição.
''';

PlateEstimate parsePlateEstimate(Map<String, dynamic> json) {
  double n(Object? v) => v is num && v.toDouble().isFinite && v >= 0 ? v.toDouble() : 0;
  final items = <PlateItem>[];
  for (final raw in (json['items'] as List? ?? const [])) {
    final m = raw as Map<String, dynamic>;
    final name = (m['name'] as String).trim();
    final grams = n(m['grams']);
    if (name.isEmpty || grams <= 0) continue;
    final fiber = m['fiber_g'];
    items.add(PlateItem(
      name: name,
      grams: grams,
      kcal: n(m['kcal']),
      proteinGrams: n(m['protein_g']),
      carbsGrams: n(m['carbs_g']),
      fatGrams: n(m['fat_g']),
      fiberGrams: fiber is num ? n(fiber) : null,
    ));
  }
  return PlateEstimate(mealType: json['meal_type'] as String?, items: items);
}

/// Estima o prato da foto. [plateGrams]: peso na balança, se a pessoa
/// informou.
Future<PlateEstimate> estimatePlate(GeminiClient client, AiPart photo, {double? plateGrams}) async {
  final json = await client.generateJson(
    system: plateEstimateInstruction,
    parts: [
      photo,
      AiPart.text(plateGrams == null
          ? 'Estime os alimentos deste prato.'
          : 'Estime os alimentos deste prato. A comida pesou ${plateGrams.round()} g na balança.'),
    ],
    schema: plateEstimateSchema,
  );
  return parsePlateEstimate(json);
}
