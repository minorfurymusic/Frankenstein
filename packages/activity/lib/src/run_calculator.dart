import 'dart:math';

import 'run_point.dart';

/// Tempo e pace de um km completo percorrido.
class RunSplit {
  final int km;
  final Duration duration;
  final double paceSecondsPerKm;

  RunSplit({
    required this.km,
    required this.duration,
    required this.paceSecondsPerKm,
  });
}

/// Resumo calculado de uma corrida/caminhada — o que
/// `packages/activity/lib/src/run_tools.dart` (`get_run_summary`) expõe
/// pro cérebro, sem os pontos de rota brutos (que ficam só no Health Data
/// Core, `docs/ARQUITETURA.md`).
class RunSummary {
  final double distanceMeters;
  final Duration duration;
  final double elevationGainMeters;
  final List<RunSplit> splits;
  final double? averagePaceSecondsPerKm;

  RunSummary({
    required this.distanceMeters,
    required this.duration,
    required this.elevationGainMeters,
    required this.splits,
    required this.averagePaceSecondsPerKm,
  });
}

/// Cálculos puros sobre uma lista de [RunPointInput] — distância
/// (haversine), splits por km, ganho de elevação, filtro de ruído por
/// precisão (`docs/PRODUTO.md:29`, `.claude/rules/activity.md:16-17`).
///
/// Não sabe nada sobre captura de GPS real nem sobre o Health Data Core
/// — isso é responsabilidade de [RunLogger]. A captura em si (sensor,
/// foreground service) é do app Android (`docs/adr/009-gps.md`),
/// fora do escopo Dart puro. Captura: `RunRecorderService.kt` (gravador
/// próprio, ADR-9 revisão 1).
class RunCalculator {
  static const double defaultMaxAccuracyMeters = 20.0;

  static const double _earthRadiusMeters = 6371000.0;

  /// Descarta pontos com precisão pior que [maxAccuracyMeters]
  /// (`.claude/rules/activity.md:16`: "Descarte pontos com precisão pior
  /// que 20 m"). Pontos sem `accuracyMeters` relatado (`null`) são
  /// mantidos — não dá pra invalidar um ponto por um dado que a fonte
  /// nunca forneceu; decisão registrada aqui, não escondida.
  static List<RunPointInput> filterByAccuracy(
    List<RunPointInput> points, {
    double maxAccuracyMeters = defaultMaxAccuracyMeters,
  }) {
    return points
        .where((p) => p.accuracyMeters == null || p.accuracyMeters! <= maxAccuracyMeters)
        .toList();
  }

  /// Distância em metros entre duas leituras, por Haversine (superfície
  /// esférica — simplificação padrão pra distância curta de corrida, não
  /// usa elipsoide WGS84 exato).
  static double distanceMeters(RunPointInput a, RunPointInput b) {
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dLat = (b.latitude - a.latitude) * pi / 180;
    final dLon = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(h), sqrt(1 - h));
    return _earthRadiusMeters * c;
  }

  /// Velocidade acima da qual um salto entre dois pontos é ruído de GPS
  /// para corrida/caminhada (12 m/s ≈ 43 km/h, acima de um velocista).
  static const double maxPlausibleSpeedMetersPerSecond = 12.0;

  /// Filtro de ruído antes do ritmo (`.claude/rules/activity.md`): tira o
  /// ponto que "pularia" mais rápido que [maxSpeed] em relação ao último
  /// ponto aceito do mesmo trecho.
  static List<RunPointInput> filterSpeedOutliers(
    List<RunPointInput> points, {
    double maxSpeed = maxPlausibleSpeedMetersPerSecond,
  }) {
    final out = <RunPointInput>[];
    for (final p in points) {
      final prev = out.isEmpty ? null : out.last;
      if (prev != null && prev.segment == p.segment) {
        final dt = p.recordedAt.difference(prev.recordedAt).inMilliseconds / 1000;
        if (dt <= 0) continue;
        if (distanceMeters(prev, p) / dt > maxSpeed) continue;
      }
      out.add(p);
    }
    return out;
  }

  static bool _sameSegment(RunPointInput a, RunPointInput b) => a.segment == b.segment;

  static double totalDistanceMeters(List<RunPointInput> points) {
    if (points.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      if (_sameSegment(points[i - 1], points[i])) total += distanceMeters(points[i - 1], points[i]);
    }
    return total;
  }

  /// Soma só os ganhos positivos de elevação entre leituras consecutivas
  /// com dado de elevação — perdas (descida) não entram no total, mesma
  /// convenção de "elevation gain" usada por apps de corrida em geral.
  static double elevationGainMeters(List<RunPointInput> points) {
    var gain = 0.0;
    for (var i = 1; i < points.length; i++) {
      final prev = points[i - 1].elevationMeters;
      final curr = points[i].elevationMeters;
      if (prev != null && curr != null && curr > prev && _sameSegment(points[i - 1], points[i])) {
        gain += curr - prev;
      }
    }
    return gain;
  }

  /// Tempo em movimento: soma do tempo de cada trecho (pausas não contam).
  static Duration totalDuration(List<RunPointInput> points) {
    var total = Duration.zero;
    for (var i = 1; i < points.length; i++) {
      if (_sameSegment(points[i - 1], points[i])) total += points[i].recordedAt.difference(points[i - 1].recordedAt);
    }
    return total;
  }

  /// Splits por km (`docs/PRODUTO.md:29`): pra cada km completo (por
  /// distância acumulada cruzando um múltiplo de 1000 m), o tempo
  /// decorrido desde o split anterior. **Simplificação registrada:** o
  /// corte do km acontece no primeiro ponto que cruza o limiar, sem
  /// interpolar a fração exata do segmento — erro fica dentro do
  /// intervalo entre leituras de GPS consecutivas, não acumula entre
  /// splits.
  static List<RunSplit> kmSplits(List<RunPointInput> points) {
    if (points.length < 2) return const [];
    final splits = <RunSplit>[];
    var distanceSinceLastSplit = 0.0;
    var timeSinceLastSplit = Duration.zero;
    var currentKm = 1;

    for (var i = 1; i < points.length; i++) {
      if (!_sameSegment(points[i - 1], points[i])) continue;
      distanceSinceLastSplit += distanceMeters(points[i - 1], points[i]);
      timeSinceLastSplit += points[i].recordedAt.difference(points[i - 1].recordedAt);
      // Epsilon contra ruído de ponto flutuante do Haversine — GPS real
      // nunca cai exatamente em 1000.000000 m, então isto não afrouxa o
      // limiar na prática, só evita perder um km por causa de erro de
      // arredondamento de fração de milímetro.
      if (distanceSinceLastSplit >= 1000 - 1e-6) {
        final duration = timeSinceLastSplit;
        splits.add(RunSplit(
          km: currentKm,
          duration: duration,
          paceSecondsPerKm: duration.inSeconds.toDouble(),
        ));
        currentKm++;
        distanceSinceLastSplit = 0;
        timeSinceLastSplit = Duration.zero;
      }
    }
    return splits;
  }

  /// `null` quando a distância total é zero (sem pace possível de
  /// calcular) — nunca divide por zero silenciosamente.
  static double? averagePaceSecondsPerKm(List<RunPointInput> points) {
    final distanceKm = totalDistanceMeters(points) / 1000;
    if (distanceKm <= 0) return null;
    return totalDuration(points).inSeconds / distanceKm;
  }

  static RunSummary summarize(List<RunPointInput> points) {
    return RunSummary(
      distanceMeters: totalDistanceMeters(points),
      duration: totalDuration(points),
      elevationGainMeters: elevationGainMeters(points),
      splits: kmSplits(points),
      averagePaceSecondsPerKm: averagePaceSecondsPerKm(points),
    );
  }
}
