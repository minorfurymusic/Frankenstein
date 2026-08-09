import 'tool_result.dart';
import 'tool_spec.dart';
import 'validation.dart';

/// Executa uma ferramenta já validada. Quem implementa isto é o módulo
/// dono (`ToolSpec.module`) — o registro não sabe nem precisa saber como
/// a ferramenta funciona por dentro.
typedef ToolHandler = Future<ToolResult> Function(Map<String, dynamic> params);

class _Entry {
  final ToolSpec spec;
  final ToolHandler handler;
  _Entry(this.spec, this.handler);
}

/// Lançada ao pedir uma ferramenta que não foi registrada.
class ToolNotFoundException implements Exception {
  final String name;
  ToolNotFoundException(this.name);

  @override
  String toString() => 'ferramenta não registrada: $name';
}

/// Lançada ao tentar executar com parâmetros que não batem no
/// `parametersSchema` da ferramenta.
class ToolValidationException implements Exception {
  final String toolName;
  final List<String> errors;
  ToolValidationException(this.toolName, this.errors);

  @override
  String toString() =>
      'parâmetros inválidos para "$toolName": ${errors.join('; ')}';
}

/// O contrato único de ferramentas entre o cérebro e os módulos
/// (`docs/ARQUITETURA.md`). Não sabe nada sobre LLM, roteador, nem sobre
/// nenhum módulo específico — só registra `ToolSpec` + `ToolHandler` e
/// executa com validação na frente.
class ToolRegistry {
  final Map<String, _Entry> _entries = {};

  void register(ToolSpec spec, ToolHandler handler) {
    _entries[spec.name] = _Entry(spec, handler);
  }

  ToolSpec specFor(String name) {
    final entry = _entries[name];
    if (entry == null) throw ToolNotFoundException(name);
    return entry.spec;
  }

  List<ToolSpec> get specs => _entries.values.map((e) => e.spec).toList();

  bool has(String name) => _entries.containsKey(name);

  /// Valida [params] contra o schema da ferramenta [name] e, se válidos,
  /// executa o handler. Lança [ToolNotFoundException]/
  /// [ToolValidationException] em vez de silenciar erro — quem chama
  /// (o pipeline do cérebro) decide como reagir.
  ///
  /// Esta chamada **não** trata confirmação humana — isso é
  /// responsabilidade de quem orquestra o pipeline (`packages/brain`),
  /// não do registro. `execute` só roda depois que a confirmação (se
  /// exigida por `ToolSpec.confirm`) já aconteceu.
  Future<ToolResult> execute(String name, Map<String, dynamic> params) async {
    final entry = _entries[name];
    if (entry == null) throw ToolNotFoundException(name);

    final validation = validateToolParameters(entry.spec.parametersSchema, params);
    if (!validation.valid) {
      throw ToolValidationException(name, validation.errors);
    }
    return entry.handler(params);
  }
}
