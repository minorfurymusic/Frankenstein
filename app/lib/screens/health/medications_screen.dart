import 'package:flutter/material.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/health_area.dart';
import '../../widgets/medication_dose_card.dart';
import '../../widgets/progress.dart';
import '../../widgets/state_views.dart';
import 'medication_form_screen.dart';

/// Nome da forma no layout (prancheta RemedioForm, chips de "Forma").
String medicationFormLabel(MedicationForm f) => switch (f) {
      MedicationForm.tablet => 'comprimido',
      MedicationForm.capsule => 'cápsula',
      MedicationForm.drops => 'gota',
      MedicationForm.liquid => 'líquido',
      MedicationForm.injection => 'injeção',
      MedicationForm.topical => 'pomada',
      MedicationForm.inhaler => 'inalador',
      MedicationForm.other => 'outra',
    };

String doseLabel(Medication m) {
  final amount = m.doseAmount == m.doseAmount.roundToDouble()
      ? formatNumber(m.doseAmount)
      : formatNumber(m.doseAmount, decimals: 1);
  return '$amount ${m.doseUnit}';
}

/// Grava "tomei"/"pulei" de uma dose da agenda. O toque no botão é a ação
/// explícita da pessoa.
void markDose(BuildContext context, AppDependencies deps, DoseView dose, DoseStatus status) {
  final now = DateTime.now();
  try {
    deps.doseLogger.log(
      name: dose.medication.name,
      doseAmount: dose.medication.doseAmount,
      doseUnit: dose.medication.doseUnit,
      status: status,
      occurredAt: now.toUtc(),
      occurredAtTzOffsetMinutes: deps.tzOffsetMinutesNow(),
      medicationId: dose.medication.id,
      scheduledLocal: dose.entry.dose.scheduledLocal,
    );
    deps.notifyDataChanged();
  } catch (e) {
    showRltError(context, e);
  }
}

/// Remédios: agenda de hoje, adesão, ativos e encerrados (pranchetas
/// Remedios, RemediosAgenda, RemediosAdesao).
class MedicationsScreen extends StatelessWidget {
  final AppDependencies deps;
  const MedicationsScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: deps.dataVersion,
      builder: (context, _, _) {
        final read = deps.healthRead;
        final active = read.activeMedications();
        final ended = read.endedMedications();
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Remédios'),
              bottom: TabBar(tabs: [Tab(text: 'Ativos (${active.length})'), Tab(text: 'Encerrados (${ended.length})')]),
            ),
            floatingActionButton: FloatingActionButton.extended(
              key: const Key('medication_new'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => MedicationFormScreen(deps: deps)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Novo remédio'),
            ),
            body: TabBarView(children: [
              _ActiveTab(deps: deps, active: active),
              _MedicationList(deps: deps, items: ended, emptyText: 'Nenhum tratamento encerrado.'),
            ]),
          ),
        );
      },
    );
  }
}

class _ActiveTab extends StatelessWidget {
  final AppDependencies deps;
  final List<Medication> active;
  const _ActiveTab({required this.deps, required this.active});

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty) {
      return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        StateCard(
          icon: Icons.medication_outlined,
          title: 'Nenhum remédio cadastrado',
          message: 'Cadastre aqui ou mande a foto da receita para o Cérebro.',
          actionLabel: 'Novo remédio',
          actionIcon: Icons.add,
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => MedicationFormScreen(deps: deps)),
          ),
        ),
        const SizedBox(height: RltSpace.l),
        const HealthDisclaimer(),
      ]);
    }
    final doses = deps.healthRead.dosesToday();
    final adherence = deps.healthRead.adherence();
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return ListView(
      key: const Key('medications_list'),
      padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.l, RltSpace.l, 96),
      children: [
        if (adherence.ratio != null)
          Container(
            padding: const EdgeInsets.all(RltSpace.m),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
            child: Row(children: [
              ProgressRing(
                value: adherence.ratio!,
                size: 56,
                strokeWidth: 6,
                color: c.success,
                center: Text('${(adherence.ratio! * 100).round()}%', style: t.labelMedium),
              ),
              const SizedBox(width: RltSpace.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Adesão nos últimos 30 dias', style: t.titleSmall),
                  Text('${adherence.taken} de ${adherence.expected} doses tomadas', style: t.bodySmall),
                ]),
              ),
            ]),
          ),
        const RltSectionHeader('Hoje'),
        if (doses.isEmpty) Text('Nenhuma dose prevista para hoje.', style: t.bodyMedium),
        for (final d in doses) ...[
          MedicationDoseCard(
            key: Key('dose_${d.medication.id}_${d.time}'),
            name: d.medication.name,
            dose: '${doseLabel(d.medication)} · ${medicationFormLabel(d.medication.form)}',
            time: d.time,
            status: d.entry.status == DoseStatus.taken
                ? DoseCardStatus.taken
                : (d.overdue ? DoseCardStatus.overdue : DoseCardStatus.upcoming),
            skipped: d.entry.status == DoseStatus.skipped,
            onTaken: () => markDose(context, deps, d, DoseStatus.taken),
            onSkipped: () => markDose(context, deps, d, DoseStatus.skipped),
          ),
          const SizedBox(height: RltSpace.s),
        ],
        const RltSectionHeader('Ativos'),
        _MedicationList(deps: deps, items: active, emptyText: '', shrinkWrap: true),
        const SizedBox(height: RltSpace.l),
        const HealthDisclaimer(),
      ],
    );
  }
}

class _MedicationList extends StatelessWidget {
  final AppDependencies deps;
  final List<Medication> items;
  final String emptyText;
  final bool shrinkWrap;
  const _MedicationList({required this.deps, required this.items, required this.emptyText, this.shrinkWrap = false});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RltColors.of(context);
    final cards = [
      for (final m in items)
        Padding(
          padding: const EdgeInsets.only(bottom: RltSpace.s),
          child: Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(RltRadius.card),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => MedicationFormScreen(deps: deps, existing: m)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(RltSpace.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const HealthAreaIcon(area: HealthArea.medication),
                    const SizedBox(width: RltSpace.m),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(m.name, style: t.titleMedium),
                        Text('${doseLabel(m)} · ${medicationFormLabel(m.form)}', style: t.bodyMedium),
                      ]),
                    ),
                    if (m.remindersEnabled)
                      Icon(Icons.notifications_none, color: c.primary, semanticLabel: 'Lembrete ligado'),
                    Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                  ]),
                  const SizedBox(height: RltSpace.s),
                  Row(children: [
                    Icon(Icons.schedule, size: 16, color: c.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(child: Text(m.timesOfDay.map(formatTimeOfDay).join(' · '), style: RltTheme.tabular(t.bodyMedium!))),
                    if (m.isContinuous)
                      const RltBadge(RltBadgeKind.continuousUse)
                    else
                      Text('Até ${ddmm(DateTime(m.endDate!.year, m.endDate!.month, m.endDate!.day))}', style: t.labelMedium),
                  ]),
                ]),
              ),
            ),
          ),
        ),
    ];
    if (shrinkWrap) return Column(children: cards);
    if (cards.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(RltSpace.xl), child: Text(emptyText, style: t.bodyMedium)));
    }
    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: cards);
  }
}
