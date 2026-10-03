import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/screens/account/account_more_screens.dart';
import 'package:frankstein/screens/account/devices_screen.dart';
import 'package:frankstein/screens/health/sleep_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein/wearables/health_connect.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

int _ms(DateTime d) => d.millisecondsSinceEpoch;

/// Uma noite de ontem para hoje: 23:00 → 06:30 (hora local), com fases.
Map<String, dynamic> _night(String id) {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day).subtract(const Duration(hours: 1)); // ontem 23:00
  DateTime at(int minutes) => start.add(Duration(minutes: minutes)).toUtc();
  return {
    'id': id,
    'start_millis': _ms(at(0)),
    'end_millis': _ms(at(450)),
    'tz_offset_minutes': now.timeZoneOffset.inMinutes,
    'stages': [
      {'stage': 'light', 'start_millis': _ms(at(0)), 'end_millis': _ms(at(120))},
      {'stage': 'deep', 'start_millis': _ms(at(120)), 'end_millis': _ms(at(210))},
      {'stage': 'rem', 'start_millis': _ms(at(210)), 'end_millis': _ms(at(260))},
      {'stage': 'light', 'start_millis': _ms(at(260)), 'end_millis': _ms(at(440))},
      {'stage': 'awake', 'start_millis': _ms(at(440)), 'end_millis': _ms(at(450))},
    ],
  };
}

void main() {
  setUpAll(loadFigtree);

  late FakeHealthConnectBridge hc;
  late AppDependencies deps;

  setUp(() {
    hc = FakeHealthConnectBridge(
      currentStatus: HealthConnectStatus.available,
      sleepRecords: [_night('hc-sleep-1')],
      heartRateRecords: [
        {'id': 'hc-hr-1#0', 'time_millis': _ms(DateTime.now().toUtc()), 'bpm': 64, 'tz_offset_minutes': -180},
        {'id': 'hc-hr-1#1', 'time_millis': _ms(DateTime.now().toUtc()), 'bpm': 0, 'tz_offset_minutes': -180},
      ],
    );
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      healthConnect: hc,
    );
  });
  tearDown(() => deps.close());

  group('WearableSync', () {
    test('conectar pede permissão, liga e grava sono (com fases) e FC; ler de novo não duplica', () async {
      expect(deps.wearables.enabled, isFalse);
      expect((await deps.wearables.syncNow()).state, WearableSyncState.notConnected);

      final first = await deps.wearables.connect();
      expect(first.state, WearableSyncState.ok);
      expect(hc.requests, 1);
      expect(deps.wearables.enabled, isTrue);
      expect(first.result!.sleepSynced, 1);
      expect(first.result!.heartRateSynced, 1, reason: 'bpm 0 é descartado');

      final sleep = deps.core.queryByType(HealthEventType.sleep).single;
      expect(sleep.source, HealthEventSource.wearable);
      expect(sleep.payload['stage_minutes'], {'light': 300, 'deep': 90, 'rem': 50, 'awake': 10});
      final night = deps.healthRead.sleeps().single;
      expect(night.minutes, 450);
      expect(night.asleepMinutes, 440);
      expect(night.stages, hasLength(5));

      final second = await deps.wearables.syncNow();
      expect(second.result!.sleepSynced, 0);
      expect(second.result!.sleepAlreadySynced, 1);
      expect(deps.core.queryByType(HealthEventType.heartRate), hasLength(1));

      // Segunda leitura começa 2 dias antes da última, não 30.
      final (from, to) = hc.lastRange!;
      expect(to.difference(from).inDays, 2);
    });

    test('sem Health Connect: indisponível; permissão negada: não liga', () async {
      hc.currentStatus = HealthConnectStatus.notInstalled;
      expect((await deps.wearables.connect()).state, WearableSyncState.unavailable);
      hc.currentStatus = HealthConnectStatus.available;
      hc.grantOnRequest = const {};
      expect((await deps.wearables.connect()).state, WearableSyncState.noPermission);
      expect(deps.wearables.enabled, isFalse);
    });

    test('só FC permitida: lê FC e não pede sono', () async {
      hc.grantOnRequest = const {HealthConnectData.heartRate};
      final o = await deps.wearables.connect();
      expect(o.result!.heartRateSynced, 1);
      expect(o.result!.sleepSynced, 0);
    });

    test('Health Connect sem resposta vira erro, não exceção', () async {
      await deps.wearables.connect();
      hc.failReads = true;
      expect((await deps.wearables.syncNow()).state, WearableSyncState.error);
    });
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  testWidgets('Dispositivos: conectar → conectado com dados lidos → desconectar', (tester) async {
    await pump(tester, DevicesScreen(deps: deps));
    expect(find.text('Conecte sua pulseira ou relógio'), findsOneWidget);
    await tester.tap(find.text('Conectar pelo Health Connect'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('hc_connected')), findsOneWidget);
    expect(find.text('Sono'), findsOneWidget);
    expect(find.text('Freq. cardíaca'), findsOneWidget);
    expect(find.textContaining('sincronizou'), findsOneWidget);
    expect(find.textContaining('1 noite e 1 batimentos novos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('hc_disconnect')));
    await tester.pumpAndSettle();
    expect(deps.wearables.enabled, isFalse);
    expect(find.text('Conecte sua pulseira ou relógio'), findsOneWidget);
  });

  testWidgets('Dispositivos sem Health Connect pede para instalar', (tester) async {
    hc.currentStatus = HealthConnectStatus.notInstalled;
    await pump(tester, DevicesScreen(deps: deps));
    expect(find.text('Health Connect não encontrado'), findsOneWidget);
    expect(find.text('Instalar Health Connect'), findsOneWidget);
  });

  testWidgets('Sono: sem pulseira → conectar; conectado → última noite com fases e semana', (tester) async {
    await pump(tester, SleepScreen(deps: deps));
    expect(find.byKey(const Key('sleep_connect')), findsOneWidget);

    await deps.wearables.connect();
    await pump(tester, SleepScreen(deps: deps));
    expect(find.byKey(const Key('sleep_last_night')), findsOneWidget);
    expect(find.text('7 h 20 min'), findsOneWidget); // 450 − 10 acordado
    expect(find.text('Profundo'), findsOneWidget);
    expect(find.text('1 h 30'), findsOneWidget);
    expect(find.text('REM'), findsOneWidget);
    expect(find.text('Últimos 7 dias'), findsOneWidget);
    expect(find.text('Meta 8 h'), findsOneWidget);
  });

  testWidgets('Sono: conectado mas sem permissão de sono mostra o pedido', (tester) async {
    await deps.wearables.connect();
    hc.granted = const {};
    await pump(tester, SleepScreen(deps: deps));
    expect(find.byKey(const Key('sleep_no_permission')), findsOneWidget);
    await tester.tap(find.text('Permitir leitura do sono'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sleep_no_permission')), findsNothing);
  });

  testWidgets('Permissões mostra o estado real do Health Connect; Privacidade explica a leitura', (tester) async {
    await deps.wearables.connect();
    await pump(tester, PermissionsScreen(deps: deps));
    expect(find.textContaining('Sono e batimentos via Health Connect (só leitura).\nPermitida'), findsOneWidget);
    await pump(tester, PrivacyScreen(deps: deps));
    expect(find.byKey(const Key('privacy_health_connect')), findsOneWidget);
  });
}
