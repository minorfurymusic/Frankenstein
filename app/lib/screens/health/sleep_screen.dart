import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';

/// Sono (prancheta Sono): noites e duração vindas da pulseira, via Health
/// Connect (`packages/wearable`). Fases do sono ainda não chegam no evento.
class SleepScreen extends StatelessWidget {
  final AppDependencies deps;
  const SleepScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nights = deps.healthRead.sleeps();
    return Scaffold(
      appBar: AppBar(title: const Text('Sono')),
      body: ListView(
        padding: const EdgeInsets.all(RltSpace.l),
        children: [
          if (nights.isEmpty)
            const StateCard(
              icon: Icons.bedtime_outlined,
              title: 'Nenhuma noite registrada',
              message: 'O sono vem da pulseira ou do relógio. Conecte em Conta › Dispositivos (Health Connect).',
              tone: StateTone.permission,
            )
          else ...[
            const RltSectionHeader('Últimas noites'),
            for (final n in nights)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.bedtime_outlined),
                title: Text(n.durationLabel, style: RltTheme.tabular(t.titleMedium!)),
                subtitle: Text('${ddmm(n.startLocal)} · ${hhmm(n.startLocal)} → ${hhmm(n.endLocal)}'),
              ),
          ],
          // TODO(frankstein): fases do sono (profundo, leve, REM) quando o leitor do Health Connect trouxer as etapas.
          const SizedBox(height: RltSpace.l),
          const HealthDisclaimer(),
        ],
      ),
    );
  }
}
