import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../step_tracking_controller.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/health_area.dart';
import '../../widgets/medication_dose_card.dart';
import '../../widgets/progress.dart';
import '../../widgets/rlt_navigation_bar.dart';
import '../../widgets/state_views.dart';
import '../../widgets/timeline_item.dart';
import '../account/goals_screen.dart';
import '../exercise/activity_screens.dart';
import '../exercise/gym_screens.dart';
import '../exercise/live_workout_screen.dart';
import '../health/medications_screen.dart';
import '../nutrition/add_food_screen.dart';
import '../nutrition/meal_labels.dart';
import 'reminders_screen.dart';

/// Minutos de atividade por dia de referência: a OMS recomenda 150–300 min
/// de atividade moderada por semana; 150 ÷ 5 dias = 30 min.
const int kActiveMinutesReference = 30;

class _Entry {
  final DateTime local;
  final HealthArea area;
  final String title;
  final String? detail;
  const _Entry(this.local, this.area, this.title, this.detail);
}

/// Início (prancheta Inicio): painel do dia num olhar — metas, remédios de
/// hoje, sono, linha do tempo, atalhos e sequência de dias com registro.
class HomeScreen extends StatefulWidget {
  final AppDependencies deps;
  final VoidCallback onOpenAccount;
  final ValueChanged<RltTab> onOpenTab;
  const HomeScreen({super.key, required this.deps, required this.onOpenAccount, required this.onOpenTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late DateTime _day = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  bool get _isToday => _day == _today();

  void _open(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Bom dia';
    if (h < 18) return 'Boa tarde';
    return 'Boa noite';
  }

  int _streak() {
    final deps = widget.deps;
    var streak = 0;
    for (var i = 0; i < 3650; i++) {
      final d = _today().subtract(Duration(days: i));
      final t = deps.dayRead.totals(d);
      final any = t.mealCount > 0 || t.waterMl > 0;
      if (!any) {
        if (i == 0) continue; // hoje ainda pode não ter registro
        break;
      }
      streak++;
    }
    return streak;
  }

  List<_Entry> _timeline() {
    final deps = widget.deps;
    final d = _day;
    final out = <_Entry>[];
    DateTime loc(HealthEvent e) => localOf(e.occurredAt, e.occurredAtTzOffsetMinutes);
    for (final e in deps.dayRead.eventsOnLocalDay(HealthEventType.meal, d)) {
      final items = (e.payload['items'] as List).map((i) => (i as Map)['name'] as String).join(', ');
      final kcal = ((e.payload['totals'] as Map)['energy_kcal'] as num).toDouble();
      out.add(_Entry(loc(e), HealthArea.meal, mealTypeLabel(MealType.fromWireValue(e.payload['meal_type'] as String)),
          '$items · ${formatNumber(kcal)} kcal'));
    }
    for (final e in deps.dayRead.eventsOnLocalDay(HealthEventType.water, d)) {
      out.add(_Entry(loc(e), HealthArea.water, 'Água', '${formatNumber((e.payload['amount_ml'] as num).toDouble())} ml'));
    }
    for (final e in deps.dayRead.eventsOnLocalDay(HealthEventType.medicationDose, d)) {
      final taken = e.payload['status'] == 'taken';
      out.add(_Entry(loc(e), HealthArea.medication,
          '${e.payload['name']} ${formatNumber((e.payload['dose_amount'] as num).toDouble())} ${e.payload['dose_unit']}',
          taken ? 'Tomado' : 'Pulado'));
    }
    for (final e in deps.dayRead.eventsOnLocalDay(HealthEventType.symptom, d)) {
      final i = e.payload['intensity'];
      out.add(_Entry(loc(e), HealthArea.symptom, e.payload['name'] as String, i == null ? null : 'Intensidade $i de 10'));
    }
    for (final a in deps.activityRead.forDay(d)) {
      out.add(_Entry(
        a.local,
        a.kind == ActivityKind.gps ? HealthArea.run : HealthArea.workout,
        a.title,
        [
          if (a.distanceMeters != null) '${formatNumber(a.distanceMeters! / 1000, decimals: 1)} km',
          if (a.duration != null) durationLabel(a.duration!),
          if (a.kcal > 0) '${formatNumber(a.kcal)} kcal',
        ].join(' · '),
      ));
    }
    for (final e in deps.dayRead.eventsOnLocalDay(HealthEventType.weight, d)) {
      out.add(_Entry(loc(e), HealthArea.body, 'Peso', '${formatNumber((e.payload['kg'] as num).toDouble(), decimals: 1)} kg'));
    }
    for (final e in deps.dayRead.eventsOnLocalDay(HealthEventType.vitalSign, d)) {
      if (e.payload['kind'] != 'blood_pressure') continue;
      final s = kpaToMmHg((e.payload['systolic_kpa'] as num).toDouble()).round();
      final di = kpaToMmHg((e.payload['diastolic_kpa'] as num).toDouble()).round();
      out.add(_Entry(loc(e), HealthArea.vitalSign, 'Pressão', '$s/$di mmHg'));
    }
    out.sort((a, b) => a.local.compareTo(b.local));
    return out;
  }

  Future<void> _quickWater() async {
    final ml = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(RltSpace.l, 0, RltSpace.l, RltSpace.l),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Quanto de água?', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: RltSpace.l),
            for (final v in const [200.0, 300.0, 500.0])
              Padding(
                padding: const EdgeInsets.only(bottom: RltSpace.s),
                child: FilledButton.tonal(
                  key: Key('quick_water_${v.round()}'),
                  onPressed: () => Navigator.pop(context, v),
                  child: Text('${v.round()} ml'),
                ),
              ),
          ]),
        ),
      ),
    );
    if (ml == null || !mounted) return;
    final now = DateTime.now();
    widget.deps.waterLogger.log(amountMl: ml, occurredAt: now.toUtc(), occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes);
    widget.deps.notifyDataChanged();
    showRltSaved(context, '+${ml.round()} ml de água.');
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: widget.deps.dataVersion,
      builder: (context, _, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final deps = widget.deps;
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final totals = deps.dayRead.totals(_day);
    final goals = deps.goals.goalsFor(_day);
    final active = deps.activityRead.activeTime(_day);
    final stepsGoal = deps.profileRepository.load()?.stepsGoal ?? 8000;
    final doses = _isToday ? deps.healthRead.dosesToday() : const <DoseView>[];
    final pendingDoses = doses.where((d) => d.entry.status == null).toList()
      ..sort((a, b) => (b.overdue ? 1 : 0).compareTo(a.overdue ? 1 : 0));
    final takenDoses = doses.where((d) => d.entry.status == DoseStatus.taken).toList();
    final sleeps = deps.healthRead.sleeps(days: 2);
    final timeline = _timeline();
    final streak = _streak();
    final dateLabel = _isToday ? 'Hoje, ${_weekday(_day)}, ${_day.day} de ${monthShort(_day.month)}.' : '${_weekday(_day)}, ${ddmm(_day)}';

    Widget mini(IconData icon, Color color, String label, String value, String sub, double ratio) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(RltSpace.m),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.icon)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 4),
                Flexible(child: Text(label, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
              ]),
              const SizedBox(height: 4),
              FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: RltTheme.tabular(t.titleMedium!))),
              Text(sub, style: t.bodySmall, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(value: ratio.clamp(0.0, 1.0), minHeight: 5, color: color, backgroundColor: c.surfaceContainerHighest),
              ),
            ]),
          ),
        );

    return ListView(
      key: const Key('home_list'),
      padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.m, RltSpace.l, RltSpace.xl),
      children: [
        Row(children: [
          Semantics(
            button: true,
            label: 'Conta e configurações',
            excludeSemantics: true,
            child: InkWell(
              key: const Key('account_avatar'),
              customBorder: const CircleBorder(),
              onTap: widget.onOpenAccount,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: c.primaryContainer,
                foregroundColor: c.onPrimaryContainer,
                // TODO(frankstein): iniciais e foto da conta Google quando o login existir (ADR-13).
                child: const Icon(Icons.person_outline),
              ),
            ),
          ),
          const SizedBox(width: RltSpace.m),
          Expanded(child: Text(_greeting(), style: t.titleLarge)),
          IconButton(
            key: const Key('reminders_button'),
            tooltip: 'Lembretes',
            onPressed: () => _open(RemindersScreen(deps: deps)),
            icon: const Icon(Icons.notifications_none),
          ),
        ]),
        const SizedBox(height: RltSpace.s),
        Row(children: [
          IconButton(
            key: const Key('home_prev_day'),
            tooltip: 'Dia anterior',
            onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton.icon(
              key: const Key('home_calendar'),
              onPressed: () async {
                final d = await showDatePicker(context: context, initialDate: _day, firstDate: DateTime(2020), lastDate: _today());
                if (d != null) setState(() => _day = DateTime(d.year, d.month, d.day));
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(dateLabel, overflow: TextOverflow.ellipsis),
            ),
          ),
          IconButton(
            tooltip: 'Próximo dia',
            onPressed: _isToday ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        if (streak > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const Key('home_streak'),
              margin: const EdgeInsets.only(bottom: RltSpace.m),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(RltRadius.chip)),
              child: Text(
                '$streak ${streak == 1 ? 'dia seguido' : 'dias seguidos'} registrando',
                style: t.labelLarge?.copyWith(fontSize: 14, color: c.onTertiaryContainer),
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Expanded(child: Text('Metas do dia', style: t.titleMedium)),
                TextButton(onPressed: () => _open(GoalsScreen(deps: deps)), child: const Text('Detalhes')),
              ]),
              Row(children: [
                ProgressRing(
                  value: goals == null || goals.caloriesKcal <= 0 ? 0 : totals.energyKcal / goals.caloriesKcal,
                  size: 120,
                  color: c.tertiary,
                  semanticsLabel: 'Calorias do dia',
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(formatNumber(totals.energyKcal), key: const Key('home_kcal'), style: RltTheme.tabular(t.titleLarge!)),
                    Text(goals == null ? 'kcal' : 'de ${formatNumber(goals.caloriesKcal)} kcal', style: t.bodySmall),
                  ]),
                ),
                const SizedBox(width: RltSpace.l),
                Expanded(
                  child: goals == null
                      ? TextButton(onPressed: () => _open(GoalsScreen(deps: deps)), child: const Text('Preencha o perfil para calcular suas metas'))
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(goals.caloriesKcal >= totals.energyKcal ? 'RESTAM' : 'ACIMA', style: t.labelSmall),
                          Text('${formatNumber((goals.caloriesKcal - totals.energyKcal).abs())} kcal', style: RltTheme.tabular(t.titleLarge!)),
                          const SizedBox(height: RltSpace.s),
                          MacroBar(label: 'Proteína', current: totals.proteinGrams, goal: goals.proteinGrams, color: c.protein),
                          const SizedBox(height: 6),
                          MacroBar(label: 'Carboidrato', current: totals.carbsGrams, goal: goals.carbsGrams, color: c.carbs),
                          const SizedBox(height: 6),
                          MacroBar(label: 'Gordura', current: totals.fatGrams, goal: goals.fatGrams, color: c.fat),
                        ]),
                ),
              ]),
              const SizedBox(height: RltSpace.l),
              Row(children: [
                mini(Icons.water_drop_outlined, c.water, 'Água', '${formatNumber(totals.waterMl / 1000, decimals: 1)} L',
                    goals == null ? 'hoje' : 'de ${formatNumber(goals.waterMl / 1000, decimals: 1)} L',
                    goals == null || goals.waterMl == 0 ? 0 : totals.waterMl / goals.waterMl),
                const SizedBox(width: RltSpace.s),
                mini(Icons.directions_walk_outlined, c.primary, 'Passos', formatNumber(totals.steps), 'de ${formatNumber(stepsGoal)}',
                    stepsGoal == 0 ? 0 : totals.steps / stepsGoal),
                const SizedBox(width: RltSpace.s),
                mini(Icons.timer_outlined, c.primary, 'Exercício', '${active.inMinutes} min', 'de $kActiveMinutesReference min',
                    active.inMinutes / kActiveMinutesReference),
              ]),
            ]),
          ),
        ),
        if (_isToday)
          ValueListenableBuilder<StepTrackingStatus>(
            valueListenable: deps.stepTracking.status,
            builder: (context, status, _) => switch (status) {
              StepTrackingStatus.permissionDenied => Padding(
                  padding: const EdgeInsets.only(top: RltSpace.m),
                  child: StateCard(
                    key: const Key('home_steps_permission'),
                    icon: Icons.directions_walk_outlined,
                    title: 'Contagem de passos desligada',
                    message: 'Permita "atividade física" para contar passos.',
                    actionLabel: 'Permitir contagem de passos',
                    tone: StateTone.permission,
                    onAction: () => deps.stepTracking.start(),
                  ),
                ),
              StepTrackingStatus.noSensor => Padding(
                  padding: const EdgeInsets.only(top: RltSpace.m),
                  child: Text('Este aparelho não tem sensor de passos. Passos podem vir de uma pulseira.', style: t.bodySmall),
                ),
              _ => const SizedBox.shrink(),
            },
          ),
        if (doses.isNotEmpty) ...[
          RltSectionHeader(
            'Remédios de hoje',
            action: TextButton(onPressed: () => _open(MedicationsScreen(deps: deps)), child: const Text('Agenda')),
          ),
          for (final d in pendingDoses.take(2)) ...[
            MedicationDoseCard(
              key: Key('home_dose_${d.medication.id}_${d.time}'),
              name: d.medication.name,
              dose: '${doseLabel(d.medication)} · ${medicationFormLabel(d.medication.form)}',
              time: d.time,
              status: d.overdue ? DoseCardStatus.overdue : DoseCardStatus.upcoming,
              onTaken: () => markDose(context, deps, d, DoseStatus.taken),
              onSkipped: () => markDose(context, deps, d, DoseStatus.skipped),
            ),
            const SizedBox(height: RltSpace.s),
          ],
          for (final d in takenDoses)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.check, size: 18, color: c.success),
                const SizedBox(width: 6),
                Expanded(child: Text('${d.medication.name} ${doseLabel(d.medication)} — tomado (${d.time})', style: t.bodyMedium)),
              ]),
            ),
        ],
        if (_isToday && sleeps.isNotEmpty) ...[
          const SizedBox(height: RltSpace.m),
          Container(
            padding: const EdgeInsets.all(RltSpace.l),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
            child: Row(children: [
              const HealthAreaIcon(area: HealthArea.sleep),
              const SizedBox(width: RltSpace.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('SONO DA ÚLTIMA NOITE', style: t.labelSmall),
                  Text(sleeps.first.durationLabel, style: RltTheme.tabular(t.titleMedium!)),
                ]),
              ),
              Text('${hhmm(sleeps.first.startLocal)} → ${hhmm(sleeps.first.endLocal)}', style: t.bodySmall),
            ]),
          ),
        ],
        RltSectionHeader('Linha do tempo'),
        if (timeline.isEmpty)
          StateCard(
            key: const Key('home_empty'),
            icon: Icons.calendar_today_outlined,
            title: _isToday ? 'Nada registrado hoje' : 'Nada registrado neste dia',
            message: 'Comece pelo mais fácil: um copo de água ou a última refeição. Ou conte tudo para o Cérebro.',
          )
        else
          for (var i = 0; i < timeline.length; i++)
            TimelineItem(
              time: hhmm(timeline[i].local),
              area: timeline[i].area,
              title: timeline[i].title,
              detail: timeline[i].detail,
              isLast: i == timeline.length - 1,
            ),
        if (_isToday) ...[
          const RltSectionHeader('Atalhos rápidos'),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: RltSpace.s,
            crossAxisSpacing: RltSpace.s,
            childAspectRatio: 1.2,
            children: [
              _Shortcut(keyName: 'shortcut_water', icon: Icons.water_drop_outlined, label: '+ Água', onTap: _quickWater),
              _Shortcut(keyName: 'shortcut_meal', icon: Icons.restaurant_outlined, label: '+ Refeição', onTap: () => _open(AddFoodScreen(deps: deps))),
              _Shortcut(keyName: 'shortcut_medication', icon: Icons.medication_outlined, label: 'Tomei remédio', onTap: () => _open(MedicationsScreen(deps: deps))),
              _Shortcut(keyName: 'shortcut_workout', icon: Icons.fitness_center, label: 'Iniciar treino', onTap: () {
                final plans = deps.workoutRepository.listPlans();
                _open(plans.isEmpty ? LiveWorkoutScreen(deps: deps) : GymScreen(deps: deps));
              }),
              _Shortcut(keyName: 'shortcut_run', icon: Icons.directions_run, label: 'Iniciar corrida', onTap: () => _open(RunsScreen(deps: deps))),
              _Shortcut(keyName: 'shortcut_brain', icon: Icons.psychology_outlined, label: 'Falar com o Cérebro', onTap: () => widget.onOpenTab(RltTab.cerebro)),
            ],
          ),
        ],
      ],
    );
  }

  static String _weekday(DateTime d) =>
      const ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'][d.weekday - 1];
}

class _Shortcut extends StatelessWidget {
  final String keyName;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _Shortcut({required this.keyName, required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Material(
      color: c.secondaryContainer,
      borderRadius: BorderRadius.circular(RltRadius.card),
      child: InkWell(
        key: Key(keyName),
        borderRadius: BorderRadius.circular(RltRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RltSpace.s),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: c.onSecondaryContainer),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.onSecondaryContainer, fontWeight: FontWeight.w700),
            ),
          ]),
        ),
      ),
    );
  }
}
