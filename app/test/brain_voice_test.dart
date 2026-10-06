import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/ai/ai_settings.dart';
import 'package:frankstein/ai/brain_ai.dart';
import 'package:frankstein/ai/voice_recorder.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/screens/brain/brain_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_health_core/health_core.dart';

import 'support/fonts.dart';

class FakeTransport implements AiTransport {
  Object? reply;
  final List<Map<String, dynamic>> bodies = [];
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    bodies.add(jsonDecode(body) as Map<String, dynamic>);
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(reply)}]}},
      ],
    }));
  }
}

final _aac = Uint8List.fromList([0xFF, 0xF1, 0x50, 0x80, 1, 2, 3, 4]);

void main() {
  setUpAll(loadFigtree);

  late FakeTransport transport;
  late FakeVoiceRecorder recorder;
  late GlobalKey<NavigatorState> nav;
  late AppDependencies deps;

  setUp(() async {
    transport = FakeTransport();
    recorder = FakeVoiceRecorder(next: RecordedAudio(_aac, const Duration(seconds: 14)));
    nav = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(nav),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      secretStore: MemorySecretStore()..values['gemini_api_key'] = 'CHAVE',
      aiTransport: transport,
      voiceRecorder: recorder,
    );
    await deps.ai.load();
    deps.ai.giveConsent();
  });
  tearDown(() => deps.close());

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(420, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(navigatorKey: nav, theme: RltTheme.light(), home: Scaffold(body: BrainScreen(deps: deps))));
    await tester.pumpAndSettle();
  }

  /// Segura o microfone; [dragX] negativo arrasta para cancelar.
  Future<void> holdMic(WidgetTester tester, {double dragX = 0}) async {
    final g = await tester.startGesture(tester.getCenter(find.byKey(const Key('chat_mic'))));
    await tester.pump(const Duration(milliseconds: 700)); // vira toque longo: começa a gravar
    await tester.pump();
    if (dragX != 0) {
      await g.moveBy(Offset(dragX, 0));
      await tester.pump();
    }
    await g.up();
    await tester.pumpAndSettle();
  }

  testWidgets('voz: segura, fala e solta — o áudio vai, volta a transcrição e o treino vira cartão', (tester) async {
    transport.reply = {
      'reply': 'Anotei o treino.',
      'transcript': 'fiz 3 séries de supino com 30 quilos, 10 repetições',
      'workouts': [
        {'exercise': 'supino reto', 'sets': 3, 'reps': 10, 'load_kg': 30},
      ],
    };
    await pump(tester);
    expect(find.byKey(const Key('chat_mic')), findsOneWidget);
    await holdMic(tester);

    final parts = (transport.bodies.single['contents'] as List).single['parts'] as List;
    expect(parts.first['inlineData']['mimeType'], 'audio/aac');
    expect(base64Decode(parts.first['inlineData']['data'] as String), _aac);
    expect(find.text('Mensagem de voz · 0:14'), findsOneWidget);
    expect(find.text('Transcrição: “fiz 3 séries de supino com 30 quilos, 10 repetições”'), findsOneWidget);
    expect(find.text('Supino reto — 3 × 10'), findsOneWidget);
    expect(find.text('30 kg · treino de hoje'), findsOneWidget);

    await tester.tap(find.byKey(const Key('confirmation_confirm')));
    await tester.pumpAndSettle();
    final session = deps.core.queryByType(HealthEventType.workoutSession).single;
    expect(session.payload['sets_count'], 3);
    expect(session.payload['exercise_ids'], ['supino-reto']);
    final sets = deps.core.queryByType(HealthEventType.setLog);
    expect(sets.map((s) => (s.payload['reps'], s.payload['load_kg'])).toSet(), {(10, 30.0)});
  });

  testWidgets('arrastar para a esquerda cancela: nada é enviado', (tester) async {
    await pump(tester);
    await holdMic(tester, dragX: -120);
    expect(recorder.cancelled, isTrue);
    expect(transport.bodies, isEmpty);
    expect(find.byKey(const Key('brain_voice_msg')), findsNothing);
  });

  testWidgets('sem permissão de microfone: explica onde liberar e não grava', (tester) async {
    recorder.granted = false;
    await pump(tester);
    await holdMic(tester);
    expect(recorder.permissionRequests, 1);
    expect(find.textContaining('permita o microfone'), findsOneWidget);
    expect(transport.bodies, isEmpty);
  });

  testWidgets('toque curto não envia: pede para segurar enquanto fala', (tester) async {
    recorder.next = RecordedAudio(_aac, const Duration(milliseconds: 300));
    await pump(tester);
    await holdMic(tester);
    expect(find.text('Segure o botão do microfone enquanto fala.'), findsOneWidget);
    expect(transport.bodies, isEmpty);
  });

  test('exercício casado com a biblioteca; o que não existe vira exercício livre', () {
    expect(matchExercise('SUPINO RETO')?.id, 'supino-reto');
    expect(matchExercise('leg press')?.id, 'leg-press');
    expect(matchExercise('supino'), isNull); // reto ou inclinado: ambíguo
    final plan = planFromReading(
      const ChatReading(workouts: [ChatWorkout(exercise: 'Remada cavalinho', sets: 2, reps: 12, loadKg: 20)]),
      medications: const [],
      now: DateTime(2026, 10, 6, 18),
    );
    final sets = (plan.calls.single.params['sets'] as List).cast<Map<String, dynamic>>();
    expect(sets.map((s) => s['exercise_id']).toSet(), {'livre-remada-cavalinho'});
    expect(sets.map((s) => s['set_number']), [1, 2]);
  });
}
