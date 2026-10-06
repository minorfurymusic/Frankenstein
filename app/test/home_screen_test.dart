import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_nutrition/nutrition.dart';
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

  Future<void> openHome(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
  }

  void logBanana({DateTime? at}) {
    final when = at ?? DateTime.now();
    deps.mealLogger.logMeal(
      items: [MealItemInput(foodId: deps.foodRepository.findByBarcode('7891000000075')!.id, grams: 100)],
      mealType: MealType.snack,
      occurredAt: when.toUtc(),
      occurredAtTzOffsetMinutes: when.timeZoneOffset.inMinutes,
    );
  }

  testWidgets('atalho "+ Água" grava e aparece na linha do tempo', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('shortcut_water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_water_300')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.water).single.payload['amount_ml'], 300);
    expect(find.text('Nada registrado hoje'), findsNothing);
    expect(find.text('300 ml'), findsOneWidget); // detalhe do item da linha do tempo
  });

  testWidgets('refeição registrada soma no anel e entra na linha do tempo', (tester) async {
    logBanana();
    await openHome(tester);
    expect(tester.widget<Text>(find.byKey(const Key('home_kcal'))).data, isNot('0'));
    expect(find.text('Lanche'), findsOneWidget);
    expect(find.textContaining('Banana prata'), findsOneWidget);
  });

  testWidgets('remédio atrasado aparece no Início e "Tomei" grava a dose', (tester) async {
    final now = DateTime.now();
    deps.medicationRepository.save(Medication(
      id: 'm1',
      name: 'Losartana',
      doseAmount: 50,
      doseUnit: 'mg',
      timesOfDay: const [0],
      startDate: LocalDate(now.year, now.month, now.day),
    ));
    await openHome(tester);
    expect(find.text('Remédios de hoje'), findsOneWidget);
    await tester.tap(find.text('Tomei'));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.medicationDose).single.payload['status'], 'taken');
    expect(find.textContaining('tomado (00:00)'), findsOneWidget);
  });

  testWidgets('sequência de dias registrando e dia anterior', (tester) async {
    logBanana(at: DateTime.now().subtract(const Duration(days: 1)));
    logBanana();
    await openHome(tester);
    expect(find.text('2 dias seguidos registrando'), findsOneWidget);
    await tester.tap(find.byKey(const Key('home_prev_day')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Banana prata'), findsOneWidget);
  });

  testWidgets('sino abre Lembretes e a escolha da água fica salva', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('reminders_button')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('reminder_water')));
    await tester.pumpAndSettle();
    expect(deps.profileRepository.getSetting('reminders'), contains('"water_on":true'));
  });

  testWidgets('"Falar com o Cérebro" troca para a aba Cérebro', (tester) async {
    await openHome(tester);
    await tester.tap(find.byKey(const Key('shortcut_brain')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_input')), findsOneWidget);
  });

  testWidgets('ver outro dia: calendário com dias dentro/fora da meta, aviso de dia anterior e voltar para hoje', (tester) async {
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.75));
    deps.bodyLogger.weight(kg: 70, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    logBanana(at: yesterday); // 100 g de banana: bem abaixo da meta de quem mantém o peso
    await openHome(tester);
    expect(find.byKey(const Key('home_past_banner')), findsNothing);

    await tester.tap(find.byKey(const Key('home_calendar')));
    await tester.pumpAndSettle();
    expect(find.text('Ver outro dia'), findsOneWidget);
    if (yesterday.month != DateTime.now().month) {
      await tester.tap(find.byTooltip('Mês anterior'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Fora da meta (1)'), findsOneWidget);
    expect(find.text('Hoje'), findsOneWidget);
    await tester.tap(find.byKey(Key('home_cal_day_${yesterday.day}')));
    await tester.pumpAndSettle();

    expect(find.text('Você está vendo um dia anterior.'), findsOneWidget);
    expect(find.textContaining('Banana prata'), findsOneWidget);
    expect(find.byKey(const Key('home_streak')), findsNothing);
    await tester.tap(find.byKey(const Key('home_back_today')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('home_past_banner')), findsNothing);
    expect(find.textContaining('Hoje,'), findsOneWidget);
  });
}
