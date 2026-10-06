import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../format.dart';
import '../../step_tracking_controller.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'run_screens.dart';
import 'share_helpers.dart';

/// Passos (prancheta Passos): histórico por dia/semana/mês, meta e estado
/// do sensor. A contagem continua com a tela bloqueada (foreground service,
/// `.claude/rules/activity.md`).
class StepsScreen extends StatefulWidget {
  final AppDependencies deps;
  const StepsScreen({super.key, required this.deps});

  @override
  State<StepsScreen> createState() => _StepsScreenState();
}

class _StepsScreenState extends State<StepsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final deps = widget.deps;
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final goal = deps.profileRepository.load()?.stepsGoal ?? 8000;
    final today = DateTime.now();
    final days = [
      for (var i = _days - 1; i >= 0; i--)
        DateTime(today.year, today.month, today.day).subtract(Duration(days: i)),
    ];
    final counts = [for (final d in days) deps.dayRead.totals(d).steps];
    final maxCount = counts.fold<int>(goal, (m, v) => v > m ? v : m);
    final avg = counts.isEmpty ? 0 : counts.reduce((a, b) => a + b) / counts.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Passos')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        ValueListenableBuilder<StepTrackingStatus>(
          valueListenable: deps.stepTracking.status,
          builder: (context, status, _) => switch (status) {
            StepTrackingStatus.active => Text(
                'Sensor ativo. A contagem continua com a tela bloqueada — fica uma notificação fixa "RLT contando seus passos".',
                style: t.bodyMedium,
              ),
            StepTrackingStatus.permissionDenied => StateCard(
                icon: Icons.directions_walk_outlined,
                title: 'Contagem de passos desligada',
                message: 'Permita "atividade física" para contar passos.',
                actionLabel: 'Permitir',
                tone: StateTone.permission,
                onAction: () => deps.stepTracking.start(),
              ),
            StepTrackingStatus.noSensor => const StateCard(
                icon: Icons.sensors_off_outlined,
                title: 'Sem sensor de passos',
                message: 'Este aparelho não tem o sensor de passos do Android. Passos podem vir de uma pulseira (Conta › Dispositivos).',
                tone: StateTone.permission,
              ),
            _ => Text('Verificando o sensor…', style: t.bodyMedium),
          },
        ),
        const SizedBox(height: RltSpace.l),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 7, label: Text('Semana')),
            ButtonSegment(value: 30, label: Text('Mês')),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: RltSpace.l),
        Text('Média: ${formatNumber(avg)} passos por dia · meta ${formatNumber(goal)}', style: t.bodyMedium),
        const SizedBox(height: RltSpace.m),
        SizedBox(
          height: 160,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < days.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: Tooltip(
                    message: '${ddmm(days[i])}: ${formatNumber(counts[i])} passos',
                    child: Container(
                      height: maxCount == 0 ? 0 : 150 * counts[i] / maxCount,
                      decoration: BoxDecoration(
                        color: counts[i] >= goal ? c.primary : c.secondaryContainer,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                      ),
                    ),
                  ),
                ),
              ),
          ]),
        ),
        const RltSectionHeader('Dias'),
        for (var i = days.length - 1; i >= 0; i--)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(i == days.length - 1 ? 'Hoje' : ddmm(days[i])),
            trailing: Text(formatNumber(counts[i]), style: RltTheme.tabular(t.titleSmall!.copyWith(color: counts[i] >= goal ? c.success : null))),
          ),
      ]),
    );
  }
}

/// "Corrida" ou "Caminhada": o que a pessoa escolheu ao gravar; em rota
/// antiga/importada, deduz pela velocidade (≥ 100 m/min = corrida).
String runTitle(HealthEvent run) {
  final kind = RunKind.fromWireValue(run.payload['activity']);
  if (kind != null) return kind == RunKind.walk ? 'Caminhada' : 'Corrida';
  final meters = (run.payload['distance_meters'] as num?)?.toDouble() ?? 0;
  final seconds = (run.payload['duration_seconds'] as num?)?.toInt() ?? 0;
  return seconds > 0 && meters / (seconds / 60) >= 100 ? 'Corrida' : 'Caminhada';
}

/// Corrida e caminhada (pranchetas CorridaHistorico, CorridaResumo):
/// histórico das rotas gravadas, resumo com parciais e exportar GPX.
class RunsScreen extends StatelessWidget {
  final AppDependencies deps;
  const RunsScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corrida e caminhada')),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) => GuardedView(
          errorTitle: 'Não foi possível carregar o histórico',
          errorMessage: 'Tente de novo.',
          builder: _history,
        ),
      ),
    );
  }

  Widget _history(BuildContext context) {
    final runs = deps.core.queryByType(HealthEventType.gpsTrack).reversed.toList();
    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        RunRecorderCard(deps: deps),
        const RltSectionHeader('Histórico'),
        if (runs.isEmpty)
          const StateCard(
            key: Key('runs_empty'),
            icon: Icons.directions_run,
            title: 'Nenhuma corrida ainda',
            message: 'Toque em iniciar e saia. O RLT grava a rota, o ritmo e as parciais — mesmo com a tela bloqueada.',
          ),
        for (final r in runs)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${runTitle(r)} · ${formatNumber(((r.payload['distance_meters'] as num?) ?? 0) / 1000, decimals: 2)} km'),
            subtitle: Text('${relativeDayTime(localOf(r.occurredAt, r.occurredAtTzOffsetMinutes))} · '
                '${durationLabel(Duration(seconds: ((r.payload['duration_seconds'] as num?) ?? 0).toInt()))} · '
                '${paceLabel((r.payload['average_pace_seconds_per_km'] as num?)?.toDouble())}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RunSummaryScreen(deps: deps, run: r))),
          ),
    ]);
  }
}

class RunSummaryScreen extends StatelessWidget {
  final AppDependencies deps;
  final HealthEvent run;
  const RunSummaryScreen({super.key, required this.deps, required this.run});

  List<RunPointInput> _points() {
    final stored = deps.core.gpsTrackPoints(run.id);
    final segments = segmentsFromPayload(run.payload, stored.length);
    return [
      for (var i = 0; i < stored.length; i++)
        RunPointInput(
          latitude: stored[i].latitude,
          longitude: stored[i].longitude,
          elevationMeters: stored[i].elevationMeters,
          recordedAt: stored[i].recordedAt,
          segment: segments[i],
        ),
    ];
  }

  Future<void> _exportGpx(BuildContext context) async {
    final points = _points();
    if (points.isEmpty) {
      showRltError(context, ArgumentError('esta rota não tem pontos para exportar'));
      return;
    }
    final gpx = exportGpx(points, creator: 'RLT');
    await deps.shareSheet.shareFile(
      Uint8List.fromList(utf8.encode(gpx)),
      fileName: 'rota.gpx',
      mimeType: 'application/gpx+xml',
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final points = _points();
    final summary = points.length < 2 ? null : RunCalculator.summarize(points);
    final day = localOf(run.occurredAt, run.occurredAtTzOffsetMinutes);
    final entry = deps.activityRead.forDay(day).where((a) => a.event.id == run.id).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(entry?.title ?? runTitle(run))),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        RltTwoColumnGrid(children: [
          RltStatTile(
            icon: Icons.route_outlined,
            iconColor: c.primary,
            label: 'Distância',
            value: formatNumber(((run.payload['distance_meters'] as num?) ?? 0) / 1000, decimals: 2),
            unit: 'km',
          ),
          RltStatTile(
            icon: Icons.timer_outlined,
            iconColor: c.primary,
            label: 'Tempo',
            value: durationLabel(Duration(seconds: ((run.payload['duration_seconds'] as num?) ?? 0).toInt())),
          ),
          RltStatTile(
            icon: Icons.speed,
            iconColor: c.primary,
            label: 'Ritmo médio',
            value: paceLabel((run.payload['average_pace_seconds_per_km'] as num?)?.toDouble()),
          ),
          RltStatTile(
            icon: Icons.local_fire_department_outlined,
            iconColor: c.tertiary,
            label: 'Gasto estimado',
            value: entry == null || entry.kcal == 0 ? '—' : formatNumber(entry.kcal),
            unit: entry == null || entry.kcal == 0 ? null : 'kcal',
            caption: summary == null ? null : 'Subida: ${formatNumber(summary.elevationGainMeters)} m',
          ),
        ]),
        if (points.length >= 2) ...[
          const SizedBox(height: RltSpace.l),
          RouteSketch(key: const Key('run_route'), points: points),
          Padding(
            padding: const EdgeInsets.only(top: RltSpace.xs),
            // TODO(frankstein): mapa de fundo offline (MapLibre/osmdroid, ADR-9) — baixar mapa é rede e precisa de decisão de como/onde.
            child: Text('Rota sem mapa de fundo. Verde: início · vermelho: fim.', style: t.bodySmall),
          ),
        ],
        if (summary != null && summary.splits.isNotEmpty) ...[
          const RltSectionHeader('Parciais por km'),
          for (final s in summary.splits)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Km ${s.km}'),
              trailing: Text(paceLabel(s.paceSecondsPerKm), style: RltTheme.tabular(t.titleSmall!)),
            ),
        ],
        const SizedBox(height: RltSpace.l),
        FilledButton.icon(
          key: const Key('run_share'),
          onPressed: () => openRunShare(context, deps, run),
          icon: const Icon(Icons.ios_share),
          label: const Text('Compartilhar'),
        ),
        const SizedBox(height: RltSpace.s),
        OutlinedButton.icon(
          key: const Key('run_gpx'),
          onPressed: () => _exportGpx(context),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Exportar GPX'),
        ),
      ]),
    );
  }
}

/// Outras atividades (prancheta OutrasAtividades): tipo, duração e
/// intensidade → calorias estimadas pelo MET.
class OtherActivityScreen extends StatefulWidget {
  final AppDependencies deps;
  const OtherActivityScreen({super.key, required this.deps});

  @override
  State<OtherActivityScreen> createState() => _OtherActivityScreenState();
}

class _OtherActivityScreenState extends State<OtherActivityScreen> {
  OtherActivity _activity = OtherActivity.swimming;
  ActivityIntensity _intensity = ActivityIntensity.moderate;
  final _minutes = TextEditingController(text: '30');

  @override
  void dispose() {
    _minutes.dispose();
    super.dispose();
  }

  int get _min => (parseNumber(_minutes.text) ?? 0).round();

  void _save() {
    final now = DateTime.now();
    try {
      widget.deps.activityLogger.log(
        activity: _activity,
        intensity: _intensity,
        duration: Duration(minutes: _min),
        occurredAt: now.subtract(Duration(minutes: _min)).toUtc(),
        occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes,
      );
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, '${_activity.label} salva em Exercícios. A meta do dia subiu.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final weights = widget.deps.healthRead.weights(days: 3650);
    final met = _activity.met(_intensity);
    final kcal = weights.isEmpty || _min <= 0 ? null : (met - 1) * weights.first.value * _min / 60;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Outra atividade'),
        actions: [TextButton(key: const Key('other_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
          for (final a in OtherActivity.values)
            ChoiceChip(key: Key('other_${a.code}'), label: Text(a.label), selected: _activity == a, onSelected: (_) => setState(() => _activity = a)),
        ]),
        const SizedBox(height: RltSpace.l),
        TextField(
          key: const Key('other_minutes'),
          controller: _minutes,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Duração', suffixText: 'min'),
          onChanged: (_) => setState(() {}),
        ),
        const RltSectionHeader('Intensidade'),
        SegmentedButton<ActivityIntensity>(
          segments: [for (final i in ActivityIntensity.values) ButtonSegment(value: i, label: Text(i.label))],
          selected: {_intensity},
          onSelectionChanged: (s) => setState(() => _intensity = s.first),
        ),
        const SizedBox(height: RltSpace.l),
        Container(
          padding: const EdgeInsets.all(RltSpace.l),
          decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
          child: Text(
            kcal == null
                ? 'Registre seu peso para estimar as calorias.'
                : 'Gasto estimado: ${formatNumber(kcal)} kcal acima do repouso (MET ${formatNumber(met, decimals: 1)}).',
            style: t.bodyLarge,
          ),
        ),
      ]),
    );
  }
}
