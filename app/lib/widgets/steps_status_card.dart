import 'package:flutter/material.dart';

import '../app_dependencies.dart';
import '../screens/account/devices_screen.dart';
import '../step_tracking_controller.dart';
import '../theme/rlt_theme.dart';
import 'state_views.dart';

/// Passos sem permissão ou aparelho sem sensor (pranchetas InicioEstados e
/// ExerciciosEstados). Some quando a contagem está funcionando.
class StepsStatusCard extends StatelessWidget {
  final AppDependencies deps;

  /// Prefixo das chaves (`<prefixo>_steps_permission`, `<prefixo>_steps_no_sensor`).
  final String keyPrefix;
  const StepsStatusCard({super.key, required this.deps, required this.keyPrefix});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<StepTrackingStatus>(
      valueListenable: deps.stepTracking.status,
      builder: (context, status, _) => switch (status) {
        StepTrackingStatus.permissionDenied => Padding(
            padding: const EdgeInsets.only(top: RltSpace.m),
            child: StateCard(
              key: Key('${keyPrefix}_steps_permission'),
              icon: Icons.directions_walk_outlined,
              title: 'Contagem de passos desligada',
              message: 'Permita “atividade física” para contar seus passos, inclusive com a tela bloqueada.',
              actionLabel: 'Permitir contagem de passos',
              tone: StateTone.permission,
              onAction: () => deps.stepTracking.start(),
            ),
          ),
        StepTrackingStatus.noSensor => Padding(
            padding: const EdgeInsets.only(top: RltSpace.m),
            child: StateCard(
              key: Key('${keyPrefix}_steps_no_sensor'),
              icon: Icons.watch_outlined,
              title: 'Sem sensor de passos',
              message: 'Este aparelho não tem sensor de passos. Conecte uma pulseira ou relógio para ver seus passos aqui.',
              actionLabel: 'Conectar dispositivo',
              tone: StateTone.permission,
              onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DevicesScreen(deps: deps))),
            ),
          ),
        _ => const SizedBox.shrink(),
      },
    );
  }
}
