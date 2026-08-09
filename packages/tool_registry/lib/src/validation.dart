import 'package:json_schema/json_schema.dart';

/// Resultado de validar parâmetros de uma ferramenta contra o
/// `parametersSchema` do [ToolSpec] correspondente
/// (`.claude/rules/brain.md`, passo 3: "Validação por JSON Schema. Saída
/// inválida = rejeita e repete").
class ValidationResult {
  final bool valid;
  final List<String> errors;

  ValidationResult._(this.valid, this.errors);

  factory ValidationResult.valid() => ValidationResult._(true, const []);

  factory ValidationResult.invalid(List<String> errors) =>
      ValidationResult._(false, errors);
}

/// Valida [params] contra o JSON Schema [schema]. Não lança — erros de
/// schema malformado viram um [ValidationResult] inválido com a mensagem,
/// pra quem chama decidir o que fazer (o pipeline do cérebro rejeita e
/// não executa a ferramenta).
ValidationResult validateToolParameters(
  Map<String, dynamic> schema,
  Map<String, dynamic> params,
) {
  final JsonSchema compiled;
  try {
    compiled = JsonSchema.create(schema);
  } catch (e) {
    return ValidationResult.invalid(['schema inválido: $e']);
  }
  final result = compiled.validate(params);
  if (result.isValid) return ValidationResult.valid();
  return ValidationResult.invalid(
    result.errors.map((e) => '${e.instancePath}: ${e.message}').toList(),
  );
}
