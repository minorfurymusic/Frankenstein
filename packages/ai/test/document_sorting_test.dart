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
  test('vários arquivos numa chamada: cada um com o seu tipo; o que falta vira "outro"', () async {
    final t = OneReply({
      'files': [
        {'index': 1, 'kind': 'prescription'},
        {'index': 2, 'kind': 'meal_plan'},
        {'index': 9, 'kind': 'exam'}, // não existe: ignorado
        {'index': 3, 'kind': 'other', 'description': 'Print da tela de metas de um app.'},
      ],
      'body': {'weight_kg': 93.7, 'height_cm': 1.83, 'body_fat_percent': 28, 'date': '2026-10-01'},
      'history': [
        {'kind': 'condition', 'title': 'Hipertensão', 'professional': 'Dr. Silva'},
        {'kind': 'allergy', 'title': '  '},
      ],
    });
    final bytes = Uint8List.fromList([1, 2, 3]);
    final files = [for (var i = 0; i < 4; i++) AiPart.file(bytes, 'image/jpeg')];
    final r = await sortDocuments(GeminiClient(apiKey: 'k', transport: t), files);

    final parts = (t.sent!['contents'] as List).single['parts'] as List;
    expect(parts.where((p) => p['inlineData'] != null), hasLength(4));
    expect(parts.first['text'], 'Arquivo 1:');
    expect(t.sent!['systemInstruction'].toString(), contains('Nunca deduza doença a partir de remédio'));

    expect(r.files.map((f) => f.kind), [SortedKind.prescription, SortedKind.mealPlan, SortedKind.other, SortedKind.other]);
    expect(r.files[2].description, 'Print da tela de metas de um app.');
    expect(r.body.weightKg, 93.7);
    expect(r.body.heightCm, closeTo(183, 1e-9), reason: 'altura escrita em metros vira cm');
    expect(r.body.bodyFatPercent, 28);
    expect(r.body.date, DateTime(2026, 10, 1));
    expect(r.history.single.title, 'Hipertensão');
    expect(r.history.single.professional, 'Dr. Silva');
  });

  test('ficha de treino: exercícios válidos, carga só quando escrita', () {
    final r = parseWorkoutPlan({
      'name': 'Treino A',
      'exercises': [
        {'name': 'Supino reto', 'sets': 4, 'reps': 10, 'load_kg': 30},
        {'name': 'Prancha', 'sets': 3, 'reps': 1},
        {'name': 'Rosca', 'sets': 0, 'reps': 10},
        {'name': '', 'sets': 3, 'reps': 10},
      ],
    });
    expect(r.name, 'Treino A');
    expect(r.exercises.map((e) => (e.name, e.sets, e.reps, e.loadKg)), [('Supino reto', 4, 10, 30.0), ('Prancha', 3, 1, null)]);
  });
}
