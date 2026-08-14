import 'run_calculator.dart';
import 'run_point.dart';

/// Ofusca os primeiros e últimos [marginMeters] (300 m por padrão) de uma
/// rota antes de qualquer compartilhamento — sem exceção, mesmo card
/// gerado localmente (`.claude/rules/activity.md:20-21`,
/// `.claude/rules/share.md:13`). Remove (não embaralha) os pontos dentro
/// dessa faixa de distância acumulada a partir de cada ponta.
///
/// Rota é dado de localização sensível: quem vê o card não pode
/// reconstruir onde a corrida começou ou terminou (normalmente
/// casa/trabalho de quem correu).
///
/// **Decisão registrada:** se a rota inteira tem menos de
/// `marginMeters * 2`, os dois recortes se sobrepõem — não existe um
/// "meio seguro" pra revelar sem também revelar onde a rota começou ou
/// terminou. Nesse caso devolve lista vazia, não uma tentativa parcial de
/// ofuscar.
List<RunPointInput> obfuscateRouteEnds(
  List<RunPointInput> points, {
  double marginMeters = 300,
}) {
  if (points.length < 2) return const [];

  final total = RunCalculator.totalDistanceMeters(points);
  if (total < marginMeters * 2) return const [];

  final distanceFromEnd = List<double>.filled(points.length, 0);
  for (var i = points.length - 2; i >= 0; i--) {
    distanceFromEnd[i] = distanceFromEnd[i + 1] + RunCalculator.distanceMeters(points[i], points[i + 1]);
  }

  final kept = <RunPointInput>[];
  var distanceFromStart = 0.0;
  for (var i = 0; i < points.length; i++) {
    if (i > 0) {
      distanceFromStart += RunCalculator.distanceMeters(points[i - 1], points[i]);
    }
    if (distanceFromStart >= marginMeters && distanceFromEnd[i] >= marginMeters) {
      kept.add(points[i]);
    }
  }
  return kept;
}
