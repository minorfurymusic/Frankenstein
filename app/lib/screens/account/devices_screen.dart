import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../wearables/health_connect.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';

/// "sincronizou há 4 min" / "hoje, 08:10".
String syncedAgo(DateTime? lastUtc, {DateTime? now}) {
  if (lastUtc == null) return 'ainda não sincronizou';
  final n = now ?? DateTime.now();
  final diff = n.toUtc().difference(lastUtc);
  if (diff.inMinutes < 1) return 'sincronizou agora';
  if (diff.inMinutes < 60) return 'sincronizou há ${diff.inMinutes} min';
  return 'sincronizou ${relativeDayTime(lastUtc.toLocal(), now: n).toLowerCase()}';
}

String syncOutcomeMessage(WearableSyncOutcome o) => switch (o.state) {
      WearableSyncState.ok => () {
          final r = o.result!;
          final news = r.sleepSynced + r.heartRateSynced;
          return news == 0
              ? 'Tudo em dia — nada novo no Health Connect.'
              : 'Sincronizado: ${r.sleepSynced} ${r.sleepSynced == 1 ? 'noite' : 'noites'} e ${r.heartRateSynced} batimentos novos.';
        }(),
      WearableSyncState.notConnected => 'Conecte pelo Health Connect primeiro.',
      WearableSyncState.unavailable => 'Health Connect não encontrado neste celular.',
      WearableSyncState.noPermission => 'O RLT não tem permissão para ler no Health Connect.',
      WearableSyncState.error => 'O Health Connect não respondeu. Tente de novo em instantes.',
    };

/// Conta › Dispositivos (prancheta ContaDispositivos): conectar a pulseira
/// ou relógio pelo Health Connect, ver o que é lido, sincronizar e
/// desconectar.
class DevicesScreen extends StatefulWidget {
  final AppDependencies deps;
  const DevicesScreen({super.key, required this.deps});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  HealthConnectStatus? _status;
  Set<HealthConnectData> _granted = const {};
  bool _busy = false;

  WearableSync get _sync => widget.deps.wearables;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await _sync.bridge.status();
    var granted = <HealthConnectData>{};
    if (status == HealthConnectStatus.available) {
      try {
        granted = await _sync.bridge.grantedPermissions();
      } catch (_) {}
    }
    if (mounted) {
      setState(() {
        _status = status;
        _granted = granted;
      });
    }
  }

  Future<void> _run(Future<WearableSyncOutcome> Function() action) async {
    setState(() => _busy = true);
    final outcome = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    showRltSaved(context, syncOutcomeMessage(outcome));
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispositivos')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        if (_status == null)
          const LoadingCard()
        else
          ..._body(context),
      ]),
    );
  }

  List<Widget> _body(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final status = _status!;
    if (status == HealthConnectStatus.unsupported) {
      return const [
        StateCard(
          icon: Icons.watch_outlined,
          title: 'Health Connect indisponível',
          message: 'O Health Connect existe a partir do Android 9. Neste aparelho, o RLT não consegue ler pulseiras.',
          tone: StateTone.permission,
        ),
      ];
    }
    if (status != HealthConnectStatus.available) {
      final update = status == HealthConnectStatus.updateRequired;
      return [
        StateCard(
          key: const Key('hc_missing'),
          icon: Icons.watch_outlined,
          title: update ? 'Atualize o Health Connect' : 'Health Connect não encontrado',
          message: update
              ? 'A versão do Health Connect deste celular é antiga. Atualize para conectar a pulseira.'
              : 'Este celular precisa do app Health Connect para conectar pulseiras. Ele é gratuito, do próprio Android.',
          tone: StateTone.permission,
          actionLabel: update ? 'Atualizar Health Connect' : 'Instalar Health Connect',
          actionIcon: Icons.download_outlined,
          onAction: () async {
            await _sync.bridge.openInstall();
          },
        ),
        const SizedBox(height: RltSpace.m),
        OutlinedButton(onPressed: _refresh, child: const Text('Já instalei')),
      ];
    }
    if (!_sync.enabled) {
      return [
        StateCard(
          key: const Key('hc_connect_card'),
          icon: Icons.watch_outlined,
          title: 'Conecte sua pulseira ou relógio',
          message: 'O RLT lê sono e batimentos pelo Health Connect do Android. Funciona com a maioria das marcas — '
              'o app da pulseira (ou o Gadgetbridge) grava lá, o RLT só lê. Nada vai para a internet.',
          tone: StateTone.permission,
          actionLabel: 'Conectar pelo Health Connect',
          actionIcon: Icons.link,
          onAction: _busy ? null : () => _run(_sync.connect),
        ),
      ];
    }
    final reads = <(String, HealthConnectData?)>[
      ('Sono', HealthConnectData.sleep),
      ('Freq. cardíaca', HealthConnectData.heartRate),
    ];
    return [
      Card(
        key: const Key('hc_connected'),
        child: Padding(
          padding: const EdgeInsets.all(RltSpace.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.watch, color: c.primary),
              const SizedBox(width: RltSpace.m),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Pulseira conectada', style: t.titleMedium),
                  Text('Via Health Connect · ${syncedAgo(_sync.lastSyncUtc)}', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                ]),
              ),
            ]),
            const SizedBox(height: RltSpace.l),
            Text('DADOS LIDOS', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant, letterSpacing: 0.8)),
            const SizedBox(height: RltSpace.s),
            Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
              for (final (label, d) in reads)
                Chip(
                  avatar: Icon(_granted.contains(d) ? Icons.check : Icons.block, size: 16),
                  label: Text(_granted.contains(d) ? label : '$label (sem permissão)'),
                ),
            ]),
            if (_granted.length < reads.length) ...[
              const SizedBox(height: RltSpace.s),
              TextButton(
                key: const Key('hc_ask_again'),
                onPressed: _busy ? null : () => _run(_sync.connect),
                child: const Text('Permitir o que falta'),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(height: RltSpace.l),
      FilledButton.icon(
        key: const Key('hc_sync_now'),
        onPressed: _busy ? null : () => _run(_sync.syncNow),
        icon: _busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : const Icon(Icons.sync),
        label: const Text('Sincronizar agora'),
      ),
      const SizedBox(height: RltSpace.s),
      OutlinedButton.icon(
        onPressed: () => _sync.bridge.openSettings(),
        icon: const Icon(Icons.open_in_new),
        label: const Text('Abrir o Health Connect'),
      ),
      const SizedBox(height: RltSpace.s),
      TextButton(
        key: const Key('hc_disconnect'),
        onPressed: () {
          _sync.disconnect();
          setState(() {});
          showRltSaved(context, 'Desconectado. O que já foi lido continua no RLT; a permissão se tira no Health Connect.');
        },
        child: const Text('Desconectar'),
      ),
      const SizedBox(height: RltSpace.l),
      Text(
        'A pulseira (pelo app dela ou pelo Gadgetbridge) grava no Health Connect; o RLT só lê. Passos continuam '
        'vindo do contador do próprio celular.',
        style: t.bodySmall,
      ),
    ];
  }
}
