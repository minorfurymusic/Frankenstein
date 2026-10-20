import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:frankstein_tool_registry/tool_registry.dart';

/// Um pedaço do que vai para a IA: texto ou arquivo (foto/PDF) que a
/// própria pessoa anexou naquela ação (`.claude/rules/brain.md`).
class AiPart {
  final String? text;
  final Uint8List? bytes;
  final String? mimeType;
  const AiPart.text(String this.text)
      : bytes = null,
        mimeType = null;
  const AiPart.file(Uint8List this.bytes, String this.mimeType) : text = null;

  Map<String, Object> toJson() => text != null
      ? {'text': text!}
      : {
          'inlineData': {'mimeType': mimeType!, 'data': base64Encode(bytes!)},
        };
}

/// Resposta HTTP crua (para o transporte ser trocado nos testes).
class AiHttpResponse {
  final int status;
  final String body;
  const AiHttpResponse(this.status, this.body);
}

/// Quem faz o POST. Em produção, [HttpAiTransport]; em teste, um falso.
abstract class AiTransport {
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body);
}

/// Quem faz o GET da lista de modelos da chave. [HttpAiTransport] faz os dois.
abstract class AiModelLister {
  Future<AiHttpResponse> get(Uri url, Map<String, String> headers);
}

/// Um modelo que a chave pode usar: nome técnico e nome que o Google mostra.
class AiModel {
  final String name;
  final String displayName;
  const AiModel(this.name, this.displayName);

  Map<String, String> toJson() => {'name': name, 'display': displayName};
  static AiModel fromJson(Map<String, dynamic> m) => AiModel(m['name'] as String, (m['display'] as String?) ?? m['name'] as String);
}

class HttpAiTransport implements AiTransport, AiModelLister {
  final Duration timeout;
  HttpAiTransport({this.timeout = const Duration(seconds: 90)});

  @override
  Future<AiHttpResponse> post(Uri url, Map<String, String> headers, String body) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.postUrl(url).timeout(timeout);
      headers.forEach(req.headers.set);
      req.add(utf8.encode(body));
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      return AiHttpResponse(res.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }

  @override
  Future<AiHttpResponse> get(Uri url, Map<String, String> headers) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      final req = await client.getUrl(url).timeout(timeout);
      headers.forEach(req.headers.set);
      final res = await req.close().timeout(timeout);
      final text = await res.transform(utf8.decoder).join().timeout(timeout);
      return AiHttpResponse(res.statusCode, text);
    } finally {
      client.close(force: true);
    }
  }
}

/// Por que a IA não respondeu — cada caso vira uma mensagem clara na tela.
enum AiFailure {
  /// Sem chave configurada (modo básico).
  noKey,

  /// Chave recusada pelo provedor.
  badKey,

  /// Limite de uso da chave atingido.
  quota,

  /// Sem internet (o pedido nem chegou ao provedor).
  network,

  /// O provedor demorou mais que o limite para responder.
  timeout,

  /// O provedor recusou o conteúdo (filtro de segurança) ou não respondeu.
  blocked,

  /// Arquivo grande demais para enviar de uma vez.
  tooLarge,

  /// A resposta não bateu no formato esperado, mesmo depois de repetir.
  invalidOutput,

  /// Servidor do provedor ocupado ou com falha passageira (HTTP 500/502/
  /// 503/504), mesmo depois de repetir sozinho.
  busy,

  /// Todos os modelos tentados neste pedido estavam sem cota ou ocupados
  /// (escada de modelos). `httpStatus` é o do último.
  exhausted,

  /// Outro erro do provedor.
  provider,
}

class AiException implements Exception {
  final AiFailure failure;
  final String? detail;

  /// Código HTTP devolvido pelo provedor, quando houve resposta.
  final int? httpStatus;
  const AiException(this.failure, [this.detail, this.httpStatus]);

  @override
  String toString() => 'AiException($failure${httpStatus == null ? '' : ' HTTP $httpStatus'}${detail == null ? '' : ': $detail'})';
}

/// Cliente REST do Gemini (Gemini Developer API), sem SDK do provedor
/// (`.claude/rules/brain.md`). Endereço, cabeçalho da chave e nomes de campo
/// conferidos no código do SDK oficial `googleapis/python-genai`
/// (`_api_client.py`: `https://generativelanguage.googleapis.com/`, `v1beta`,
/// `x-goog-api-key`; `models.py`: `{model}:generateContent`, `inlineData`,
/// `systemInstruction`, `generationConfig.responseMimeType` e
/// `responseJsonSchema`).
class GeminiClient {
  static const defaultModel = 'gemini-flash-latest';
  static const baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models';

  /// O pedido com anexos vai inteiro no corpo; acima disso o provedor
  /// recusa. Folga abaixo dos 20 MB.
  static const maxInlineBytes = 15 * 1024 * 1024;

  /// Escada usada quando a lista de modelos da chave ainda não foi lida:
  /// do melhor para o mais leve. Nome que não existir (404) é pulado.
  static const defaultLadder = [
    'gemini-flash-latest',
    'gemini-2.5-flash',
    'gemini-flash-lite-latest',
    'gemini-2.5-flash-lite',
    'gemini-2.0-flash',
  ];

  final String apiKey;
  final AiTransport transport;

  /// Escada de modelos, do melhor para o mais leve. Com um só, não troca.
  final List<String> models;

  /// No máximo quantos modelos sem cota/ocupados tentar num pedido.
  final int maxModelsPerCall;

  /// De onde o próximo pedido começa (fica no último que respondeu ou no
  /// último tentado).
  int currentIndex;

  /// Avisa a posição na escada depois de cada tentativa: `ok` quando
  /// respondeu. Quem guarda a posição entre pedidos é o app.
  final void Function(int index, String model, {required bool ok})? onModel;

  /// Modelo que deu a última resposta.
  String? lastModel;

  /// Espera antes de repetir quando o servidor está ocupado (500/502/503/
  /// 504): uma entrada por nova tentativa.
  final List<Duration> busyRetryDelays;

  GeminiClient({
    required this.apiKey,
    String model = defaultModel,
    List<String>? models,
    int startIndex = 0,
    this.maxModelsPerCall = 3,
    this.onModel,
    AiTransport? transport,
    this.busyRetryDelays = const [Duration(seconds: 2), Duration(seconds: 5)],
  })  : models = models == null || models.isEmpty ? [model] : List.unmodifiable(models),
        currentIndex = startIndex,
        transport = transport ?? HttpAiTransport();

  /// Modelo de onde o próximo pedido começa.
  String get model => models[currentIndex.clamp(0, models.length - 1)];

  static bool _isBusy(int status) => status == 500 || status == 502 || status == 503 || status == 504;

  Uri _url(String m) => Uri.parse('$baseUrl/$m:generateContent');

  /// Modelos de texto que a chave pode usar, já na ordem da escada. Só
  /// nomes e versões — nenhum dado da pessoa vai junto.
  Future<List<AiModel>> listModels() async {
    final Object t = transport;
    if (t is! AiModelLister) throw const AiException(AiFailure.provider, 'transporte sem GET');
    final out = <AiModel>[];
    String? page;
    for (var n = 0; n < 5; n++) {
      final AiHttpResponse res;
      try {
        res = await t.get(
          Uri.parse('$baseUrl?pageSize=1000${page == null ? '' : '&pageToken=$page'}'),
          {'x-goog-api-key': apiKey},
        );
      } on SocketException catch (e) {
        throw AiException(AiFailure.network, e.message);
      } on TimeoutException {
        throw const AiException(AiFailure.timeout, 'tempo esgotado');
      } on HttpException catch (e) {
        throw AiException(AiFailure.network, e.message);
      }
      if (res.status != 200) throw _errorFor(res);
      final Map<String, dynamic> json;
      try {
        json = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {
        throw const AiException(AiFailure.provider, 'resposta ilegível');
      }
      for (final raw in (json['models'] as List? ?? const [])) {
        if (raw is! Map) continue;
        final full = raw['name'];
        if (full is! String) continue;
        final name = full.startsWith('models/') ? full.substring(7) : full;
        final methods = (raw['supportedGenerationMethods'] as List?) ?? const [];
        if (!methods.contains('generateContent') || !isLadderModel(name)) continue;
        final display = raw['displayName'];
        out.add(AiModel(name, display is String && display.trim().isNotEmpty ? display.trim() : name));
      }
      page = json['nextPageToken'] as String?;
      if (page == null || page.isEmpty) break;
    }
    return sortLadder(out);
  }

  /// Pede uma resposta em JSON no formato [schema] e valida contra ele.
  /// Saída inválida = repete; no máximo 2 tentativas (`.claude/rules/brain.md`).
  Future<Map<String, dynamic>> generateJson({
    required String system,
    required List<AiPart> parts,
    required Map<String, dynamic> schema,
    int attempts = 2,
  }) async {
    final size = parts.fold<int>(0, (s, p) => s + (p.bytes?.length ?? 0));
    if (size > maxInlineBytes) throw const AiException(AiFailure.tooLarge);
    final body = jsonEncode({
      'systemInstruction': {
        'parts': [
          {'text': system},
        ],
      },
      'contents': [
        {'role': 'user', 'parts': [for (final p in parts) p.toJson()]},
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseJsonSchema': schema,
        'temperature': 0.2,
      },
    });
    List<String> lastErrors = const [];
    for (var i = 0; i < attempts; i++) {
      final text = await _call(body);
      Object? decoded;
      try {
        decoded = jsonDecode(text);
      } on FormatException {
        lastErrors = ['não é JSON'];
        continue;
      }
      if (decoded is! Map<String, dynamic>) {
        lastErrors = ['não é um objeto JSON'];
        continue;
      }
      final v = validateToolParameters(schema, decoded);
      if (v.valid) return decoded;
      lastErrors = v.errors;
    }
    throw AiException(AiFailure.invalidOutput, lastErrors.join('; '));
  }

  /// Teste da chave em Conta › Cérebro: pedido mínimo, sem dado de saúde.
  Future<void> ping() async {
    await _call(jsonEncode({
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': 'Responda apenas: ok'},
          ],
        },
      ],
    }));
  }

  /// Um pedido. Com escada: sem cota (429) ou ocupado (5xx) passa para o
  /// próximo modelo, até [maxModelsPerCall] modelos, cada um uma vez;
  /// modelo inexistente (404) é pulado sem contar. Chave recusada e outros
  /// erros param na hora.
  Future<String> _call(String body) async {
    if (models.length == 1) {
      final text = await _post(models.single, body, busyRetryDelays);
      lastModel = models.single;
      onModel?.call(0, models.single, ok: true);
      return text;
    }
    final start = currentIndex.clamp(0, models.length - 1);
    // Desce a partir de onde parou; no fim da escada, volta ao topo.
    final order = [for (var i = start; i < models.length; i++) i, for (var i = 0; i < start; i++) i];
    AiException? last;
    var tried = 0;
    for (final i in order) {
      if (tried >= maxModelsPerCall) break;
      final m = models[i];
      try {
        final text = await _post(m, body, const []);
        currentIndex = i;
        lastModel = m;
        onModel?.call(i, m, ok: true);
        return text;
      } on AiException catch (e) {
        if (e.httpStatus == 404) continue;
        if (e.failure != AiFailure.quota && e.failure != AiFailure.busy) rethrow;
        last = e;
        tried++;
        currentIndex = i;
        onModel?.call(i, m, ok: false);
      }
    }
    if (last == null) throw const AiException(AiFailure.provider, 'nenhum modelo da lista existe', 404);
    throw AiException(AiFailure.exhausted, last.detail, last.httpStatus);
  }

  Future<String> _post(String model, String body, List<Duration> busyRetryDelays) async {
    AiHttpResponse res;
    var retry = 0;
    while (true) {
      try {
        res = await transport.post(_url(model), {'content-type': 'application/json', 'x-goog-api-key': apiKey}, body);
      } on SocketException catch (e) {
        throw AiException(AiFailure.network, e.message);
      } on TimeoutException {
        throw const AiException(AiFailure.timeout, 'tempo esgotado');
      } on HttpException catch (e) {
        throw AiException(AiFailure.network, e.message);
      }
      // Servidor ocupado é passageiro: repete sozinho antes de avisar.
      if (!_isBusy(res.status) || retry >= busyRetryDelays.length) break;
      await Future<void>.delayed(busyRetryDelays[retry++]);
    }
    if (res.status != 200) throw _errorFor(res);
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiException(AiFailure.provider, 'resposta ilegível');
    }
    final candidates = json['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw AiException(AiFailure.blocked, (json['promptFeedback'] as Map?)?['blockReason']?.toString());
    }
    final first = candidates.first as Map<String, dynamic>;
    final parts = ((first['content'] as Map?)?['parts'] as List?) ?? const [];
    final text = [
      for (final p in parts)
        if (p is Map && p['text'] is String && p['thought'] != true) p['text'] as String,
    ].join();
    if (text.isEmpty) throw AiException(AiFailure.blocked, first['finishReason']?.toString());
    return text;
  }

  static AiException _errorFor(AiHttpResponse res) {
    String? message;
    String? status;
    try {
      final e = (jsonDecode(res.body) as Map<String, dynamic>)['error'] as Map<String, dynamic>;
      message = e['message'] as String?;
      status = e['status'] as String?;
    } catch (_) {}
    final m = (message ?? '').toLowerCase();
    final code = res.status;
    if (code == 429 || status == 'RESOURCE_EXHAUSTED') return AiException(AiFailure.quota, message, code);
    if (code == 401 || code == 403 || m.contains('api key') || status == 'PERMISSION_DENIED' || status == 'UNAUTHENTICATED') {
      return AiException(AiFailure.badKey, message, code);
    }
    if (code == 413) return AiException(AiFailure.tooLarge, message, code);
    if (_isBusy(code)) return AiException(AiFailure.busy, message, code);
    return AiException(AiFailure.provider, message ?? 'HTTP $code', code);
  }
}

/// Entra na escada: Gemini Flash e Flash-Lite de texto. Fora: Pro (cota
/// grátis mínima), modelos de imagem, voz, embedding, experimentais e
/// versões datadas repetidas (`-001`).
bool isLadderModel(String name) {
  final n = name.toLowerCase();
  if (!n.startsWith('gemini') || !n.contains('flash')) return false;
  const skip = ['embedding', 'tts', 'image', 'live', 'audio', 'native', 'exp', 'thinking', 'computer', 'robotics', '8b'];
  if (skip.any(n.contains)) return false;
  return !RegExp(r'-\d{3}$').hasMatch(n);
}

/// Posição na escada (menor = antes): Flash antes de Lite; versão mais
/// nova antes; estável antes de preview da mesma versão.
int ladderRank(String name) {
  final n = name.toLowerCase();
  final v = RegExp(r'gemini-(\d+(?:\.\d+)?)').firstMatch(n);
  final version = v == null ? 0.0 : double.parse(v.group(1)!);
  var rank = ((100 - version) * 100).round();
  if (n.contains('lite')) rank += 100000;
  if (n.contains('preview')) rank += 5;
  return rank;
}

/// Ordena e tira repetidos; se houver versão com número, os apelidos
/// "-latest" saem (gastariam uma tentativa na mesma cota).
List<AiModel> sortLadder(List<AiModel> models) {
  final seen = <String>{};
  final unique = [for (final m in models) if (seen.add(m.name)) m];
  final hasVersioned = unique.any((m) => !m.name.endsWith('-latest'));
  final kept = [for (final m in unique) if (!hasVersioned || !m.name.endsWith('-latest')) m];
  kept.sort((a, b) {
    final r = ladderRank(a.name).compareTo(ladderRank(b.name));
    return r != 0 ? r : a.name.compareTo(b.name);
  });
  return kept;
}
