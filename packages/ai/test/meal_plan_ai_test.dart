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
    return AiHttpResponse(
      200,
      jsonEncode({
        'candidates': [
          {
            'content': {
              'parts': [
                {'text': jsonEncode(json)},
              ],
            },
          },
        ],
      }),
    );
  }
}

void main() {
  const plan = {
    'name': 'Cardápio da Dra. Ana',
    'meals': [
      {
        'meal_type': 'breakfast',
        'time': '07:30',
        'items': [
          {'description': '2 ovos mexidos', 'kcal': 150, 'protein_g': 12},
          {'description': ' '},
        ],
      },
      {'meal_type': 'snack', 'time': 'manhã', 'items': []},
      {
        'meal_type': 'lunch',
        'items': [
          {'description': '4 colheres de sopa de arroz ou 1 batata média', 'kcal': -5},
        ],
      },
    ],
  };

  test('lê o plano importado: mantém o texto do profissional, descarta vazio e número inválido', () async {
    final t = OneReply(plan);
    final draft = await readMealPlan(GeminiClient(apiKey: 'k', transport: t), const [AiPart.text('x')]);
    expect(t.sent!['systemInstruction']['parts'][0]['text'], contains('Não mude, não troque'));
    expect(draft.name, 'Cardápio da Dra. Ana');
    expect(draft.meals.map((m) => m.mealType), ['breakfast', 'lunch']);
    expect(draft.meals.first.time, '07:30');
    expect(draft.meals.first.items.single.description, '2 ovos mexidos');
    expect(draft.meals.first.items.single.proteinGrams, 12);
    expect(draft.meals.last.items.single.kcal, isNull);
  });

  test('sugestão manda só metas e preferências; pede para nunca usar alérgenos', () async {
    final t = OneReply(plan);
    await suggestMealPlan(
      GeminiClient(apiKey: 'k', transport: t),
      caloriesKcal: 1834.6,
      proteinGrams: 130,
      carbsGrams: 190,
      fatGrams: 61,
      fiberGrams: 26,
      preferences: const {'sem_lactose'},
      allergies: 'amendoim',
      dislikes: 'jiló',
    );
    final text = (t.sent!['contents'] as List).single['parts'][0]['text'] as String;
    expect(text, contains('1835 kcal'));
    expect(text, contains('amendoim'));
    expect(text, contains('jiló'));
    expect(text, contains('sem_lactose'));
    expect(t.sent!['systemInstruction']['parts'][0]['text'], contains('NUNCA inclua alimento citado como alergia'));
    expect(t.sent!['systemInstruction']['parts'][0]['text'], contains('Não inclua suplementos, remédios'));
  });
}
