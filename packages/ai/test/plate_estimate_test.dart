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
  test('estima o prato: manda a foto e o peso da balança; descarta item sem porção', () async {
    final t = OneReply({
      'meal_type': 'lunch',
      'items': [
        {'name': 'Arroz branco', 'grams': 150, 'kcal': 192, 'protein_g': 3.8, 'carbs_g': 42, 'fat_g': 0.3, 'fiber_g': 2.4},
        {'name': 'Frango grelhado', 'grams': 120, 'kcal': 191, 'protein_g': 38, 'carbs_g': 0, 'fat_g': 3},
        {'name': 'Molho', 'grams': 0, 'kcal': 10, 'protein_g': 0, 'carbs_g': 1, 'fat_g': 1},
      ],
    });
    final photo = Uint8List.fromList([1, 2, 3]);
    final e = await estimatePlate(GeminiClient(apiKey: 'k', transport: t), AiPart.file(photo, 'image/jpeg'), plateGrams: 420);
    final parts = (t.sent!['contents'] as List).single['parts'] as List;
    expect(parts.first['inlineData']['mimeType'], 'image/jpeg');
    expect(parts.last['text'], contains('420 g'));
    expect(e.mealType, 'lunch');
    expect(e.items.map((i) => i.name), ['Arroz branco', 'Frango grelhado']);
    expect(e.kcal, closeTo(383, 1e-9));
    expect(e.items.first.fiberGrams, 2.4);
    expect(e.items[1].fiberGrams, isNull);
  });

  test('mudar a porção recalcula na proporção', () {
    const arroz = PlateItem(name: 'Arroz', grams: 150, kcal: 192, proteinGrams: 3.6, carbsGrams: 42, fatGrams: 0.3);
    final menos = arroz.withGrams(100);
    expect(menos.kcal, closeTo(128, 1e-9));
    expect(menos.carbsGrams, closeTo(28, 1e-9));
  });
}
