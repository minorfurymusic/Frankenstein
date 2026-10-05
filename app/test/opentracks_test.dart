import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/run/opentracks.dart';
import 'package:frankstein/screens/exercise/run_screens.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

const _metersPerDegree = 6371000.0 * 3.141592653589793 / 180;

/// Pontos no formato do canal (latitude/longitude já divididas por 1E6 no
/// Kotlin), andando para o norte; [types] marca início/fim de trecho.
Map<String, Object?> channelTrack({required int id, String? type, required List<(double meters, int second, int kind)> pts}) {
  final t0 = DateTime.utc(2026, 10, 5, 9).millisecondsSinceEpoch;
  return {
    'id': id,
    'name': 'Corrida (RLT)',
    'activity_type': type,
    'uuid': 'abcd$id',
    'tz_offset_seconds': -10800,
    'recording': false,
    'points': [
      for (final (m, s, k) in pts)
        {'lat': -23 + m / _metersPerDegree, 'lon': -46.0, 't': t0 + s * 1000, 'alt': 760.0, 'acc': 4.0, 'type': k},
    ],
  };
}

void main() {
  setUpAll(loadFigtree);

  test('converte a trilha: trechos pelas marcas de início, ignora "parado" e fim, fuso em minutos', () {
    final t = trackFromChannel(channelTrack(id: 7, type: 'running', pts: [
      (0, 0, -2),
      (300, 90, 0),
      (300, 95, 1), // fim de trecho (pausa)
      (300, 200, 3), // parado
      (310, 300, -2), // retomou
      (610, 390, 0),
    ]));
    expect(t.kind, RunKind.run);
    expect(t.tzOffsetMinutes, -180);
    expect(t.externalId, 'abcd7');
    expect(t.points.map((p) => p.segment), [0, 0, 1, 1]);
    expect(RunCalculator.totalDistanceMeters(t.points), closeTo(600, 1));
    expect(trackFromChannel(channelTrack(id: 1, type: 'hiking', pts: const [])).kind, RunKind.walk);
    expect(trackFromChannel(channelTrack(id: 1, type: 'cycling', pts: const [])).kind, isNull);
  });

  late FakeOpenTracksBridge ot;
  late AppDependencies deps;

  setUp(() {
    ot = FakeOpenTracksBridge(isInstalled: true);
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      openTracks: ot,
    );
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('OpenTracks instalado: grava por ele, acompanha ao vivo e salva sem duplicar', (tester) async {
    await pump(tester, RunStartScreen(deps: deps));
    // Com o OpenTracks instalado, ele grava; sem escolha de gravador.
    expect(find.byKey(const Key('run_recorder_choice')), findsNothing);
    expect(find.byKey(const Key('run_opentracks_info')), findsOneWidget);
    expect(find.byKey(const Key('run_auto_pause')), findsNothing);
    await tester.tap(find.text('Caminhada'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('run_start')));
    await tester.pump();
    await tester.pump();
    expect(ot.startedKind, RunKind.walk);

    ot.tracks = [trackFromChannel(channelTrack(id: 3, type: 'walking', pts: [for (var i = 0; i <= 60; i++) (i * 10.0, i * 6, i == 0 ? -2 : 0)]))];
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('via OpenTracks'), findsOneWidget);
    expect(find.textContaining('0,60'), findsOneWidget);
    expect(find.text('06:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ot_finish')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ot_save')));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(ot.stopped, isTrue);
    final run = deps.core.queryByType(HealthEventType.gpsTrack).single;
    expect(run.source, HealthEventSource.opentracks);
    expect(run.externalId, 'abcd3');
    expect(run.payload['activity'], 'walk');
    expect(run.occurredAtTzOffsetMinutes, -180);
    expect(find.byKey(const Key('run_route')), findsOneWidget);

    // A mesma trilha de novo não vira duas.
    final again = trackFromChannel(channelTrack(id: 3, type: 'walking', pts: [(0, 0, -2), (100, 60, 0)]));
    expect(saveOpenTracksTrack(deps.core, again, fallbackTzOffsetMinutes: 0), isNull);
  });

  testWidgets('OpenTracks não responde (APIs desligadas): explica o que ligar', (tester) async {
    ot.answersStart = false;
    await pump(tester, RunStartScreen(deps: deps));
    await tester.tap(find.byKey(const Key('run_start')));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(seconds: 2));
    }
    expect(find.byKey(const Key('ot_no_answer')), findsOneWidget);
    expect(find.textContaining('API pública'), findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('"mostrar no painel" no OpenTracks: o RLT pergunta e traz a trilha', (tester) async {
    ot.current = OpenTracksSession(recording: false, receivedAt: DateTime.now());
    ot.tracks = [trackFromChannel(channelTrack(id: 9, type: 'running', pts: [for (var i = 0; i <= 50; i++) (i * 20.0, i * 5, i == 0 ? -2 : 0)]))];
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(FrankstitApp(dependencies: deps, navigatorKey: GlobalKey<NavigatorState>()));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ot_import')), findsOneWidget);
    expect(find.textContaining('Corrida · 1,00 km'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ot_import_yes')));
    await tester.pumpAndSettle();
    final run = deps.core.queryByType(HealthEventType.gpsTrack).single;
    expect(run.externalId, 'abcd9');
    expect(ot.current, isNull);
  });
}
