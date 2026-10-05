import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frankstein_activity/activity.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../format.dart';
import '../../run/opentracks.dart';
import '../../run/run_recorder.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'activity_screens.dart';
import 'run_screens.dart';

const openTracksSetupHelp =
    'No OpenTracks, abra Configurações e ligue a "API pública" (iniciar/parar pelo RLT) e a "API de dados" '
    '(mandar a trilha para o painel). As duas vêm desligadas por privacidade.';

/// Gravação feita pelo OpenTracks, acompanhada no RLT (ADR-9 revisão 2):
/// o RLT pede para começar; o OpenTracks grava e devolve a trilha pela API
/// de dados; ao terminar, o RLT salva a rota.
class OpenTracksLiveScreen extends StatefulWidget {
  final AppDependencies deps;
  final RunKind kind;
  const OpenTracksLiveScreen({super.key, required this.deps, required this.kind});

  @override
  State<OpenTracksLiveScreen> createState() => _OpenTracksLiveScreenState();
}

class _OpenTracksLiveScreenState extends State<OpenTracksLiveScreen> {
  /// 6 consultas × 2 s ≈ 12 s esperando o OpenTracks responder.
  static const maxTriesWithoutAnswer = 6;
  Timer? _timer;
  int _triesWithoutAnswer = 0;
  OpenTracksTrack? _track;
  bool _connected = false;
  bool _timedOut = false;
  bool _finishing = false;

  OpenTracksBridge get _ot => widget.deps.openTracks;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final session = await _ot.session();
    if (!mounted) return;
    if (session == null) {
      _triesWithoutAnswer++;
      if (_triesWithoutAnswer >= maxTriesWithoutAnswer && !_timedOut) setState(() => _timedOut = true);
      return;
    }
    List<OpenTracksTrack>? tracks;
    try {
      tracks = await _ot.read();
    } catch (_) {
      tracks = null;
    }
    if (!mounted) return;
    setState(() {
      _connected = true;
      _timedOut = false;
      if (tracks != null && tracks.isNotEmpty) _track = tracks.first;
    });
  }

  Future<void> _retry() async {
    setState(() {
      _timedOut = false;
      _triesWithoutAnswer = 0;
    });
    await _ot.start(widget.kind);
  }

  Future<void> _finish() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar?'),
        content: const Text('O OpenTracks para de gravar. Salvar a rota no RLT?'),
        actions: [
          TextButton(key: const Key('ot_discard'), onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Não salvar')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar')),
          FilledButton(key: const Key('ot_save'), onPressed: () => Navigator.pop(context, 'save'), child: const Text('Salvar')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _finishing = true);
    _timer?.cancel();
    await _ot.stop();
    if (choice == 'discard') {
      await _ot.clear();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    // O OpenTracks fecha a trilha; lê de novo para pegar os últimos pontos.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    List<OpenTracksTrack>? tracks;
    try {
      tracks = await _ot.read();
    } catch (_) {}
    final track = (tracks != null && tracks.isNotEmpty) ? tracks.first : _track;
    await _ot.clear();
    if (!mounted) return;
    final event = track == null
        ? null
        : saveOpenTracksTrack(widget.deps.core, track, fallbackTzOffsetMinutes: widget.deps.tzOffsetMinutesNow());
    if (event == null) {
      showRltError(context, 'Não deu para trazer a rota (poucos pontos com GPS bom ou já estava no RLT). Ela continua no OpenTracks.');
      Navigator.of(context).pop();
      return;
    }
    widget.deps.notifyDataChanged();
    await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => RunSummaryScreen(deps: widget.deps, run: event)));
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final points = _track?.points ?? const <RunPointInput>[];
    final moving = RunCalculator.totalDuration(RunCalculator.filterSpeedOutliers(RunCalculator.filterByAccuracy(points)));
    final stats = LiveRunStats.from(points, moving);
    return Scaffold(
      appBar: AppBar(
        title: Text(runKindLabel(widget.kind).toUpperCase()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: RltSpace.l),
            child: Center(
              child: Text(_connected ? 'via OpenTracks' : 'Abrindo o OpenTracks…',
                  key: const Key('ot_status'), style: t.labelLarge?.copyWith(color: _connected ? c.success : c.onSurfaceVariant)),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        if (_timedOut)
          StateCard(
            key: const Key('ot_no_answer'),
            icon: Icons.link_off,
            title: 'O OpenTracks não respondeu',
            message: openTracksSetupHelp,
            tone: StateTone.permission,
            actionLabel: 'Tentar de novo',
            onAction: _retry,
          ),
        const SizedBox(height: RltSpace.l),
        Text('TEMPO EM MOVIMENTO', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant, letterSpacing: 0.8), textAlign: TextAlign.center),
        Text(clockLabel(moving), key: const Key('ot_time'), style: RltTheme.tabular(t.displayMedium!), textAlign: TextAlign.center),
        const SizedBox(height: RltSpace.m),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: formatNumber(stats.distanceMeters / 1000, decimals: 2), style: RltTheme.tabular(t.displaySmall!)),
            TextSpan(text: ' km', style: t.titleMedium),
          ]),
          key: const Key('ot_distance'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RltSpace.xl),
        Row(children: [
          Expanded(
            child: Column(children: [
              Text(paceLabel(stats.currentPaceSecondsPerKm), style: RltTheme.tabular(t.headlineMedium!)),
              Text('ritmo atual /km', style: t.bodySmall),
            ]),
          ),
          Expanded(
            child: Column(children: [
              Text(paceLabel(stats.averagePaceSecondsPerKm), style: RltTheme.tabular(t.headlineMedium!)),
              Text('ritmo médio /km', style: t.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: RltSpace.xl),
        FilledButton.icon(
          key: const Key('ot_finish'),
          onPressed: _finishing ? null : _finish,
          icon: const Icon(Icons.stop),
          label: const Text('Terminar'),
        ),
        const SizedBox(height: RltSpace.l),
        Text(
          'Quem grava é o OpenTracks: pausar, tela bloqueada e GPS ficam com ele. O RLT mostra os números e salva a rota no fim.',
          style: t.bodySmall,
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}

/// A pessoa escolheu "mostrar no painel" no OpenTracks e o RLT recebeu a
/// trilha: pergunta antes de trazer (nada é gravado sem confirmar).
Future<void> offerOpenTracksImport(BuildContext context, AppDependencies deps) async {
  final session = await deps.openTracks.session();
  if (session == null || session.recording || !context.mounted) return;
  List<OpenTracksTrack> tracks;
  try {
    tracks = await deps.openTracks.read() ?? const [];
  } catch (_) {
    await deps.openTracks.clear();
    return;
  }
  if (!context.mounted) return;
  final usable = [for (final t in tracks) if (t.points.length >= 2) t];
  if (usable.isEmpty) {
    await deps.openTracks.clear();
    return;
  }
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      key: const Key('ot_import'),
      title: const Text('Trazer do OpenTracks?'),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final t in usable)
          Builder(builder: (context) {
            final km = RunCalculator.totalDistanceMeters(t.points) / 1000;
            final first = t.points.first.recordedAt.add(Duration(minutes: t.tzOffsetMinutes ?? deps.tzOffsetMinutesNow()));
            final label = switch (t.kind) {
              RunKind.run => 'Corrida',
              RunKind.walk => 'Caminhada',
              null => t.name?.isNotEmpty == true ? t.name! : 'Atividade',
            };
            return Text('$label · ${formatNumber(km, decimals: 2)} km · ${ddmm(first)} ${hhmm(first)}');
          }),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Agora não')),
        FilledButton(key: const Key('ot_import_yes'), onPressed: () => Navigator.pop(context, true), child: const Text('Trazer')),
      ],
    ),
  );
  await deps.openTracks.clear();
  if (ok != true || !context.mounted) return;
  var saved = 0;
  for (final t in usable) {
    if (saveOpenTracksTrack(deps.core, t, fallbackTzOffsetMinutes: deps.tzOffsetMinutesNow()) != null) saved++;
  }
  deps.notifyDataChanged();
  if (!context.mounted) return;
  showRltSaved(
    context,
    saved == 0 ? 'Essa rota já estava no RLT.' : '${saved == 1 ? 'Rota trazida' : '$saved rotas trazidas'} para Exercícios › Corrida e caminhada.',
  );
}
