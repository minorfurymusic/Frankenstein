import 'package:flutter/material.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'live_workout_screen.dart';
import 'share_helpers.dart';

/// Academia (prancheta Academia): planos, biblioteca e histórico com
/// recordes.
class GymScreen extends StatelessWidget {
  final AppDependencies deps;
  const GymScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Academia'),
          bottom: const TabBar(tabs: [Tab(text: 'Planos'), Tab(text: 'Biblioteca'), Tab(text: 'Histórico')]),
        ),
        body: ValueListenableBuilder<int>(
          valueListenable: deps.dataVersion,
          builder: (context, _, _) => TabBarView(children: [
            _PlansTab(deps: deps),
            ExerciseLibraryBody(deps: deps),
            _HistoryTab(deps: deps),
          ]),
        ),
      ),
    );
  }
}

class _PlansTab extends StatelessWidget {
  final AppDependencies deps;
  const _PlansTab({required this.deps});

  @override
  Widget build(BuildContext context) => GuardedView(errorTitle: 'Não foi possível carregar os planos', errorMessage: 'Tente de novo.', builder: _build);

  Widget _build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final plans = deps.workoutRepository.listPlans();
    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
      if (plans.isEmpty)
        const StateCard(
          icon: Icons.fitness_center_outlined,
          title: 'Nenhum plano de treino',
          message: 'Monte um plano com exercícios, séries, repetições e carga. Ou conte ao Cérebro o que você fez.',
        ),
      for (final p in plans)
        Card(
          margin: const EdgeInsets.only(bottom: RltSpace.s),
          child: ListTile(
            key: Key('plan_${p.id}'),
            title: Text(p.name, style: t.titleSmall),
            subtitle: Text('${p.exercises.length} exercícios · ${p.exercises.map((e) => e.exerciseName).take(3).join(', ')}'
                '${p.exercises.length > 3 ? '…' : ''}'),
            trailing: IconButton.filled(
              key: Key('plan_start_${p.id}'),
              tooltip: 'Começar ${p.name}',
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LiveWorkoutScreen(deps: deps, plan: p))),
              icon: const Icon(Icons.play_arrow),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlanFormScreen(deps: deps, existing: p))),
          ),
        ),
      const SizedBox(height: RltSpace.s),
      FilledButton.icon(
        key: const Key('plan_new'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlanFormScreen(deps: deps))),
        icon: const Icon(Icons.add),
        label: const Text('Novo plano'),
      ),
      const SizedBox(height: RltSpace.s),
      OutlinedButton.icon(
        key: const Key('free_workout'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LiveWorkoutScreen(deps: deps))),
        icon: const Icon(Icons.play_arrow_outlined),
        label: const Text('Treino livre'),
      ),
    ]);
  }
}

/// Corpo da biblioteca dentro da aba (sem Scaffold próprio).
class ExerciseLibraryBody extends StatelessWidget {
  final AppDependencies deps;
  const ExerciseLibraryBody({super.key, required this.deps});

  @override
  Widget build(BuildContext context) => Navigator(
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ExerciseLibraryScreen(deps: deps),
        ),
      );
}

class _HistoryTab extends StatelessWidget {
  final AppDependencies deps;
  const _HistoryTab({required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final sessions = deps.core
        .queryByType(HealthEventType.workoutSession)
        .where((e) => e.payload['kind'] != 'other_activity')
        .toList()
        .reversed
        .toList();
    if (sessions.isEmpty) {
      return ListView(padding: const EdgeInsets.all(RltSpace.l), children: const [
        StateCard(icon: Icons.history, title: 'Nenhum treino ainda', message: 'Seus treinos e recordes aparecem aqui.'),
      ]);
    }
    final exerciseIds = <String>{for (final s in sessions) ...(s.payload['exercise_ids'] as List).cast<String>()};
    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
      const RltSectionHeader('Recordes'),
      for (final id in exerciseIds)
        Builder(builder: (context) {
          final pr = deps.workoutLogger.personalRecord(id);
          if (pr == null) return const SizedBox.shrink();
          final name = findCatalogExercise(id)?.name ?? id;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.emoji_events_outlined, color: RltColors.of(context).tertiary),
            title: Text(name),
            trailing: Text('${formatNumber(pr.loadKg, decimals: pr.loadKg % 1 == 0 ? 0 : 1)} kg × ${pr.reps}',
                style: RltTheme.tabular(t.titleSmall!)),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => ExerciseProgressScreen(deps: deps, exerciseId: id, name: name),
            )),
          );
        }),
      const RltSectionHeader('Treinos'),
      for (final s in sessions)
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(relativeDayTime(localOf(s.occurredAt, s.occurredAtTzOffsetMinutes))),
          subtitle: Text('${s.payload['sets_count']} séries'
              '${s.payload['duration_seconds'] == null ? '' : ' · ${durationLabel(Duration(seconds: (s.payload['duration_seconds'] as num).toInt()))}'}'),
          trailing: IconButton(
            tooltip: 'Compartilhar',
            onPressed: () => openWorkoutShare(context, deps, s),
            icon: const Icon(Icons.ios_share),
          ),
        ),
    ]);
  }
}

/// Criar/editar plano de treino (prancheta PlanoTreino): exercícios da
/// biblioteca com séries, repetições e carga.
class PlanFormScreen extends StatefulWidget {
  final AppDependencies deps;
  final WorkoutPlan? existing;
  const PlanFormScreen({super.key, required this.deps, this.existing});

  @override
  State<PlanFormScreen> createState() => _PlanFormScreenState();
}

class _PlanItem {
  final String id;
  final String name;
  int sets;
  int reps;
  double? load;
  _PlanItem(this.id, this.name, this.sets, this.reps, this.load);
}

class _PlanFormScreenState extends State<PlanFormScreen> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final List<_PlanItem> _items = [
    for (final e in widget.existing?.exercises ?? const <PlannedExercise>[])
      _PlanItem(e.exerciseId, e.exerciseName, e.targetSets, e.targetReps, e.targetLoadKg),
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final e = await Navigator.of(context).push<CatalogExercise>(
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen(pickMode: true)),
    );
    if (e != null) setState(() => _items.add(_PlanItem(e.id, e.name, 3, 10, null)));
  }

  void _save() {
    try {
      if (_name.text.trim().isEmpty) throw ArgumentError('dê um nome ao plano');
      if (_items.isEmpty) throw ArgumentError('adicione pelo menos um exercício');
      widget.deps.workoutRepository.savePlan(WorkoutPlan(
        id: widget.existing?.id ?? HealthDataCore.newId(),
        name: _name.text.trim(),
        exercises: [
          for (final i in _items)
            PlannedExercise(exerciseId: i.id, exerciseName: i.name, targetSets: i.sets, targetReps: i.reps, targetLoadKg: i.load),
        ],
      ));
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, 'Plano salvo em Exercícios › Academia.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  void _delete() {
    widget.deps.workoutRepository.deletePlan(widget.existing!.id);
    widget.deps.notifyDataChanged();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget stepper(String label, int value, ValueChanged<int> onChanged) => Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(tooltip: 'Menos $label', onPressed: value > 1 ? () => onChanged(value - 1) : null, icon: const Icon(Icons.remove)),
          Text('$value $label', style: RltTheme.tabular(t.bodyMedium!)),
          IconButton(tooltip: 'Mais $label', onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add)),
        ]);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Novo plano' : 'Editar plano'),
        actions: [TextButton(key: const Key('plan_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        TextField(key: const Key('plan_name'), controller: _name, decoration: const InputDecoration(labelText: 'Nome do plano (ex.: Treino A — Superiores)')),
        const RltSectionHeader('Exercícios'),
        for (var i = 0; i < _items.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: RltSpace.s),
            child: Padding(
              padding: const EdgeInsets.all(RltSpace.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(_items[i].name, style: t.titleSmall)),
                  IconButton(tooltip: 'Remover', onPressed: () => setState(() => _items.removeAt(i)), icon: const Icon(Icons.close)),
                ]),
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  stepper('séries', _items[i].sets, (v) => setState(() => _items[i].sets = v)),
                  stepper('reps', _items[i].reps, (v) => setState(() => _items[i].reps = v)),
                ]),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    initialValue: _items[i].load == null ? '' : formatNumber(_items[i].load!, decimals: 1),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Carga (opcional)', suffixText: 'kg'),
                    onChanged: (v) => _items[i].load = parseNumber(v),
                  ),
                ),
              ]),
            ),
          ),
        TextButton.icon(key: const Key('plan_add_exercise'), onPressed: _add, icon: const Icon(Icons.add), label: const Text('Adicionar exercício')),
        if (widget.existing != null) ...[
          const SizedBox(height: RltSpace.l),
          OutlinedButton.icon(onPressed: _delete, icon: const Icon(Icons.delete_outline), label: const Text('Apagar plano')),
        ],
      ]),
    );
  }
}
