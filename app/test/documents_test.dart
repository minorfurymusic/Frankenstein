import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/screens/health/documents_screens.dart';
import 'package:frankstein/screens/health/health_tab.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_health_records/health_records.dart';

import 'support/fonts.dart';

// PNG 1×1 válido, para a tela cheia conseguir decodificar.
final _png = base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=');

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  late FakeDocumentPicker picker;

  setUp(() {
    picker = FakeDocumentPicker();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      documentPicker: picker,
    );
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  MemoryDocumentFileStore store() => deps.documentFiles as MemoryDocumentFileStore;

  testWidgets('Saúde abre Receitas e Exames (sem "em construção")', (tester) async {
    await pump(tester, Scaffold(body: HealthTab(deps: deps)));
    await tester.scrollUntilVisible(find.byKey(const Key('section_receitas')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('section_receitas')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma receita guardada'), findsOneWidget);
    expect(find.textContaining('em construção'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('section_exames')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('section_exames')));
    await tester.pumpAndSettle();
    expect(find.text('Nenhum exame ainda'), findsOneWidget);
    expect(find.text('Conectar prontuário de hospital'), findsOneWidget);
    expect(find.text('Premium'), findsOneWidget);
  });

  testWidgets('receita: fotografar → preencher → vincular remédio → salvar → lista → tela cheia', (tester) async {
    final med = Medication(
      id: 'm1',
      name: 'Metformina',
      doseAmount: 500,
      doseUnit: 'mg',
      form: MedicationForm.tablet,
      timesOfDay: const [8 * 60],
      startDate: LocalDate(2026, 1, 1),
    );
    deps.medicationRepository.save(med);
    await pump(tester, PrescriptionsScreen(deps: deps));

    picker.next = PickedDocument(bytes: _png, name: 'IMG_0001.png', mimeType: 'image/png');
    await tester.tap(find.text('Fotografar receita'));
    await tester.pumpAndSettle();
    expect(picker.lastSource, 'camera');
    expect(find.text('Nova receita'), findsOneWidget);
    expect(find.text('IMG_0001.png'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('document_title')), 'Dra. Helena Martins');
    await tester.tap(find.byKey(const Key('document_link_m1')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('document_save')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final saved = deps.documents.list(HealthDocumentKind.prescription).single;
    expect(saved.title, 'Dra. Helena Martins');
    expect(saved.linkedMedicationIds, ['m1']);
    expect(saved.files.single.mimeType, 'image/png');
    expect(store().files.keys, [saved.files.single.storedName]);

    expect(find.text('Dra. Helena Martins'), findsOneWidget);
    expect(find.text('FOTO'), findsOneWidget);
    expect(find.text('Metformina'), findsOneWidget);

    await tester.tap(find.byKey(Key('document_${saved.id}')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Remédios vinculados'), findsOneWidget);
  });

  testWidgets('exame em PDF: categoria, filtro, PDF ilegível avisa, apagar remove o arquivo', (tester) async {
    await pump(tester, ExamsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('document_add')));
    await tester.pumpAndSettle();

    picker.next = PickedDocument(bytes: Uint8List.fromList(utf8.encode('%PDF-1.4')), name: 'resultado_lab.pdf', mimeType: 'application/pdf');
    await tester.tap(find.byKey(const Key('document_pdf')));
    await tester.pumpAndSettle();
    expect(find.text('resultado_lab.pdf'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('document_title')), 'Ultrassom de abdome');
    await tester.tap(find.byKey(const Key('document_category_image')));
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('document_save')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();

    final exam = deps.documents.list(HealthDocumentKind.exam).single;
    expect(exam.category, ExamCategory.image);
    expect(find.text('PDF'), findsOneWidget);

    await tester.tap(find.byKey(const Key('exam_filter_urine')));
    await tester.pumpAndSettle();
    expect(find.text('Nada nesta categoria.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('exam_filter_image')));
    await tester.pumpAndSettle();
    expect(find.text('Ultrassom de abdome'), findsOneWidget);

    // Fora do Android não há leitor de PDF: avisa em vez de quebrar.
    await tester.tap(find.byKey(Key('document_${exam.id}')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('Não foi possível abrir o arquivo'), findsOneWidget);

    await tester.tap(find.byKey(const Key('document_edit')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('document_delete')), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const Key('document_delete')));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('document_delete_confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(deps.documents.list(HealthDocumentKind.exam), isEmpty);
    expect(store().files, isEmpty);
    expect(find.text('Nenhum exame ainda'), findsOneWidget);
  });

  testWidgets('salvar sem nome não grava nada nem deixa arquivo sobrando', (tester) async {
    await pump(tester, ExamsScreen(deps: deps));
    await tester.tap(find.byKey(const Key('document_add')));
    await tester.pumpAndSettle();
    picker.next = PickedDocument(bytes: _png, name: 'foto.png', mimeType: 'image/png');
    await tester.tap(find.byKey(const Key('document_gallery')));
    await tester.pumpAndSettle();
    expect(picker.lastSource, 'gallery');
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('document_save')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(deps.documents.list(HealthDocumentKind.exam), isEmpty);
    expect(store().files, isEmpty);
    expect(find.text('Novo exame'), findsOneWidget);
  });
}
