import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

import '../../app_dependencies.dart';
import '../../data/activity_read_model.dart';
import '../../format.dart';
import '../../run/run_recorder.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import 'activity_screens.dart';
import 'opentracks_screens.dart';

String runKindLabel(RunKind k) => k == RunKind.walk ? 'Caminhada' : 'Corrida';

/// "mm:ss" ou "h:mm:ss".
String clockLabel(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Salva a gravação (do arquivo do gravador) como `gps_track` e apaga o
/// arquivo. Devolve o evento, ou `null` se não houve pontos suficientes.
Future<HealthEvent?> saveRecordedRun(AppDependencies deps, RunKind kind) async {
  final points = await deps.runRecorder.points();
  try {
    final event = RunLogger(core: deps.core).logRun(
      points,
      occurredAtTzOffsetMinutes: deps.tzOffsetMinutesNow(),
      kind: kind,
    );
    await deps.runRecorder.discard();
    deps.notifyDataChanged();
    return event;
  } on InsufficientRunDataException {
    return null;
  }
}

/// Corrida e caminhada — iniciar (pranchetas CorridaIniciar e
/// CorridaEstados): tipo, permissão de localização, GPS do celular e pausa
/// automática.
class RunStartScreen extends StatefulWidget {
  final AppDependencies deps;
  const RunStartScreen({super.key, required this.deps});

  @override
  State<RunStartScreen> createState() => _RunStartScreenState();
}

class _RunStartScreenState extends State<RunStartScreen> {
  RunKind _kind = RunKind.run;
  late bool _autoPause = widget.deps.profileRepository.getSetting('run_auto_pause') != '0';
  bool? _permission;
  bool? _gps;
  bool _starting = false;

  /// OpenTracks instalado: quem grava é ele (ADR-9 revisão 2). O gravador
  /// do RLT é a alternativa para quando ele não está instalado.
  bool _openTracksInstalled = false;

  RunRecorder get _rec => widget.deps.runRecorder;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final p = await _rec.hasPermission();
    final g = await _rec.gpsEnabled();
    final ot = await widget.deps.openTracks.installed();
    if (mounted) {
      setState(() {
        _permission = p;
        _gps = g;
        _openTracksInstalled = ot;
      });
    }
  }

  bool get _viaOpenTracks => _openTracksInstalled;

  Future<void> _start() async {
    setState(() => _starting = true);
    widget.deps.profileRepository.setSetting('run_auto_pause', _autoPause ? '1' : '0');
    if (_viaOpenTracks) {
      await widget.deps.openTracks.start(_kind);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OpenTracksLiveScreen(deps: widget.deps, kind: _kind)),
      );
      return;
    }
    try {
      await _rec.start(_kind, autoPause: _autoPause);
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => LiveRunScreen(deps: widget.deps)));
    } catch (e) {
      if (mounted) {
        setState(() => _starting = false);
        showRltError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final ready = _viaOpenTracks || (_permission == true && _gps == true);
    return Scaffold(
      appBar: AppBar(title: const Text('Corrida e caminhada')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        SegmentedButton<RunKind>(
          segments: const [
            ButtonSegment(value: RunKind.run, label: Text('Corrida'), icon: Icon(Icons.directions_run)),
            ButtonSegment(value: RunKind.walk, label: Text('Caminhada'), icon: Icon(Icons.directions_walk)),
          ],
          selected: {_kind},
          onSelectionChanged: (v) => setState(() => _kind = v.first),
        ),
        const SizedBox(height: RltSpace.l),
        if (_viaOpenTracks)
          Card(
            key: const Key('run_opentracks_info'),
            child: ListTile(
              leading: const Icon(Icons.route_outlined),
              title: const Text('O OpenTracks grava; o RLT acompanha e salva no fim'),
              subtitle: const Text(openTracksSetupHelp),
            ),
          )
        else if (_permission == null)
          const LoadingCard()
        else if (_permission == false)
          StateCard(
            key: const Key('run_no_permission'),
            icon: Icons.location_off_outlined,
            title: 'Sem permissão de localização',
            message: 'Sem ela não dá para medir distância e ritmo. O RLT usa a localização só enquanto grava, e a rota fica no celular.',
            tone: StateTone.permission,
            actionLabel: 'Permitir',
            onAction: () async {
              await _rec.requestPermission();
              await _check();
            },
          )
        else if (_gps == false)
          StateCard(
            key: const Key('run_gps_off'),
            icon: Icons.gps_off,
            title: 'GPS do celular desligado',
            message: 'Ligue a localização nas configurações rápidas do Android e toque em "Verificar de novo".',
            tone: StateTone.permission,
            actionLabel: 'Verificar de novo',
            onAction: _check,
          )
        else
          Card(
            child: ListTile(
              key: const Key('run_ready'),
              leading: Icon(Icons.gps_fixed, color: RltColors.of(context).success),
              title: const Text('GPS pronto'),
              subtitle: const Text('O sinal aparece ao iniciar. Em lugar aberto ele fica bom mais rápido.'),
            ),
          ),
        const SizedBox(height: RltSpace.m),
        if (!_viaOpenTracks) SwitchListTile(
          key: const Key('run_auto_pause'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Pausa automática'),
          subtitle: const Text('Pausa quando você para'),
          value: _autoPause,
          onChanged: (v) => setState(() => _autoPause = v),
        ),
        const SizedBox(height: RltSpace.l),
        FilledButton.icon(
          key: const Key('run_start'),
          onPressed: ready && !_starting ? _start : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Iniciar'),
        ),
        const SizedBox(height: RltSpace.s),
        Text('Continua gravando com a tela bloqueada. Aparece uma notificação fixa enquanto grava.', style: t.bodySmall),
      ]),
    );
  }
}

/// Ao vivo (prancheta CorridaAoVivo): tempo, distância, ritmo atual e
/// médio, sinal do GPS, pausar/retomar e terminar.
class LiveRunScreen extends StatefulWidget {
  final AppDependencies deps;
  const LiveRunScreen({super.key, required this.deps});

  @override
  State<LiveRunScreen> createState() => _LiveRunScreenState();
}

class _LiveRunScreenState extends State<LiveRunScreen> {
  Timer? _timer;
  RunRecorderStatus? _status;
  final List<RunPointInput> _points = [];
  LiveRunStats _stats = const LiveRunStats(distanceMeters: 0);
  bool _finishing = false;

  RunRecorder get _rec => widget.deps.runRecorder;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    final status = await _rec.status();
    final fresh = await _rec.points(from: _points.length);
    if (!mounted) return;
    _points.addAll(fresh);
    setState(() {
      _status = status;
      _stats = LiveRunStats.from(_points, status.active);
    });
  }

  Future<void> _finish() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terminar?'),
        content: const Text('Salvar a rota, o tempo e as parciais?'),
        actions: [
          TextButton(key: const Key('run_discard'), onPressed: () => Navigator.pop(context, 'discard'), child: const Text('Descartar')),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Continuar')),
          FilledButton(key: const Key('run_save'), onPressed: () => Navigator.pop(context, 'save'), child: const Text('Salvar')),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    setState(() => _finishing = true);
    _timer?.cancel();
    final kind = _status?.kind ?? RunKind.run;
    await _rec.finish();
    if (choice == 'discard') {
      await _rec.discard();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final event = await saveRecordedRun(widget.deps, kind);
    if (!mounted) return;
    if (event == null) {
      await _rec.discard();
      if (!mounted) return;
      showRltError(context, 'Poucos pontos com GPS bom para formar uma rota — nada foi salvo.');
      Navigator.of(context).pop();
      return;
    }
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => RunSummaryScreen(deps: widget.deps, run: event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final s = _status;
    final paused = s?.state == RunRecorderState.paused || s?.state == RunRecorderState.autoPaused;
    final gpsLabel = s == null || s.lastAccuracyMeters == null
        ? 'Procurando sinal…'
        : (s.gpsGood ? 'GPS bom' : 'GPS fraco (${formatNumber(s.lastAccuracyMeters!)} m)');
    return Scaffold(
      appBar: AppBar(
        title: Text(runKindLabel(s?.kind ?? RunKind.run).toUpperCase()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: RltSpace.l),
            child: Center(
              child: Text(gpsLabel,
                  key: const Key('run_gps_label'),
                  style: t.labelLarge?.copyWith(color: s?.gpsGood == true ? c.success : c.onSurfaceVariant)),
            ),
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        if (s?.state == RunRecorderState.noPermission || s?.state == RunRecorderState.noGps)
          const StateCard(
            icon: Icons.gps_off,
            title: 'Sem GPS',
            message: 'O Android não liberou a localização. Volte, confira a permissão e o GPS e inicie de novo.',
            tone: StateTone.permission,
          ),
        if (s?.state == RunRecorderState.autoPaused)
          Card(
            key: const Key('run_auto_paused'),
            color: c.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(RltSpace.m),
              child: Text('Pausa automática — você parou', style: t.titleSmall?.copyWith(color: c.onTertiaryContainer)),
            ),
          ),
        const SizedBox(height: RltSpace.l),
        Text('TEMPO', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant, letterSpacing: 0.8), textAlign: TextAlign.center),
        Text(clockLabel(s?.active ?? Duration.zero),
            key: const Key('run_time'), style: RltTheme.tabular(t.displayMedium!), textAlign: TextAlign.center),
        const SizedBox(height: RltSpace.m),
        Text.rich(
          TextSpan(children: [
            TextSpan(text: formatNumber(_stats.distanceMeters / 1000, decimals: 2), style: RltTheme.tabular(t.displaySmall!)),
            TextSpan(text: ' km', style: t.titleMedium),
          ]),
          key: const Key('run_distance'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: RltSpace.xl),
        Row(children: [
          Expanded(child: _Metric(value: paceLabel(_stats.currentPaceSecondsPerKm), label: 'ritmo atual /km')),
          Expanded(child: _Metric(value: paceLabel(_stats.averagePaceSecondsPerKm), label: 'ritmo médio /km')),
        ]),
        const SizedBox(height: RltSpace.xl),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              key: const Key('run_pause'),
              onPressed: _finishing || s == null
                  ? null
                  : () async {
                      paused ? await _rec.resume() : await _rec.pause();
                      await _tick();
                    },
              icon: Icon(paused ? Icons.play_arrow : Icons.pause),
              label: Text(paused ? 'Retomar' : 'Pausar'),
            ),
          ),
          const SizedBox(width: RltSpace.m),
          Expanded(
            child: FilledButton.icon(
              key: const Key('run_finish'),
              onPressed: _finishing ? null : _finish,
              icon: const Icon(Icons.stop),
              label: const Text('Terminar'),
            ),
          ),
        ]),
        const SizedBox(height: RltSpace.l),
        Text('Continua contando com a tela bloqueada. Pode sair desta tela: a gravação segue até você terminar.',
            style: t.bodySmall, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Text(value, style: RltTheme.tabular(t.headlineMedium!)),
      Text(label, style: t.bodySmall?.copyWith(color: RltColors.of(context).onSurfaceVariant)),
    ]);
  }
}

/// Topo do histórico de corridas: iniciar, voltar para a gravação em
/// andamento, ou salvar/descartar uma gravação interrompida.
class RunRecorderCard extends StatefulWidget {
  final AppDependencies deps;
  const RunRecorderCard({super.key, required this.deps});

  @override
  State<RunRecorderCard> createState() => _RunRecorderCardState();
}

class _RunRecorderCardState extends State<RunRecorderCard> {
  late Future<RunRecorderStatus> _status = widget.deps.runRecorder.status();

  void _refresh() {
    final next = widget.deps.runRecorder.status();
    setState(() {
      _status = next;
    });
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RunRecorderStatus>(
      future: _status,
      builder: (context, snap) {
        final s = snap.data;
        if (s == null) return const SizedBox(height: 48);
        switch (s.state) {
          case RunRecorderState.unsupported:
            return const StateCard(
              icon: Icons.directions_run_outlined,
              title: 'Gravação pelo GPS',
              message: 'Disponível no celular Android.',
            );
          case RunRecorderState.interrupted:
            return StateCard(
              key: const Key('run_interrupted'),
              icon: Icons.restore,
              title: '${runKindLabel(s.kind)} interrompida',
              message: 'O app fechou durante a gravação. ${s.points} pontos estão guardados.',
              actionLabel: 'Salvar',
              actionIcon: Icons.save_outlined,
              onAction: () async {
                final e = await saveRecordedRun(widget.deps, s.kind);
                if (!context.mounted) return;
                if (e == null) {
                  showRltError(context, 'Poucos pontos com GPS bom para formar uma rota.');
                } else {
                  showRltSaved(context, '${runKindLabel(s.kind)} salva.');
                }
                _refresh();
              },
            );
          case RunRecorderState.recording:
          case RunRecorderState.paused:
          case RunRecorderState.autoPaused:
            return StateCard(
              key: const Key('run_in_progress'),
              icon: Icons.fiber_manual_record,
              title: '${runKindLabel(s.kind)} em andamento',
              message: 'Tempo: ${clockLabel(s.active)}',
              actionLabel: 'Abrir',
              onAction: () => _push(LiveRunScreen(deps: widget.deps)),
            );
          default:
            return FilledButton.icon(
              key: const Key('run_new'),
              onPressed: () => _push(RunStartScreen(deps: widget.deps)),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar corrida ou caminhada'),
            );
        }
      },
    );
  }
}

/// Desenho da rota sem mapa de fundo (mapa offline ainda não existe; baixar
/// mapa é rede e precisa de ação explícita — ADR-9 revisão 1).
class RouteSketch extends StatelessWidget {
  final List<RunPointInput> points;
  const RouteSketch({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Container(
      height: 180,
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(RltRadius.card)),
      child: CustomPaint(painter: _RoutePainter(points, c.primary, c.success, c.error), size: Size.infinite),
    );
  }
}

class _RoutePainter extends CustomPainter {
  final List<RunPointInput> points;
  final Color line;
  final Color start;
  final Color end;
  _RoutePainter(this.points, this.line, this.start, this.end);

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    var minLat = points.first.latitude, maxLat = minLat, minLon = points.first.longitude, maxLon = minLon;
    for (final p in points) {
      minLat = p.latitude < minLat ? p.latitude : minLat;
      maxLat = p.latitude > maxLat ? p.latitude : maxLat;
      minLon = p.longitude < minLon ? p.longitude : minLon;
      maxLon = p.longitude > maxLon ? p.longitude : maxLon;
    }
    // Longitude encolhe com a latitude: corrige para o desenho não esticar.
    final cosLat = _cos((minLat + maxLat) / 2);
    final w = (maxLon - minLon) * cosLat;
    final h = maxLat - minLat;
    const pad = 16.0;
    final scale = (w == 0 && h == 0)
        ? 1.0
        : [if (w > 0) (size.width - 2 * pad) / w, if (h > 0) (size.height - 2 * pad) / h].reduce((a, b) => a < b ? a : b);
    final ox = (size.width - w * scale) / 2;
    final oy = (size.height - h * scale) / 2;
    Offset at(RunPointInput p) => Offset(ox + (p.longitude - minLon) * cosLat * scale, oy + (maxLat - p.latitude) * scale);
    final paint = Paint()
      ..color = line
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    var path = Path()..moveTo(at(points.first).dx, at(points.first).dy);
    for (var i = 1; i < points.length; i++) {
      final o = at(points[i]);
      if (points[i].segment != points[i - 1].segment) {
        canvas.drawPath(path, paint);
        path = Path()..moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(at(points.first), 6, Paint()..color = start);
    canvas.drawCircle(at(points.last), 6, Paint()..color = end);
  }

  static double _cos(double degrees) => math.cos(degrees * math.pi / 180);

  @override
  bool shouldRepaint(_RoutePainter old) => old.points != points;
}
