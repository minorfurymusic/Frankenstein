// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_profile/profile.dart';

import '../../app_dependencies.dart';
import '../../data/day_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/progress.dart';
import '../../widgets/state_views.dart';
import '../account/goals_screen.dart';
import '../account/profile_screen.dart';
import 'add_food_screen.dart';
import 'diet_screens.dart';
import 'meal_labels.dart';

/// Aba Nutrição (prancheta NutricaoHoje): Hoje, Diário, Tendências e
/// Galeria; atalhos para Dieta e metas e Receitas próprias.
class NutritionTab extends StatelessWidget {
  final AppDependencies deps;
  const NutritionTab({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(children: [
        RltPageTitle(
          'Nutrição',
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              key: const Key('nutrition_goals'),
              tooltip: 'Dieta e metas',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DietAndGoalsScreen(deps: deps))),
              icon: const Icon(Icons.track_changes),
            ),
            IconButton(
              key: const Key('nutrition_recipes'),
              tooltip: 'Receitas próprias',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecipesScreen(deps: deps))),
              icon: const Icon(Icons.menu_book_outlined),
            ),
          ]),
        ),
        const TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [Tab(text: 'Hoje'), Tab(text: 'Diário'), Tab(text: 'Tendências'), Tab(text: 'Galeria')],
        ),
        Expanded(
          child: ValueListenableBuilder<int>(
            valueListenable: deps.dataVersion,
            builder: (context, _, _) => TabBarView(children: [
              NutritionDayView(deps: deps, key: const Key('nutrition_today')),
              DiaryView(deps: deps),
              TrendsView(deps: deps),
              // TODO(frankstein): galeria de pratos precisa das fotos do prato (câmera + IA, etapa de integrações).
              ListView(padding: const EdgeInsets.all(RltSpace.l), children: const [
                StateCard(
                  icon: Icons.photo_library_outlined,
                  title: 'Galeria de pratos: em construção',
                  message: 'As fotos dos pratos entram junto com a câmera e a IA.',
                ),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }
}

/// Um dia de nutrição: anel de calorias, macros, fibra, água, refeições.
/// Também é a tela do dia aberto pelo Diário.
class NutritionDayView extends StatefulWidget {
  final AppDependencies deps;
  final DateTime? initialDay;
  const NutritionDayView({super.key, required this.deps, this.initialDay});

  @override
  State<NutritionDayView> createState() => _NutritionDayViewState();
}

class _NutritionDayViewState extends State<NutritionDayView> {
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    final d = widget.initialDay ?? DateTime.now();
    _day = DateTime(d.year, d.month, d.day);
  }

  bool get _isToday {
    final n = DateTime.now();
    return _day.year == n.year && _day.month == n.month && _day.day == n.day;
  }

  void _addWater(double ml) {
    final deps = widget.deps;
    final now = DateTime.now();
    final local = _isToday ? now : DateTime(_day.year, _day.month, _day.day, 12);
    try {
      deps.waterLogger.log(amountMl: ml, occurredAt: local.toUtc(), occurredAtTzOffsetMinutes: local.timeZoneOffset.inMinutes);
      deps.notifyDataChanged();
      showRltSaved(context, '+${formatNumber(ml)} ml de água.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  void _closeDay(DailyGoals? goals, DayTotals totals) {
    final deps = widget.deps;
    deps.nutrition.closeDay(_day);
    final p = deps.profileRepository.load();
    final String message;
    if (goals == null || p == null) {
      message = 'Dia fechado com ${formatNumber(totals.energyKcal)} kcal. Preencha o perfil para comparar com a meta.';
    } else {
      final hit = metCalorieGoal(p.objective, consumedKcal: totals.energyKcal, goalKcal: goals.caloriesKcal);
      message = hit
          ? 'Você bateu a meta: ${formatNumber(totals.energyKcal)} de ${formatNumber(goals.caloriesKcal)} kcal.'
          : 'Meta não batida: ${formatNumber(totals.energyKcal)} de ${formatNumber(goals.caloriesKcal)} kcal.';
    }
    deps.notifyDataChanged();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Dia fechado'),
        content: Text('$message\nRegistros feitos depois atualizam o resultado.'),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final totals = deps.dayRead.totals(_day);
    final goals = deps.goals.goalsFor(_day);
    final remaining = goals == null ? null : goals.caloriesKcal - totals.energyKcal;
    final waterGoal = goals?.waterMl;
    final dayLabel = _isToday ? 'Hoje, ${_day.day} de ${monthShort(_day.month)}.' : '${ddmm(_day)}/${_day.year}';
    final byMeal = <MealType, List<HealthEvent>>{};
    for (final e in totals.meals) {
      byMeal.putIfAbsent(MealType.fromWireValue(e.payload['meal_type'] as String), () => []).add(e);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, RltSpace.xl),
      children: [
        Row(children: [
          IconButton(
            key: const Key('day_prev'),
            tooltip: 'Dia anterior',
            onPressed: () => setState(() => _day = _day.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(child: Text(dayLabel, textAlign: TextAlign.center, style: t.titleSmall)),
          IconButton(
            tooltip: 'Próximo dia',
            onPressed: _isToday ? null : () => setState(() => _day = _day.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ]),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.l),
            child: Column(children: [
              Row(children: [
                ProgressRing(
                  value: goals == null || goals.caloriesKcal <= 0 ? 0 : totals.energyKcal / goals.caloriesKcal,
                  size: 132,
                  color: c.tertiary,
                  semanticsLabel: 'Calorias do dia',
                  center: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      formatNumber(remaining == null ? totals.energyKcal : remaining.abs()),
                      key: const Key('kcal_center'),
                      style: RltTheme.tabular(t.headlineMedium!),
                    ),
                    Text(
                      remaining == null ? 'kcal hoje' : (remaining >= 0 ? 'kcal restantes' : 'kcal acima'),
                      style: t.bodySmall,
                    ),
                  ]),
                ),
                const SizedBox(width: RltSpace.l),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Consumidas', style: t.labelMedium),
                    Text('${formatNumber(totals.energyKcal)} kcal', style: RltTheme.tabular(t.titleMedium!)),
                    const SizedBox(height: RltSpace.s),
                    Text('Meta', style: t.labelMedium),
                    Text(goals == null ? '—' : '${formatNumber(goals.caloriesKcal)} kcal', style: RltTheme.tabular(t.titleMedium!)),
                  ]),
                ),
              ]),
              if (goals == null) ...[
                const SizedBox(height: RltSpace.m),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(deps: deps))),
                  child: const Text('Preencha o perfil para ver suas metas'),
                ),
              ] else ...[
                const SizedBox(height: RltSpace.l),
                MacroBar(label: 'Proteína', current: totals.proteinGrams, goal: goals.proteinGrams, color: c.protein),
                const SizedBox(height: RltSpace.s),
                MacroBar(label: 'Carboidrato', current: totals.carbsGrams, goal: goals.carbsGrams, color: c.carbs),
                const SizedBox(height: RltSpace.s),
                MacroBar(label: 'Gordura', current: totals.fatGrams, goal: goals.fatGrams, color: c.fat),
                const SizedBox(height: RltSpace.s),
                MacroBar(label: 'Fibra', current: totals.fiberGrams, goal: goals.fiberGrams, color: c.success),
              ],
            ]),
          ),
        ),
        const SizedBox(height: RltSpace.m),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.l),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Icon(Icons.water_drop_outlined, color: c.water),
                const SizedBox(width: RltSpace.s),
                Expanded(
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: 'Água  ', style: t.titleMedium),
                    TextSpan(
                      text: waterGoal == null
                          ? '${formatNumber(totals.waterMl)} ml'
                          : '${formatNumber(totals.waterMl)} de ${formatNumber(waterGoal)} ml',
                      style: RltTheme.tabular(t.bodyMedium!),
                    ),
                  ])),
                ),
                if (waterGoal != null && waterGoal > 0)
                  Text('${(totals.waterMl / waterGoal * 100).round()}%', style: t.titleSmall?.copyWith(color: c.water)),
              ]),
              if (waterGoal != null) ...[
                const SizedBox(height: RltSpace.s),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: waterGoal <= 0 ? 0 : (totals.waterMl / waterGoal).clamp(0.0, 1.0),
                    minHeight: 8,
                    color: c.water,
                    backgroundColor: c.surfaceContainerHighest,
                  ),
                ),
              ],
              const SizedBox(height: RltSpace.m),
              Row(children: [
                for (final ml in const [200.0, 300.0, 500.0]) ...[
                  Expanded(
                    child: FilledButton.tonal(
                      key: Key('water_${ml.round()}'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                      onPressed: () => _addWater(ml),
                      child: FittedBox(fit: BoxFit.scaleDown, child: Text('+${ml.round()} ml')),
                    ),
                  ),
                  if (ml != 500) const SizedBox(width: RltSpace.s),
                ],
              ]),
            ]),
          ),
        ),
        for (final type in MealType.values) _MealSection(deps: deps, day: _day, type: type, events: byMeal[type] ?? const []),
        const SizedBox(height: RltSpace.l),
        if (_isToday)
          OutlinedButton.icon(
            key: const Key('close_day'),
            onPressed: () => _closeDay(goals, totals),
            icon: const Icon(Icons.task_alt),
            label: Text(deps.nutrition.isClosedManually(_day) ? 'Dia fechado — ver resultado' : 'Fechar o dia'),
          ),
      ],
    );
  }
}

class _MealSection extends StatelessWidget {
  final AppDependencies deps;
  final DateTime day;
  final MealType type;
  final List<HealthEvent> events;
  const _MealSection({required this.deps, required this.day, required this.type, required this.events});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final items = <Map<String, dynamic>>[];
    DateTime? firstLocal;
    double kcal = 0;
    for (final e in events) {
      firstLocal ??= localOf(e.occurredAt, e.occurredAtTzOffsetMinutes);
      kcal += ((e.payload['totals'] as Map<String, dynamic>)['energy_kcal'] as num).toDouble();
      for (final i in (e.payload['items'] as List)) {
        items.add(i as Map<String, dynamic>);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(top: RltSpace.m),
      child: Container(
        padding: const EdgeInsets.all(RltSpace.l),
        decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(mealTypeLabel(type), style: t.titleMedium),
                if (firstLocal != null) Text(hhmm(firstLocal), style: t.bodySmall),
              ]),
            ),
            if (items.isNotEmpty) Text('${formatNumber(kcal)} kcal', style: RltTheme.tabular(t.titleSmall!)),
          ]),
          for (final i in items)
            Padding(
              padding: const EdgeInsets.only(top: RltSpace.s),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i['name'] as String, style: t.bodyLarge),
                    Text('${formatNumber((i['grams'] as num).toDouble())} g', style: t.bodySmall),
                  ]),
                ),
                Text('${formatNumber((i['energy_kcal'] as num).toDouble())} kcal', style: RltTheme.tabular(t.bodyMedium!)),
              ]),
            ),
          const SizedBox(height: RltSpace.s),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: Key('meal_add_${type.name}'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AddFoodScreen(deps: deps, mealType: type, day: day)),
              ),
              icon: const Icon(Icons.add),
              label: const Text('Adicionar'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Diário (prancheta NutricaoDiario; `docs/specs/nutricao.md`, tela 4): mês
/// em calendário, cada dia marcado dentro/fora da meta; tocar abre o dia.
class DiaryView extends StatefulWidget {
  final AppDependencies deps;
  const DiaryView({super.key, required this.deps});

  @override
  State<DiaryView> createState() => _DiaryViewState();
}

class _DiaryViewState extends State<DiaryView> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final profile = deps.profileRepository.load();
    final today = DateTime.now();
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
        hit = metCalorieGoal(profile!.objective, consumedKcal: totals.energyKcal, goalKcal: goals.caloriesKcal);
        hit ? inGoal++ : outGoal++;
      }
      final color = hit == null ? null : (hit ? c.successContainer : c.errorContainer);
      return InkWell(
        key: Key('diary_day_$d'),
        borderRadius: BorderRadius.circular(RltRadius.chip),
        onTap: future
            ? null
            : () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text('${ddmm(date)}/${date.year}')),
                    body: NutritionDayView(deps: deps, initialDay: date),
                  ),
                )),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(RltRadius.chip)),
          alignment: Alignment.center,
          child: Text('$d', style: t.bodyMedium?.copyWith(color: future ? c.outline : null)),
        ),
      );
    }

    final cells = [for (var i = 0; i < leading; i++) const SizedBox(), for (var d = 1; d <= days; d++) cell(d)];
    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
      Row(children: [
        IconButton(
          tooltip: 'Mês anterior',
          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(child: Text('${monthShort(_month.month)} de ${_month.year}', textAlign: TextAlign.center, style: t.titleMedium)),
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
      Wrap(spacing: 16, children: [
        _Legend(color: c.successContainer, label: 'Dentro da meta ($inGoal)'),
        _Legend(color: c.errorContainer, label: 'Fora da meta ($outGoal)'),
      ]),
      if (profile == null) ...[
        const SizedBox(height: RltSpace.m),
        Text('Preencha o perfil para marcar os dias contra a meta.', style: t.bodySmall),
      ],
    ]);
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 14, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]);
}

/// Tendências (prancheta NutricaoTendencias; `docs/specs/nutricao.md`, tela
/// 5): sequência de dias, calorias contra a meta, média de macros, água e
/// peso, em 7/30/90 dias.
class TrendsView extends StatefulWidget {
  final AppDependencies deps;
  const TrendsView({super.key, required this.deps});

  @override
  State<TrendsView> createState() => _TrendsViewState();
}

class _TrendsViewState extends State<TrendsView> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final today = DateTime.now();
    final totals = [
      for (var i = _days - 1; i >= 0; i--) deps.dayRead.totals(DateTime(today.year, today.month, today.day).subtract(Duration(days: i))),
    ];
    final logged = totals.where((d) => d.mealCount > 0).toList();
    var streak = 0;
    for (var i = 0;; i++) {
      final d = deps.dayRead.totals(DateTime(today.year, today.month, today.day).subtract(Duration(days: i)));
      if (d.mealCount == 0) {
        if (i == 0) continue; // hoje ainda pode não ter registro
        break;
      }
      streak++;
      if (i > 3650) break;
    }
    double avg(double Function(DayTotals) f) => logged.isEmpty ? 0 : logged.map(f).reduce((a, b) => a + b) / logged.length;
    final goal = deps.goals.goalsFor(today);
    final weights = deps.healthRead.weights(days: _days);

    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
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
      RltTwoColumnGrid(children: [
        RltStatTile(
          key: const Key('trend_streak'),
          icon: Icons.local_fire_department_outlined,
          iconColor: c.tertiary,
          label: 'Sequência',
          value: '$streak',
          unit: streak == 1 ? 'dia' : 'dias',
          caption: 'seguidos registrando',
        ),
        RltStatTile(
          icon: Icons.restaurant_outlined,
          iconColor: c.tertiary,
          label: 'Média de calorias',
          value: formatNumber(avg((d) => d.energyKcal)),
          unit: 'kcal',
          caption: '${logged.length} de $_days dias com registro',
        ),
        RltStatTile(icon: Icons.egg_outlined, iconColor: c.protein, label: 'Proteína média', value: formatNumber(avg((d) => d.proteinGrams)), unit: 'g'),
        RltStatTile(icon: Icons.grass_outlined, iconColor: c.success, label: 'Fibra média', value: formatNumber(avg((d) => d.fiberGrams)), unit: 'g'),
        RltStatTile(icon: Icons.bakery_dining_outlined, iconColor: c.carbs, label: 'Carboidrato médio', value: formatNumber(avg((d) => d.carbsGrams)), unit: 'g'),
        RltStatTile(icon: Icons.water_drop_outlined, iconColor: c.water, label: 'Água média', value: formatNumber(avg((d) => d.waterMl)), unit: 'ml'),
      ]),
      const RltSectionHeader('Calorias por dia'),
      if (logged.isEmpty)
        Text('Sem refeições registradas neste período.', style: t.bodyMedium)
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.l),
            child: RltLineChart(
              semanticsLabel: 'Calorias por dia nos últimos $_days dias',
              series: [ChartSeries(label: 'Consumidas', color: c.tertiary, points: [for (final d in logged) ChartPoint(d.day, d.energyKcal)])],
              referenceY: goal?.caloriesKcal,
              referenceLabel: goal == null ? null : 'Meta de hoje',
            ),
          ),
        ),
      const RltSectionHeader('Peso'),
      if (weights.isEmpty)
        Text('Sem pesagens neste período.', style: t.bodyMedium)
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.l),
            child: RltLineChart(
              semanticsLabel: 'Peso nos últimos $_days dias',
              series: [ChartSeries(label: 'Peso', color: c.protein, points: [for (final w in weights) ChartPoint(w.local, w.value)])],
            ),
          ),
        ),
      // TODO(frankstein): peso contra a meta de peso com previsão de chegada (precisa de "peso desejado" no perfil — decisão de produto).
      const SizedBox(height: RltSpace.l),
      OutlinedButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GoalsScreen(deps: deps))),
        child: const Text('Ver metas'),
      ),
    ]);
  }
}
