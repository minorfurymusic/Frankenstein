import 'dart:convert';

import 'package:frankstein_ai/ai.dart';
import 'package:test/test.dart';

class OneReply implements AiTransport {
  final Object json;
  Map<String, dynamic>? sent;
  OneReply(this.json);
  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    sent = jsonDecode(body) as Map<String, dynamic>;
    return AiHttpResponse(200, jsonEncode({
      'candidates': [
        {'content': {'parts': [{'text': jsonEncode(json)}]}},
      ],
    }));
  }
}

void main() {
  test('uma frase, vários registros: água, refeição e remédio com hora; só o texto e a hora vão', () async {
    final t = OneReply({
      'reply': 'Anotei três coisas.',
      'water': [
        {'amount_ml': 2000},
      ],
      'meals': [
        {
          'meal_type': 'breakfast',
          'items': [
            {'name': 'Ovo cozido', 'grams': 150, 'kcal': 219, 'protein_g': 19, 'carbs_g': 1.6, 'fat_g': 14.5},
            {'name': 'Nada', 'grams': 0, 'kcal': 0},
          ],
        },
      ],
      'medication_doses': [
        {'name': 'Dipirona', 'status': 'taken', 'at': '2026-10-05T09:00:00-03:00'},
        {'name': 'Losartana', 'dose_amount': 50, 'status': 'taken'}, // sem unidade: dose descartada
      ],
      'vital_signs': [
        {'kind': 'blood_pressure', 'systolic_mmhg': 120, 'diastolic_mmhg': 80, 'glucose_context': ''},
      ],
      'body_measurements': [
        {'kind': 'weight', 'value': 0},
      ],
      'questions': ['steps'],
    });
    final now = DateTime(2026, 10, 5, 14, 30);
    final r = await readChatMessage(GeminiClient(apiKey: 'k', transport: t), 'bebi 2 L de água, comi 3 ovos e tomei dipirona às 9h', now: now);

    final sent = (t.sent!['contents'] as List).single['parts'] as List;
    expect(sent.single['text'], startsWith('Agora: 2026-10-05T14:30:00'));
    expect(sent.single['text'], endsWith('Mensagem: bebi 2 L de água, comi 3 ovos e tomei dipirona às 9h'));
    expect(t.sent!['systemInstruction'].toString(), contains('Nunca complete, sugira ou corrija dose'));

    expect(r.reply, 'Anotei três coisas.');
    expect(r.water, [
      {'amount_ml': 2000},
    ]);
    expect(r.meals.single.items.single.name, 'Ovo cozido');
    expect(r.doses.first.at, '2026-10-05T12:00:00.000Z');
    expect(r.doses.first.doseAmount, isNull);
    expect(r.doses.last.doseAmount, isNull);
    expect(r.vitalSigns.single, {'kind': 'blood_pressure', 'systolic_mmhg': 120, 'diastolic_mmhg': 80});
    expect(r.bodyMeasurements, isEmpty);
    expect(r.questions, ['steps']);
    expect(r.isEmpty, isFalse);
  });

  test('aviso de procurar atendimento vem como bandeira, não como texto livre', () {
    final r = parseChatReading({
      'reply': 'Anotei.',
      'seek_care': true,
      'symptoms': [
        {'name': 'Dor no peito', 'intensity': 8},
      ],
    });
    expect(r.seekCare, isTrue);
    expect(r.symptoms.single, {'name': 'Dor no peito', 'intensity': 8});
  });

  test('describeNow leva fuso e dia da semana', () {
    final s = describeNow(DateTime(2026, 10, 5, 9, 5));
    expect(s, matches(RegExp(r'^2026-10-05T09:05:00[+-]\d\d:\d\d \(segunda\)$')));
  });
}
