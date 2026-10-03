import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/run/run_recorder.dart';
import 'package:frankstein/screens/exercise/activity_screens.dart';
import 'package:frankstein/screens/exercise/run_screens.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

const _metersPerDegree = 6371000.0 * 3.141592653589793 / 180;

void main() {
  setUpAll(loadFigtree);

  late FakeRunRecorder rec;
  late AppDependencies deps;
  final start = DateTime.utc(2026, 10, 3, 9, 0);

  setUp(() {
    rec = FakeRunRecorder();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      runRecorder: rec,
    );
  });
  tearDown(() => deps.close());

  /// Anda [meters] para o norte em [seconds], um ponto a cada 5 s.
  void walk({required double fromMeters, required double meters, required int fromSecond, required int seconds}) {
    final steps = seconds ~/ 5;
    for (var i = 0; i <= steps; i++) {
      final m = fromMeters + meters * i / steps;
      rec.addPoint(-23 + m / _metersPerDegree, -46, start.add(Duration(seconds: fromSecond + i * 5)));
    }
  }

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  test('ritmo ao vivo: médio pelo tempo ativo, atual pelos últimos 30 s', () {
    rec.state = RunRecorderState.recording;
    walk(fromMeters: 0, meters: 1000, fromSecond: 0, seconds: 360); // 6:00/km
    walk(fromMeters: 1000, meters: 100, fromSecond: 365, seconds: 30); // 5:00/km no fim
    final s = LiveRunStats.from(rec.recorded, const Duration(seconds: 395));
    expect(s.distanceMeters, closeTo(1100, 2));
    expect(s.averagePaceSecondsPerKm, closeTo(359, 3));
    expect(s.currentPaceSecondsPerKm, closeTo(300, 5));
    expect(clockLabel(const Duration(minutes: 24, seconds: 18)), '24:18');
    expect(clockLabel(const Duration(hours: 1, minutes: 2, seconds: 3)), '1:02:03');
  });

  testWidgets('iniciar: sem permissão pede; depois inicia e mostra a tela ao vivo', (tester) async {
    rec.permission = false;
    await pump(tester, RunStartScreen(deps: deps));
    expect(find.byKey(const Key('run_no_permission')), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('run_start'))).onPressed, isNull);
    await tester.tap(find.text('Permitir'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('run_ready')), findsOneWidget);
    await tester.tap(find.text('Caminhada'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('run_start')));
    await tester.pump();
    await tester.pump();
    expect(rec.state, RunRecorderState.recording);
    expect(rec.kind, RunKind.walk);
    expect(find.text('CAMINHADA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // fecha a tela e o relógio
  });

  testWidgets('ao vivo: distância e tempo, pausa abre trecho novo, terminar salva e mostra o resumo', (tester) async {
    await rec.start(RunKind.run, autoPause: true);
    walk(fromMeters: 0, meters: 1200, fromSecond: 0, seconds: 420);
    rec.active = const Duration(seconds: 420);
    await pump(tester, LiveRunScreen(deps: deps));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('07:00'), findsOneWidget);
    expect(find.textContaining('1,20'), findsOneWidget);
    expect(find.text('GPS bom'), findsOneWidget);

    await tester.tap(find.byKey(const Key('run_pause')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Retomar'), findsOneWidget);
    walk(fromMeters: 1200, meters: 500, fromSecond: 600, seconds: 60); // pausado: não grava
    await tester.tap(find.byKey(const Key('run_pause')));
    await tester.pump();
    await tester.pump();
    walk(fromMeters: 1300, meters: 400, fromSecond: 700, seconds: 140);

    await tester.tap(find.byKey(const Key('run_finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run_save')));
    await tester.pumpAndSettle();

    final run = deps.core.queryByType(HealthEventType.gpsTrack).single;
    expect(run.payload['activity'], 'run');
    expect(run.payload['segment_start_indices'], hasLength(2));
    expect((run.payload['distance_meters'] as num).toDouble(), closeTo(1600, 5)); // os 100 m andados na pausa não contam
    expect(run.payload['duration_seconds'], 560);
    expect(rec.discarded, isTrue);
    expect(find.text('Corrida'), findsWidgets);
    expect(find.byKey(const Key('run_route')), findsOneWidget);
  });

  testWidgets('gravação interrompida aparece no histórico e pode ser salva', (tester) async {
    await rec.start(RunKind.walk, autoPause: false);
    walk(fromMeters: 0, meters: 600, fromSecond: 0, seconds: 480);
    rec.state = RunRecorderState.interrupted;
    await pump(tester, RunsScreen(deps: deps));
    expect(find.byKey(const Key('run_interrupted')), findsOneWidget);
    expect(find.text('Caminhada interrompida'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    final run = deps.core.queryByType(HealthEventType.gpsTrack).single;
    expect(run.payload['activity'], 'walk');
    expect(rec.discarded, isTrue);
    expect(find.byKey(const Key('run_new')), findsOneWidget);
    expect(find.textContaining('Caminhada · 0,60 km'), findsOneWidget);
  });

  testWidgets('terminar e descartar não grava nada', (tester) async {
    await rec.start(RunKind.run, autoPause: true);
    walk(fromMeters: 0, meters: 300, fromSecond: 0, seconds: 120);
    await pump(tester, Scaffold(body: Builder(builder: (context) {
      return TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LiveRunScreen(deps: deps))),
        child: const Text('abrir'),
      );
    })));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run_finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('run_discard')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.gpsTrack), isEmpty);
    expect(rec.discarded, isTrue);
    expect(find.text('abrir'), findsOneWidget);
  });
}
