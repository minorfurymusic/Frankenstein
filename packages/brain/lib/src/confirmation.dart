import 'package:frankstein_tool_registry/tool_registry.dart';

/// Confirmação humana obrigatória antes de executar ferramenta de
/// escrita (`.claude/rules/brain.md`, passo 4). A implementação real é
/// UI (diálogo no app) — fora do escopo deste pacote, que só define o
/// contrato. Em teste, uma implementação fake decide sim/não sem UI.
abstract class ConfirmationGate {
  Future<bool> confirm(ToolSpec spec, Map<String, dynamic> params);
}
