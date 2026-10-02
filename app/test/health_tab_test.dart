import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/health_read_model.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

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

  Future<void> openHealthTab(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('nav_saude')));
    await tester.pumpAndSettle();
  }

  Medication midnightMedication() {
    final today = DateTime.now();
    return Medication(
      id: HealthDataCore.newId(),
      name: 'Losartana',
      doseAmount: 50,
      doseUnit: 'mg',
      form: MedicationForm.tablet,
      timesOfDay: const [0], // 00:00 — sempre já passou: dose atrasada
      startDate: LocalDate(today.year, today.month, today.day),
    );
  }

  testWidgets('aba Saúde vazia: resumos com traço, seções e aviso fixo de saúde', (tester) async {
    await openHealthTab(tester);
    expect(find.text('Saúde'), findsWidgets);
    expect(find.text('Próximo remédio'), findsOneWidget);
    expect(find.text('Nenhum cadastrado'), findsOneWidget);
    for (final s in ['Remédios', 'Receitas médicas', 'Histórico médico', 'Exames e documentos', 'Sinais vitais', 'Corpo', 'Sono']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    expect(find.textContaining('não faz diagnóstico'), findsOneWidget);
  });

  testWidgets('cadastrar remédio pelo formulário: aparece na lista e na agenda de hoje', (tester) async {
    await openHealthTab(tester);
    await tester.tap(find.byKey(const Key('section_remedios')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum remédio cadastrado'), findsOneWidget);

    await tester.tap(find.byKey(const Key('medication_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medication_name')), 'Metformina');
    await tester.enterText(find.byKey(const Key('medication_dose')), '850');
    await tester.tap(find.byKey(const Key('medication_save')));
    await tester.pumpAndSettle();

    final saved = deps.medicationRepository.listAll().single;
    expect(saved.name, 'Metformina');
    expect(saved.doseAmount, 850);
    expect(saved.doseUnit, 'mg');
    expect(saved.timesOfDay, [8 * 60]);
    expect(saved.isContinuous, isTrue);
    expect(find.text('Ativos (1)'), findsOneWidget);
    expect(find.text('Metformina'), findsWidgets);
  });

  testWidgets('formulário não salva remédio sem dose e explica por quê', (tester) async {
    await openHealthTab(tester);
    await tester.tap(find.byKey(const Key('section_remedios')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('medication_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('medication_name')), 'Sem dose');
    await tester.tap(find.byKey(const Key('medication_save')));
    await tester.pump();
    expect(find.textContaining('Não salvei'), findsOneWidget);
    expect(deps.medicationRepository.listAll(), isEmpty);
  });

  testWidgets('"Tomei" grava a dose como evento e o cartão vira "tomado"', (tester) async {
    final m = midnightMedication();
    deps.medicationRepository.save(m);
    await openHealthTab(tester);
    expect(find.text('Atrasado · 00:00'), findsOneWidget);

    await tester.tap(find.byKey(const Key('section_remedios')));
    await tester.pumpAndSettle();
    expect(find.text('ATRASADO'), findsOneWidget);
    await tester.tap(find.text('Tomei'));
    await tester.pumpAndSettle();

    final doses = deps.core.queryByType(HealthEventType.medicationDose);
    expect(doses, hasLength(1));
    expect(doses.single.payload['status'], 'taken');
    expect(doses.single.payload['medication_id'], m.id);
    expect(find.text('TOMADO'), findsOneWidget);
  });

  testWidgets('registrar sintoma pelo formulário grava evento com intensidade', (tester) async {
    await openHealthTab(tester);
    await tester.tap(find.byKey(const Key('section_historico')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('symptom_new')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Náusea'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('symptom_save')));
    await tester.pumpAndSettle();

    final events = deps.core.queryByType(HealthEventType.symptom);
    expect(events.single.payload['name'], 'Náusea');
    expect(events.single.payload['intensity'], 4);
    expect(find.text('Náusea'), findsOneWidget); // no diário
  });

  testWidgets('registrar pressão: grava em kPa (SI) e mostra em mmHg', (tester) async {
    await openHealthTab(tester);
    await tester.tap(find.byKey(const Key('section_vitais')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('vital_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('vital_value_a')), '122');
    await tester.enterText(find.byKey(const Key('vital_value_b')), '81');
    await tester.tap(find.byKey(const Key('vital_save')));
    await tester.pumpAndSettle();

    final e = deps.core.queryByType(HealthEventType.vitalSign).single;
    expect(e.payload['systolic_kpa'], closeTo(16.265, 0.001));
    expect(find.textContaining('122/81', findRichText: true), findsWidgets);
  });

  testWidgets('registrar peso em Corpo aparece no resumo da aba', (tester) async {
    await openHealthTab(tester);
    await tester.tap(find.byKey(const Key('section_corpo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('body_new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('body_value')), '68,4');
    await tester.tap(find.byKey(const Key('body_save')));
    await tester.pumpAndSettle();
    expect(deps.core.queryByType(HealthEventType.weight).single.payload['kg'], 68.4);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('68,4', findRichText: true), findsOneWidget);
  });

  group('HealthReadModel', () {
    test('adesão conta doses tomadas sobre previstas nos dias anteriores', () {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 3));
      final m = Medication(
        id: 'm1',
        name: 'Vitamina D',
        doseAmount: 2000,
        doseUnit: 'UI',
        timesOfDay: const [12 * 60],
        startDate: LocalDate(start.year, start.month, start.day),
      );
      deps.medicationRepository.save(m);
      final yesterday = now.subtract(const Duration(days: 1));
      deps.doseLogger.log(
        name: m.name,
        doseAmount: m.doseAmount,
        doseUnit: m.doseUnit,
        status: DoseStatus.taken,
        occurredAt: DateTime(yesterday.year, yesterday.month, yesterday.day, 12).toUtc(),
        occurredAtTzOffsetMinutes: yesterday.timeZoneOffset.inMinutes,
        medicationId: m.id,
        scheduledLocal: '${LocalDate(yesterday.year, yesterday.month, yesterday.day).toIso()}T12:00',
      );
      final a = deps.healthRead.adherence();
      expect(a.expected, 3);
      expect(a.taken, 1);
      expect(a.ratio, closeTo(1 / 3, 1e-9));
    });

    test('glicemia volta em mg/dL e saturação em %', () {
      final at = DateTime.now().toUtc();
      deps.vitalSignLogger.glucose(mgDl: 98, occurredAt: at, occurredAtTzOffsetMinutes: 0);
      deps.vitalSignLogger.spo2(percent: 97, occurredAt: at, occurredAtTzOffsetMinutes: 0);
      expect(deps.healthRead.vitals(VitalKind.glucose).single.display, '98');
      expect(deps.healthRead.vitals(VitalKind.spo2).single.display, '97');
    });
  });
}
