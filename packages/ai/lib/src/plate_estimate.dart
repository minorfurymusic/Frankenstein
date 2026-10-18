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

  /// Açúcares totais da porção, quando a IA estimou.
  final double? sugarGrams;

  /// Bebida: a quantidade em [grams] é em ml (1 ml ≈ 1 g para as contas).
  final bool liquid;
  const PlateItem({
    required this.name,
    required this.grams,
    required this.kcal,
    this.proteinGrams = 0,
    this.carbsGrams = 0,
    this.fatGrams = 0,
    this.fiberGrams,
    this.sugarGrams,
    this.liquid = false,
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
      sugarGrams: sugarGrams == null ? null : sugarGrams! * f,
      liquid: liquid,
    );
  }
}

class PlateEstimate {
  /// `breakfast`, `lunch`, `dinner`, `snack` — palpite pela comida; o app
  /// usa o que a pessoa escolheu, se escolheu.
  final String? mealType;
  final List<PlateItem> items;

  /// Foto sem comida: o que a IA viu, em uma frase (ADR-19).
  final String? notFood;
  const PlateEstimate({this.mealType, this.items = const [], this.notFood});

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
    'not_food': {'type': 'string'},
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
          'sugar_g': {'type': 'number'},
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
- Para cada alimento, estime kcal, protein_g, carbs_g, fat_g e, se souber, fiber_g e sugar_g (açúcares totais), para a porção estimada (use valores típicos de tabelas brasileiras, como a TACO).
- meal_type: seu palpite (café da manhã = breakfast, almoço = lunch, jantar = dinner, lanche = snack).
- Se vier "A pessoa disse", use: ela sabe o que comeu (ex.: "pastel de carne, não comi a borda", "tirei a gordura"). Ajuste nomes, porções e valores a isso.
- Se a foto não for de comida, devolva items vazio e, em not_food, diga em uma frase curta o que a foto mostra (ex.: "Print da tela de metas de um app.").
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
    final sugar = m['sugar_g'];
    items.add(PlateItem(
      name: name,
      grams: grams,
      kcal: n(m['kcal']),
      proteinGrams: n(m['protein_g']),
      carbsGrams: n(m['carbs_g']),
      fatGrams: n(m['fat_g']),
      fiberGrams: fiber is num ? n(fiber) : null,
      sugarGrams: sugar is num ? n(sugar) : null,
    ));
  }
  final notFood = json['not_food'];
  return PlateEstimate(
    mealType: json['meal_type'] as String?,
    items: items,
    notFood: items.isEmpty && notFood is String && notFood.trim().isNotEmpty ? notFood.trim() : null,
  );
}

/// Estima o prato da foto. [plateGrams]: peso na balança, se a pessoa
/// informou. [note]: o que a pessoa escreveu junto com a foto.
Future<PlateEstimate> estimatePlate(GeminiClient client, AiPart photo, {double? plateGrams, String? note}) async {
  final said = note == null || note.trim().isEmpty ? '' : ' A pessoa disse: "${note.trim()}".';
  final json = await client.generateJson(
    system: plateEstimateInstruction,
    parts: [
      photo,
      AiPart.text(plateGrams == null
          ? 'Estime os alimentos deste prato.$said'
          : 'Estime os alimentos deste prato. A comida pesou ${plateGrams.round()} g na balança.$said'),
    ],
    schema: plateEstimateSchema,
  );
  return parsePlateEstimate(json);
}

const mealRefineInstruction = '''
Você corrige uma refeição já estimada num app de registro alimentar no Brasil, a partir de uma observação da pessoa.
Regras:
- Parta dos itens recebidos (nome, gramas ou ml, kcal e macros) e aplique só o que a observação diz (ex.: "não comi a borda do pastel" = menos massa; "tirei a gordura" = menos gordura; "era frango, não peixe" = troque o alimento).
- kcal e macros são o total de cada item na porção dele (valores típicos de tabelas brasileiras, como a TACO).
- Itens que a observação não muda ficam iguais. Item que a pessoa não comeu sai.
- O que se põe na comida ou bebida (açúcar, azeite, leite) é item próprio; não conte duas vezes.
- Não dê conselho de saúde nem comente a refeição.
''';

/// Corrige os itens com a observação da pessoa — só texto: a foto não vai
/// de novo.
Future<List<PlateItem>> refineMealItems(GeminiClient client, List<PlateItem> items, String note) async {
  String n(double v) => v.toStringAsFixed(1);
  final lines = [
    for (final i in items)
      '- ${i.name}: ${n(i.grams)} ${i.liquid ? 'ml' : 'g'}, ${n(i.kcal)} kcal, P ${n(i.proteinGrams)} g, C ${n(i.carbsGrams)} g, G ${n(i.fatGrams)} g',
  ].join('\n');
  final json = await client.generateJson(
    system: mealRefineInstruction,
    parts: [AiPart.text('Itens:\n$lines\n\nObservação da pessoa: "${note.trim()}"')],
    schema: plateEstimateSchema,
  );
  final liquid = {for (final i in items) if (i.liquid) i.name.toLowerCase()};
  return [
    for (final i in parsePlateEstimate(json).items)
      liquid.contains(i.name.toLowerCase()) ? PlateItem(
              name: i.name,
              grams: i.grams,
              kcal: i.kcal,
              proteinGrams: i.proteinGrams,
              carbsGrams: i.carbsGrams,
              fatGrams: i.fatGrams,
              fiberGrams: i.fiberGrams,
              sugarGrams: i.sugarGrams,
              liquid: true,
            ) : i,
  ];
}
