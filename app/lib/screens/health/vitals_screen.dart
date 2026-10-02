import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/state_views.dart';

/// Sinais vitais (prancheta Vitais): uma aba por tipo, última medida,
/// gráfico de 7/30/90 dias e registros. Manual ou vindo da pulseira.
class VitalsScreen extends StatelessWidget {
  final AppDependencies deps;
  final VitalKind initial;
  const VitalsScreen({super.key, required this.deps, this.initial = VitalKind.bloodPressure});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: VitalKind.values.length,
      initialIndex: initial.index,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Sinais vitais'),
            bottom: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [for (final k in VitalKind.values) Tab(text: k.label)],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            key: const Key('vital_new'),
            onPressed: () {
              final kind = VitalKind.values[DefaultTabController.of(context).index];
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => VitalForm(deps: deps, kind: kind),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Registrar'),
          ),
          body: ValueListenableBuilder<int>(
            valueListenable: deps.dataVersion,
            builder: (context, _, _) => TabBarView(children: [
              for (final k in VitalKind.values) _VitalTab(deps: deps, kind: k),
            ]),
          ),
        );
      }),
    );
  }
}

class _VitalTab extends StatefulWidget {
  final AppDependencies deps;
  final VitalKind kind;
  const _VitalTab({required this.deps, required this.kind});

  @override
  State<_VitalTab> createState() => _VitalTabState();
}

class _VitalTabState extends State<_VitalTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final all = widget.deps.healthRead.vitals(widget.kind);
    if (all.isEmpty) {
      return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        StateCard(
          icon: Icons.monitor_heart_outlined,
          title: 'Nenhuma medida de ${widget.kind.label.toLowerCase()}',
          message: 'Toque em "Registrar" ou conecte uma pulseira em Conta › Dispositivos.',
        ),
        const SizedBox(height: RltSpace.l),
        const HealthDisclaimer(),
      ]);
    }
    final last = all.first;
    final cutoff = DateTime.now().subtract(Duration(days: _days));
    final inPeriod = all.where((r) => r.local.isAfter(cutoff)).toList();
    final isPressure = widget.kind == VitalKind.bloodPressure;
    return ListView(
      padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.l, RltSpace.l, 96),
      children: [
        Text('Última medida', style: t.labelMedium),
        Text.rich(TextSpan(children: [
          TextSpan(text: last.display, style: RltTheme.tabular(t.headlineMedium!)),
          TextSpan(text: ' ${widget.kind.unit}', style: t.bodyMedium),
        ])),
        Text('${relativeDayTime(last.local)} · ${last.fromWearable ? 'pulseira' : 'registro manual'}', style: t.bodySmall),
        const SizedBox(height: RltSpace.l),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('7 dias')),
            ButtonSegment(value: 30, label: Text('30 dias')),
            ButtonSegment(value: 90, label: Text('90 dias')),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: RltSpace.l),
        if (inPeriod.isEmpty)
          Text('Sem medidas neste período.', style: t.bodyMedium)
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(RltSpace.l),
              child: RltLineChart(
                semanticsLabel: 'Gráfico de ${widget.kind.label} nos últimos $_days dias',
                series: [
                  ChartSeries(
                    label: isPressure ? 'Sistólica' : widget.kind.label,
                    color: isPressure ? c.error : c.primary,
                    points: [for (final r in inPeriod) ChartPoint(r.local, r.value)],
                  ),
                  if (isPressure)
                    ChartSeries(
                      label: 'Diastólica',
                      color: c.protein,
                      points: [for (final r in inPeriod) ChartPoint(r.local, r.secondary!)],
                    ),
                ],
              ),
            ),
          ),
        const RltSectionHeader('Registros'),
        for (final r in all.take(30))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${r.display} ${widget.kind.unit}${r.note == null ? '' : ' · ${r.note}'}', style: RltTheme.tabular(t.bodyLarge!)),
            subtitle: Text(relativeDayTime(r.local)),
            trailing: Chip(
              avatar: Icon(r.fromWearable ? Icons.watch_outlined : Icons.edit_outlined, size: 16),
              label: Text(r.fromWearable ? 'Pulseira' : 'Manual'),
              backgroundColor: c.secondaryContainer,
              side: BorderSide.none,
            ),
          ),
        const SizedBox(height: RltSpace.l),
        const HealthDisclaimer(),
      ],
    );
  }
}

/// Formulário de registro manual de um sinal vital, em folha de baixo.
class VitalForm extends StatefulWidget {
  final AppDependencies deps;
  final VitalKind kind;
  const VitalForm({super.key, required this.deps, required this.kind});

  @override
  State<VitalForm> createState() => _VitalFormState();
}

class _VitalFormState extends State<VitalForm> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _context = TextEditingController();

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _context.dispose();
    super.dispose();
  }

  double? _num(TextEditingController c) => parseNumber(c.text);

  void _save() {
    final a = _num(_a);
    if (a == null || (widget.kind == VitalKind.bloodPressure && _num(_b) == null)) {
      showRltError(context, ArgumentError('preencha o valor em número'));
      return;
    }
    final now = DateTime.now();
    final at = now.toUtc();
    final tz = widget.deps.tzOffsetMinutesNow();
    final log = widget.deps.vitalSignLogger;
    try {
      switch (widget.kind) {
        case VitalKind.bloodPressure:
          log.bloodPressure(systolicMmHg: a, diastolicMmHg: _num(_b)!, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case VitalKind.glucose:
          log.glucose(mgDl: a, context: _context.text, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case VitalKind.heartRate:
          log.heartRate(bpm: a.round(), occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case VitalKind.temperature:
          log.temperature(celsius: a, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case VitalKind.spo2:
          log.spo2(percent: a, occurredAt: at, occurredAtTzOffsetMinutes: tz);
      }
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, '${widget.kind.label} salva em Saúde › Sinais vitais.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const numeric = TextInputType.numberWithOptions(decimal: true);
    return Padding(
      padding: EdgeInsets.fromLTRB(RltSpace.l, 0, RltSpace.l, MediaQuery.viewInsetsOf(context).bottom + RltSpace.l),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Registrar ${widget.kind.label.toLowerCase()}', style: t.titleLarge),
          const SizedBox(height: RltSpace.l),
          if (widget.kind == VitalKind.bloodPressure)
            Row(children: [
              Expanded(
                child: TextField(
                  key: const Key('vital_value_a'),
                  controller: _a,
                  keyboardType: numeric,
                  decoration: const InputDecoration(labelText: 'Sistólica', suffixText: 'mmHg'),
                ),
              ),
              const SizedBox(width: RltSpace.m),
              Expanded(
                child: TextField(
                  key: const Key('vital_value_b'),
                  controller: _b,
                  keyboardType: numeric,
                  decoration: const InputDecoration(labelText: 'Diastólica', suffixText: 'mmHg'),
                ),
              ),
            ])
          else
            TextField(
              key: const Key('vital_value_a'),
              controller: _a,
              keyboardType: numeric,
              decoration: InputDecoration(labelText: widget.kind.label, suffixText: widget.kind.unit),
            ),
          if (widget.kind == VitalKind.glucose) ...[
            const SizedBox(height: RltSpace.m),
            TextField(controller: _context, decoration: const InputDecoration(labelText: 'Momento (ex.: jejum, após almoço)')),
          ],
          const SizedBox(height: RltSpace.l),
          FilledButton(key: const Key('vital_save'), onPressed: _save, child: const Text('Salvar')),
        ],
      ),
    );
  }
}
