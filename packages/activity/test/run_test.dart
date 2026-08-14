import 'dart:math' show pi;

import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

// Metros por grau de latitude no MESMO modelo esférico que
// `RunCalculator.distanceMeters` usa (raio 6371 km) — precisa bater
// exatamente, não é uma aproximação WGS84 separada, senão os testes de
// limiar (splits por km) ficam sensíveis a diferença de poucos metros
// entre os dois modelos.
const double _earthRadiusMeters = 6371000.0;
const double _metersPerDegreeLat = _earthRadiusMeters * pi / 180;

RunPointInput _pointAt({
  required double metersNorthOfOrigin,
  required DateTime recordedAt,
  double? elevationMeters,
  double? accuracyMeters,
  double baseLat = -23.0,
  double baseLon = -46.0,
}) {
  return RunPointInput(
    latitude: baseLat + metersNorthOfOrigin / _metersPerDegreeLat,
    longitude: baseLon,
    recordedAt: recordedAt,
    elevationMeters: elevationMeters,
    accuracyMeters: accuracyMeters,
  );
}

void main() {
  group('RunPointInput — validação', () {
    test('rejeita recordedAt fora de UTC', () {
      expect(
        () => RunPointInput(latitude: 0, longitude: 0, recordedAt: DateTime(2026, 8, 10)),
        throwsArgumentError,
      );
    });

    test('rejeita latitude fora de [-90, 90]', () {
      expect(
        () => RunPointInput(latitude: 91, longitude: 0, recordedAt: DateTime.utc(2026, 8, 10)),
        throwsArgumentError,
      );
    });
  });

  group('RunCalculator — filtro de ruído por precisão', () {
    test('descarta pontos com accuracyMeters pior que o limiar, mantém null', () {
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10), accuracyMeters: 5),
        _pointAt(metersNorthOfOrigin: 10, recordedAt: DateTime.utc(2026, 8, 10, 0, 1), accuracyMeters: 25),
        _pointAt(metersNorthOfOrigin: 20, recordedAt: DateTime.utc(2026, 8, 10, 0, 2), accuracyMeters: null),
        _pointAt(metersNorthOfOrigin: 30, recordedAt: DateTime.utc(2026, 8, 10, 0, 3), accuracyMeters: 20),
      ];

      final filtered = RunCalculator.filterByAccuracy(points);
      expect(filtered, hasLength(3));
      expect(filtered.map((p) => p.accuracyMeters), [5, null, 20]);
    });
  });

  group('RunCalculator — distância (Haversine)', () {
    test('dois pontos ~1000 m ao norte batem com a distância esperada (±1%)', () {
      final a = _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10));
      final b = _pointAt(metersNorthOfOrigin: 1000, recordedAt: DateTime.utc(2026, 8, 10, 0, 5));

      final distance = RunCalculator.distanceMeters(a, b);
      expect(distance, closeTo(1000, 10));
    });

    test('totalDistanceMeters soma segmentos consecutivos', () {
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10)),
        _pointAt(metersNorthOfOrigin: 500, recordedAt: DateTime.utc(2026, 8, 10, 0, 2, 30)),
        _pointAt(metersNorthOfOrigin: 1500, recordedAt: DateTime.utc(2026, 8, 10, 0, 7, 30)),
      ];
      expect(RunCalculator.totalDistanceMeters(points), closeTo(1500, 15));
    });

    test('menos de 2 pontos devolve distância zero', () {
      expect(RunCalculator.totalDistanceMeters([]), 0);
      expect(
        RunCalculator.totalDistanceMeters(
            [_pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10))]),
        0,
      );
    });
  });

  group('RunCalculator — elevação', () {
    test('soma só ganhos positivos, ignora descidas e pontos sem elevação', () {
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10), elevationMeters: 700),
        _pointAt(metersNorthOfOrigin: 100, recordedAt: DateTime.utc(2026, 8, 10, 0, 1), elevationMeters: 710),
        _pointAt(metersNorthOfOrigin: 200, recordedAt: DateTime.utc(2026, 8, 10, 0, 2), elevationMeters: 705),
        _pointAt(metersNorthOfOrigin: 300, recordedAt: DateTime.utc(2026, 8, 10, 0, 3)),
        _pointAt(metersNorthOfOrigin: 400, recordedAt: DateTime.utc(2026, 8, 10, 0, 4), elevationMeters: 720),
      ];
      // +10 (700->710); 710->705 ignorado (descida); 705->null->720 sem par completo intermediário
      expect(RunCalculator.elevationGainMeters(points), 10.0);
    });
  });

  group('RunCalculator — splits por km e pace', () {
    test('kmSplits corta a cada 1000 m percorridos, com o tempo decorrido do split', () {
      final start = DateTime.utc(2026, 8, 10, 6, 0);
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: start),
        _pointAt(metersNorthOfOrigin: 1000, recordedAt: start.add(const Duration(minutes: 5))),
        _pointAt(metersNorthOfOrigin: 2000, recordedAt: start.add(const Duration(minutes: 11))),
        _pointAt(metersNorthOfOrigin: 2500, recordedAt: start.add(const Duration(minutes: 14))),
      ];

      final splits = RunCalculator.kmSplits(points);
      expect(splits, hasLength(2));
      expect(splits[0].km, 1);
      expect(splits[0].duration, const Duration(minutes: 5));
      expect(splits[1].km, 2);
      expect(splits[1].duration, const Duration(minutes: 6));
    });

    test('averagePaceSecondsPerKm é null quando não houve deslocamento', () {
      final p = _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10));
      expect(RunCalculator.averagePaceSecondsPerKm([p, p]), isNull);
    });

    test('summarize combina distância, duração, elevação e splits', () {
      final start = DateTime.utc(2026, 8, 10, 6, 0);
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: start, elevationMeters: 700),
        _pointAt(metersNorthOfOrigin: 1000, recordedAt: start.add(const Duration(minutes: 5)), elevationMeters: 705),
      ];
      final summary = RunCalculator.summarize(points);
      expect(summary.distanceMeters, closeTo(1000, 10));
      expect(summary.duration, const Duration(minutes: 5));
      expect(summary.elevationGainMeters, 5.0);
      expect(summary.splits, hasLength(1));
      expect(summary.averagePaceSecondsPerKm, isNotNull);
    });
  });

  group('obfuscateRouteEnds — privacidade de rota', () {
    test('rota menor que 600 m devolve lista vazia', () {
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10)),
        _pointAt(metersNorthOfOrigin: 400, recordedAt: DateTime.utc(2026, 8, 10, 0, 3)),
      ];
      expect(obfuscateRouteEnds(points), isEmpty);
    });

    test('remove pontos dentro de 300 m do início e do fim, mantém o meio', () {
      final start = DateTime.utc(2026, 8, 10, 6, 0);
      final points = [
        for (var m = 0; m <= 1000; m += 100)
          _pointAt(metersNorthOfOrigin: m.toDouble(), recordedAt: start.add(Duration(seconds: m * 5))),
      ];

      final obfuscated = obfuscateRouteEnds(points);
      expect(obfuscated, isNotEmpty);
      for (final p in obfuscated) {
        final metersFromOrigin = (p.latitude - (-23.0)) * _metersPerDegreeLat;
        expect(metersFromOrigin, greaterThanOrEqualTo(300 - 0.5));
        expect(metersFromOrigin, lessThanOrEqualTo(700 + 0.5));
      }
    });
  });

  group('GPX — export/import', () {
    test('exportGpx produz XML com trkpt por ponto; importGpx lê de volta os mesmos valores', () {
      final points = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10, 6, 0), elevationMeters: 700),
        _pointAt(metersNorthOfOrigin: 50, recordedAt: DateTime.utc(2026, 8, 10, 6, 1), elevationMeters: null),
      ];

      final xmlString = exportGpx(points);
      expect(xmlString, contains('<gpx'));
      expect(xmlString, contains('trkpt'));

      final imported = importGpx(xmlString);
      expect(imported, hasLength(2));
      expect(imported[0].latitude, points[0].latitude);
      expect(imported[0].longitude, points[0].longitude);
      expect(imported[0].elevationMeters, 700);
      expect(imported[0].recordedAt, points[0].recordedAt);
      expect(imported[1].elevationMeters, isNull);
    });

    test('importGpx rejeita trkpt sem <time>', () {
      const xmlSemTime = '''
<?xml version="1.0" encoding="UTF-8"?>
<gpx version="1.1" creator="teste"><trk><trkseg>
<trkpt lat="-23.0" lon="-46.0"></trkpt>
</trkseg></trk></gpx>
''';
      expect(() => importGpx(xmlSemTime), throwsA(isA<InvalidGpxException>()));
    });

    test('importGpx rejeita XML malformado', () {
      expect(() => importGpx('<gpx>'), throwsA(isA<InvalidGpxException>()));
    });
  });

  group('RunLogger', () {
    late HealthDataCore core;
    late RunLogger logger;
    setUp(() {
      core = HealthDataCore.openInMemory();
      logger = RunLogger(core: core);
    });
    tearDown(() => core.close());

    test('logRun filtra por precisão, calcula resumo e grava gps_track + pontos', () {
      final start = DateTime.utc(2026, 8, 10, 6, 0);
      final rawPoints = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: start, accuracyMeters: 5),
        _pointAt(metersNorthOfOrigin: 500, recordedAt: start.add(const Duration(minutes: 3)), accuracyMeters: 40), // descartado
        _pointAt(metersNorthOfOrigin: 1000, recordedAt: start.add(const Duration(minutes: 6)), accuracyMeters: 8),
      ];

      final event = logger.logRun(rawPoints, occurredAtTzOffsetMinutes: -180);

      expect(event.type, HealthEventType.gpsTrack);
      expect(event.payload['points_count'], 2);
      expect(event.payload['points_discarded_by_accuracy'], 1);
      expect(event.payload['distance_meters'], closeTo(1000, 10));

      final storedPoints = core.gpsTrackPoints(event.id);
      expect(storedPoints, hasLength(2));
      expect(storedPoints[0].accuracyMeters, 5);
      expect(storedPoints[1].accuracyMeters, 8);
    });

    test('logRun com menos de 2 pontos após filtro lança InsufficientRunDataException', () {
      final rawPoints = [
        _pointAt(metersNorthOfOrigin: 0, recordedAt: DateTime.utc(2026, 8, 10), accuracyMeters: 5),
        _pointAt(metersNorthOfOrigin: 500, recordedAt: DateTime.utc(2026, 8, 10, 0, 3), accuracyMeters: 99),
      ];
      expect(() => logger.logRun(rawPoints, occurredAtTzOffsetMinutes: -180),
          throwsA(isA<InsufficientRunDataException>()));
    });
  });

  group('get_run_summary — ferramenta do cérebro', () {
    late HealthDataCore core;
    late RunLogger logger;
    setUp(() {
      core = HealthDataCore.openInMemory();
      logger = RunLogger(core: core);
    });
    tearDown(() => core.close());

    test('getRunSummarySpec é ferramenta de leitura', () {
      final spec = getRunSummarySpec();
      expect(spec.write, isFalse);
      expect(spec.confirm, isFalse);
      expect(spec.module, 'activity');
    });

    test('devolve o resumo de uma corrida gravada', () async {
      final start = DateTime.utc(2026, 8, 10, 6, 0);
      final event = logger.logRun(
        [
          _pointAt(metersNorthOfOrigin: 0, recordedAt: start),
          _pointAt(metersNorthOfOrigin: 1000, recordedAt: start.add(const Duration(minutes: 5))),
        ],
        occurredAtTzOffsetMinutes: -180,
      );

      final result = await getRunSummaryHandler(core)({'event_id': event.id});
      expect(result.success, isTrue);
      expect(result.data!['distance_meters'], closeTo(1000, 10));
    });

    test('event_id inexistente ou de outro tipo devolve falha', () async {
      final result = await getRunSummaryHandler(core)({'event_id': 'nao-existe'});
      expect(result.success, isFalse);
    });
  });
}
