import 'package:flutter/material.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/state_views.dart';
import '../../widgets/steps_status_card.dart';
import '../../widgets/common.dart';
import '../../widgets/health_area.dart';
import '../../widgets/progress.dart';
import '../../widgets/timeline_item.dart';
import 'activity_screens.dart';
import 'gym_screens.dart';
import 'live_workout_screen.dart';

/// Aba Exercícios (prancheta ExerciciosHoje): anel de passos, minutos
/// ativos, calorias gastas, próximo treino, atalhos e seções.
class ExerciseTab extends StatelessWidget {
  final AppDependencies deps;
  const ExerciseTab({super.key, required this.deps});

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  /// Próximo treino: o plano seguinte ao último usado (rodízio A → B → C);
  /// sem histórico, o primeiro plano.
  WorkoutPlan? _nextPlan() {
    final plans = deps.workoutRepository.listPlans();
    if (plans.isEmpty) return null;
    final sessions = deps.core.queryByType(HealthEventType.workoutSession).where((e) => e.payload['plan_id'] != null);
    if (sessions.isEmpty) return plans.first;
    final lastId = sessions.last.payload['plan_id'];
    final i = plans.indexWhere((p) => p.id == lastId);
    return plans[(i + 1) % plans.length];
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: deps.dataVersion,
      builder: (context, _, _) => GuardedView(errorTitle: 'Não foi possível carregar os exercícios', builder: (context) {
        final c = RltColors.of(context);
        final t = Theme.of(context).textTheme;
        final today = DateTime.now();
        final day = DateTime(today.year, today.month, today.day);
        final steps = deps.dayRead.totals(day).steps;
        final profile = deps.profileRepository.load();
        final goal = profile?.stepsGoal ?? 8000;
        final activities = deps.activityRead.forDay(day);
        final active = deps.activityRead.activeTime(day);
        final weights = deps.healthRead.weights(days: 3650);
        final stepsKcal = profile == null || weights.isEmpty
            ? 0.0
            : HealthFormulas.stepsKcal(steps: steps, sex: profile.sex, heightMeters: profile.heightMeters, weightKg: weights.first.value);
        final burned = stepsKcal + activities.fold(0.0, (s, a) => s + a.kcal);
        final km = profile == null ? null : steps * HealthFormulas.stepLengthMeters(profile.sex, profile.heightMeters) / 1000;
        final next = _nextPlan();

        return ListView(
          key: const Key('tab_exercicios'),
          padding: const EdgeInsets.only(bottom: RltSpace.xl),
          children: [
            const RltPageTitle('Exercícios'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RltSpace.l),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(RltSpace.l),
                    child: Row(children: [
                      ProgressRing(
                        value: goal == 0 ? 0 : steps / goal,
                        size: 132,
                        semanticsLabel: 'Passos de hoje',
                        center: Column(mainAxisSize: MainAxisSize.min, children: [
                          Text(formatNumber(steps), key: const Key('steps_today'), style: RltTheme.tabular(t.headlineMedium!)),
                          Text('de ${formatNumber(goal)} passos', style: t.bodySmall),
                        ]),
                      ),
                      const SizedBox(width: RltSpace.l),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Minutos ativos', style: t.labelMedium),
                          Text('${active.inMinutes} min', style: RltTheme.tabular(t.titleMedium!)),
                          const SizedBox(height: RltSpace.s),
                          Text('Calorias gastas', style: t.labelMedium),
                          Text(weights.isEmpty ? '—' : '${formatNumber(burned)} kcal', style: RltTheme.tabular(t.titleMedium!)),
                          const SizedBox(height: RltSpace.s),
                          Text('Distância', style: t.labelMedium),
                          Text(km == null ? '—' : '${formatNumber(km, decimals: 1)} km', style: RltTheme.tabular(t.titleMedium!)),
                        ]),
                      ),
                    ]),
                  ),
                ),
                StepsStatusCard(deps: deps, keyPrefix: 'exercise'),
                const SizedBox(height: RltSpace.m),
                Row(children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('start_workout'),
                      onPressed: () => _open(context, next == null ? GymScreen(deps: deps) : LiveWorkoutScreen(deps: deps, plan: next)),
                      icon: const Icon(Icons.fitness_center),
                      label: const Text('Iniciar treino'),
                    ),
                  ),
                  const SizedBox(width: RltSpace.s),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      key: const Key('start_run'),
                      onPressed: () => _open(context, RunsScreen(deps: deps)),
                      icon: const Icon(Icons.directions_run),
                      label: const Text('Iniciar corrida'),
                    ),
                  ),
                ]),
                if (next != null) ...[
                  const SizedBox(height: RltSpace.m),
                  Container(
                    padding: const EdgeInsets.all(RltSpace.l),
                    decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Text('PRÓXIMO TREINO', style: t.labelSmall),
                      Text(next.name, style: t.titleMedium),
                      Text('${next.exercises.length} exercícios', style: t.bodyMedium),
                      const SizedBox(height: RltSpace.m),
                      FilledButton.icon(
                        key: const Key('start_next_plan'),
                        onPressed: () => _open(context, LiveWorkoutScreen(deps: deps, plan: next)),
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Começar agora'),
                      ),
                    ]),
                  ),
                ],
                if (next == null) ...[
                  const SizedBox(height: RltSpace.m),
                  StateCard(
                    key: const Key('exercise_no_plan'),
                    icon: Icons.fitness_center_outlined,
                    title: 'Nenhum treino planejado',
                    message: 'Monte seu primeiro plano de academia.',
                    actionLabel: 'Criar plano de treino',
                    actionIcon: Icons.add,
                    onAction: () => _open(context, PlanFormScreen(deps: deps)),
                  ),
                ],
                if (activities.isNotEmpty) ...[
                  const RltSectionHeader('Hoje'),
                  for (var i = 0; i < activities.length; i++)
                    TimelineItem(
                      time: hhmm(activities[i].local),
                      area: activities[i].kind == ActivityKind.gps ? HealthArea.run : HealthArea.workout,
                      title: activities[i].title,
                      detail: [
                        if (activities[i].distanceMeters != null) '${formatNumber(activities[i].distanceMeters! / 1000, decimals: 2)} km',
                        if (activities[i].duration != null) durationLabel(activities[i].duration!),
                        ?activities[i].detail,
                        if (activities[i].kcal > 0) '${formatNumber(activities[i].kcal)} kcal',
                      ].join(' · '),
                      isLast: i == activities.length - 1,
                    ),
                ],
                const RltSectionHeader('Seções'),
                RltSectionTile(
                  key: const Key('section_passos'),
                  icon: Icons.directions_walk_outlined,
                  iconColor: c.primary,
                  title: 'Passos',
                  subtitle: 'Histórico por dia, semana e mês',
                  onTap: () => _open(context, StepsScreen(deps: deps)),
                ),
                RltSectionTile(
                  key: const Key('section_academia'),
                  icon: Icons.fitness_center_outlined,
                  iconColor: c.primary,
                  title: 'Academia',
                  subtitle: 'Planos, biblioteca, recordes',
                  onTap: () => _open(context, GymScreen(deps: deps)),
                ),
                RltSectionTile(
                  icon: Icons.directions_run_outlined,
                  iconColor: c.primary,
                  title: 'Corrida e caminhada',
                  subtitle: 'Histórico de rotas, GPX',
                  onTap: () => _open(context, RunsScreen(deps: deps)),
                ),
                RltSectionTile(
                  key: const Key('section_outras'),
                  icon: Icons.pool_outlined,
                  iconColor: c.primary,
                  title: 'Outras atividades',
                  subtitle: 'Natação, bike, futebol…',
                  onTap: () => _open(context, OtherActivityScreen(deps: deps)),
                ),
              ]),
            ),
          ],
        );
      }),
    );
  }
}
