import 'package:flutter/material.dart';

import '../../app_version.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';

/// Conta › Sobre (prancheta ContaSobre): nome, versão, aviso de saúde,
/// licenças de código aberto, política de privacidade e termos de uso.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const appName = 'RLT — Real Life Track';

  void _open(BuildContext context, Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Sobre')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(RltRadius.card)),
            child: Icon(Icons.favorite_outline, size: 36, color: c.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: RltSpace.m),
        Text(appName, style: t.titleLarge, textAlign: TextAlign.center),
        Text('Versão $kAppVersion', key: const Key('about_version'), style: t.bodyMedium, textAlign: TextAlign.center),
        const SizedBox(height: RltSpace.l),
        const HealthDisclaimer(),
        const SizedBox(height: RltSpace.m),
        ListTile(
          key: const Key('about_licenses'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.code),
          title: const Text('Licenças de código aberto'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLicensePage(
            context: context,
            applicationName: appName,
            applicationVersion: kAppVersion,
            applicationLegalese: 'Código aberto (copyleft). Sem anúncios, sem telemetria.',
          ),
        ),
        ListTile(
          key: const Key('about_privacy'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.lock_outline),
          title: const Text('Política de privacidade'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, const _CommitmentsScreen(title: 'Política de privacidade')),
        ),
        ListTile(
          key: const Key('about_terms'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.description_outlined),
          title: const Text('Termos de uso'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(context, const _CommitmentsScreen(title: 'Termos de uso')),
        ),
      ]),
    );
  }
}

/// Os compromissos do app, em linguagem simples. O texto jurídico completo
/// da política e dos termos ainda não existe.
// TODO(frankstein): texto jurídico da política de privacidade (LGPD) e dos termos de uso, revisado por advogado, antes de publicar.
class _CommitmentsScreen extends StatelessWidget {
  final String title;
  const _CommitmentsScreen({required this.title});

  static const commitments = [
    'Seus dados de saúde ficam no seu celular. Nada vai para a internet sem uma ação sua.',
    'Sem anúncios, sem telemetria e sem rastreador.',
    'A IA só é usada com a sua chave e depois do seu consentimento; só vai o que você mandar naquela mensagem.',
    'Você pode exportar ou apagar tudo quando quiser, sem custo e sem limite.',
    'O RLT registra; não faz diagnóstico nem prescrição.',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text('Nossos compromissos', style: t.titleMedium),
        const SizedBox(height: RltSpace.s),
        for (final c in commitments)
          Padding(
            padding: const EdgeInsets.only(bottom: RltSpace.s),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Padding(padding: EdgeInsets.only(top: 2), child: Icon(Icons.check, size: 18)),
              const SizedBox(width: RltSpace.s),
              Expanded(child: Text(c, style: t.bodyMedium)),
            ]),
          ),
        const SizedBox(height: RltSpace.m),
        Text('O texto completo será publicado antes do lançamento.', key: const Key('about_full_text_pending'), style: t.bodySmall),
      ]),
    );
  }
}
