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

class HttpAiTransport implements AiTransport {
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
}

/// Por que a IA não respondeu — cada caso vira uma mensagem clara na tela.
enum AiFailure {
  /// Sem chave configurada (modo básico).
  noKey,

  /// Chave recusada pelo provedor.
  badKey,

  /// Limite de uso da chave atingido.
  quota,

  /// Sem internet / tempo esgotado.
  network,

  /// O provedor recusou o conteúdo (filtro de segurança) ou não respondeu.
  blocked,

  /// Arquivo grande demais para enviar de uma vez.
  tooLarge,

  /// A resposta não bateu no formato esperado, mesmo depois de repetir.
  invalidOutput,

  /// Outro erro do provedor.
  provider,
}

class AiException implements Exception {
  final AiFailure failure;
  final String? detail;
  const AiException(this.failure, [this.detail]);

  @override
  String toString() => 'AiException($failure${detail == null ? '' : ': $detail'})';
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

  final String apiKey;
  final String model;
  final AiTransport transport;

  GeminiClient({required this.apiKey, this.model = defaultModel, AiTransport? transport})
      : transport = transport ?? HttpAiTransport();

  Uri get _url => Uri.parse('$baseUrl/$model:generateContent');

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

  Future<String> _call(String body) async {
    final AiHttpResponse res;
    try {
      res = await transport.post(_url, {'content-type': 'application/json', 'x-goog-api-key': apiKey}, body);
    } on SocketException catch (e) {
      throw AiException(AiFailure.network, e.message);
    } on TimeoutException {
      throw const AiException(AiFailure.network, 'tempo esgotado');
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
    if (res.status == 429 || status == 'RESOURCE_EXHAUSTED') return AiException(AiFailure.quota, message);
    if (res.status == 401 || res.status == 403 || m.contains('api key') || status == 'PERMISSION_DENIED' || status == 'UNAUTHENTICATED') {
      return AiException(AiFailure.badKey, message);
    }
    if (res.status == 413) return AiException(AiFailure.tooLarge, message);
    return AiException(AiFailure.provider, message ?? 'HTTP ${res.status}');
  }
}
