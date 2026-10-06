import 'package:flutter/material.dart';
import 'package:frankstein_profile/profile.dart';

import '../app_dependencies.dart';
import '../format.dart';
import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// Mês em calendário com cada dia marcado dentro/fora da meta de calorias
/// (pranchetas NutricaoDiario e InicioCalendario). Dia sem refeição fica sem
/// cor; dia futuro não abre. Tocar num dia chama [onOpenDay].
class MonthGoalCalendar extends StatefulWidget {
  final AppDependencies deps;
  final ValueChanged<DateTime> onOpenDay;

  /// Prefixo das chaves dos dias (`<prefixo>_day_<n>`), para teste.
  final String keyPrefix;

  /// Mês aberto ao começar (padrão: o mês de hoje).
  final DateTime? initialMonth;

  /// Dia em destaque (ex.: o dia aberto no Início).
  final DateTime? selected;

  const MonthGoalCalendar({
    super.key,
    required this.deps,
    required this.onOpenDay,
    this.keyPrefix = 'calendar',
    this.initialMonth,
    this.selected,
  });

  @override
  State<MonthGoalCalendar> createState() => _MonthGoalCalendarState();
}

class _MonthGoalCalendarState extends State<MonthGoalCalendar> {
  late DateTime _month = DateTime((widget.initialMonth ?? DateTime.now()).year, (widget.initialMonth ?? DateTime.now()).month);

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final profile = deps.profileRepository.load();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = DateTime(_month.year, _month.month + 1, 0).day;
    final leading = DateTime(_month.year, _month.month, 1).weekday % 7; // domingo = 0
    const names = ['D', 'S', 'T', 'Q', 'Q', 'S', 'S'];
    var inGoal = 0, outGoal = 0;

    Widget cell(int d) {
      final date = DateTime(_month.year, _month.month, d);
      final future = date.isAfter(today);
      final totals = future ? null : deps.dayRead.totals(date);
      final goals = future || profile == null ? null : deps.goals.goalsFor(date);
      bool? hit;
      if (totals != null && totals.mealCount > 0 && goals != null) {
        hit = metCalorieGoal(goals.objective, consumedKcal: totals.energyKcal, goalKcal: goals.caloriesKcal);
        hit ? inGoal++ : outGoal++;
      }
      final color = hit == null ? null : (hit ? c.successContainer : c.errorContainer);
      final isToday = date == today;
      final isSelected = widget.selected != null && date == widget.selected;
      return Semantics(
        button: !future,
        label: '$d de ${monthShort(_month.month)}${hit == null ? '' : (hit ? ', dentro da meta' : ', fora da meta')}${isToday ? ', hoje' : ''}',
        excludeSemantics: true,
        child: InkWell(
          key: Key('${widget.keyPrefix}_day_$d'),
          borderRadius: BorderRadius.circular(RltRadius.chip),
          onTap: future ? null : () => widget.onOpenDay(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected ? c.primaryContainer : color,
              borderRadius: BorderRadius.circular(RltRadius.chip),
              border: isToday ? Border.all(color: c.primary, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text('$d', style: t.bodyMedium?.copyWith(color: future ? c.outline : null)),
          ),
        ),
      );
    }

    final cells = [for (var i = 0; i < leading; i++) const SizedBox(), for (var d = 1; d <= days; d++) cell(d)];
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text('${monthLong(_month.month)} de ${_month.year}',
              key: Key('${widget.keyPrefix}_month'), textAlign: TextAlign.center, style: t.titleMedium),
        ),
        IconButton(
          tooltip: 'Próximo mês',
          onPressed: _month.year == today.year && _month.month == today.month
              ? null
              : () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
          icon: const Icon(Icons.chevron_right),
        ),
      ]),
      Row(children: [for (final n in names) Expanded(child: Center(child: Text(n, style: t.labelMedium)))]),
      GridView.count(crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), children: cells),
      const SizedBox(height: RltSpace.m),
      Wrap(spacing: 16, runSpacing: 6, children: [
        _Legend(color: c.successContainer, label: 'Dentro da meta ($inGoal)'),
        _Legend(color: c.errorContainer, label: 'Fora da meta ($outGoal)'),
        _Legend(border: c.primary, label: 'Hoje'),
      ]),
      if (profile == null) ...[
        const SizedBox(height: RltSpace.m),
        Text('Preencha o perfil para marcar os dias contra a meta.', style: t.bodySmall),
      ],
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color? color;
  final Color? border;
  final String label;
  const _Legend({this.color, this.border, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border == null ? null : Border.all(color: border!, width: 2),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}
