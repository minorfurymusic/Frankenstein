import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';

void main() {
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

  testWidgets('app se chama RLT e usa o tema RLT', (tester) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    final material = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(material.title, 'RLT');
    expect(material.theme!.colorScheme.primary, RltTheme.light().colorScheme.primary);
    expect(material.darkTheme!.colorScheme.primary, RltTheme.dark().colorScheme.primary);
  });

  testWidgets('as 5 abas abrem', (tester) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('nav_saude')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab_saude')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_nutricao')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nutrition_today')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_exercicios')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('tab_exercicios')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_cerebro')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('chat_input')), findsOneWidget);

    await tester.tap(find.byKey(const Key('nav_inicio')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('dashboard_list')), findsOneWidget);
  });

  testWidgets('avatar do Início abre Conta, com Sobre e as seções do layout', (tester) async {
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('account_avatar')));
    await tester.pumpAndSettle();
    expect(find.text('Conta'), findsOneWidget);
    for (final section in ['Perfil', 'Metas', 'Cérebro (IA)', 'Assinatura', 'Privacidade e dados', 'Preferências']) {
      await tester.scrollUntilVisible(find.text(section), 200);
      expect(find.text(section), findsOneWidget, reason: section);
    }
    await tester.scrollUntilVisible(find.byKey(const Key('account_about')), 200);
    expect(find.byKey(const Key('account_about')), findsOneWidget);
  });
}
