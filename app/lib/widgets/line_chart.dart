import 'package:flutter/material.dart';

import '../format.dart';
import '../theme/rlt_colors.dart';

class ChartPoint {
  final DateTime x;
  final double y;
  const ChartPoint(this.x, this.y);
}

class ChartSeries {
  final String label;
  final Color color;
  final List<ChartPoint> points;
  const ChartSeries({required this.label, required this.color, required this.points});
}

/// Gráfico de linha simples (pranchetas Vitais, Corpo, ExameMarcador), sem
/// biblioteca externa: eixo X no tempo, grade horizontal, pontos marcados,
/// linha de referência opcional tracejada (meta). Legenda embaixo.
class RltLineChart extends StatelessWidget {
  final List<ChartSeries> series;
  final double? referenceY;
  final String? referenceLabel;
  final double height;
  final String semanticsLabel;

  const RltLineChart({
    super.key,
    required this.series,
    required this.semanticsLabel,
    this.referenceY,
    this.referenceLabel,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final all = [for (final s in series) ...s.points];
    if (all.isEmpty) return const SizedBox.shrink();
    all.sort((a, b) => a.x.compareTo(b.x));
    final first = all.first.x;
    final last = all.last.x;
    return Semantics(
      label: semanticsLabel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(
              painter: _LineChartPainter(
                series: series,
                referenceY: referenceY,
                grid: c.outlineVariant,
                reference: c.tertiary,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(children: [
            Text(ddmm(first), style: t.labelMedium),
            const Spacer(),
            if (last != first) Text(ddmm(last), style: t.labelMedium),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            children: [
              for (final s in series) _Legend(color: s.color, label: s.label),
              if (referenceY != null && referenceLabel != null) _Legend(color: c.tertiary, label: referenceLabel!, dashed: true),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final bool dashed;
  const _Legend({required this.color, required this.label, this.dashed = false});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: dashed ? 6 : 14, height: 3, color: color),
      if (dashed) ...[const SizedBox(width: 2), Container(width: 6, height: 3, color: color)],
      const SizedBox(width: 6),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ]);
  }
}

class _LineChartPainter extends CustomPainter {
  final List<ChartSeries> series;
  final double? referenceY;
  final Color grid;
  final Color reference;

  _LineChartPainter({required this.series, required this.referenceY, required this.grid, required this.reference});

  @override
  void paint(Canvas canvas, Size size) {
    final points = [for (final s in series) ...s.points];
    var minY = points.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    var maxY = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    if (referenceY != null) {
      minY = minY < referenceY! ? minY : referenceY!;
      maxY = maxY > referenceY! ? maxY : referenceY!;
    }
    final pad = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.15;
    minY -= pad;
    maxY += pad;
    final minX = points.map((p) => p.x.millisecondsSinceEpoch).reduce((a, b) => a < b ? a : b);
    final maxX = points.map((p) => p.x.millisecondsSinceEpoch).reduce((a, b) => a > b ? a : b);
    const inset = 6.0;

    double dx(DateTime x) => maxX == minX
        ? size.width / 2
        : inset + (x.millisecondsSinceEpoch - minX) / (maxX - minX) * (size.width - 2 * inset);
    double dy(double y) => size.height - (y - minY) / (maxY - minY) * size.height;

    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = size.height * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    if (referenceY != null) {
      final paint = Paint()
        ..color = reference
        ..strokeWidth = 1.5;
      final y = dy(referenceY!);
      for (double x = 0; x < size.width; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
      }
    }

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final sorted = [...s.points]..sort((a, b) => a.x.compareTo(b.x));
      final line = Paint()
        ..color = s.color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(dx(sorted.first.x), dy(sorted.first.y));
      for (final p in sorted.skip(1)) {
        path.lineTo(dx(p.x), dy(p.y));
      }
      canvas.drawPath(path, line);
      final dot = Paint()..color = s.color;
      for (final p in sorted) {
        canvas.drawCircle(Offset(dx(p.x), dy(p.y)), 3.5, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => true;
}
