import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/data/data_export.dart';
import 'package:frankstein/documents/document_files.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/screens/account/account_more_screens.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  AppDependencies memoryDeps(FakeShareSheet share) => AppDependencies.inMemory(
        confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
        shareSheet: share,
        imageCapturer: FakeCardImageCapturer(),
      );

  testWidgets('exportar todos os dados gera .zip (JSON + arquivos de exames) e sai pelo compartilhamento', (tester) async {
    final share = FakeShareSheet();
    final deps = memoryDeps(share);
    addTearDown(deps.close);
    final now = DateTime.now();
    deps.waterLogger.log(amountMl: 400, occurredAt: now.toUtc(), occurredAtTzOffsetMinutes: -180);
    final pdf = await deps.documentFiles.store(
      PickedDocument(bytes: Uint8List.fromList(utf8.encode('%PDF-1.4 teste')), name: 'hemograma.pdf', mimeType: 'application/pdf'),
    );
    deps.documents.save(HealthDocument(
      id: 'e1',
      kind: HealthDocumentKind.exam,
      title: 'Hemograma',
      category: ExamCategory.blood,
      files: [pdf],
    ));
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: PrivacyScreen(deps: deps)));
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('export_all')));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(share.lastFileName, allOf(startsWith('rlt-dados-'), endsWith('.zip')));
    expect(share.lastFileMimeType, 'application/zip');
    final zip = ZipDecoder().decodeBytes(share.lastBytes!);
    final pdfInZip = zip.findFile('arquivos/${pdf.storedName}')!;
    expect(utf8.decode(pdfInZip.content as List<int>), '%PDF-1.4 teste');
    final json = jsonDecode(utf8.decode(zip.findFile('dados.json')!.content as List<int>)) as Map<String, dynamic>;
    expect(json['format'], 'rlt-export');
    final doc = (json['health_documents'] as List).single as Map<String, dynamic>;
    expect(doc['title'], 'Hemograma');
    expect(doc['files'][0]['path_in_export'], 'arquivos/${pdf.storedName}');
    final water = (json['events'] as List).cast<Map<String, dynamic>>().where((e) => e['type'] == 'water').single;
    expect(water['payload']['amount_ml'], 400);
    expect(water['tz_offset_minutes'], -180);
  });

  test('exportação com o app vazio não quebra e vem com listas vazias', () {
    final deps = memoryDeps(FakeShareSheet());
    addTearDown(deps.close);
    final e = buildFullExport(deps);
    expect(e['medications'], isEmpty);
    expect(e['events'], isEmpty);
  });

  testWidgets('apagar todos os dados: só com APAGAR digitado; apaga os arquivos do banco', (tester) async {
    final dir = Directory.systemTemp.createTempSync('rlt_erase_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final deps = AppDependencies.open(
      dbDirectoryPath: dir.path,
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
    addTearDown(deps.close);
    deps.waterLogger.log(amountMl: 200, occurredAt: DateTime.now().toUtc(), occurredAtTzOffsetMinutes: 0);
    expect(File('${dir.path}/frankstein_health.sqlite3').existsSync(), isTrue);
    late HealthDocumentFile photo;
    await tester.runAsync(() async {
      photo = await deps.documentFiles.store(PickedDocument(bytes: Uint8List(10), name: 'receita.jpg', mimeType: 'image/jpeg'));
    });
    final photoFile = File('${dir.path}/${AppDependencies.documentsDirName}/${photo.storedName}');
    expect(photoFile.existsSync(), isTrue);

    var closed = false;
    await tester.pumpWidget(MaterialApp(
      theme: RltTheme.light(),
      home: EraseDataScreen(deps: deps, onErased: () async => closed = true),
    ));
    expect(tester.widget<FilledButton>(find.byKey(const Key('erase_confirm'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('erase_word')), 'apagar');
    await tester.pump();
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const Key('erase_confirm')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('erase_done')), findsOneWidget);
    for (final name in AppDependencies.dbFileNames) {
      expect(File('${dir.path}/$name').existsSync(), isFalse, reason: name);
    }
    expect(photoFile.existsSync(), isFalse);
    await tester.tap(find.byKey(const Key('erase_close_app')));
    expect(closed, isTrue);
  });

  testWidgets('Conta abre Privacidade, Permissões, Assinatura (sem preço) e Cérebro', (tester) async {
    final deps = memoryDeps(FakeShareSheet());
    addTearDown(deps.close);
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<NavigatorState>();
    await tester.pumpWidget(FrankstitApp(dependencies: deps, navigatorKey: key));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('account_avatar')));
    await tester.pumpAndSettle();

    Future<void> openAndBack(String section, String expectText) async {
      await tester.tap(find.byKey(Key('account_$section')));
      await tester.pumpAndSettle();
      expect(find.textContaining(expectText), findsWidgets, reason: section);
      await tester.pageBack();
      await tester.pumpAndSettle();
    }

    await openAndBack('Privacidade e dados', 'Exportar todos os dados');
    await openAndBack('Permissões', 'Atividade física');
    await openAndBack('Cérebro (IA)', 'Modo atual: básico');
    await tester.tap(find.byKey(const Key('account_Assinatura')));
    await tester.pumpAndSettle();
    expect(find.text('Plano atual: Grátis'), findsOneWidget);
    expect(find.text('Relatório para levar à consulta'), findsOneWidget);
    expect(find.textContaining(RegExp(r'R\$|US\$|/mês|comprar|preço', caseSensitive: false)), findsNothing);
    expect(find.textContaining('Mais espaço'), findsNothing); // removido pela ADR-14
  });

  test('HealthEventType cobre os tipos exportados', () {
    expect(HealthEventType.values.map((t) => t.wireValue), contains('medication_dose'));
  });
}
