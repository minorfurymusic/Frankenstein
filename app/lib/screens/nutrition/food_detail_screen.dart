// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import 'meal_labels.dart';

/// Detalhe do alimento (prancheta DetalheAlimento; `docs/specs/nutricao.md`,
/// tela 3): tabela nutricional da quantidade escolhida, refeição, horário e
/// confirmar. O toque em "Adicionar" é a confirmação — grava o `meal`.
class FoodDetailScreen extends StatefulWidget {
  final AppDependencies deps;
  final Food food;
  final MealType? mealType;
  final MealItemInputMethod inputMethod;
  final DateTime? day;

  const FoodDetailScreen({
    super.key,
    required this.deps,
    required this.food,
    this.mealType,
    this.inputMethod = MealItemInputMethod.search,
    this.day,
  });

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  late final TextEditingController _grams;
  late MealType _meal;
  late TimeOfDay _time;

  bool get _isPortionItem => widget.food.id.startsWith('custom-') && widget.food.barcode == null;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _time = TimeOfDay.fromDateTime(now);
    _meal = widget.mealType ?? mealTypeForTime(now);
    final recipe = widget.deps.nutrition.recipeFor(widget.food.id);
    _grams = TextEditingController(text: formatNumber(recipe?.servingGrams ?? 100));
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  double get _amount => parseNumber(_grams.text) ?? 0;

  void _add() {
    final grams = _amount;
    final day = widget.day ?? DateTime.now();
    final local = DateTime(day.year, day.month, day.day, _time.hour, _time.minute);
    try {
      widget.deps.mealLogger.logMeal(
        items: [MealItemInput(foodId: widget.food.id, grams: grams, inputMethod: widget.inputMethod)],
        mealType: _meal,
        occurredAt: local.toUtc(),
        occurredAtTzOffsetMinutes: local.timeZoneOffset.inMinutes,
      );
      widget.deps.notifyDataChanged();
      Navigator.of(context).popUntil((r) => r.isFirst);
      showRltSaved(context, '${widget.food.name} salvo em Nutrição › ${mealTypeLabel(_meal)}.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final f = widget.food;
    final factor = _amount / 100;
    final store = widget.deps.nutrition;
    String g(double? per100, {int decimals = 1}) => per100 == null ? '—' : '${formatNumber(per100 * factor, decimals: decimals)} g';
    Widget line(String label, String value, {bool bold = false, bool indent = false}) => Container(
          padding: EdgeInsets.fromLTRB(indent ? 16 : 0, 12, 0, 12),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.outlineVariant))),
          child: Row(children: [
            Expanded(child: Text(label, style: bold ? t.titleSmall : t.bodyLarge)),
            Text(value, style: RltTheme.tabular(bold ? t.titleSmall! : t.bodyLarge!)),
          ]),
        );
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(f.name, overflow: TextOverflow.ellipsis),
          Text(f.source == FoodSource.custom ? 'Meu item' : 'Catálogo brasileiro (TACO)', style: t.bodySmall),
        ]),
        actions: [
          IconButton(
            key: const Key('food_favorite'),
            tooltip: store.isFavorite(f.id) ? 'Tirar dos favoritos' : 'Favoritar',
            onPressed: () => setState(() => store.toggleFavorite(f.id)),
            icon: Icon(store.isFavorite(f.id) ? Icons.star : Icons.star_border, color: store.isFavorite(f.id) ? c.tertiary : null),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(RltSpace.l),
          child: FilledButton.icon(
            key: const Key('food_add'),
            onPressed: _amount > 0 ? _add : null,
            icon: const Icon(Icons.check),
            label: Text('Adicionar ao ${mealTypeLabel(_meal).toLowerCase()}'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(RltSpace.l),
        children: [
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('food_grams'),
                controller: _grams,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Quantidade',
                  suffixText: 'g',
                  helperText: _isPortionItem ? '100 g = 1 porção do seu item' : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: RltSpace.m),
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showTimePicker(context: context, initialTime: _time);
                  if (picked != null) setState(() => _time = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Horário', suffixIcon: Icon(Icons.schedule)),
                  child: Text('${two(_time.hour)}:${two(_time.minute)}'),
                ),
              ),
            ),
          ]),
          const SizedBox(height: RltSpace.m),
          Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
            for (final m in MealType.values)
              ChoiceChip(label: Text(mealTypeLabel(m)), selected: _meal == m, onSelected: (_) => setState(() => _meal = m)),
          ]),
          const SizedBox(height: RltSpace.l),
          Container(
            padding: const EdgeInsets.all(RltSpace.l),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Calorias', style: t.labelMedium),
              Text.rich(TextSpan(children: [
                TextSpan(text: formatNumber(f.energyKcalPer100g * factor), style: RltTheme.tabular(t.headlineMedium!)),
                TextSpan(text: ' kcal', style: t.bodyMedium),
              ])),
              const SizedBox(height: RltSpace.s),
              Row(children: [
                _Macro(label: 'Proteína', value: g(f.proteinPer100g, decimals: 0), color: c.protein),
                _Macro(label: 'Carbo', value: g(f.carbohydratesPer100g, decimals: 0), color: c.carbs),
                _Macro(label: 'Gordura', value: g(f.fatPer100g, decimals: 0), color: c.fat),
              ]),
            ]),
          ),
          RltSectionHeader('Tabela nutricional · ${formatNumber(_amount)} g'),
          line('Valor energético', '${formatNumber(f.energyKcalPer100g * factor)} kcal', bold: true),
          line('Carboidratos', g(f.carbohydratesPer100g)),
          line('Açúcares', g(f.sugarPer100g), indent: true),
          line('Fibra alimentar', g(f.fiberPer100g), indent: true),
          line('Proteínas', g(f.proteinPer100g)),
          line('Gorduras totais', g(f.fatPer100g)),
          line('Gorduras saturadas', g(f.saturatedFatPer100g), indent: true),
          line('Sódio', f.sodiumPer100g == null ? '—' : '${formatNumber(f.sodiumPer100g! * factor * 1000)} mg'),
          const SizedBox(height: RltSpace.s),
          Text('"—" = a fonte não traz esse valor.', style: t.bodySmall),
        ],
      ),
    );
  }
}

class _Macro extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Macro({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: RltTheme.tabular(t.titleMedium!.copyWith(color: color))),
        Text(label, style: t.bodySmall),
      ]),
    );
  }
}
