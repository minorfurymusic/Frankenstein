import 'package:flutter/material.dart';

import '../app_dependencies.dart';
import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';
import 'ai_settings.dart';

/// Antes do primeiro envio à IA (prancheta CerebroConsentimento;
/// `.claude/rules/brain.md`): diz qual empresa recebe, o que vai e o que
/// nunca vai. Devolve `true` se já consentiu ou se concordou agora.
Future<bool> ensureAiConsent(BuildContext context, AppDependencies deps, {required String sending}) async {
  final ai = deps.ai;
  if (ai.consentedAt != null) return true;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AiConsentDialog(sending: sending),
  );
  if (ok == true) {
    ai.giveConsent();
    return true;
  }
  return false;
}

class AiConsentDialog extends StatelessWidget {
  final String sending;
  const AiConsentDialog({super.key, required this.sending});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    Widget item(IconData icon, Color color, String text) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: RltSpace.s),
            Expanded(child: Text(text, style: t.bodyMedium)),
          ]),
        );
    return AlertDialog(
      key: const Key('ai_consent'),
      title: const Text('Antes do primeiro envio'),
      content: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('O que você enviar vai para o provedor de IA que você escolheu.', style: t.bodyMedium),
          const SizedBox(height: RltSpace.m),
          Text('EMPRESA QUE RECEBE', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant, letterSpacing: 0.8)),
          Text(AiSettings.providerName, style: t.titleMedium),
          const SizedBox(height: RltSpace.m),
          Text('Sim, é enviado', style: t.titleSmall),
          item(Icons.check, c.success, sending),
          const SizedBox(height: RltSpace.s),
          Text('Nunca é enviado', style: t.titleSmall),
          item(Icons.block, c.error, 'Seu histórico de saúde guardado no app'),
          item(Icons.block, c.error, 'Sua conta (nome e e-mail) e sua localização'),
          const SizedBox(height: RltSpace.m),
          Text(
            'O provedor trata os dados pela política dele. Você pode apagar a chave e voltar ao modo básico quando quiser.',
            style: t.bodySmall,
          ),
        ]),
      ),
      actions: [
        TextButton(key: const Key('ai_consent_no'), onPressed: () => Navigator.pop(context, false), child: const Text('Não agora')),
        FilledButton(key: const Key('ai_consent_yes'), onPressed: () => Navigator.pop(context, true), child: const Text('Concordo e enviar')),
      ],
    );
  }
}
