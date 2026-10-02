import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// Conta e Configurações, aberta pelo avatar do Início (prancheta Conta).
/// Nesta etapa só a lista de seções existe; "Sobre" já abre as licenças.
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  static const _sections = <(String, String, IconData)>[
    ('Perfil', 'Dados usados nas fórmulas', Icons.person_outline),
    ('Metas', 'Calorias, macros, água, passos, sono', Icons.flag_outlined),
    ('Cérebro (IA)', 'Sua chave de IA e o que é enviado', Icons.psychology_outlined),
    ('Assinatura', 'Plano atual', Icons.workspace_premium_outlined),
    ('Permissões', 'Passos, notificações, câmera, localização', Icons.verified_user_outlined),
    ('Dispositivos', 'Pulseira ou relógio via Health Connect', Icons.watch_outlined),
    ('Lembretes', 'Remédios, água, treino', Icons.notifications_none),
    ('Privacidade e dados', 'Exportar ou apagar seus dados', Icons.lock_outline),
    ('Preferências', 'Tema, unidades, idioma', Icons.tune),
  ];

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conta')),
      body: ListView(
        key: const Key('account_list'),
        padding: const EdgeInsets.symmetric(vertical: RltSpace.s),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: c.primaryContainer,
              foregroundColor: c.onPrimaryContainer,
              child: const Icon(Icons.person_outline),
            ),
            // TODO(frankstein): nome, e-mail e foto da conta Google (ADR-13) — login entra na rodada de testes.
            title: Text('Conta Google', style: t.titleSmall),
            subtitle: const Text('Login entra na rodada de testes das telas'),
          ),
          const Divider(),
          for (final (title, subtitle, icon) in _sections)
            ListTile(
              leading: Icon(icon, color: c.onSurfaceVariant),
              title: Text(title, style: t.titleSmall),
              subtitle: Text(subtitle),
              trailing: const Icon(Icons.chevron_right),
              // TODO(frankstein): telas Conta* (pranchetas ContaPerfil, ContaMetas, ContaCerebro…).
              onTap: () => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text('$title: tela em construção.'))),
            ),
          ListTile(
            key: const Key('account_about'),
            leading: Icon(Icons.info_outline, color: c.onSurfaceVariant),
            title: Text('Sobre', style: t.titleSmall),
            subtitle: const Text('Versão, licenças de código aberto'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'RLT — Real Life Track',
              applicationLegalese:
                  'Código aberto (copyleft). Sem anúncios, sem telemetria.\n\n'
                  'O RLT não faz diagnóstico nem prescrição. Em caso de dúvida ou sintoma '
                  'preocupante, procure um profissional de saúde.',
            ),
          ),
        ],
      ),
    );
  }
}
