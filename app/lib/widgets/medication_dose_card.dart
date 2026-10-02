import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';
import 'health_area.dart';

/// Estado de uma dose na tela: próxima, atrasada ou tomada (prancheta
/// Componentes, "Cartão de remédio — próximo / atrasado / tomado").
enum DoseCardStatus { upcoming, overdue, taken }

class MedicationDoseCard extends StatelessWidget {
  final String name;
  final String dose;
  final String time; // "HH:mm" local
  final DoseCardStatus status;
  final String? takenAt; // "HH:mm", só quando tomada
  final VoidCallback? onTaken;
  final VoidCallback? onSkipped;
  final VoidCallback? onUndo;

  /// Dose marcada como pulada: mostra "Pulado" no lugar dos botões.
  final bool skipped;

  const MedicationDoseCard({
    this.skipped = false,
    super.key,
    required this.name,
    required this.dose,
    required this.time,
    required this.status,
    this.takenAt,
    this.onTaken,
    this.onSkipped,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final taken = status == DoseCardStatus.taken;
    final overdue = status == DoseCardStatus.overdue && !skipped;
    final statusLabel = skipped
        ? 'PULADO'
        : switch (status) {
            DoseCardStatus.upcoming => 'PRÓXIMO',
            DoseCardStatus.overdue => 'ATRASADO',
            DoseCardStatus.taken => 'TOMADO',
          };
    final onColor = overdue ? c.onErrorContainer : c.onSurface;

    return Container(
      padding: const EdgeInsets.all(RltSpace.l),
      decoration: BoxDecoration(
        color: overdue ? c.errorContainer : (taken || skipped ? c.surfaceContainerLow : c.surface),
        borderRadius: BorderRadius.circular(RltRadius.card),
        border: overdue || taken || skipped ? null : Border.all(color: c.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HealthAreaIcon(area: HealthArea.medication, size: 40),
              const SizedBox(width: RltSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: t.titleMedium?.copyWith(color: onColor)),
                    Text(dose, style: t.bodyMedium?.copyWith(color: onColor)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time, style: RltTheme.tabular(t.titleMedium!.copyWith(color: onColor))),
                  Text(statusLabel, style: t.labelSmall?.copyWith(color: onColor, letterSpacing: 0.5)),
                ],
              ),
            ],
          ),
          const SizedBox(height: RltSpace.m),
          if (taken || skipped)
            Row(
              children: [
                Expanded(
                  child: Text(
                    skipped ? 'Pulado' : (takenAt == null ? 'Tomado' : 'Tomado às $takenAt'),
                    style: t.bodySmall,
                  ),
                ),
                if (onUndo != null) TextButton(onPressed: onUndo, child: const Text('Desfazer')),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onSkipped,
                    style: overdue ? OutlinedButton.styleFrom(foregroundColor: c.onErrorContainer, side: BorderSide(color: c.onErrorContainer)) : null,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('Pulei'),
                  ),
                ),
                const SizedBox(width: RltSpace.s),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onTaken,
                    style: overdue ? FilledButton.styleFrom(backgroundColor: c.error, foregroundColor: c.onError) : null,
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Tomei'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
