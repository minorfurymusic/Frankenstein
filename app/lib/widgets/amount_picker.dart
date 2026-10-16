// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../data/household_measures.dart';
import '../format.dart';
import '../theme/rlt_theme.dart';

/// Quantidade do alimento: em gramas (ml nas bebidas) ou numa medida
/// caseira × quantas ("2 × ovo médio"). Avisa o total em gramas/ml.
class AmountPicker extends StatefulWidget {
  final Food food;
  final double initialGrams;
  final ValueChanged<double> onChanged;
  const AmountPicker({super.key, required this.food, required this.initialGrams, required this.onChanged});

  @override
  State<AmountPicker> createState() => _AmountPickerState();
}

class _AmountPickerState extends State<AmountPicker> {
  late final _value = TextEditingController(text: formatNumber(widget.initialGrams));
  late final List<HouseholdMeasure> _measures = measuresFor(widget.food);
  HouseholdMeasure? _measure;

  String get _unit => isLiquidFood(widget.food) ? 'ml' : 'g';

  double get _grams {
    final v = parseNumber(_value.text) ?? 0;
    return _measure == null ? v : v * _measure!.grams;
  }

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _pick(HouseholdMeasure? m) {
    setState(() {
      _measure = m;
      _value.text = m == null ? formatNumber(_grams == 0 ? 100 : _grams) : '1';
    });
    widget.onChanged(_grams);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<HouseholdMeasure?>(
        key: const Key('amount_measure'),
        initialValue: _measure,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Medida'),
        items: [
          DropdownMenuItem(value: null, child: Text(_unit == 'ml' ? 'Mililitros (ml)' : 'Gramas (g)')),
          for (final m in _measures) DropdownMenuItem(value: m, child: Text(m.label)),
        ],
        onChanged: _pick,
      ),
      const SizedBox(height: RltSpace.s),
      TextField(
        key: const Key('food_grams'),
        controller: _value,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: InputDecoration(
          labelText: _measure == null ? 'Quantidade' : 'Quantas',
          suffixText: _measure == null ? _unit : '× ${_measure!.label}',
          helperText: _measure == null ? null : '= ${formatNumber(_grams)} $_unit',
        ),
        onChanged: (_) {
          setState(() {});
          widget.onChanged(_grams);
        },
      ),
      if (_measure != null) Text('Medida aproximada; dá para digitar em $_unit.', style: t.bodySmall),
    ]);
  }
}
