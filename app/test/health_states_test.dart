import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/reminders/reminders.dart';
import 'package:frankstein/screens/account/devices_screen.dart';
import 'package:frankstein/screens/health/body_screen.dart';
import 'package:frankstein/screens/health/documents_screens.dart';
import 'package:frankstein/screens/health/health_tab.dart';
import 'package:frankstein/screens/health/medications_screen.dart';
import 'package:frankstein/screens/health/symptoms_screen.dart';
import 'package:frankstein/screens/health/vitals_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_health_records/health_records.dart';

import 'support/fonts.dart';

class NoNotifications extends NoopReminderScheduler {
  @override
  Future<bool> hasPermission() async => false;
}

class DeniedCamera extends FakeDocumentPicker {
  @override
  Future<PickedDocument?> takePhoto() async => throw PlatformException(code: 'camera_access_denied');
}

/// Estados das pranchetas SaudeEstados, RemediosEstados, VitaisEstados,
/// CorpoEstados, HistoricoEstados, ReceitasEstados e ExamesEstados.
void main() {
  setUpAll(loadFigtree);

  late FakeDocumentPicker picker;
  late AppDependencies deps;
  var coreClosed = false;

  AppDependencies build({ReminderScheduler? reminders, FakeDocumentPicker? documents}) {
    picker = documents ?? FakeDocumentPicker();
    return AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      reminderScheduler: reminders,
      documentPicker: picker,
    );
  }

  setUp(() {
    coreClosed = false;
    deps = build();
  });
  tearDown(() {
    try {
      deps.close();
    } catch (_) {
      if (!coreClosed) rethrow;
    }
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox()); // começa sem telas empilhadas do passo anterior
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  Medication med(String id) => Medication(
        id: id,
        name: 'Losartana',
        doseAmount: 50,
        doseUnit: 'mg',
        form: MedicationForm.tablet,
        timesOfDay: const [8 * 60],
        startDate: LocalDate(2026, 1, 1),
      );

  testWidgets('Saúde: erro de leitura mostra "Não foi possível carregar o resumo"', (tester) async {
    deps.core.close();
    coreClosed = true;
    await pump(tester, Scaffold(body: HealthTab(deps: deps)));
    expect(find.text('Não foi possível carregar o resumo'), findsOneWidget);
    expect(find.text('Seus dados estão salvos no celular. Tente de novo.'), findsOneWidget);
  });

  testWidgets('Saúde: receitas válidas e exames com a data do último', (tester) async {
    deps.medicationRepository.save(med('m1'));
    final today = LocalDate.fromDateTime(DateTime.now());
    deps.documents.save(HealthDocument(id: 'r1', kind: HealthDocumentKind.prescription, title: 'Dra. Ana', validUntil: LocalDate(2020, 1, 1)));
    deps.documents.save(HealthDocument(id: 'r2', kind: HealthDocumentKind.prescription, title: 'Dr. Bruno'));
    deps.documents.save(HealthDocument(id: 'e1', kind: HealthDocumentKind.exam, title: 'Glicemia', category: ExamCategory.blood, date: LocalDate(2026, 9, 25)));
    deps.documents.save(HealthDocument(id: 'e2', kind: HealthDocumentKind.exam, title: 'Hemograma', category: ExamCategory.blood, date: LocalDate(2026, 3, 14)));
    await pump(tester, Scaffold(body: HealthTab(deps: deps)));
    expect(find.byKey(const Key('health_empty')), findsNothing);
    expect(find.text('1 receita válida'), findsOneWidget);
    expect(find.text('2 exames · último 25/09'), findsOneWidget);
    expect(today, isNotNull);
  });

  testWidgets('Remédios vazio: convite da prancheta; notificações desligadas avisam que o lembrete não toca', (tester) async {
    await pump(tester, MedicationsScreen(deps: deps));
    expect(find.byKey(const Key('medications_empty')), findsOneWidget);
    expect(find.textContaining('ele lê os remédios, doses e horários'), findsOneWidget);
    await tester.tap(find.text('Fotografar receita'));
    await tester.pumpAndSettle();
    expect(find.byType(PrescriptionsScreen), findsOneWidget);

    deps.close();
    deps = build(reminders: NoNotifications());
    deps.medicationRepository.save(med('m2'));
    await pump(tester, MedicationsScreen(deps: deps));
    expect(find.byKey(const Key('medications_no_notifications')), findsOneWidget);
    expect(find.text('Notificações desligadas: os lembretes não vão tocar.'), findsOneWidget);
  });

  testWidgets('Sinais vitais vazio: registrar agora abre o formulário; conectar pulseira abre Dispositivos', (tester) async {
    await pump(tester, VitalsScreen(deps: deps));
    expect(find.text('Nenhuma medida ainda'), findsOneWidget);
    expect(find.textContaining('Registre a pressão manualmente'), findsOneWidget);
    await tester.tap(find.text('Registrar agora'));
    await tester.pumpAndSettle();
    expect(find.byType(VitalForm), findsOneWidget);
    Navigator.of(tester.element(find.byType(VitalForm))).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Conectar pulseira'));
    await tester.pumpAndSettle();
    expect(find.byType(DevicesScreen), findsOneWidget);
  });

  testWidgets('Corpo e Histórico vazios: textos e ações das pranchetas', (tester) async {
    await pump(tester, BodyScreen(deps: deps));
    expect(find.text('Registre seu peso'), findsOneWidget);
    await tester.tap(find.text('Registrar peso'));
    await tester.pumpAndSettle();
    expect(find.byType(BodyForm), findsOneWidget);

    await pump(tester, SymptomsScreen(deps: deps));
    expect(find.textContaining('Ajuda muito na hora da consulta.'), findsOneWidget);
    expect(find.byKey(const Key('symptoms_empty')), findsOneWidget);
  });

  testWidgets('Receitas e Exames vazios: fotografar ou enviar PDF; câmera negada explica o que fazer', (tester) async {
    await pump(tester, PrescriptionsScreen(deps: deps));
    expect(find.byKey(const Key('documents_empty')), findsOneWidget);
    await tester.tap(find.text('Enviar PDF'));
    await tester.pumpAndSettle();
    expect(picker.lastSource, 'pdf');

    await pump(tester, ExamsScreen(deps: deps));
    expect(find.textContaining('O Cérebro pode ler os valores para você conferir e acompanhar.'), findsOneWidget);

    deps.close();
    deps = build(documents: DeniedCamera());
    await pump(tester, PrescriptionsScreen(deps: deps));
    await tester.tap(find.text('Fotografar receita'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Permita o uso da câmera'), findsOneWidget);
  });
}
