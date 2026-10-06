import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/app_version.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/screens/account/about_screen.dart';
import 'package:frankstein/screens/nutrition/add_food_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import 'support/fonts.dart';

/// Acabamentos: pranchetas ContaSobre, AdicaoRapida, CodigoBarras e
/// InicioFonteGrande.
void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  setUp(() {
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: home));
    await tester.pumpAndSettle();
  }

  test('a versão mostrada no app é a do pubspec.yaml', () {
    final line = File('pubspec.yaml').readAsLinesSync().firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':').last.trim().split('+').first, kAppVersion);
  });

  testWidgets('Sobre: versão, aviso de saúde, licenças, privacidade e termos', (tester) async {
    await pump(tester, const AboutScreen());
    expect(find.text('RLT — Real Life Track'), findsOneWidget);
    expect(find.text('Versão $kAppVersion'), findsOneWidget);
    expect(find.textContaining('não faz diagnóstico nem prescrição'), findsOneWidget);
    await tester.tap(find.byKey(const Key('about_privacy')));
    await tester.pumpAndSettle();
    expect(find.text('Nossos compromissos'), findsOneWidget);
    expect(find.textContaining('sem custo e sem limite'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('about_licenses')));
    await tester.pumpAndSettle();
    expect(find.byType(LicensePage), findsOneWidget);
  });

  testWidgets('adição rápida: "Salvar como item meu" desligado não entra em Meus itens', (tester) async {
    Food? created;
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async => created = await Navigator.of(context).push<Food>(MaterialPageRoute(builder: (_) => QuickAddScreen(deps: deps))),
          child: const Text('abrir'),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Para adicionar com um toque depois'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('quick_name')), 'Café com leite');
    await tester.enterText(find.byKey(const Key('quick_kcal')), '120');
    await tester.tap(find.byKey(const Key('quick_save_mine')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quick_save')));
    await tester.pumpAndSettle();
    expect(created?.name, 'Café com leite');
    expect(deps.nutrition.myItems(), isEmpty);
  });

  testWidgets('código não encontrado: tela da prancheta; "Ler outro código" lê de novo e "Cadastrar produto" abre o cadastro',
      (tester) async {
    await pump(tester, AddFoodScreen(deps: deps, mealType: MealType.snack));
    await tester.tap(find.byKey(const Key('add_barcode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('barcode_input')), '7891234567895');
    await tester.tap(find.byKey(const Key('barcode_ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('barcode_not_found')), findsOneWidget);
    expect(find.textContaining('O código 7891234567895 não está no catálogo.'), findsOneWidget);

    await tester.tap(find.text('Ler outro código'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('barcode_input')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('barcode_input')), '7891234567895');
    await tester.tap(find.byKey(const Key('barcode_ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cadastrar produto'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickAddScreen), findsOneWidget);
    expect(find.text('Novo item'), findsOneWidget);
  });

  testWidgets('fonte do sistema em 160%: Início, Nutrição, Saúde e Cérebro sem quebrar o layout', (tester) async {
    final when = DateTime.now();
    deps.waterLogger.log(amountMl: 500, occurredAt: when.toUtc(), occurredAtTzOffsetMinutes: when.timeZoneOffset.inMinutes);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(FrankstitApp(dependencies: deps, navigatorKey: nav));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Início');
    for (final tab in ['Nutrição', 'Saúde', 'Cérebro', 'Exercícios']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: tab);
    }
    expect(HealthEventType.water, isNotNull);
  });
}
