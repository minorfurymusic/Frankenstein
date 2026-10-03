import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  late FakeShareSheet share;
  late Widget app;

  setUp(() {
    final navigatorKey = GlobalKey<NavigatorState>();
    share = FakeShareSheet();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(navigatorKey),
      shareSheet: share,
      imageCapturer: FakeCardImageCapturer(),
    );
    app = FrankstitApp(dependencies: deps, navigatorKey: navigatorKey);
  });
  tearDown(() => deps.close());

  Future<void> openTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_exercicios')));
    await tester.pumpAndSettle();
  }

  void giveProfile() {
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.75));
    deps.bodyLogger.weight(kg: 70, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
  }

  testWidgets('aba mostra passos de hoje e as seções', (tester) async {
    await openTab(tester);
    expect(tester.widget<Text>(find.byKey(const Key('steps_today'))).data, '0');
    for (final s in ['Passos', 'Academia', 'Corrida e caminhada', 'Outras atividades']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
  });

  testWidgets('criar plano com exercício da biblioteca e treinar: série concluída, descanso, finalizar grava', (tester) async {
    await openTab(tester);
    await tester.tap(find.byKey(const Key('section_academia')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('plan_name')), 'Treino A');
    await tester.tap(find.byKey(const Key('plan_add_exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('library_supino-reto')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('plan_save')));
    await tester.pumpAndSettle();
    final plan = deps.workoutRepository.listPlans().single;
    expect(plan.exercises.single.exerciseId, 'supino-reto');
    expect(plan.exercises.single.targetSets, 3);

    await tester.tap(find.byKey(Key('plan_start_${plan.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('live_load')), '40');
    await tester.tap(find.byKey(const Key('live_set_done')));
    await tester.pump();
    expect(find.byKey(const Key('live_rest')), findsOneWidget);
    await tester.pump(const Duration(seconds: 2)); // cronômetro anda
    await tester.tap(find.byKey(const Key('live_finish')));
    await tester.pumpAndSettle();

    final session = deps.core.queryByType(HealthEventType.workoutSession).single;
    expect(session.payload['plan_id'], plan.id);
    expect(session.payload['sets_count'], 1);
    expect(session.payload['duration_seconds'], greaterThanOrEqualTo(1));
    final set = deps.core.queryByType(HealthEventType.setLog).single;
    expect(set.payload['load_kg'], 40);
    expect(find.text('Treino salvo'), findsOneWidget);
  });

  testWidgets('outra atividade grava e soma na meta de calorias do dia', (tester) async {
    giveProfile();
    final before = deps.goals.goalsFor(DateTime.now())!.caloriesKcal;
    await openTab(tester);
    await tester.tap(find.byKey(const Key('section_outras')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Gasto estimado'), findsOneWidget);
    await tester.tap(find.byKey(const Key('other_save')));
    await tester.pumpAndSettle();
    final e = deps.core.queryByType(HealthEventType.workoutSession).single;
    expect(e.payload['activity'], 'swimming');
    final after = deps.goals.goalsFor(DateTime.now())!;
    // natação moderada (MET 8,3) 30 min, 70 kg: (8,3 − 1) × 70 × 0,5 = 255,5
    expect(after.exerciseKcal, closeTo(255.5, 1e-6));
    expect(after.caloriesKcal, closeTo(before + 255.5, 1e-6));
  });

  testWidgets('corrida gravada: histórico, resumo e GPX pelo compartilhamento', (tester) async {
    giveProfile();
    final start = DateTime.now().toUtc().subtract(const Duration(hours: 1));
    final points = [
      for (var i = 0; i <= 30; i++)
        RunPointInput(latitude: -23.0 + i * 100 / 111194.9, longitude: -46.0, accuracyMeters: 5, recordedAt: start.add(Duration(seconds: i * 36))),
    ]; // 3 km em 18 min = 10 km/h
    final run = RunLogger(core: deps.core).logRun(points, occurredAtTzOffsetMinutes: -180);
    await openTab(tester);
    await tester.tap(find.text('Corrida e caminhada'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3,00 km'), findsOneWidget);
    await tester.tap(find.textContaining('3,00 km'));
    await tester.pumpAndSettle();
    expect(find.text('Corrida'), findsWidgets);
    await tester.tap(find.byKey(const Key('run_gpx')));
    await tester.pumpAndSettle();
    expect(share.lastFileName, 'rota.gpx');
    expect(String.fromCharCodes(share.lastBytes!), contains('<gpx'));
    final entry = deps.activityRead.forDay(DateTime.now()).single;
    expect(entry.event.id, run.id);
    // ACSM corrida: 10 km/h = 166,7 m/min → MET (0,2 × 166,7 + 3,5)/3,5 ≈ 10,52; 18 min, 70 kg
    expect(entry.kcal, closeTo((((0.2 * 3000 / 18) + 3.5) / 3.5 - 1) * 70 * 0.3, 0.5));
  });
}
