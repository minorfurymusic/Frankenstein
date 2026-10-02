import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// Anel de progresso (prancheta Componentes, "Anel de progresso"). `value`
/// pode passar de 1 (meta estourada): o anel fica cheio e o centro mostra o
/// número real.
class ProgressRing extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Color? color;
  final Widget? center;
  final String? semanticsLabel;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 120,
    this.strokeWidth = 12,
    this.color,
    this.center,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Semantics(
      label: semanticsLabel,
      value: '${(value * 100).round()}%',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _RingPainter(
            value: value.isNaN ? 0 : value.clamp(0.0, 1.0),
            color: color ?? c.primary,
            track: c.surfaceContainerHighest,
            strokeWidth: strokeWidth,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;
  _RingPainter({required this.value, required this.color, required this.track, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, base..color = track);
    if (value > 0) {
      canvas.drawArc(arcRect, -math.pi / 2, math.pi * 2 * value, false, base..color = color);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track || old.strokeWidth != strokeWidth;
}

/// Barra de macro: rótulo, "atual / meta g" e barra (prancheta
/// Componentes, "Barra de macro").
class MacroBar extends StatelessWidget {
  final String label;
  final double current;
  final double goal;
  final String unit;
  final Color color;

  const MacroBar({
    super.key,
    required this.label,
    required this.current,
    required this.goal,
    required this.color,
    this.unit = 'g',
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RltColors.of(context);
    final ratio = goal <= 0 ? 0.0 : (current / goal).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: t.labelMedium)),
            Text(
              '${formatNumber(current)} / ${formatNumber(goal)} $unit',
              style: RltTheme.tabular(t.labelMedium!.copyWith(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            color: color,
            backgroundColor: c.surfaceContainerHighest,
            semanticsLabel: label,
          ),
        ),
      ],
    );
  }
}

/// Número no formato brasileiro do layout: milhar com ponto ("1.120"),
/// decimal com vírgula ("68,0"). Sem `intl` — evita dependência só para isso.
String formatNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final negative = parts[0].startsWith('-');
  final digits = negative ? parts[0].substring(1) : parts[0];
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  final integer = '${negative ? '-' : ''}$buffer';
  return parts.length > 1 ? '$integer,${parts[1]}' : integer;
}
