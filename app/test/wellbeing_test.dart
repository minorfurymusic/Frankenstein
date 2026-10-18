import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/insights/wellbeing.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  final List<Object> replies = [];
  final List<String> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(body);
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
  late AppDependencies deps;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12);

  setUp(() async {
    transport = FakeTransport();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      secretStore: MemorySecretStore()..values['gemini_api_key'] = 'CHAVE',
      aiTransport: transport,
    );
    await deps.ai.load();
    deps.ai.giveConsent();
  });
  tearDown(() => deps.close());

  void meal(DateTime local, double kcal, double sugar) {
    final food = deps.nutrition.createEstimatedFood(name: 'Bolo', grams: 100, kcal: kcal, carbs: 50, sugar: sugar);
    deps.mealLogger.logMeal(
      items: [MealItemInput(foodId: food.id, grams: 100)],
      mealType: MealType.snack,
      occurredAt: local.toUtc(),
      occurredAtTzOffsetMinutes: local.timeZoneOffset.inMinutes,
    );
  }

  void seed() {
    deps.profileRepository.save(Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 1.80));
    deps.bodyLogger.weight(kg: 80, occurredAt: today.subtract(const Duration(days: 20)).toUtc(), occurredAtTzOffsetMinutes: 0);
    deps.bodyLogger.weight(kg: 81.2, occurredAt: today.toUtc(), occurredAtTzOffsetMinutes: 0);
    for (var d = 0; d < 5; d++) {
      meal(today.subtract(Duration(days: d)), 2600, 60);
    }
    final low = today.subtract(const Duration(days: 1));
    deps.moodLogger.log(mood: 1, feelings: const ['triste'], occurredAt: low.toUtc(), occurredAtTzOffsetMinutes: 0);
  }

  test('resumos: comida, açúcar e peso; humor só com o consentimento próprio', () {
    seed();
    final s = buildWellbeingSnapshot(deps, now: today);
    expect(s.text, contains('Comida: 5 de 7 dias com registro; média de 2.600 kcal/dia'));
    expect(s.text, contains('acima da meta em'));
    expect(s.text, contains('Açúcar (onde foi estimado): média de 60 g/dia'));
    expect(s.text, contains('80,0 kg'));
    expect(s.text, contains('+1,2 kg'));
    expect(s.text, isNot(contains('Humor')));
    expect(s.includesMental, isFalse);

    deps.ai.mentalHealthConsent = true;
    final withMental = buildWellbeingSnapshot(deps, now: today);
    expect(withMental.text, contains('Humor (1 a 5) em 14 dias: média 1,0; 1 registros "mal" ou "muito mal"; sentimentos mais marcados: triste'));
  });

  testWidgets('"Como estou?" no Cérebro: mostra o que foi, a IA responde e as sugestões viram toques', (tester) async {
    seed();
    transport.replies.add({
      'summary': 'Seu peso subiu um pouco nas últimas semanas.',
      'observations': ['O peso subiu 1,2 kg enquanto as calorias ficaram acima da meta.'],
      'suggestions': ['Me ajude a trocar o doce da tarde'],
    });
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('brain_example_Como estou?')));
    await tester.pumpAndSettle();

    final sent = transport.bodies.single;
    expect(sent, contains('Açúcar (onde foi estimado)'));
    expect(sent, isNot(contains('Humor'))); // sem o consentimento próprio
    expect(sent, isNot(contains('triste')));
    expect(find.textContaining('O que foi para a IA:'), findsOneWidget);
    expect(find.textContaining('Seu peso subiu um pouco'), findsOneWidget);
    expect(find.textContaining('• O peso subiu 1,2 kg'), findsOneWidget);
    expect(find.byKey(const Key('brain_reply_Me ajude a trocar o doce da tarde')), findsOneWidget);
  });

  testWidgets('sem dados, não chama a IA e diz o que registrar', (tester) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('chat_input')), 'como eu tô?');
    await tester.pump();
    await tester.tap(find.byKey(const Key('chat_send')));
    await tester.pumpAndSettle();
    expect(transport.bodies, isEmpty);
    expect(find.textContaining('Ainda não há registros suficientes'), findsOneWidget);
  });
}
