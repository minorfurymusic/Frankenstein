import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/screens/exercise/activity_screens.dart';
import 'package:frankstein/screens/exercise/exercise_tab.dart';
import 'package:frankstein/screens/exercise/gym_screens.dart';
import 'package:frankstein/screens/home/home_screen.dart';
import 'package:frankstein/screens/nutrition/add_food_screen.dart';
import 'package:frankstein/screens/nutrition/nutrition_tab.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/step_tracking_controller.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein/widgets/state_views.dart';

import 'support/fonts.dart';

/// Estados das pranchetas InicioEstados, NutricaoEstados,
/// ExerciciosEstados, AcademiaEstados e CorridaEstados.
void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  var closed = false;

  setUp(() {
    closed = false;
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
    );
  });
  tearDown(() {
    try {
      deps.close();
    } catch (_) {
      // O teste de erro já fechou o banco de saúde de propósito.
      if (!closed) rethrow;
    }
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: Scaffold(body: home)));
    await tester.pumpAndSettle();
  }

  testWidgets('erro ao ler: mostra o aviso da prancheta e "Tentar de novo" monta a tela outra vez', (tester) async {
    var fail = true;
    await pump(
      tester,
      GuardedView(
        errorTitle: 'Não foi possível carregar as refeições',
        builder: (_) => fail ? throw StateError('banco fechado') : const Text('refeições'),
      ),
    );
    expect(find.byKey(const Key('state_error')), findsOneWidget);
    expect(find.text('Não foi possível carregar as refeições'), findsOneWidget);
    expect(find.text('Seus registros continuam salvos no celular. Tente de novo.'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('refeições'), findsOneWidget);
  });

  testWidgets('Início com o banco indisponível: erro em vez de tela quebrada', (tester) async {
    deps.core.close(); // banco de saúde indisponível
    closed = true;
    await pump(tester, HomeScreen(deps: deps, onOpenAccount: () {}, onOpenTab: (_) {}));
    expect(tester.takeException(), isNull);
    expect(find.text('Não foi possível abrir os dados de hoje'), findsOneWidget);
    expect(find.textContaining('se continuar, reinicie o app'), findsOneWidget);
  });

  testWidgets('Nutrição sem refeição: convite da prancheta abre Adicionar alimento', (tester) async {
    await pump(tester, NutritionDayView(deps: deps));
    expect(find.byKey(const Key('nutrition_empty')), findsOneWidget);
    expect(find.text('Nenhuma refeição hoje'), findsOneWidget);
    expect(find.text('Busque um alimento, leia o código de barras ou fotografe o prato.'), findsOneWidget);
    await tester.tap(find.text('Adicionar alimento'));
    await tester.pumpAndSettle();
    expect(find.byType(AddFoodScreen), findsOneWidget);
  });

  testWidgets('Exercícios: sem plano convida a criar; passos sem permissão e sem sensor têm o próprio aviso', (tester) async {
    await pump(tester, ExerciseTab(deps: deps));
    expect(find.text('Nenhum treino planejado'), findsOneWidget);
    expect(find.byKey(const Key('exercise_steps_permission')), findsNothing);

    deps.stepTracking.status.value = StepTrackingStatus.permissionDenied;
    await tester.pumpAndSettle();
    expect(find.text('Contagem de passos desligada'), findsOneWidget);
    expect(find.text('Permitir contagem de passos'), findsOneWidget);

    deps.stepTracking.status.value = StepTrackingStatus.noSensor;
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise_steps_no_sensor')), findsOneWidget);
    expect(find.text('Conectar dispositivo'), findsOneWidget);

    await tester.tap(find.text('Criar plano de treino'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanFormScreen), findsOneWidget);
  });

  testWidgets('Academia e Corrida vazias: textos das pranchetas', (tester) async {
    await pump(tester, GymScreen(deps: deps));
    expect(find.text('Nenhum plano de treino'), findsOneWidget);
    expect(find.textContaining('Ou conte ao Cérebro o que você fez.'), findsOneWidget);

    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: RunsScreen(deps: deps)));
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma corrida ainda'), findsOneWidget);
  });
}
