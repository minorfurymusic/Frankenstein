/// Resultado de uma execução de ferramenta.
class ToolResult {
  final bool success;
  final Map<String, dynamic>? data;
  final String? error;

  ToolResult._(this.success, this.data, this.error);

  factory ToolResult.ok([Map<String, dynamic>? data]) =>
      ToolResult._(true, data ?? const {}, null);

  factory ToolResult.failure(String error) => ToolResult._(false, null, error);
}
