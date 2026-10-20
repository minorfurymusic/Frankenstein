import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/screens/exercise/activity_screens.dart';
import 'package:frankstein/screens/exercise/exercise_tab.dart';
import 'package:frankstein/screens/exercise/live_workout_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

/// Editar e excluir (correção append-only, `.claude/rules/datacore.md`).
void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  setUp(() {
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.83));
    deps.bodyLogger.weight(kg: 93.7, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  HealthEvent workout() => deps.workoutLogger.logSession(
        WorkoutSessionInput(sets: [
          SetEntry(exerciseId: 'supino-reto', exerciseName: 'Supino reto', setNumber: 1, reps: 12, loadKg: 34),
          SetEntry(exerciseId: 'supino-reto', exerciseName: 'Supino reto', setNumber: 2, reps: 10, loadKg: 0),
        ], duration: const Duration(minutes: 5)),
        occurredAt: DateTime.now().toUtc(),
        occurredAtTzOffsetMinutes: DateTime.now().timeZoneOffset.inMinutes,
      );

  testWidgets('treino salvo: editar a carga de uma série, excluir outra e o gasto acompanha', (tester) async {
    final session = workout();
    await pump(tester, WorkoutSummaryScreen(deps: deps, session: session));
    final before = deps.activityRead.sessionKcal(session, 93.7);

    await tester.tap(find.byKey(const Key('saved_set_2_supino-reto_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved_set_2_supino-reto_edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit_field_0')), '68');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();
    final sets = deps.core.queryByType(HealthEventType.setLog);
    expect(sets.map((s) => s.payload['load_kg']), containsAll([34, 68.0]));
    expect(deps.activityRead.sessionKcal(session, 93.7), greaterThan(before));

    await tester.tap(find.byKey(const Key('saved_set_1_supino-reto_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('saved_set_1_supino-reto_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.setLog), hasLength(1));
    expect(find.text('1 séries'), findsOneWidget);
  });

  testWidgets('excluir o treino inteiro some do dia (sessão e séries)', (tester) async {
    final session = workout();
    await pump(tester, Builder(
      builder: (context) => TextButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => WorkoutSummaryScreen(deps: deps, session: session))),
        child: const Text('abrir'),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('workout_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.workoutSession), isEmpty);
    expect(deps.core.queryByType(HealthEventType.setLog), isEmpty);
    expect(deps.activityRead.forDay(DateTime.now()), isEmpty);
  });

  testWidgets('Exercícios › Hoje: tocar no treino abre o resumo, e de lá se exclui', (tester) async {
    workout();
    await pump(tester, Scaffold(body: ExerciseTab(deps: deps)));
    await tester.scrollUntilVisible(find.text('Treino de academia'), 200);
    await tester.tap(find.text('Treino de academia'));
    await tester.pumpAndSettle();
    expect(find.text('Treino salvo'), findsOneWidget);
    expect(find.byKey(const Key('saved_set_1_supino-reto_menu')), findsOneWidget);

    await tester.tap(find.byKey(const Key('workout_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.workoutSession), isEmpty);
    expect(find.text('Treino de academia'), findsNothing);
  });

  testWidgets('passos à mão por distância: 1,2 km vira passos pela passada; editar e excluir', (tester) async {
    await pump(tester, StepsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('steps_manual_add')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Distância'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('steps_manual_value')), '1,2');
    await tester.pump();
    await tester.tap(find.byKey(const Key('steps_manual_save')));
    await tester.pumpAndSettle();
    // Passada 0,415 × 1,83 m = 0,759 m → 1.200 / 0,759 ≈ 1.580.
    expect(deps.dayRead.totals(DateTime.now()).steps, 1580);

    await tester.tap(find.byKey(const Key('steps_manual_menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('steps_manual_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(deps.dayRead.totals(DateTime.now()).steps, 0);
  });

  testWidgets('treino ao vivo: excluir série e exercício antes de salvar', (tester) async {
    await pump(tester, LiveWorkoutScreen(
      deps: deps,
      plan: WorkoutPlan(id: 'p', name: 'A', exercises: [
        PlannedExercise(exerciseId: 'supino-reto', exerciseName: 'Supino reto', targetSets: 3, targetReps: 10),
      ]),
    ));
    expect(find.byKey(const Key('live_remove_set_2')), findsOneWidget);
    await tester.tap(find.byKey(const Key('live_remove_set_2')));
    await tester.pump();
    expect(find.byKey(const Key('live_remove_set_2')), findsNothing);
    await tester.tap(find.byKey(const Key('live_remove_exercise')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('live_add_exercise')), findsOneWidget);
  });

  testWidgets('Início: tocar na água da linha do tempo edita; no peso, exclui', (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final now = DateTime.now();
    deps.waterLogger.log(amountMl: 500, occurredAt: now.toUtc(), occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes);
    await tester.pumpWidget(FrankstitApp(dependencies: deps, navigatorKey: GlobalKey<NavigatorState>()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('500 ml'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline_edit')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('edit_field_0')), '300');
    await tester.tap(find.byKey(const Key('edit_save')));
    await tester.pumpAndSettle();
    expect(deps.dayRead.totals(now).waterMl, 300);

    await tester.tap(find.text('93,7 kg').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('timeline_delete')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('confirm_delete')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.weight), isEmpty);
  });
}
