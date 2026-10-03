import 'package:flutter/material.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

/// Implementação real de [ConfirmationGate]: mostra um diálogo com a
/// ferramenta e os parâmetros decididos, e só deixa a pipeline continuar
/// quando o usuário responde — `.claude/rules/brain.md`, passo 4
/// ("Confirmação humana obrigatória para toda ferramenta de escrita").
///
/// Usa um [GlobalKey<NavigatorState>] em vez de receber um `BuildContext`
/// no construtor: [AppDependencies] (que recebe este gate) é construído
/// antes da árvore de widgets existir, então não há `BuildContext`
/// disponível ainda nesse momento — só quando [confirm] é chamado de
/// verdade, depois do primeiro frame.
/// Mostra a proposta e devolve a decisão da pessoa (o Cérebro usa um
/// cartão dentro da conversa — prancheta CerebroChat).
typedef ProposalPresenter = Future<bool> Function(ToolSpec spec, Map<String, dynamic> params);

class AppConfirmationGate implements ConfirmationGate {
  final GlobalKey<NavigatorState> navigatorKey;
  AppConfirmationGate(this.navigatorKey);

  /// Quando a tela do Cérebro está aberta, ela pede as confirmações como
  /// cartões de proposta; sem ela, cai no diálogo abaixo. Nos dois casos
  /// nada é gravado antes do "Confirmar" (`.claude/rules/brain.md`).
  ProposalPresenter? presenter;

  @override
  Future<bool> confirm(ToolSpec spec, Map<String, dynamic> params) async {
    final inline = presenter;
    if (inline != null) return inline(spec, params);
    final context = navigatorKey.currentContext;
    if (context == null) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: Text(spec.description),
        content: Text(params.toString()),
        actions: [
          TextButton(
            key: const Key('confirmation_cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            key: const Key('confirmation_confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}
