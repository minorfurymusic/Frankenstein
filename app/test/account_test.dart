import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/format.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  late Widget app;

  setUp(() {
    final navigatorKey = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(navigatorKey),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
    app = FrankstitApp(dependencies: deps, navigatorKey: navigatorKey);
  });
  tearDown(() => deps.close());

  Future<void> openAccount(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_avatar')));
    await tester.pumpAndSettle();
  }

  testWidgets('Metas sem perfil pede o perfil; preencher o perfil calcula as metas', (tester) async {
    await openAccount(tester);
    await tester.tap(find.byKey(const Key('account_Metas')));
    await tester.pumpAndSettle();
    expect(find.text('Preencha seu perfil'), findsOneWidget);

    await tester.tap(find.text('Abrir perfil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Masculino'));
    await tester.enterText(find.byKey(const Key('profile_height')), '175');
    await tester.enterText(find.byKey(const Key('profile_weight')), '70');
    await tester.tap(find.byKey(const Key('profile_birth')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('profile_save')));
    await tester.pumpAndSettle();

    final p = deps.profileRepository.load()!;
    expect(p.sex, BiologicalSex.male);
    expect(p.heightMeters, 1.75);
    expect(deps.core.queryByType(HealthEventType.weight).single.payload['kg'], 70);

    // Voltou para Metas, agora calculadas (nascimento padrão 01/01/1990).
    final expected = computeDailyGoals(p, DayInputs(weightKg: 70, date: DateTime.now()));
    expect(
      find.descendant(of: find.byKey(const Key('goal_calories')), matching: find.text('${formatNumber(expected.caloriesKcal)} kcal')),
      findsOneWidget,
    );
    expect(find.text('Gasto em repouso (Mifflin-St Jeor)'), findsOneWidget);
    expect(find.text('2.000 ml'), findsOneWidget); // água: piso EFSA homem × 80%
    expect(find.byKey(const Key('goal_fiber')), findsOneWidget);
  });

  testWidgets('ajuste manual da meta de água vale e pode voltar ao calculado', (tester) async {
    deps.profileRepository.save(Profile(sex: BiologicalSex.female, birthDate: DateTime(1990), heightMeters: 1.65));
    deps.bodyLogger.weight(kg: 60, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
    await openAccount(tester);
    await tester.tap(find.byKey(const Key('account_Metas')));
    await tester.pumpAndSettle();
    expect(find.text('1.680 ml'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goal_water')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal_edit_value')), '2.500');
    await tester.tap(find.byKey(const Key('goal_edit_save')));
    await tester.pumpAndSettle();
    expect(deps.profileRepository.loadOverrides().waterMl, 2500);
    expect(find.text('2.500 ml'), findsOneWidget);
    expect(find.text('Ajustada por você'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goal_water')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Voltar ao calculado'));
    await tester.pumpAndSettle();
    expect(deps.profileRepository.loadOverrides().waterMl, isNull);
    expect(find.text('1.680 ml'), findsOneWidget);
  });

  testWidgets('meta de sono: 8 h por padrão, ajustável em horas', (tester) async {
    deps.profileRepository.save(Profile(sex: BiologicalSex.female, birthDate: DateTime(1990), heightMeters: 1.65));
    deps.bodyLogger.weight(kg: 60, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
    await openAccount(tester);
    await tester.tap(find.byKey(const Key('account_Metas')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('goal_sleep')), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('8 h'), findsOneWidget);
    await tester.tap(find.byKey(const Key('goal_sleep')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal_edit_value')), '7,5');
    await tester.tap(find.byKey(const Key('goal_edit_save')));
    await tester.pumpAndSettle();
    expect(deps.profileRepository.loadOverrides().sleepMinutes, 450);
    expect(find.text('7,5 h'), findsOneWidget);
  });

  testWidgets('Preferências troca o tema e guarda a escolha', (tester) async {
    await openAccount(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('account_Preferências')), 200);
    await tester.tap(find.byKey(const Key('account_Preferências')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();
    expect(deps.themeMode.value, ThemeMode.dark);
    expect(deps.profileRepository.getSetting('theme_mode'), 'dark');
    expect(tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode, ThemeMode.dark);
  });

  testWidgets('Corpo mostra IMC com a altura do perfil', (tester) async {
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.75));
    deps.bodyLogger.weight(kg: 70, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_saude')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('section_corpo')));
    await tester.pumpAndSettle();
    expect(find.textContaining('22,9', findRichText: true), findsOneWidget);
    expect(find.textContaining('Peso adequado'), findsOneWidget);
  });

  group('números e dias', () {
    test('parseNumber aceita vírgula, ponto decimal e milhar', () {
      expect(parseNumber('68,4'), 68.4);
      expect(parseNumber('68.4'), 68.4);
      expect(parseNumber('1.200'), 1200);
      expect(parseNumber('1.200,5'), 1200.5);
      expect(parseNumber(''), isNull);
      expect(parseNumber('abc'), isNull);
    });

    test('totais do dia usam o dia local de cada evento, não o dia UTC', () {
      // 22:00 em Brasília (UTC−3) de 1º/10 = 01:00 UTC de 2/10.
      deps.core.insertEvent(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.water,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 10, 2, 1),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 10, 2, 1),
        payload: const {'amount_ml': 300},
        confidence: 1,
      ));
      expect(deps.dayRead.totals(DateTime(2026, 10, 1)).waterMl, 300);
      expect(deps.dayRead.totals(DateTime(2026, 10, 2)).waterMl, 0);
    });
  });
}
