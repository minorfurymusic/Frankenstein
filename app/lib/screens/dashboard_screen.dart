import 'package:flutter/material.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_share/share.dart';

import '../app_dependencies.dart';
import '../step_tracking_controller.dart';
import 'log_meal_screen.dart';
import 'log_workout_screen.dart';
import 'share_preview_screen.dart';

/// Resumo do dia — chama `get_daily_summary` direto no `ToolRegistry`
/// (não passa pelo roteador/chat: é uma tela que carrega dado ao abrir,
/// não uma conversa). `docs/ARQUITETURA.md:81-82`. Também oferece
/// compartilhar o treino/corrida mais recente, quando existir um
/// (`.claude/rules/share.md`).
///
/// **Layout final do dashboard mínimo** (ciclo pós-primeiro teste em
/// device real): 5 cards. Água/Refeições/Treinos têm "+" — cada um monta
/// o mesmo texto de comando que o chat aceita e manda pro mesmo
/// `BrainPipeline.handle`, reaproveitando a confirmação já existente
/// (`log_meal_screen.dart`, `log_workout_screen.dart`, diálogo de água
/// inline abaixo). Passos usa o sensor Android real
/// (`step_tracking_controller.dart`, `StepCounterService.kt`) — o card
/// reflete `StepTrackingStatus` ao vivo (permissão negada, sem sensor,
/// plataforma sem suporte ainda, ou ativo), sem ação manual (não faz
/// sentido "adicionar" passo). Corridas continua sem ação — GPS real é o
/// próximo item de plataforma nativa, card já no formato definitivo.
class DashboardScreen extends StatefulWidget {
  final AppDependencies dependencies;
  const DashboardScreen({super.key, required this.dependencies});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final date = '${now.year}-$month-$day';

    final result = await widget.dependencies.registry.execute('get_daily_summary', {'date': date});
    if (!mounted) return;
    setState(() {
      if (result.success) {
        _summary = result.data;
      } else {
        _error = result.error;
      }
    });
  }

  void _shareLatestWorkout() {
    final core = widget.dependencies.core;
    final latest = core.queryByType(HealthEventType.workoutSession).lastOrNull;
    if (latest == null) return;

    final card = buildWorkoutShareCard(latest);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SharePreviewScreen(
        title: 'Compartilhar treino',
        cardContent: WorkoutCardVisual(data: card),
        suggestedFileName: 'treino.png',
        shareText: 'Meu treino de hoje — Frankstein',
        shareSheet: widget.dependencies.shareSheet,
        imageCapturer: widget.dependencies.imageCapturer,
      ),
    ));
  }

  void _shareLatestRun() {
    final core = widget.dependencies.core;
    final latest = core.queryByType(HealthEventType.gpsTrack).lastOrNull;
    if (latest == null) return;

    final points = core.gpsTrackPoints(latest.id);
    final card = buildRunShareCard(latest, points);
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SharePreviewScreen(
        title: 'Compartilhar corrida',
        cardContent: RunCardVisual(data: card),
        suggestedFileName: 'corrida.png',
        shareText: 'Minha corrida — Frankstein',
        shareSheet: widget.dependencies.shareSheet,
        imageCapturer: widget.dependencies.imageCapturer,
      ),
    ));
  }

  Future<void> _openLogMeal() async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LogMealScreen(dependencies: widget.dependencies)),
    );
    if (logged == true) _load();
  }

  Future<void> _openLogWorkout() async {
    final logged = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => LogWorkoutScreen(dependencies: widget.dependencies)),
    );
    if (logged == true) _load();
  }

  Future<void> _logWater(double amountMl) async {
    final result = await widget.dependencies.pipeline.handle('registrar água ${amountMl}ml');
    if (!mounted) return;
    if (result.outcome == PipelineOutcome.executed && result.toolResult!.success) {
      _load();
    }
  }

  Future<void> _openQuickWaterDialog() async {
    final customController = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Registrar água'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              children: [200, 300, 500].map((ml) {
                return OutlinedButton(
                  key: Key('quick_water_${ml}ml'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    _logWater(ml.toDouble());
                  },
                  child: Text('+${ml}ml'),
                );
              }).toList(),
            ),
            TextField(
              key: const Key('log_water_custom_field'),
              controller: customController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Outra quantidade (ml)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('log_water_custom_confirm'),
            onPressed: () {
              final amount = double.tryParse(customController.text.trim());
              Navigator.of(dialogContext).pop();
              if (amount != null && amount > 0) _logWater(amount);
            },
            child: const Text('Registrar'),
          ),
        ],
      ),
    );
  }

  String? _stepsSubtitle(StepTrackingStatus status) {
    switch (status) {
      case StepTrackingStatus.unknown:
        return 'verificando sensor...';
      case StepTrackingStatus.unsupportedPlatform:
        return 'sem sensor real ainda (só Android por enquanto)';
      case StepTrackingStatus.noSensor:
        return 'este aparelho não tem sensor de passos';
      case StepTrackingStatus.permissionDenied:
        return 'permissão negada — sem ela, passos não são contados';
      case StepTrackingStatus.active:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(child: Text('Não deu pra carregar o resumo: $error'));
    }
    final summary = _summary;
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final steps = summary['steps'] as Map<String, dynamic>;
    final meals = summary['meals'] as Map<String, dynamic>;
    final water = summary['water'] as Map<String, dynamic>;
    final workouts = summary['workouts'] as Map<String, dynamic>;
    final runs = summary['runs'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('dashboard_list'),
        padding: const EdgeInsets.all(16),
        children: [
          ValueListenableBuilder<StepTrackingStatus>(
            valueListenable: widget.dependencies.stepTracking.status,
            builder: (context, status, _) {
              return Column(
                children: [
                  _SummaryCard(
                    key: const Key('dashboard_steps'),
                    label: 'Passos',
                    value: '${steps['total']}',
                    subtitle: _stepsSubtitle(status),
                  ),
                  if (status == StepTrackingStatus.permissionDenied)
                    TextButton(
                      key: const Key('retry_step_permission'),
                      onPressed: () => widget.dependencies.stepTracking.start(),
                      child: const Text('Tentar de novo'),
                    ),
                ],
              );
            },
          ),
          _SummaryCard(
            key: const Key('dashboard_water'),
            label: 'Água',
            value: '${water['total_amount_ml']} ml',
            onAdd: _openQuickWaterDialog,
            addKey: const Key('dashboard_add_water'),
          ),
          _SummaryCard(
            key: const Key('dashboard_meals'),
            label: 'Refeições',
            value: '${meals['count']} (${meals['total_energy_kcal']} kcal)',
            onAdd: _openLogMeal,
            addKey: const Key('dashboard_add_meal'),
          ),
          _SummaryCard(
            key: const Key('dashboard_workouts'),
            label: 'Treinos',
            value: '${workouts['count']} (${workouts['total_sets']} séries)',
            onAdd: _openLogWorkout,
            addKey: const Key('dashboard_add_workout'),
          ),
          if ((workouts['count'] as int) > 0)
            TextButton.icon(
              key: const Key('share_latest_workout'),
              onPressed: _shareLatestWorkout,
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar último treino'),
            ),
          _SummaryCard(
            key: const Key('dashboard_runs'),
            label: 'Corridas',
            value: '${runs['count']} (${runs['total_distance_meters']} m)',
            subtitle: 'requer GPS real (não disponível ainda)',
          ),
          if ((runs['count'] as int) > 0)
            TextButton.icon(
              key: const Key('share_latest_run'),
              onPressed: _shareLatestRun,
              icon: const Icon(Icons.share),
              label: const Text('Compartilhar última corrida'),
            ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final VoidCallback? onAdd;
  final Key? addKey;
  const _SummaryCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    this.onAdd,
    this.addKey,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        subtitle: subtitle == null ? null : Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value),
            if (onAdd != null)
              IconButton(
                key: addKey,
                icon: const Icon(Icons.add),
                onPressed: onAdd,
              ),
          ],
        ),
      ),
    );
  }
}
