import 'dart:convert';

import 'package:frankstein_ai/ai.dart';
import 'package:test/test.dart';

class ModelTransport implements AiTransport, AiModelLister {
  /// Resposta por modelo, na ordem em que o modelo é chamado.
  final Map<String, List<AiHttpResponse>> byModel;
  final List<String> calls = [];
  final List<Uri> gets = [];
  String listBody = '{}';
  ModelTransport(this.byModel);

  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    final m = url.pathSegments.last.split(':').first;
    calls.add(m);
    final q = byModel[m];
    if (q == null || q.isEmpty) return const AiHttpResponse(404, '{"error":{"code":404,"status":"NOT_FOUND"}}');
    return q.removeAt(0);
  }

  @override
  Future<AiHttpResponse> get(Uri url, Map<String, String> headers) async {
    gets.add(url);
    return AiHttpResponse(200, listBody);
  }
}

AiHttpResponse okText(String t) => AiHttpResponse(
    200,
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': t},
            ],
          },
        },
      ],
    }));

const quota = AiHttpResponse(429, '{"error":{"code":429,"status":"RESOURCE_EXHAUSTED","message":"Quota exceeded"}}');
const busy = AiHttpResponse(503, '{"error":{"code":503,"status":"UNAVAILABLE","message":"overloaded"}}');
const badKey = AiHttpResponse(400, '{"error":{"code":400,"status":"INVALID_ARGUMENT","message":"API key not valid"}}');

void main() {
  test('sem cota (429) ou ocupado (503): desce para o próximo modelo e avisa a posição', () async {
    final t = ModelTransport({
      'a': [quota],
      'b': [busy],
      'c': [okText('ok')],
    });
    final events = <String>[];
    final c = GeminiClient(
      apiKey: 'k',
      models: const ['a', 'b', 'c', 'd'],
      transport: t,
      onModel: (i, m, {required ok}) => events.add('$i$m$ok'),
    );
    await c.ping();
    expect(t.calls, ['a', 'b', 'c']);
    expect(c.lastModel, 'c');
    expect(c.currentIndex, 2);
    expect(events, ['0afalse', '1bfalse', '2ctrue']);
  });

  test('começa de onde parou e não tenta mais de 3 modelos; sem nenhum, erro "esgotado"', () async {
    final t = ModelTransport({
      'b': [quota],
      'c': [quota],
      'd': [quota],
      'a': [okText('nunca')],
    });
    final c = GeminiClient(apiKey: 'k', models: const ['a', 'b', 'c', 'd'], startIndex: 1, transport: t);
    await expectLater(
        c.ping(), throwsA(isA<AiException>().having((e) => e.failure, 'f', AiFailure.exhausted).having((e) => e.httpStatus, 's', 429)));
    expect(t.calls, ['b', 'c', 'd']);
    expect(c.currentIndex, 3);
  });

  test('no fim da escada volta ao topo, cada modelo uma vez', () async {
    final t = ModelTransport({
      'c': [busy],
      'a': [okText('ok')],
    });
    final c = GeminiClient(apiKey: 'k', models: const ['a', 'b', 'c'], startIndex: 2, transport: t);
    await c.ping();
    expect(t.calls, ['c', 'a']);
    expect(c.lastModel, 'a');
  });

  test('modelo inexistente (404) é pulado sem contar', () async {
    final t = ModelTransport({
      'b': [quota],
      'd': [quota],
      'e': [okText('ok')],
    });
    final c = GeminiClient(apiKey: 'k', models: const ['x', 'b', 'y', 'd', 'e'], transport: t);
    await c.ping();
    expect(t.calls, ['x', 'b', 'y', 'd', 'e']);
    expect(c.lastModel, 'e');
  });

  test('chave recusada não desce a escada', () async {
    final t = ModelTransport({
      'a': [badKey],
      'b': [okText('ok')],
    });
    final c = GeminiClient(apiKey: 'k', models: const ['a', 'b'], transport: t);
    await expectLater(c.ping(), throwsA(isA<AiException>().having((e) => e.failure, 'f', AiFailure.badKey)));
    expect(t.calls, ['a']);
  });

  test('lista de modelos: só Flash/Lite de texto, na ordem da escada, com o nome do Google', () async {
    final t = ModelTransport({})
      ..listBody = jsonEncode({
        'models': [
          for (final (n, d) in [
            ('gemini-2.0-flash', 'Gemini 2.0 Flash'),
            ('gemini-2.0-flash-001', 'Gemini 2.0 Flash 001'),
            ('gemini-2.5-flash-lite', 'Gemini 2.5 Flash-Lite'),
            ('gemini-2.5-flash', 'Gemini 2.5 Flash'),
            ('gemini-3-flash-preview', 'Gemini 3 Flash Preview'),
            ('gemini-2.5-pro', 'Gemini 2.5 Pro'),
            ('gemini-2.5-flash-image', 'Nano Banana'),
            ('gemini-flash-latest', 'Gemini Flash Latest'),
            ('gemini-2.5-flash-preview-tts', 'TTS'),
          ])
            {
              'name': 'models/$n',
              'displayName': d,
              'supportedGenerationMethods': ['generateContent'],
            },
          {
            'name': 'models/gemini-embedding-001',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });
    final list = await GeminiClient(apiKey: 'k', transport: t).listModels();
    expect([for (final m in list) m.name], ['gemini-3-flash-preview', 'gemini-2.5-flash', 'gemini-2.0-flash', 'gemini-2.5-flash-lite']);
    expect(list.first.displayName, 'Gemini 3 Flash Preview');
    expect(t.gets.single.toString(), 'https://generativelanguage.googleapis.com/v1beta/models?pageSize=1000');
    expect(t.gets.single.toString(), isNot(contains('key')));
  });
}
