import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/data/household_measures.dart';
import 'package:frankstein/widgets/amount_picker.dart';
import 'package:frankstein_nutrition/nutrition.dart';

Food _food(String name) => Food(
      id: 'x',
      name: name,
      source: FoodSource.custom,
      energyKcalPer100g: 100,
      carbohydratesPer100g: 0,
      fatPer100g: 0,
      proteinPer100g: 0,
    );

void main() {
  test('bebida em ml; ovo com tamanhos; óleo com fio', () {
    expect(isLiquidFood(_food('Café, infusão 10%')), isTrue);
    expect(isLiquidFood(_food('Arroz, integral, cozido')), isFalse);
    expect(measuresFor(_food('Ovo, de galinha, inteiro, frito')).map((m) => m.label), contains('ovo médio'));
    expect(measuresFor(_food('Óleo, de soja')).map((m) => m.label), contains('fio (5 g)'));
  });

  testWidgets('2 × ovo médio = 88 g', (tester) async {
    double grams = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: AmountPicker(food: _food('Ovo, de galinha, inteiro, cozido/10minutos'), initialGrams: 100, onChanged: (g) => grams = g)),
    ));
    await tester.tap(find.byKey(const Key('amount_measure')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ovo médio').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food_grams')), '2');
    await tester.pump();
    expect(grams, 88);
    expect(find.text('= 88 g'), findsOneWidget);
  });
}
