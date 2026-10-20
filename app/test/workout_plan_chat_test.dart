import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/reminders/reminders.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<Object> replies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': jsonEncode(replies.removeAt(0))},
            ],
          },
        },
      ],
    }));
  }
}

void main() {
  setUpAll(loadFigtree);

  late FakeTransport transport;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = FakeTransport();
    nav = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(nav),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      secretStore: MemorySecretStore()..values['gemini_api_key'] = 'CHAVE',
      aiTransport: transport,
    );
    await deps.ai.load();
    deps.ai.giveConsent();
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
  }

  testWidgets('"crie o treino para mim às 18:30": vira plano e lembrete, não treino feito', (tester) async {
    transport.replies.add({
      'reply': 'Montei o seu treino.',
      'workout_plan': {
        'time': '18:30',
        'exercises': [
          {'exercise': 'Supino reto', 'sets': 3, 'reps': 12, 'load_kg': 34},
          {'exercise': 'Agachamento sem peso', 'sets': 3, 'reps': 20, 'load_kg': 0},
        ],
      },
    });
    await pump(tester);
    await tester.enterText(find.byKey(const Key('chat_input')), 'crie o treino para mim com o horário para as 18:30');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();

    expect(find.text('Plano de treino — Meu treino'), findsOneWidget);
    expect(find.textContaining('Supino reto — 3 × 12 · 34 kg'), findsOneWidget);
    expect(find.textContaining('Agachamento sem peso — 3 × 20 · peso do corpo'), findsOneWidget);
    expect(find.textContaining('todo dia às 18:30'), findsOneWidget);
    expect(deps.workoutRepository.listPlans(), isEmpty, reason: 'nada salvo antes de confirmar');

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    final plan = deps.workoutRepository.listPlans().single;
    expect(plan.name, 'Meu treino');
    expect(plan.exercises.map((e) => (e.exerciseId, e.targetSets, e.targetReps, e.targetLoadKg)), [
      ('supino-reto', 3, 12, 34.0),
      ('livre-agachamento-sem-peso', 3, 20, null),
    ]);
    final prefs = ReminderPrefs.fromSettings(deps.profileRepository);
    expect((prefs.workoutOn, prefs.workoutMinutes), (true, 18 * 60 + 30));
    expect(deps.core.queryAllVersions(HealthEventType.setLog), isEmpty);
    expect(deps.core.queryAllVersions(HealthEventType.workoutSession), isEmpty);
  });

  testWidgets('plano sem horário não mexe no lembrete; a água continua como estava', (tester) async {
    deps.profileRepository.setSetting('reminders', jsonEncode({'water_on': true, 'water_every_hours': 3, 'workout_on': false, 'workout_time': 1080}));
    transport.replies.add({
      'reply': 'Montei o Treino A.',
      'workout_plan': {
        'name': 'Treino A',
        'exercises': [
          {'exercise': 'Leg press', 'sets': 4, 'reps': 10, 'load_kg': 100},
        ],
      },
    });
    await pump(tester);
    await tester.enterText(find.byKey(const Key('chat_input')), 'monta meu treino A: leg press 4x10 com 100 kg');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lembrete'), findsNothing);
    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();

    expect(deps.workoutRepository.listPlans().single.name, 'Treino A');
    final prefs = ReminderPrefs.fromSettings(deps.profileRepository);
    expect((prefs.waterOn, prefs.waterEveryHours, prefs.workoutOn), (true, 3, false));
  });
}
