import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import 'share_helpers.dart';

class _LiveSet {
  double loadKg;
  int reps;
  double rpe;
  bool done = false;
  _LiveSet(this.loadKg, this.reps, this.rpe);
}

class _LiveExercise {
  final String id;
  final String name;
  final List<_LiveSet> sets;
  _LiveExercise(this.id, this.name, this.sets);
}

/// Treino ao vivo (prancheta TreinoAoVivo): exercício atual, séries com
/// carga/repetições/RPE editáveis, descanso cronometrado, próximo exercício,
/// finalizar. Grava só ao finalizar — o toque em "Finalizar" é a
/// confirmação.
class LiveWorkoutScreen extends StatefulWidget {
  final AppDependencies deps;
  final WorkoutPlan? plan;
  final Duration restDuration;
  const LiveWorkoutScreen({super.key, required this.deps, this.plan, this.restDuration = const Duration(seconds: 90)});

  @override
  State<LiveWorkoutScreen> createState() => _LiveWorkoutScreenState();
}

class _LiveWorkoutScreenState extends State<LiveWorkoutScreen> {
  final _started = DateTime.now();
  late final List<_LiveExercise> _exercises;
  int _current = 0;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  Duration? _restLeft;

  @override
  void initState() {
    super.initState();
    _exercises = [
      for (final e in widget.plan?.exercises ?? const <PlannedExercise>[])
        _LiveExercise(e.exerciseId, e.exerciseName, [
          for (var i = 0; i < e.targetSets; i++)
            _LiveSet(e.targetLoadKg ?? widget.deps.workoutLogger.personalRecord(e.exerciseId)?.loadKg ?? 0, e.targetReps, 7),
        ]),
    ];
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_started);
        if (_restLeft != null) {
          final left = _restLeft! - const Duration(seconds: 1);
          _restLeft = left <= Duration.zero ? null : left;
        }
      });
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final picked = await Navigator.of(context).push<CatalogExercise>(
      MaterialPageRoute(builder: (_) => const ExerciseLibraryScreen(pickMode: true)),
    );
    if (picked == null) return;
    setState(() {
      _exercises.add(_LiveExercise(picked.id, picked.name, [
        for (var i = 0; i < 3; i++) _LiveSet(widget.deps.workoutLogger.personalRecord(picked.id)?.loadKg ?? 0, 10, 7),
      ]));
      _current = _exercises.length - 1;
    });
  }

  void _completeSet(_LiveSet s) {
    setState(() {
      s.done = true;
      _restLeft = widget.restDuration;
    });
  }

  Future<void> _finish() async {
    final done = <SetEntry>[];
    for (final e in _exercises) {
      var n = 0;
      for (final s in e.sets.where((s) => s.done)) {
        n++;
        done.add(SetEntry(exerciseId: e.id, exerciseName: e.name, setNumber: n, reps: s.reps, loadKg: s.loadKg, rpe: s.rpe));
      }
    }
    if (done.isEmpty) {
      final leave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Nenhuma série concluída'),
          content: const Text('Sair sem salvar o treino?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Continuar treinando')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sair sem salvar')),
          ],
        ),
      );
      if (leave == true && mounted) Navigator.of(context).pop();
      return;
    }
    final deps = widget.deps;
    final duration = DateTime.now().difference(_started);
    try {
      final event = deps.workoutLogger.logSession(
        WorkoutSessionInput(
          planId: widget.plan?.id,
          sets: done,
          duration: duration.inSeconds <= 0 ? const Duration(seconds: 1) : duration,
        ),
        occurredAt: _started.toUtc(),
        occurredAtTzOffsetMinutes: _started.timeZoneOffset.inMinutes,
      );
      deps.notifyDataChanged();
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => WorkoutSummaryScreen(deps: deps, session: event),
      ));
    } catch (e) {
      if (mounted) showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final elapsed = '${two(_elapsed.inMinutes)}:${two(_elapsed.inSeconds % 60)}';
    final title = widget.plan?.name ?? 'Treino livre';
    if (_exercises.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$elapsed de treino', style: t.titleMedium),
              const SizedBox(height: RltSpace.l),
              FilledButton.icon(
                key: const Key('live_add_exercise'),
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar exercício'),
              ),
            ]),
          ),
        ),
      );
    }
    final ex = _exercises[_current];
    final next = _current + 1 < _exercises.length ? _exercises[_current + 1] : null;
    final doneSets = _exercises.fold<int>(0, (s, e) => s + e.sets.where((x) => x.done).length);
    final totalSets = _exercises.fold<int>(0, (s, e) => s + e.sets.length);
    final activeIndex = ex.sets.indexWhere((s) => !s.done);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Fechar', onPressed: _finish, icon: const Icon(Icons.close)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleSmall),
          Text('Exercício ${_current + 1} de ${_exercises.length} · $elapsed de treino', style: t.bodySmall),
        ]),
        actions: [TextButton(key: const Key('live_finish'), onPressed: _finish, child: const Text('Finalizar'))],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(RltSpace.l),
          decoration: BoxDecoration(border: Border(top: BorderSide(color: c.outlineVariant))),
          child: Row(children: [
            Expanded(
              child: next == null
                  ? TextButton.icon(onPressed: _addExercise, icon: const Icon(Icons.add), label: const Text('Adicionar exercício'))
                  : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                      Text('PRÓXIMO EXERCÍCIO', style: t.labelSmall),
                      Text('${next.name} · ${next.sets.length} × ${next.sets.first.reps}', style: t.titleSmall, overflow: TextOverflow.ellipsis),
                    ]),
            ),
            if (_current > 0)
              IconButton(tooltip: 'Exercício anterior', onPressed: () => setState(() => _current--), icon: const Icon(Icons.chevron_left)),
            if (next != null)
              FilledButton.tonalIcon(
                key: const Key('live_next'),
                onPressed: () => setState(() => _current++),
                icon: const Icon(Icons.chevron_right),
                label: const Text('Próximo'),
              ),
          ]),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text(ex.name, style: t.headlineSmall),
        Text('${ex.sets.length} séries · descanso ${widget.restDuration.inSeconds} s', style: t.bodyMedium),
        const SizedBox(height: RltSpace.s),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: totalSets == 0 ? 0 : doneSets / totalSets, minHeight: 6),
        ),
        if (_restLeft != null) ...[
          const SizedBox(height: RltSpace.m),
          Container(
            key: const Key('live_rest'),
            padding: const EdgeInsets.all(RltSpace.m),
            decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(RltRadius.card)),
            child: Row(children: [
              Icon(Icons.timer_outlined, color: c.onSecondaryContainer),
              const SizedBox(width: RltSpace.s),
              Expanded(
                child: Text(
                  'Descanso: ${_restLeft!.inMinutes}:${two(_restLeft!.inSeconds % 60)}',
                  style: RltTheme.tabular(t.titleMedium!.copyWith(color: c.onSecondaryContainer)),
                ),
              ),
              TextButton(onPressed: () => setState(() => _restLeft = null), child: const Text('Pular')),
            ]),
          ),
        ],
        const SizedBox(height: RltSpace.m),
        for (var i = 0; i < ex.sets.length; i++)
          i == activeIndex
              ? _ActiveSetCard(key: Key('live_set_$i'), number: i + 1, set: ex.sets[i], onDone: () => _completeSet(ex.sets[i]))
              : ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: ex.sets[i].done
                      ? CircleAvatar(radius: 14, backgroundColor: c.primary, child: Icon(Icons.check, size: 16, color: c.onPrimary))
                      : CircleAvatar(radius: 14, backgroundColor: c.surfaceContainerHigh, child: Text('${i + 1}', style: t.labelMedium)),
                  title: Text('${formatNumber(ex.sets[i].loadKg, decimals: ex.sets[i].loadKg % 1 == 0 ? 0 : 1)} kg × ${ex.sets[i].reps}',
                      style: RltTheme.tabular(t.bodyLarge!)),
                  trailing: Text(ex.sets[i].done ? 'RPE ${ex.sets[i].rpe.round()}' : '—', style: t.bodyMedium),
                ),
        TextButton.icon(
          onPressed: () => setState(() => ex.sets.add(_LiveSet(ex.sets.last.loadKg, ex.sets.last.reps, 7))),
          icon: const Icon(Icons.add),
          label: const Text('Adicionar série'),
        ),
      ]),
    );
  }
}

class _ActiveSetCard extends StatefulWidget {
  final int number;
  final _LiveSet set;
  final VoidCallback onDone;
  const _ActiveSetCard({super.key, required this.number, required this.set, required this.onDone});

  @override
  State<_ActiveSetCard> createState() => _ActiveSetCardState();
}

class _ActiveSetCardState extends State<_ActiveSetCard> {
  late final _load = TextEditingController(text: formatNumber(widget.set.loadKg, decimals: widget.set.loadKg % 1 == 0 ? 0 : 1));
  late final _reps = TextEditingController(text: '${widget.set.reps}');

  @override
  void dispose() {
    _load.dispose();
    _reps.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: RltSpace.s),
      padding: const EdgeInsets.all(RltSpace.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RltRadius.card),
        border: Border.all(color: c.primary, width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Série ${widget.number}', style: t.titleMedium)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(999)),
            child: Text('Agora', style: t.labelMedium?.copyWith(color: c.onPrimaryContainer)),
          ),
        ]),
        const SizedBox(height: RltSpace.m),
        Row(children: [
          Expanded(
            child: TextField(
              key: const Key('live_load'),
              controller: _load,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Carga', suffixText: 'kg'),
              onChanged: (v) => widget.set.loadKg = parseNumber(v) ?? widget.set.loadKg,
            ),
          ),
          const SizedBox(width: RltSpace.s),
          Expanded(
            child: TextField(
              key: const Key('live_reps'),
              controller: _reps,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Repetições'),
              onChanged: (v) => widget.set.reps = int.tryParse(v) ?? widget.set.reps,
            ),
          ),
          const SizedBox(width: RltSpace.s),
          Expanded(
            child: DropdownButtonFormField<int>(
              initialValue: widget.set.rpe.round(),
              decoration: const InputDecoration(labelText: 'Esforço (RPE)'),
              items: [for (var i = 1; i <= 10; i++) DropdownMenuItem(value: i, child: Text('$i'))],
              onChanged: (v) => widget.set.rpe = (v ?? 7).toDouble(),
            ),
          ),
        ]),
        const SizedBox(height: RltSpace.m),
        FilledButton.icon(
          key: const Key('live_set_done'),
          onPressed: widget.set.reps > 0 ? widget.onDone : null,
          icon: const Icon(Icons.check),
          label: const Text('Série concluída'),
        ),
      ]),
    );
  }
}

/// Resumo do treino salvo: séries, gasto estimado e compartilhar.
class WorkoutSummaryScreen extends StatelessWidget {
  final AppDependencies deps;
  final HealthEvent session;
  const WorkoutSummaryScreen({super.key, required this.deps, required this.session});

  @override
  Widget build(BuildContext context) {
    final seconds = (session.payload['duration_seconds'] as num?)?.toInt();
    final weights = deps.healthRead.weights(days: 3650);
    final kcal = seconds == null || weights.isEmpty
        ? null
        : HealthFormulas.activityKcal(met: strengthTrainingMet, weightKg: weights.first.value, duration: Duration(seconds: seconds));
    final sets = deps.core
        .queryByType(HealthEventType.setLog, from: session.occurredAt, to: session.occurredAt)
        .where((e) => e.payload['session_event_id'] == session.id)
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Treino salvo')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        RltTwoColumnGrid(children: [
          RltStatTile(
            icon: Icons.timer_outlined,
            iconColor: RltColors.of(context).primary,
            label: 'Duração',
            value: seconds == null ? '—' : durationLabel(Duration(seconds: seconds)),
          ),
          RltStatTile(
            icon: Icons.local_fire_department_outlined,
            iconColor: RltColors.of(context).tertiary,
            label: 'Gasto estimado',
            value: kcal == null ? '—' : formatNumber(kcal),
            unit: kcal == null ? null : 'kcal',
            caption: kcal == null ? 'Registre seu peso para estimar' : 'acima do repouso, entra na meta do dia',
          ),
        ]),
        RltSectionHeader('${sets.length} séries'),
        for (final s in sets)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.payload['exercise_name'] as String),
            subtitle: Text('Série ${s.payload['set_number']} · ${formatNumber((s.payload['load_kg'] as num).toDouble(), decimals: 1)} kg × ${s.payload['reps']}'
                '${s.payload['rpe'] == null ? '' : ' · RPE ${(s.payload['rpe'] as num).round()}'}'),
          ),
        const SizedBox(height: RltSpace.l),
        FilledButton.icon(
          key: const Key('workout_share'),
          onPressed: () => openWorkoutShare(context, deps, session),
          icon: const Icon(Icons.ios_share),
          label: const Text('Compartilhar'),
        ),
        const SizedBox(height: RltSpace.s),
        OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Concluir')),
      ]),
    );
  }
}

/// Biblioteca de exercícios: busca e filtro por grupo muscular. Em
/// [pickMode], tocar devolve o exercício escolhido.
class ExerciseLibraryScreen extends StatefulWidget {
  final bool pickMode;
  final AppDependencies? deps;
  const ExerciseLibraryScreen({super.key, this.pickMode = false, this.deps});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  String _q = '';
  MuscleGroup? _group;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final list = exerciseCatalog
        .where((e) => _group == null || e.group == _group)
        .where((e) => _q.isEmpty || e.name.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.pickMode ? 'Escolher exercício' : 'Biblioteca de exercícios')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        TextField(
          key: const Key('library_search'),
          decoration: const InputDecoration(labelText: 'Buscar exercício', prefixIcon: Icon(Icons.search)),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
        const SizedBox(height: RltSpace.m),
        Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
          for (final g in MuscleGroup.values)
            FilterChip(label: Text(g.label), selected: _group == g, onSelected: (v) => setState(() => _group = v ? g : null)),
        ]),
        const SizedBox(height: RltSpace.s),
        for (final e in list)
          ListTile(
            key: Key('library_${e.id}'),
            contentPadding: EdgeInsets.zero,
            title: Text(e.name, style: t.bodyLarge),
            subtitle: Text(e.group.label),
            trailing: widget.pickMode ? const Icon(Icons.add) : const Icon(Icons.chevron_right),
            onTap: widget.pickMode
                ? () => Navigator.of(context).pop(e)
                : (widget.deps == null
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => ExerciseProgressScreen(deps: widget.deps!, exerciseId: e.id, name: e.name),
                        ))),
          ),
      ]),
    );
  }
}

/// Progressão de um exercício: maior carga por dia e recorde.
class ExerciseProgressScreen extends StatelessWidget {
  final AppDependencies deps;
  final String exerciseId;
  final String name;
  const ExerciseProgressScreen({super.key, required this.deps, required this.exerciseId, required this.name});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final sets = deps.core.queryByType(HealthEventType.setLog).where((e) => e.payload['exercise_id'] == exerciseId).toList();
    final best = <DateTime, double>{};
    for (final s in sets) {
      final local = localOf(s.occurredAt, s.occurredAtTzOffsetMinutes);
      final day = DateTime(local.year, local.month, local.day);
      final load = (s.payload['load_kg'] as num).toDouble();
      if (load > (best[day] ?? -1)) best[day] = load;
    }
    final pr = deps.workoutLogger.personalRecord(exerciseId);
    final points = best.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        RltStatTile(
          icon: Icons.emoji_events_outlined,
          iconColor: c.tertiary,
          label: 'Recorde',
          value: pr == null ? '—' : formatNumber(pr.loadKg, decimals: pr.loadKg % 1 == 0 ? 0 : 1),
          unit: pr == null ? null : 'kg × ${pr.reps}',
          caption: pr == null ? 'Ainda sem séries registradas' : ddmm(pr.occurredAt.toLocal()),
        ),
        const RltSectionHeader('Progressão da carga'),
        if (points.length < 2)
          Text('O gráfico aparece a partir do segundo treino com este exercício.', style: t.bodyMedium)
        else
          RltLineChart(
            semanticsLabel: 'Maior carga por treino em $name',
            series: [ChartSeries(label: 'Maior carga (kg)', color: c.primary, points: [for (final p in points) ChartPoint(p.key, p.value)])],
          ),
      ]),
    );
  }
}
