import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';
import 'health_area.dart';

/// Os quatro estados do cartão de proposta da IA (prancheta Componentes).
/// Nada é salvo antes do toque em "Confirmar" (`.claude/rules/brain.md`:
/// confirmação humana antes de qualquer escrita).
enum ProposalState { pending, editing, confirmed, discarded }

/// Cartão de proposta — o componente mais importante do app
/// (`docs/design/PROMPT-CLAUDE-DESIGN.md`, seção 3). Um cartão por item que a
/// IA (ou o roteador do modo básico) entendeu.
class ProposalCard extends StatelessWidget {
  final HealthArea area;
  final String title;
  final String? detail;
  final String? whenLabel;
  final ProposalState state;

  /// Onde ficou salvo, ex.: "Nutrição › Água". Só no estado confirmado.
  final String? savedIn;

  /// Campos de edição, só no estado `editing`.
  final Widget? editor;

  final VoidCallback? onConfirm;
  final VoidCallback? onEdit;
  final VoidCallback? onDiscard;
  final VoidCallback? onCancelEdit;
  final VoidCallback? onUndo;

  /// Chaves dos botões, para teste e acessibilidade automatizada.
  final Key? confirmKey;
  final Key? discardKey;

  const ProposalCard({
    this.confirmKey,
    this.discardKey,
    super.key,
    required this.area,
    required this.title,
    required this.state,
    this.detail,
    this.whenLabel,
    this.savedIn,
    this.editor,
    this.onConfirm,
    this.onEdit,
    this.onDiscard,
    this.onCancelEdit,
    this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final discarded = state == ProposalState.discarded;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        HealthAreaIcon(area: area),
        const SizedBox(width: RltSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(area.label.toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: 0.6)),
              Text(
                title,
                style: t.titleMedium?.copyWith(
                  decoration: discarded ? TextDecoration.lineThrough : null,
                  color: discarded ? c.onSurfaceVariant : null,
                ),
              ),
              if (state == ProposalState.editing)
                Text('Edite antes de confirmar', style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant))
              else if (detail != null && !discarded)
                Text(detail!, style: RltTheme.tabular(t.bodyMedium!.copyWith(color: c.onSurfaceVariant))),
            ],
          ),
        ),
      ],
    );

    final List<Widget> body = switch (state) {
      ProposalState.pending => [
          if (whenLabel != null) ...[
            const SizedBox(height: RltSpace.s),
            Row(children: [
              Icon(Icons.schedule, size: 14, color: c.onSurfaceVariant),
              const SizedBox(width: 6),
              Text(whenLabel!, style: t.bodySmall),
            ]),
          ],
          const SizedBox(height: RltSpace.s),
          // OverflowBar: com fonte grande do sistema (o layout testa 160%) os
          // botões descem para uma segunda linha em vez de estourar.
          OverflowBar(
            alignment: MainAxisAlignment.spaceBetween,
            overflowAlignment: OverflowBarAlignment.end,
            overflowSpacing: RltSpace.s,
            children: [
              TextButton(key: discardKey, onPressed: onDiscard, child: const Text('Descartar')),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton.outlined(
                    onPressed: onEdit,
                    tooltip: 'Editar $title',
                    icon: const Icon(Icons.edit_outlined, size: 20),
                  ),
                  const SizedBox(width: RltSpace.s),
                  FilledButton.icon(key: confirmKey, onPressed: onConfirm, icon: const Icon(Icons.check, size: 18), label: const Text('Confirmar')),
                ],
              ),
            ],
          ),
        ],
      ProposalState.editing => [
          if (editor != null) ...[const SizedBox(height: RltSpace.m), editor!],
          const SizedBox(height: RltSpace.m),
          OverflowBar(
            alignment: MainAxisAlignment.end,
            overflowAlignment: OverflowBarAlignment.end,
            spacing: RltSpace.s,
            overflowSpacing: RltSpace.s,
            children: [
              TextButton(onPressed: onCancelEdit, child: const Text('Cancelar')),
              FilledButton.icon(onPressed: onConfirm, icon: const Icon(Icons.check, size: 18), label: const Text('Confirmar')),
            ],
          ),
        ],
      ProposalState.confirmed => [
          const SizedBox(height: RltSpace.s),
          Row(
            children: [
              Icon(Icons.check, size: 18, color: c.success),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  savedIn == null ? 'Salvo' : 'Salvo em $savedIn',
                  style: t.labelLarge?.copyWith(fontSize: 14, color: c.success),
                ),
              ),
              if (onUndo != null) TextButton(onPressed: onUndo, child: const Text('Desfazer')),
            ],
          ),
        ],
      ProposalState.discarded => [
          const SizedBox(height: RltSpace.s),
          Row(
            children: [
              Icon(Icons.close, size: 18, color: c.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(child: Text('Descartado — nada foi salvo', style: t.labelLarge?.copyWith(fontSize: 14, color: c.onSurfaceVariant))),
              if (onUndo != null) TextButton(onPressed: onUndo, child: const Text('Desfazer')),
            ],
          ),
        ],
    };

    final content = Padding(
      padding: const EdgeInsets.all(RltSpace.l),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, ...body]),
    );

    if (discarded) {
      return CustomPaint(
        painter: _DashedBorderPainter(color: c.outline, radius: RltRadius.card),
        child: content,
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: state == ProposalState.confirmed ? c.surfaceContainerLow : c.surface,
        borderRadius: BorderRadius.circular(RltRadius.card),
        border: switch (state) {
          ProposalState.editing => Border.all(color: c.primary, width: 1.5),
          ProposalState.confirmed => null,
          _ => Border.all(color: c.outlineVariant),
        },
      ),
      child: content,
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius((Offset.zero & size).deflate(0.5), Radius.circular(radius));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (double d = 0; d < metric.length; d += 7) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}
