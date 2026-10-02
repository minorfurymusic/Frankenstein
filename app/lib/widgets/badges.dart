import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';

/// Selos da prancheta Componentes ("Selos"). O Premium nunca mostra preço
/// nem onde comprar (ADR-7, ADR-14).
enum RltBadgeKind { estimate, premium, continuousUse, overdue }

class RltBadge extends StatelessWidget {
  final RltBadgeKind kind;
  const RltBadge(this.kind, {super.key});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final (String label, IconData? icon, Color bg, Color fg) = switch (kind) {
      RltBadgeKind.estimate => ('Estimativa', Icons.info_outline, c.tertiaryContainer, c.onTertiaryContainer),
      RltBadgeKind.premium => ('Premium', Icons.workspace_premium_outlined, c.secondaryContainer, c.onSecondaryContainer),
      RltBadgeKind.continuousUse => ('Uso contínuo', null, c.secondaryContainer, c.onSecondaryContainer),
      RltBadgeKind.overdue => ('Atrasado', Icons.warning_amber_rounded, c.errorContainer, c.onErrorContainer),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: fg), const SizedBox(width: 4)],
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Aviso curto de saúde — rodapé fixo da aba Saúde e das respostas do
/// Cérebro sobre saúde (`.claude/rules/brain.md`: a IA registra, não
/// diagnostica).
class HealthDisclaimer extends StatelessWidget {
  static const text =
      'O RLT não faz diagnóstico nem prescrição. Em caso de dúvida ou sintoma preocupante, procure um profissional de saúde.';

  const HealthDisclaimer({super.key});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: c.surfaceContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: c.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall)),
        ],
      ),
    );
  }
}
