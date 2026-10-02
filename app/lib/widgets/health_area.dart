import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';

/// Área de destino de um registro. Cartões de proposta, linha do tempo e
/// atalhos mostram o mesmo ícone e a mesma cor para a mesma área
/// (`docs/design/PROMPT-CLAUDE-DESIGN.md`, seção 3: "cada um com o ícone da
/// área de destino").
enum HealthArea {
  meal('Refeição', Icons.restaurant_outlined),
  water('Água', Icons.water_drop_outlined),
  symptom('Sintoma', Icons.sentiment_dissatisfied_outlined),
  medication('Remédio', Icons.medication_outlined),
  workout('Treino', Icons.fitness_center_outlined),
  run('Corrida', Icons.directions_run_outlined),
  sleep('Sono', Icons.bedtime_outlined),
  vitalSign('Sinal vital', Icons.monitor_heart_outlined),
  body('Corpo', Icons.monitor_weight_outlined),
  steps('Passos', Icons.directions_walk_outlined);

  final String label;
  final IconData icon;
  const HealthArea(this.label, this.icon);

  /// Cor do ícone. Refeição usa a terciária (o anel de calorias do design
  /// também), remédio e sintoma usam o erro — como no layout.
  Color color(RltColors c) => switch (this) {
        HealthArea.meal => c.tertiary,
        HealthArea.water => c.water,
        HealthArea.symptom => c.tertiary,
        HealthArea.medication => c.error,
        HealthArea.workout => c.primary,
        HealthArea.run => c.primary,
        HealthArea.sleep => c.sleep,
        HealthArea.vitalSign => c.error,
        HealthArea.body => c.secondary,
        HealthArea.steps => c.primary,
      };
}

/// Ícone da área num quadrado de canto 12 (`RltRadius.icon`), como nos
/// cartões do layout.
class HealthAreaIcon extends StatelessWidget {
  final HealthArea area;
  final double size;
  final bool circle;
  const HealthAreaIcon({super.key, required this.area, this.size = 40, this.circle = false});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final color = area.color(c);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surfaceContainerHigh,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(12),
        border: circle ? null : Border.all(color: color.withValues(alpha: 0.6)),
      ),
      alignment: Alignment.center,
      child: Icon(area.icon, size: size * 0.5, color: color, semanticLabel: area.label),
    );
  }
}
