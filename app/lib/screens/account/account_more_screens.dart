import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app_dependencies.dart';
import '../../data/data_export.dart';
import '../../step_tracking_controller.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../wearables/health_connect.dart';
import 'devices_screen.dart';

/// Conta › Privacidade e dados (prancheta ContaPrivacidade): exportar tudo
/// (grátis, sem limite) e apagar tudo (confirmação forte).
class PrivacyScreen extends StatelessWidget {
  final AppDependencies deps;
  const PrivacyScreen({super.key, required this.deps});

  Future<void> _export(BuildContext context) async {
    final zip = await buildFullExportZip(deps);
    final now = DateTime.now();
    final name = 'rlt-dados-${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.zip';
    await deps.shareSheet.shareFile(zip, fileName: name, mimeType: 'application/zip');
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidade e dados')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text(
          'Seus dados de saúde ficam só neste celular. Nada vai para a internet sem uma ação sua. '
          'Sem anúncios, sem telemetria, sem rastreador.',
          style: t.bodyLarge,
        ),
        const RltSectionHeader('Pulseira e Health Connect'),
        Text(
          'Com a sua permissão, o RLT só LÊ do Health Connect o sono (com as fases) e a frequência cardíaca que a '
          'pulseira ou o relógio gravou lá. Não escreve nada no Health Connect, não envia esses dados para a internet '
          'e usa só para mostrar o seu sono e os seus batimentos aqui. A permissão pode ser tirada a qualquer hora no '
          'próprio Health Connect; o que já foi lido sai com "Apagar todos os dados".',
          key: const Key('privacy_health_connect'),
          style: t.bodyMedium,
        ),
        const RltSectionHeader('Exportar'),
        Text('Todos os seus registros num arquivo .zip (dados em JSON, mais as fotos e PDFs de receitas e exames), '
            'sempre grátis e sem limite (LGPD art. 18). Você escolhe para onde mandar.', style: t.bodyMedium),
        const SizedBox(height: RltSpace.m),
        FilledButton.icon(
          key: const Key('export_all'),
          onPressed: () => _export(context),
          icon: const Icon(Icons.file_download_outlined),
          label: const Text('Exportar todos os dados'),
        ),
        const RltSectionHeader('Apagar'),
        Text('Apaga todos os registros, remédios, metas, planos e preferências deste celular. Não dá para desfazer. '
            'Exporte antes se quiser guardar uma cópia.', style: t.bodyMedium),
        const SizedBox(height: RltSpace.m),
        OutlinedButton.icon(
          key: const Key('erase_all'),
          style: OutlinedButton.styleFrom(foregroundColor: c.error, side: BorderSide(color: c.error)),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => EraseDataScreen(deps: deps))),
          icon: const Icon(Icons.delete_forever_outlined),
          label: const Text('Apagar todos os dados'),
        ),
      ]),
    );
  }
}

/// Confirmação forte (prancheta ContaExcluir): explica o que é apagado e
/// pede para digitar APAGAR.
class EraseDataScreen extends StatefulWidget {
  final AppDependencies deps;
  final bool deleteAccount;

  /// Fecha o app depois de apagar (o próximo início abre bancos novos).
  /// Teste injeta um no-op.
  final Future<void> Function()? onErased;
  const EraseDataScreen({super.key, required this.deps, this.deleteAccount = false, this.onErased});

  @override
  State<EraseDataScreen> createState() => _EraseDataScreenState();
}

class _EraseDataScreenState extends State<EraseDataScreen> {
  final _word = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  Future<void> _erase() async {
    await widget.deps.eraseAllDataAndClose();
    if (!mounted) return;
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(RltSpace.xl),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.check_circle_outline, size: 64, color: c.success),
              const SizedBox(height: RltSpace.l),
              Text('Dados apagados', style: t.headlineSmall, textAlign: TextAlign.center, key: const Key('erase_done')),
              const SizedBox(height: RltSpace.s),
              Text('O RLT vai fechar. Ao abrir de novo, ele começa do zero.', style: t.bodyLarge, textAlign: TextAlign.center),
              const SizedBox(height: RltSpace.xl),
              FilledButton(
                key: const Key('erase_close_app'),
                onPressed: widget.onErased ?? () => SystemNavigator.pop(),
                child: const Text('Fechar o app'),
              ),
            ]),
          ),
        ),
      );
    }
    final ok = _word.text.trim().toUpperCase() == 'APAGAR';
    return Scaffold(
      appBar: AppBar(title: Text(widget.deleteAccount ? 'Excluir conta' : 'Apagar todos os dados')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text('Isto apaga deste celular:', style: t.titleSmall),
        const SizedBox(height: RltSpace.s),
        for (final item in const [
          'refeições, água, passos, treinos, corridas e atividades',
          'remédios, doses, sintomas, sinais vitais e medidas',
          'perfil, metas, preferências, lembretes',
          'planos de treino, itens e receitas próprias',
        ])
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.remove, size: 18, color: c.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text(item, style: t.bodyLarge)),
            ]),
          ),
        if (widget.deleteAccount) ...[
          const SizedBox(height: RltSpace.m),
          // TODO(frankstein): apagar também a conta no servidor quando o login Google existir (ADR-13).
          Text('A conta Google entra com o login; quando existir, ela também é excluída aqui.', style: t.bodySmall),
        ],
        const SizedBox(height: RltSpace.l),
        Text('Para confirmar, digite APAGAR:', style: t.titleSmall),
        const SizedBox(height: RltSpace.s),
        TextField(
          key: const Key('erase_word'),
          controller: _word,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: RltSpace.l),
        FilledButton.icon(
          key: const Key('erase_confirm'),
          style: FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.onError),
          onPressed: ok ? _erase : null,
          icon: const Icon(Icons.delete_forever),
          label: const Text('Apagar tudo agora'),
        ),
      ]),
    );
  }
}

/// Conta › Permissões (prancheta ContaPermissoes): cada permissão, para que
/// serve e o estado.
class PermissionsScreen extends StatelessWidget {
  final AppDependencies deps;
  const PermissionsScreen({super.key, required this.deps});

  Future<String> _healthConnectState() async {
    final bridge = deps.wearables.bridge;
    switch (await bridge.status()) {
      case HealthConnectStatus.unsupported:
        return 'Indisponível neste aparelho (precisa do Android 9 ou mais novo)';
      case HealthConnectStatus.notInstalled:
      case HealthConnectStatus.updateRequired:
        return 'Health Connect não encontrado';
      case HealthConnectStatus.available:
        final granted = await bridge.grantedPermissions();
        if (granted.length == HealthConnectData.values.length) return 'Permitida';
        if (granted.isEmpty) return 'Não permitida';
        return 'Permitida em parte';
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget row(IconData icon, String title, String why, String state, {VoidCallback? onTap}) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(icon),
          title: Text(title, style: t.titleSmall),
          subtitle: Text('$why\n$state'),
          isThreeLine: true,
          trailing: onTap == null ? null : TextButton(onPressed: onTap, child: const Text('Ativar')),
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Permissões')),
      body: ValueListenableBuilder<StepTrackingStatus>(
        valueListenable: deps.stepTracking.status,
        builder: (context, steps, _) => ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
          row(
            Icons.directions_walk_outlined,
            'Atividade física',
            'Contar passos, mesmo com a tela bloqueada.',
            switch (steps) {
              StepTrackingStatus.active => 'Permitida',
              StepTrackingStatus.permissionDenied => 'Negada',
              StepTrackingStatus.noSensor => 'Aparelho sem sensor de passos',
              StepTrackingStatus.unsupportedPlatform => 'Indisponível neste aparelho',
              StepTrackingStatus.unknown => 'Verificando…',
            },
            onTap: steps == StepTrackingStatus.permissionDenied ? () => deps.stepTracking.start() : null,
          ),
          FutureBuilder<bool>(
            future: deps.reminders.scheduler.hasPermission(),
            builder: (context, snap) => row(
              Icons.notifications_none,
              'Notificações',
              'Lembretes de remédio, água e treino.',
              snap.data == null ? 'Verificando…' : (snap.data! ? 'Permitida' : 'Negada'),
              onTap: snap.data == false ? () => deps.reminders.scheduler.requestPermission() : null,
            ),
          ),
          row(
            Icons.photo_camera_outlined,
            'Câmera',
            'Código de barras e fotos de receitas e exames. Nada é gravado sem você salvar.',
            'O Android pergunta na primeira vez que você abre a câmera',
          ),
          FutureBuilder<String>(
            future: _healthConnectState(),
            builder: (context, snap) => row(
              Icons.watch_outlined,
              'Dados de saúde da pulseira',
              'Sono e batimentos via Health Connect (só leitura).',
              snap.data ?? 'Verificando…',
              onTap: snap.data == null || snap.data!.startsWith('Permitida')
                  ? null
                  : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DevicesScreen(deps: deps))),
            ),
          ),
          FutureBuilder<bool>(
            future: deps.runRecorder.hasPermission(),
            builder: (context, snap) => row(
              Icons.location_on_outlined,
              'Localização',
              'Gravar a rota da corrida e da caminhada, só enquanto grava.',
              snap.data == null ? 'Verificando…' : (snap.data! ? 'Permitida' : 'O Android pergunta quando você inicia uma corrida'),
            ),
          ),
          FutureBuilder<bool>(
            key: const Key('permission_mic'),
            future: deps.voiceRecorder.hasPermission(),
            builder: (context, snap) => row(
              Icons.mic_none,
              'Microfone',
              'Falar com o Cérebro (com a IA ativa). O áudio vai à IA só quando você solta o botão e não fica guardado.',
              snap.data == null ? 'Verificando…' : (snap.data! ? 'Permitida' : 'O Android pergunta quando você segura o microfone no Cérebro'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Conta › Assinatura (prancheta ContaAssinatura; ADR-14). Nenhum preço,
/// valor ou link de compra (ADR-7). O plano vem do servidor — o cliente
/// nunca decide (`.claude/rules/monetizacao.md`).
class SubscriptionScreen extends StatelessWidget {
  const SubscriptionScreen({super.key});

  static const premium = [
    'Conectar prontuário de hospital',
    'Relatório para levar à consulta',
    'Backup criptografado e sincronização entre aparelhos',
    'Acesso pelo navegador',
    'Histórico na nuvem',
    'Conta familiar',
    'Suporte prioritário',
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Assinatura')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text('Plano atual: Grátis', style: t.titleLarge, key: const Key('plan_current')),
        const SizedBox(height: RltSpace.s),
        Text('Tudo o que é essencial, sem anúncios e sem limite para exportar seus dados.', style: t.bodyMedium),
        const RltSectionHeader('Recursos Premium'),
        for (final p in premium)
          ListTile(contentPadding: EdgeInsets.zero, title: Text(p), trailing: const RltBadge(RltBadgeKind.premium)),
        const SizedBox(height: RltSpace.l),
        OutlinedButton(
          key: const Key('plan_refresh'),
          // TODO(frankstein): consultar o entitlement assinado no servidor (ADR-7/ADR-13) quando ele existir.
          onPressed: () => showRltSaved(context, 'O status vem do servidor do RLT, que ainda não está no ar.'),
          child: const Text('Atualizar status da assinatura'),
        ),
      ]),
    );
  }
}

