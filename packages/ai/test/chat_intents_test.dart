import 'dart:convert';
import 'dart:typed_data';

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

  test('mensagem de voz: o áudio vai como anexo, volta a transcrição e o treino', () async {
    final t = OneReply({
      'reply': 'Anotei o treino.',
      'transcript': 'fiz 3 séries de supino com 30 quilos, 10 repetições',
      'workouts': [
        {'exercise': 'Supino reto', 'sets': 3, 'reps': 10, 'load_kg': 30},
        {'exercise': 'Prancha', 'sets': 0, 'reps': 1},
        {'exercise': 'Flexão', 'sets': 3, 'reps': 15},
      ],
    });
    final audio = AiPart.file(Uint8List.fromList([0xFF, 0xF1, 1, 2]), 'audio/aac');
    final r = await readChatMessage(GeminiClient(apiKey: 'k', transport: t), '', now: DateTime(2026, 10, 6, 18, 40), audio: audio);
    final parts = (t.sent!['contents'] as List).single['parts'] as List;
    expect(parts.first['inlineData']['mimeType'], 'audio/aac');
    expect(parts.last['text'], contains('mensagem de voz no áudio anexo'));
    expect(r.transcript, 'fiz 3 séries de supino com 30 quilos, 10 repetições');
    expect(r.workouts.map((w) => (w.exercise, w.sets, w.reps, w.loadKg)), [('Supino reto', 3, 10, 30.0), ('Flexão', 3, 15, 0.0)]);
    expect(r.isEmpty, isFalse);
  });

  test('bebida vem marcada como líquida (ml), não gramas', () {
    final r = parseChatReading({
      'meals': [
        {
          'meal_type': 'snack',
          'items': [
            {'name': 'Energético sem açúcar', 'grams': 1000, 'liquid': true, 'kcal': 15},
            {'name': 'Pão', 'grams': 50, 'kcal': 130},
          ],
        },
      ],
    });
    expect(r.meals.single.items.map((i) => (i.name, i.liquid)), [('Energético sem açúcar', true), ('Pão', false)]);
  });

  test('remédio sem horário: o aviso usa a dose dita; sem dose, pede a da receita — nunca sugere número', () {
    final r = parseChatReading({
      'reply': 'Ok.',
      'new_medications': [
        {'name': 'Creatina', 'dose_amount': 6, 'dose_unit': 'g', 'times': []},
        {'name': 'Hidroclorotiazida', 'times': []},
      ],
    });
    expect(r.newMedications, isEmpty);
    expect(r.incomplete, [
      'Para cadastrar Creatina 6 g, me diga os horários (ex.: "às 08:00 e às 20:00").',
      'Para cadastrar Hidroclorotiazida, me diga a dose (como está na receita ou na embalagem) e os horários.',
    ]);
  });

  test('a instrução proíbe perguntar de novo o que o app já pergunta e usar questions sem pergunta', () {
    expect(chatReadingInstruction, contains('Em reply, não repita essa pergunta'));
    expect(chatReadingInstruction, contains('contar o que toma não é perguntar'));
  });

  test('ADR-27: conversa e explica remédio como a bula, sem mandar mudar tratamento nem afirmar diagnóstico', () {
    expect(chatReadingInstruction, contains('CONVERSA como um assistente de IA comum'));
    expect(chatReadingInstruction, contains('explica remédios e doenças como a bula'));
    expect(chatReadingInstruction, contains('não mande a pessoa começar, parar, trocar ou mudar a dose'));
    expect(chatReadingInstruction, contains('não diga que a pessoa TEM uma doença'));
    expect(chatReadingInstruction, isNot(contains('o app só registra')));
  });

  test('atividade ida e volta: a distância de um trecho é dobrada; sem round_trip fica como dita', () {
    final r = parseChatReading({
      'reply': 'Ok.',
      'activities': [
        {'activity': 'walking', 'distance_m': 700, 'round_trip': true},
        {'activity': 'walking', 'distance_m': 500},
        {'activity': 'other', 'label': 'Brincar'},
      ],
    });
    expect(r.activities, [
      {'activity': 'walking', 'distance_m': 1400.0, 'round_trip': true},
      {'activity': 'walking', 'distance_m': 500.0},
    ]);
  });

  test('"caminhei até a praia, uns 700 m" = ida e volta por padrão (jeito comum de falar)', () {
    expect(chatReadingInstruction, contains('caminhada ou corrida até um lugar = round_trip = true'));
    expect(chatReadingInstruction, contains('voltou de outro jeito'));
  });
}
