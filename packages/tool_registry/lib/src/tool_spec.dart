/// A especificação de uma ferramenta do cérebro — o contrato único entre
/// `packages/brain` e os módulos (`docs/ARQUITETURA.md:43-67`).
///
/// `parametersSchema` é um JSON Schema (draft usado por
/// [package:json_schema](https://pub.dev/packages/json_schema)) — os
/// parâmetros de uma chamada são sempre validados contra ele antes de
/// qualquer execução (`.claude/rules/brain.md`, passo 3 do pipeline).
class ToolSpec {
  final String name;
  final String description;

  /// Ferramenta de escrita — muda estado em algum módulo/no Health Data
  /// Core. Toda ferramenta de escrita exige confirmação humana
  /// (`.claude/rules/brain.md`, passo 4): `write == true` implica
  /// `confirm == true`, reforçado no construtor.
  final bool write;
  final bool confirm;

  /// Módulo dono da ferramenta (`nutrition`, `activity`, etc.) — só
  /// metadado aqui; o registro não sabe nem precisa saber onde o módulo
  /// mora.
  final String module;

  final Map<String, dynamic> parametersSchema;

  ToolSpec({
    required this.name,
    required this.description,
    required this.write,
    required this.confirm,
    required this.module,
    required this.parametersSchema,
  }) {
    if (write && !confirm) {
      throw ArgumentError(
          'ToolSpec "$name": ferramenta de escrita (write=true) precisa de confirm=true — .claude/rules/brain.md, passo 4');
    }
  }
}
