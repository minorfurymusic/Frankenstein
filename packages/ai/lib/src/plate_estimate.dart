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

/// Produto embalado na foto (lata, garrafa, pacote, código de barras): só
/// o que está ESCRITO na embalagem — a IA não estima valor de produto
/// embalado (decisão do usuário, 2026-10-20).
class PackageLabel {
  final String? brand;
  final String? product;

  /// Conteúdo da embalagem, em g (ou ml, se [liquid]).
  final double? netAmount;
  final bool liquid;

  /// Números do código de barras impressos, já conferidos pelo dígito
  /// verificador; `null` se ilegíveis ou errados.
  final String? barcode;

  /// Tabela nutricional por 100 g/ml, só se legível na foto.
  final PlateItem? per100;
  const PackageLabel({this.brand, this.product, this.netAmount, this.liquid = false, this.barcode, this.per100});

  /// "Energético Bally": produto e marca, sem repetir a marca.
  String? get displayName {
    final p = product?.trim() ?? '';
    final b = brand?.trim() ?? '';
    if (p.isEmpty) return b.isEmpty ? null : b;
    if (b.isEmpty || p.toLowerCase().contains(b.toLowerCase())) return p;
    return '$p $b';
  }
}

/// Confere o dígito verificador de EAN-8, UPC-A (12) e EAN-13.
bool validRetailBarcode(String digits) {
  if (!RegExp(r'^(\d{8}|\d{12}|\d{13})$').hasMatch(digits)) return false;
  var sum = 0;
  final body = digits.substring(0, digits.length - 1);
  for (var i = 0; i < body.length; i++) {
    final d = int.parse(body[body.length - 1 - i]);
    sum += i.isEven ? d * 3 : d;
  }
  return (10 - sum % 10) % 10 == int.parse(digits[digits.length - 1]);
}

class PlateEstimate {
  /// `breakfast`, `lunch`, `dinner`, `snack` — palpite pela comida; o app
  /// usa o que a pessoa escolheu, se escolheu.
  final String? mealType;
  final List<PlateItem> items;

  /// Foto sem comida: o que a IA viu, em uma frase (ADR-19).
  final String? notFood;

  /// Foto de produto embalado: o que está escrito nele (sem [items]).
  final PackageLabel? package;
  const PlateEstimate({this.mealType, this.items = const [], this.notFood, this.package});

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
    'package': {
      'type': 'object',
      'properties': {
        'brand': {'type': 'string'},
        'product': {'type': 'string'},
        'net_amount': {'type': 'number'},
        'liquid': {'type': 'boolean'},
        'barcode': {'type': 'string'},
        'nutrition_per_100': {
          'type': 'object',
          'properties': {
            'kcal': {'type': 'number'},
            'protein_g': {'type': 'number'},
            'carbs_g': {'type': 'number'},
            'fat_g': {'type': 'number'},
            'sugar_g': {'type': 'number'},
          },
          'required': ['kcal'],
        },
      },
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
- Produto embalado (lata, garrafa, pacote, rótulo ou código de barras de um alimento ou bebida industrializado): NÃO estime nada. Preencha package copiando só o que está escrito: brand (marca, ex.: "Bally"), product (ex.: "Energético"), net_amount (conteúdo em g ou ml), liquid (bebida), barcode (os números impressos embaixo das barras, só dígitos) e nutrition_per_100 SÓ se a tabela nutricional estiver legível na foto (valores convertidos para 100 g ou 100 ml). Sem tabela legível, deixe nutrition_per_100 de fora. Com package, items fica vazio.
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
  final package = _package(json['package']);
  return PlateEstimate(
    mealType: json['meal_type'] as String?,
    items: package == null ? items : const [],
    notFood: package == null && items.isEmpty && notFood is String && notFood.trim().isNotEmpty ? notFood.trim() : null,
    package: package,
  );
}

PackageLabel? _package(Object? raw) {
  if (raw is! Map) return null;
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  double? pos(Object? v) => v is num && v.toDouble().isFinite && v > 0 ? v.toDouble() : null;
  final digits = (text(raw['barcode']) ?? '').replaceAll(RegExp(r'\D'), '');
  final liquid = raw['liquid'] == true;
  final t = raw['nutrition_per_100'];
  final kcal = t is Map && t['kcal'] is num && (t['kcal'] as num) >= 0 ? (t['kcal'] as num).toDouble() : null;
  double n(String k) => t is Map && t[k] is num && (t[k] as num) >= 0 ? (t[k] as num).toDouble() : 0;
  final label = PackageLabel(
    brand: text(raw['brand']),
    product: text(raw['product']),
    netAmount: pos(raw['net_amount']),
    liquid: liquid,
    barcode: validRetailBarcode(digits) ? digits : null,
    per100: kcal == null
        ? null
        : PlateItem(
            name: '',
            grams: 100,
            kcal: kcal,
            proteinGrams: n('protein_g'),
            carbsGrams: n('carbs_g'),
            fatGrams: n('fat_g'),
            sugarGrams: t is Map && t['sugar_g'] is num ? n('sugar_g') : null,
            liquid: liquid,
          ),
  );
  return label.displayName == null && label.barcode == null ? null : label;
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
