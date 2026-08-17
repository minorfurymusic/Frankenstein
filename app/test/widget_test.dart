import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

class _TestApp {
  final AppDependencies dependencies;
  final Widget widget;
  final FakeShareSheet shareSheet;
  _TestApp(this.dependencies, this.widget, this.shareSheet);
}

_TestApp _buildTestApp() {
  final navigatorKey = GlobalKey<NavigatorState>();
  final shareSheet = FakeShareSheet();
  final dependencies = AppDependencies.inMemory(
    confirmationGate: AppConfirmationGate(navigatorKey),
    shareSheet: shareSheet,
    imageCapturer: FakeCardImageCapturer(),
  );
  final widget = FrankstitApp(dependencies: dependencies, navigatorKey: navigatorKey);
  return _TestApp(dependencies, widget, shareSheet);
}

// "Hoje" ao meio-dia UTC — não a meia-noite (evita o evento cair no dia
// UTC errado por causa da hora exata em que o teste rodar) nem uma data
// fixa (`DashboardScreen`/`get_daily_summary` consultam o dia real via
// `DateTime.now()`; uma data hardcoded quebra sozinha quando o relógio
// real passa dela — já aconteceu neste projeto).
DateTime _todayNoonUtc() {
  final now = DateTime.now().toUtc();
  return DateTime.utc(now.year, now.month, now.day, 12, 0);
}

HealthEvent _insertWorkoutSessionEvent(HealthDataCore core) {
  final event = HealthEvent(
    id: HealthDataCore.newId(),
    type: HealthEventType.workoutSession,
    source: HealthEventSource.manual,
    occurredAt: _todayNoonUtc(),
    occurredAtTzOffsetMinutes: -180,
    recordedAt: _todayNoonUtc().add(const Duration(minutes: 30)),
    payload: const {'sets_count': 10, 'exercise_ids': ['supino-reto']},
    confidence: 1.0,
  );
  core.insertEvent(event);
  return event;
}

HealthEvent _insertGpsTrackEvent(HealthDataCore core) {
  final event = HealthEvent(
    id: HealthDataCore.newId(),
    type: HealthEventType.gpsTrack,
    source: HealthEventSource.manual,
    occurredAt: _todayNoonUtc(),
    occurredAtTzOffsetMinutes: -180,
    recordedAt: _todayNoonUtc().add(const Duration(minutes: 30)),
    payload: const {
      'distance_meters': 5000.0,
      'duration_seconds': 1800,
      'average_pace_seconds_per_km': 360.0,
    },
    confidence: 1.0,
  );
  core.insertEvent(event);
  core.insertGpsTrackPoints([
    for (var m = 0; m <= 1000; m += 100)
      GpsTrackPoint(
        eventId: event.id,
        seq: m ~/ 100,
        latitude: -23.0 + m / 111194.926644,
        longitude: -46.0,
        recordedAt: event.occurredAt.add(Duration(seconds: m)),
      ),
  ]);
  return event;
}

void main() {
  testWidgets('app sobe na aba Resumo, com o dashboard carregado (zerado, sem eventos)',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('bottom_nav')), findsOneWidget);
    expect(find.byKey(const Key('dashboard_list')), findsOneWidget);
    expect(find.text('0'), findsOneWidget); // passos
  });

  testWidgets('alterna para a aba Chat pelo bottom nav', (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('chat_input')), findsOneWidget);
  });

  testWidgets('comando de leitura reconhecido ("resumo de hoje") mostra resposta do get_daily_summary',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat_input')), 'resumo de hoje');
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('get_daily_summary'), findsOneWidget);
  });

  testWidgets('comando não reconhecido pelo roteador determinístico fica unresolved',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('chat_input')), 'oi, tudo bem?');
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não entendi'), findsOneWidget);
  });

  testWidgets('log_meal confirmado grava HealthEvent de verdade (comida real do catálogo TACO)',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'registrar refeição lunch: taco-1 150g',
    );
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    // Ferramenta de escrita — precisa aparecer o diálogo de confirmação
    // antes de qualquer coisa ser gravada (.claude/rules/brain.md, passo 4).
    expect(find.byKey(const Key('confirmation_confirm')), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('log_meal'), findsOneWidget);
    final mealEvents = app.dependencies.core.queryByType(HealthEventType.meal);
    expect(mealEvents, hasLength(1));
    expect(mealEvents.single.payload['meal_type'], 'lunch');
  });

  testWidgets('log_meal recusado no diálogo não grava nada', (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('chat_input')),
      'registrar refeição dinner: taco-1 100g',
    );
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('confirmation_cancel')));
    await tester.pumpAndSettle();

    expect(find.textContaining('não registrei nada'), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);
  });

  testWidgets('compartilhar treino: preview obrigatório aparece, share só acontece no toque',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    _insertWorkoutSessionEvent(app.dependencies.core);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('share_latest_workout')), findsOneWidget);
    await tester.tap(find.byKey(const Key('share_latest_workout')));
    await tester.pumpAndSettle();

    // Preview obrigatório: o card aparece antes de qualquer compartilhamento,
    // e nada foi compartilhado só por abrir a tela (.claude/rules/share.md).
    expect(find.byKey(const Key('workout_card_visual')), findsOneWidget);
    expect(find.text('10 séries'), findsOneWidget);
    expect(app.shareSheet.called, isFalse);

    // FakeCardImageCapturer no lugar do RepaintBoundary.toImage() real —
    // essa parte depende do pipeline de rasterização do engine, que não
    // completa neste ambiente headless (`app/lib/card_image_capturer.dart`).
    await tester.tap(find.byKey(const Key('share_button')));
    await tester.pumpAndSettle();

    expect(app.shareSheet.called, isTrue);
    expect(app.shareSheet.lastFileName, 'treino.png');
    expect(app.shareSheet.lastBytes, isNotEmpty);
  });

  testWidgets('compartilhar corrida: rota chega ofuscada no card (não crua)',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    _insertGpsTrackEvent(app.dependencies.core);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('share_latest_run')), findsOneWidget);
    await tester.tap(find.byKey(const Key('share_latest_run')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_card_visual')), findsOneWidget);
    // Rota de 1000 m — obfuscateRouteEnds corta os 300 m iniciais/finais,
    // então o card mostra menos pontos que a rota original de 11.
    expect(find.textContaining('pontos de rota (ofuscada)'), findsOneWidget);

    await tester.tap(find.byKey(const Key('share_button')));
    await tester.pumpAndSettle();

    expect(app.shareSheet.called, isTrue);
    expect(app.shareSheet.lastFileName, 'corrida.png');
  });

  testWidgets('sem treino/corrida gravados, botões de compartilhar não aparecem',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('share_latest_workout')), findsNothing);
    expect(find.byKey(const Key('share_latest_run')), findsNothing);
  });

  Future<void> sendChat(WidgetTester tester, String text) async {
    await tester.tap(find.text('Chat'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat_input')), text);
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
  }

  testWidgets('comando "buscar alimento" (search_food) encontra comida real do catálogo TACO',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await sendChat(tester, 'buscar alimento arroz');

    expect(find.textContaining('search_food'), findsOneWidget);
    // "arroz" bate em vários itens reais do TACO — a mensagem de resposta
    // não é vazia (results não é []).
    expect(find.textContaining('results: []'), findsNothing);
  });

  testWidgets('comando "plano de treino" (get_workout_plan) lê um plano real cadastrado',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    app.dependencies.workoutRepository.insertPlan(WorkoutPlan(
      id: 'plano-peito',
      name: 'Treino A — peito',
      exercises: [
        PlannedExercise(exerciseId: 'supino-reto', exerciseName: 'Supino reto', targetSets: 4, targetReps: 8),
      ],
    ));

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await sendChat(tester, 'plano de treino plano-peito');

    expect(find.textContaining('get_workout_plan'), findsOneWidget);
    expect(find.textContaining('Treino A'), findsOneWidget);
  });

  testWidgets('comando "resumo da corrida" (get_run_summary) lê um gps_track real gravado',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    final run = _insertGpsTrackEvent(app.dependencies.core);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await sendChat(tester, 'resumo da corrida ${run.id}');

    expect(find.textContaining('get_run_summary'), findsOneWidget);
    expect(find.textContaining('5000.0'), findsOneWidget);
  });

  testWidgets('comando "registrar treino" (log_workout_session) confirmado grava HealthEvent de verdade',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    expect(app.dependencies.core.queryByType(HealthEventType.workoutSession), isEmpty);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();
    await sendChat(tester, 'registrar treino: supino-reto 1x8x70, supino-reto 2x6x75');

    // Ferramenta de escrita — precisa do diálogo de confirmação antes de
    // gravar (.claude/rules/brain.md, passo 4).
    expect(find.byKey(const Key('confirmation_confirm')), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.workoutSession), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    expect(find.textContaining('log_workout_session'), findsOneWidget);
    final events = app.dependencies.core.queryByType(HealthEventType.workoutSession);
    expect(events, hasLength(1));
    expect(events.single.payload['sets_count'], 2);
    final setLogs = app.dependencies.core.queryByType(HealthEventType.setLog);
    expect(setLogs, hasLength(2));
    expect(setLogs[0].payload['load_kg'], 70.0);
    expect(setLogs[1].payload['load_kg'], 75.0);
  });

  testWidgets('dashboard: "+" da água registra de verdade via diálogo rápido',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    expect(app.dependencies.core.queryByType(HealthEventType.water), isEmpty);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_add_water')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('quick_water_300ml')));
    await tester.pumpAndSettle();

    // Escrita — mesmo diálogo de confirmação de qualquer outra ferramenta.
    expect(find.byKey(const Key('confirmation_confirm')), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.water), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    final events = app.dependencies.core.queryByType(HealthEventType.water);
    expect(events, hasLength(1));
    expect(events.single.payload['amount_ml'], 300.0);
    expect(find.text('300.0 ml'), findsOneWidget);
  });

  testWidgets('dashboard: "+" da refeição abre busca real, registra via LogMealScreen',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_add_meal')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('log_meal_search_field')), 'arroz');
    await tester.pumpAndSettle();

    // "arroz" bate em vários itens reais do catálogo TACO — pega o primeiro.
    expect(find.byType(ListTile), findsWidgets);
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('log_meal_grams_field')), '150');
    await tester.tap(find.byKey(const Key('log_meal_confirm_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirmation_confirm')), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.meal), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    final events = app.dependencies.core.queryByType(HealthEventType.meal);
    expect(events, hasLength(1));
    expect(events.single.payload['items'], hasLength(1));
    expect((events.single.payload['items'] as List).single['grams'], 150.0);
  });

  testWidgets('dashboard: "+" do treino abre formulário real, registra via LogWorkoutScreen',
      (WidgetTester tester) async {
    final app = _buildTestApp();
    addTearDown(app.dependencies.close);
    expect(app.dependencies.core.queryByType(HealthEventType.workoutSession), isEmpty);

    await tester.pumpWidget(app.widget);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('dashboard_add_workout')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('log_workout_exercise_field')), 'supino-reto');
    await tester.enterText(find.byKey(const Key('log_workout_sets_field')), '2');
    await tester.enterText(find.byKey(const Key('log_workout_reps_field')), '8');
    await tester.enterText(find.byKey(const Key('log_workout_load_field')), '60');
    await tester.tap(find.byKey(const Key('log_workout_submit_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('confirmation_confirm')), findsOneWidget);
    expect(app.dependencies.core.queryByType(HealthEventType.workoutSession), isEmpty);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    final events = app.dependencies.core.queryByType(HealthEventType.workoutSession);
    expect(events, hasLength(1));
    expect(events.single.payload['sets_count'], 2);
    final setLogs = app.dependencies.core.queryByType(HealthEventType.setLog);
    expect(setLogs, hasLength(2));
    expect(setLogs.every((s) => s.payload['load_kg'] == 60.0), isTrue);
  });
}
