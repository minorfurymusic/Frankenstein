import 'package:flutter/material.dart';

import '../app_dependencies.dart';
import '../theme/rlt_colors.dart';
import 'account/account_more_screens.dart';
import 'account/goals_screen.dart';
import 'account/preferences_screen.dart';
import 'account/profile_screen.dart';
import 'home/reminders_screen.dart';
import '../theme/rlt_theme.dart';

/// Conta e Configurações, aberta pelo avatar do Início (prancheta Conta).
/// Cada seção abre a sua tela; "Sobre" abre versão e licenças.
class AccountScreen extends StatelessWidget {
  final AppDependencies deps;
  const AccountScreen({super.key, required this.deps});

  Widget _screenFor(String title) => switch (title) {
        'Perfil' => ProfileScreen(deps: deps),
        'Metas' => GoalsScreen(deps: deps),
        'Preferências' => PreferencesScreen(deps: deps),
        'Lembretes' => RemindersScreen(deps: deps),
        'Cérebro (IA)' => const BrainSettingsScreen(),
        'Assinatura' => const SubscriptionScreen(),
        'Permissões' => PermissionsScreen(deps: deps),
        'Dispositivos' => const DevicesScreen(),
        'Privacidade e dados' => PrivacyScreen(deps: deps),
        _ => PreferencesScreen(deps: deps),
      };

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
              key: Key('account_$title'),
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _screenFor(title))),
            ),
          ListTile(
            key: const Key('account_delete'),
            leading: Icon(Icons.person_remove_outlined, color: c.error),
            title: Text('Excluir conta e todos os dados', style: t.titleSmall?.copyWith(color: c.error)),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => EraseDataScreen(deps: deps, deleteAccount: true)),
            ),
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
