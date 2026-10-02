import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';
import 'health_area.dart';

/// Item da linha do tempo do dia (prancheta Componentes, "Item da linha do
/// tempo"): horário, ícone da área ligado ao próximo por um traço, título,
/// detalhe e seta. Tocar abre o item.
class TimelineItem extends StatelessWidget {
  final String time; // "HH:mm" local
  final HealthArea area;
  final String title;
  final String? detail;
  final bool isLast;
  final VoidCallback? onTap;

  const TimelineItem({
    super.key,
    required this.time,
    required this.area,
    required this.title,
    this.detail,
    this.isLast = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RltRadius.chip),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: kRltMinTouch + 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(time, style: RltTheme.tabular(t.labelMedium!.copyWith(fontWeight: FontWeight.w700))),
                ),
              ),
              Column(
                children: [
                  HealthAreaIcon(area: area, size: 36, circle: true),
                  if (!isLast) Expanded(child: Container(width: 2, color: c.outlineVariant)),
                ],
              ),
              const SizedBox(width: RltSpace.m),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: RltSpace.m),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.titleMedium),
                      if (detail != null) Text(detail!, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                    ],
                  ),
                ),
              ),
              if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Icon(Icons.chevron_right, color: c.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
