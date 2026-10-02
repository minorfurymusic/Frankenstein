import 'package:flutter/material.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_profile/profile.dart';

import '../../app_dependencies.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/progress.dart';

/// O que dá para registrar em Corpo, com rótulo e unidade da tela.
enum BodyField {
  weight('Peso', 'kg', null),
  bodyFat('Gordura corporal', '%', 'body_fat'),
  waist('Cintura', 'cm', BodyMeasurementKind.waist),
  hip('Quadril', 'cm', BodyMeasurementKind.hip),
  chest('Peito', 'cm', BodyMeasurementKind.chest),
  neck('Pescoço', 'cm', BodyMeasurementKind.neck),
  arm('Braço', 'cm', BodyMeasurementKind.arm),
  thigh('Coxa', 'cm', BodyMeasurementKind.thigh),
  calf('Panturrilha', 'cm', BodyMeasurementKind.calf);

  final String label;
  final String unit;
  final Object? kind; // BodyMeasurementKind, 'body_fat' ou null (peso)
  const BodyField(this.label, this.unit, this.kind);

  String get wireKind => kind is BodyMeasurementKind ? (kind as BodyMeasurementKind).wireValue : '$kind';
}

/// Corpo (prancheta Corpo): peso, % de gordura, medidas, gráfico do peso.
class BodyScreen extends StatefulWidget {
  final AppDependencies deps;
  const BodyScreen({super.key, required this.deps});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  int _months = 3;

  String _delta(List<BodyReading> readings, String unit, {int decimals = 1}) {
    if (readings.length < 2) return 'Primeira medida';
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final older = readings.where((r) => r.local.isBefore(cutoff)).toList();
    final base = older.isEmpty ? readings.last : older.first;
    final d = readings.first.value - base.value;
    final sign = d > 0 ? '+' : (d < 0 ? '−' : '');
    return '$sign${formatNumber(d.abs(), decimals: decimals)} $unit em 30 dias';
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    return Scaffold(
      appBar: AppBar(title: const Text('Corpo')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('body_new'),
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => BodyForm(deps: deps),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Registrar medida'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) {
          final c = RltColors.of(context);
          final t = Theme.of(context).textTheme;
          final weights = deps.healthRead.weights();
          final fat = deps.healthRead.measurements('body_fat');
          final waist = deps.healthRead.measurements('waist');
          final height = deps.profileRepository.load()?.heightMeters;
          final bmi = height == null || weights.isEmpty ? null : HealthFormulas.bmi(weightKg: weights.first.value, heightMeters: height);
          final whtr = height == null || waist.isEmpty
              ? null
              : HealthFormulas.waistToHeight(waistMeters: waist.first.value / 100, heightMeters: height);
          final cutoff = DateTime.now().subtract(Duration(days: 30 * _months));
          final chartPoints = [for (final w in weights.where((w) => w.local.isAfter(cutoff))) ChartPoint(w.local, w.value)];
          return ListView(
            padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, 96),
            children: [
              RltTwoColumnGrid(children: [
                RltStatTile(
                  icon: Icons.monitor_weight_outlined,
                  iconColor: c.secondary,
                  label: 'Peso',
                  value: weights.isEmpty ? '—' : formatNumber(weights.first.value, decimals: 1),
                  unit: weights.isEmpty ? null : 'kg',
                  caption: weights.isEmpty ? 'Sem registro' : _delta(weights, 'kg'),
                ),
                RltStatTile(
                  icon: Icons.donut_small_outlined,
                  iconColor: c.fat,
                  label: 'Gordura corporal',
                  value: fat.isEmpty ? '—' : formatNumber(fat.first.value),
                  unit: fat.isEmpty ? null : '%',
                  caption: fat.isEmpty ? 'Sem registro' : _delta(fat, 'ponto', decimals: 0),
                ),
                RltStatTile(
                  key: const Key('body_bmi'),
                  icon: Icons.straighten,
                  iconColor: c.primary,
                  label: 'IMC',
                  value: bmi == null ? '—' : formatNumber(bmi, decimals: 1),
                  caption: height == null
                      ? 'Informe sua altura em Conta › Perfil'
                      : (bmi == null ? 'Registre seu peso' : '${HealthFormulas.bmiCategory(bmi)} · referência 18,5 a 24,9'),
                ),
                RltStatTile(
                  icon: Icons.straighten,
                  iconColor: c.primary,
                  label: 'Cintura/altura',
                  value: whtr == null ? '—' : formatNumber(whtr, decimals: 2),
                  caption: height == null
                      ? 'Informe sua altura em Conta › Perfil'
                      : (whtr == null ? 'Registre a cintura' : 'Referência: até 0,5'),
                ),
              ]),
              const SizedBox(height: RltSpace.l),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(RltSpace.l),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text('Peso', style: t.titleMedium),
                    const SizedBox(height: RltSpace.s),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 3, label: Text('3 m')),
                        ButtonSegment(value: 6, label: Text('6 m')),
                        ButtonSegment(value: 12, label: Text('1 a')),
                      ],
                      selected: {_months},
                      onSelectionChanged: (s) => setState(() => _months = s.first),
                    ),
                    const SizedBox(height: RltSpace.l),
                    if (chartPoints.isEmpty)
                      Text('Sem pesagens neste período.', style: t.bodyMedium)
                    else
                      RltLineChart(
                        semanticsLabel: 'Gráfico do peso nos últimos $_months meses',
                        series: [ChartSeries(label: 'Peso', color: c.protein, points: chartPoints)],
                      ),
                    // TODO(frankstein): linha da meta e projeção de quando chega lá (precisa de Conta › Metas, ADR-15).
                  ]),
                ),
              ),
              const RltSectionHeader('Medidas'),
              for (final f in BodyField.values.where((f) => f.kind is BodyMeasurementKind))
                Builder(builder: (context) {
                  final readings = deps.healthRead.measurements(f.wireKind);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(f.label, style: t.bodyLarge),
                    subtitle: Text(readings.isEmpty ? 'Sem registro' : '${formatNumber(readings.first.value, decimals: 1)} cm · ${ddmm(readings.first.local)}'),
                    trailing: readings.length < 2
                        ? null
                        : Text(_delta(readings, 'cm').split(' em ').first, style: RltTheme.tabular(t.titleSmall!)),
                  );
                }),
              const SizedBox(height: RltSpace.l),
              const HealthDisclaimer(),
            ],
          );
        },
      ),
    );
  }
}

class BodyForm extends StatefulWidget {
  final AppDependencies deps;
  const BodyForm({super.key, required this.deps});

  @override
  State<BodyForm> createState() => _BodyFormState();
}

class _BodyFormState extends State<BodyForm> {
  BodyField _field = BodyField.weight;
  final _value = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    super.dispose();
  }

  void _save() {
    final v = parseNumber(_value.text);
    if (v == null) {
      showRltError(context, ArgumentError('preencha o valor em número'));
      return;
    }
    final at = DateTime.now().toUtc();
    final tz = widget.deps.tzOffsetMinutesNow();
    final log = widget.deps.bodyLogger;
    try {
      switch (_field) {
        case BodyField.weight:
          log.weight(kg: v, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case BodyField.bodyFat:
          log.bodyFat(percent: v, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        default:
          log.circumference(kind: _field.kind! as BodyMeasurementKind, centimeters: v, occurredAt: at, occurredAtTzOffsetMinutes: tz);
      }
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, '${_field.label} salvo em Saúde › Corpo.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(RltSpace.l, 0, RltSpace.l, MediaQuery.viewInsetsOf(context).bottom + RltSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registrar medida', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: RltSpace.l),
          Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
            for (final f in BodyField.values)
              ChoiceChip(label: Text(f.label), selected: _field == f, onSelected: (_) => setState(() => _field = f)),
          ]),
          const SizedBox(height: RltSpace.l),
          TextField(
            key: const Key('body_value'),
            controller: _value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: _field.label, suffixText: _field.unit),
          ),
          const SizedBox(height: RltSpace.l),
          FilledButton(key: const Key('body_save'), onPressed: _save, child: const Text('Salvar')),
        ],
      ),
    );
  }
}
