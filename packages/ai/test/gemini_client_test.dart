import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:frankstein_ai/ai.dart';
import 'package:test/test.dart';

class FakeTransport implements AiTransport {
  final List<AiHttpResponse> replies;
  final List<(Uri, Map<String, String>, Map<String, dynamic>)> calls = [];
  Object? throwOnCall;
  FakeTransport(this.replies);

  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    calls.add((url, headers, jsonDecode(body) as Map<String, dynamic>));
    if (throwOnCall != null) throw throwOnCall!;
    return replies.removeAt(0);
  }
}

AiHttpResponse ok(Object json) => AiHttpResponse(
      200,
      jsonEncode({
        'candidates': [
          {
            'content': {
              'role': 'model',
              'parts': [
                {'text': json is String ? json : jsonEncode(json)},
              ],
            },
            'finishReason': 'STOP',
          },
        ],
      }),
    );

void main() {
  final pdf = Uint8List.fromList(utf8.encode('%PDF-1.4'));

  test('pedido: modelo na URL, chave só no cabeçalho, arquivo em inlineData e esquema JSON', () async {
    final t = FakeTransport([
      ok({
        'title': 'Hemograma completo',
        'date': '2026-09-25',
        'category': 'blood',
        'markers': [
          {'name': 'Glicemia de jejum', 'value': 102, 'unit': 'mg/dL', 'reference_low': 70, 'reference_high': 99},
          {'name': 'HbA1c', 'value': 5.9, 'unit': '%'},
        ],
      }),
    ]);
    final client = GeminiClient(apiKey: 'CHAVE-SECRETA', transport: t);
    final r = await readExam(client, [AiPart.file(pdf, 'application/pdf')]);

    final (url, headers, body) = t.calls.single;
    expect(url.toString(), 'https://generativelanguage.googleapis.com/v1beta/models/gemini-flash-latest:generateContent');
    expect(url.toString(), isNot(contains('CHAVE')));
    expect(headers['x-goog-api-key'], 'CHAVE-SECRETA');
    final parts = (body['contents'] as List).single['parts'] as List;
    expect(parts.first['inlineData']['mimeType'], 'application/pdf');
    expect(base64Decode(parts.first['inlineData']['data'] as String), pdf);
    expect(body['generationConfig']['responseMimeType'], 'application/json');
    expect(body['generationConfig']['responseJsonSchema'], examReadingSchema);
    expect(body['systemInstruction']['parts'][0]['text'], contains('Não converta'));

    expect(r.title, 'Hemograma completo');
    expect(r.date, DateTime(2026, 9, 25));
    expect(r.category, 'blood');
    expect(r.markers.first.referenceHigh, 99);
    expect(r.markers[1].value, 5.9);
    expect(r.markers[1].unit, '%');
  });

  test('saída fora do formato: repete uma vez e aceita a segunda', () async {
    final t = FakeTransport([
      ok({'markers': 'nada'}),
      ok({'markers': []}),
    ]);
    final r = await readExam(GeminiClient(apiKey: 'k', transport: t), const [AiPart.text('x')]);
    expect(t.calls, hasLength(2));
    expect(r.markers, isEmpty);
  });

  test('duas saídas inválidas: desiste com invalidOutput (máx. 2 tentativas)', () async {
    final t = FakeTransport([ok('não é json'), ok({'markers': [{'name': 'x'}]})]);
    await expectLater(
      readExam(GeminiClient(apiKey: 'k', transport: t), const [AiPart.text('x')]),
      throwsA(isA<AiException>().having((e) => e.failure, 'failure', AiFailure.invalidOutput)),
    );
    expect(t.calls, hasLength(2));
  });

  test('erros do provedor viram falhas claras', () async {
    Future<AiFailure> failureFor(AiHttpResponse res) async {
      try {
        await GeminiClient(apiKey: 'k', transport: FakeTransport([res])).ping();
      } on AiException catch (e) {
        return e.failure;
      }
      fail('devia falhar');
    }

    expect(
      await failureFor(const AiHttpResponse(400, '{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT"}}')),
      AiFailure.badKey,
    );
    expect(await failureFor(const AiHttpResponse(429, '{"error":{"status":"RESOURCE_EXHAUSTED"}}')), AiFailure.quota);
    expect(await failureFor(const AiHttpResponse(500, 'oops')), AiFailure.provider);
    expect(await failureFor(const AiHttpResponse(200, '{"promptFeedback":{"blockReason":"SAFETY"}}')), AiFailure.blocked);

    final t = FakeTransport([])..throwOnCall = const SocketException('sem rede');
    await expectLater(
      GeminiClient(apiKey: 'k', transport: t).ping(),
      throwsA(isA<AiException>().having((e) => e.failure, 'failure', AiFailure.network)),
    );
  });

  test('arquivo grande demais não sai do aparelho', () async {
    final t = FakeTransport([]);
    final big = Uint8List(GeminiClient.maxInlineBytes + 1);
    await expectLater(
      readExam(GeminiClient(apiKey: 'k', transport: t), [AiPart.file(big, 'image/jpeg')]),
      throwsA(isA<AiException>().having((e) => e.failure, 'failure', AiFailure.tooLarge)),
    );
    expect(t.calls, isEmpty);
  });

  test('leitura descarta data impossível, faixa invertida e nome vazio', () {
    final r = parseExamReading({
      'date': '2026-02-31',
      'markers': [
        {'name': ' ', 'value': 1, 'unit': 'x'},
        {'name': 'Ferritina', 'value': 80, 'unit': 'ng/mL', 'reference_low': 300, 'reference_high': 30},
      ],
    });
    expect(r.date, isNull);
    expect(r.markers.single.name, 'Ferritina');
    expect(r.markers.single.referenceLow, isNull);
  });

  test('ignora partes de "pensamento" do modelo', () async {
    final t = FakeTransport([
      AiHttpResponse(
        200,
        jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': 'pensando…', 'thought': true},
                  {'text': '{"markers":[]}'},
                ],
              },
            },
          ],
        }),
      ),
    ]);
    final r = await readExam(GeminiClient(apiKey: 'k', transport: t), const [AiPart.text('x')]);
    expect(r.markers, isEmpty);
  });
}
