// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_nutrition/nutrition.dart';

/// Medida caseira: "1 ovo médio" = 44 g. A pessoa escolhe a medida e quantas;
/// o app converte em gramas (ou ml, nas bebidas; 1 ml ≈ 1 g).
class HouseholdMeasure {
  final String label;
  final double grams;
  const HouseholdMeasure(this.label, this.grams);
}

bool _starts(String name, List<String> prefixes) => prefixes.any(name.startsWith);

/// Alimento que a IA estimou (foto do prato ou conversa no Cérebro).
bool isEstimatedFood(Food f) => RegExp(r'^(chat|photo)-').hasMatch(f.id);

/// Bebida: quantidade em ml. Estimado pela IA como bebida (marcado no id),
/// ou pelo nome da TACO e dos itens próprios.
// TODO(frankstein): trocar pela coluna "liquido" da base nova de alimentos.
bool isLiquidFood(Food f) {
  if (RegExp(r'^(chat|photo)-ml-').hasMatch(f.id)) return true;
  final n = foldForSearch(f.name);
  const drinks = ['cafe', 'cha', 'leite', 'suco', 'refrigerante', 'agua', 'cerveja', 'vinho', 'energetico', 'refresco'];
  if (drinks.contains(n)) return true;
  return _starts(n, [
    'cafe preto',
    'cafe com ',
    'cafe sem ',
    'cafe pingado',
    'cafe expresso',
    'energetico',
    'agua ',
    'refresco',
    'achocolatado liquido',
    'suco',
    'leite, de vaca',
    'leite de vaca',
    'cafe, infusao',
    'cafe coado',
    'cha,',
    'cha ',
    'refrigerante',
    'bebida',
    'agua de coco',
    'cerveja',
    'vinho',
    'caldo de cana',
    'cachaca',
  ]);
}

/// Medidas que fazem sentido para o alimento. Valores aproximados — a
/// pessoa pode sempre digitar gramas.
// TODO(frankstein): medidas por alimento vindas da base nova (USDA/Open Food
// Facts); o peso do ovo é a classe de venda sem a casca (~12 %), a conferir.
List<HouseholdMeasure> measuresFor(Food f) {
  final n = foldForSearch(f.name);
  if (isLiquidFood(f)) {
    return const [
      HouseholdMeasure('copo (200 ml)', 200),
      HouseholdMeasure('xícara (240 ml)', 240),
      HouseholdMeasure('xícara de café (50 ml)', 50),
      HouseholdMeasure('lata (350 ml)', 350),
      HouseholdMeasure('colher de sopa (15 ml)', 15),
    ];
  }
  if (n.startsWith('ovo, de galinha, inteiro') || n.startsWith('ovo de galinha') || n.startsWith('omelete')) {
    return const [
      HouseholdMeasure('ovo pequeno', 40),
      HouseholdMeasure('ovo médio', 44),
      HouseholdMeasure('ovo grande', 48),
    ];
  }
  if (_starts(n, ['oleo', 'azeite', 'manteiga', 'margarina'])) {
    return const [
      HouseholdMeasure('fio (5 g)', 5),
      HouseholdMeasure('colher de chá (5 g)', 5),
      HouseholdMeasure('colher de sopa (13 g)', 13),
    ];
  }
  return const [
    HouseholdMeasure('colher de sopa (≈15 g)', 15),
    HouseholdMeasure('colher de chá (≈5 g)', 5),
    HouseholdMeasure('fatia/unidade pequena (≈30 g)', 30),
  ];
}
