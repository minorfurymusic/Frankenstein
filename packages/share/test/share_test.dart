import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_share/share.dart';
import 'package:test/test.dart';

HealthEvent _workoutSessionEvent({
  required int setsCount,
  required List<String> exerciseIds,
}) {
  return HealthEvent(
    id: HealthDataCore.newId(),
    type: HealthEventType.workoutSession,
    source: HealthEventSource.manual,
    occurredAt: DateTime.utc(2026, 8, 15, 19, 0),
    occurredAtTzOffsetMinutes: -180,
    recordedAt: DateTime.utc(2026, 8, 15, 19, 30),
    payload: {'sets_count': setsCount, 'exercise_ids': exerciseIds},
    confidence: 1.0,
  );
}

HealthEvent _gpsTrackEvent({
  required double distanceMeters,
  required int durationSeconds,
  double? averagePaceSecondsPerKm,
}) {
  return HealthEvent(
    id: HealthDataCore.newId(),
    type: HealthEventType.gpsTrack,
    source: HealthEventSource.manual,
    occurredAt: DateTime.utc(2026, 8, 15, 7, 0),
    occurredAtTzOffsetMinutes: -180,
    recordedAt: DateTime.utc(2026, 8, 15, 7, 30),
    payload: {
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'average_pace_seconds_per_km': averagePaceSecondsPerKm,
    },
    confidence: 1.0,
  );
}

GpsTrackPoint _point({required String eventId, required int seq, required double metersNorth}) {
  const metersPerDegreeLat = 111194.926644; // mesmo modelo esférico de RunCalculator
  return GpsTrackPoint(
    eventId: eventId,
    seq: seq,
    latitude: -23.0 + metersNorth / metersPerDegreeLat,
    longitude: -46.0,
    recordedAt: DateTime.utc(2026, 8, 15, 7, 0).add(Duration(seconds: seq * 10)),
  );
}

void main() {
  group('buildWorkoutShareCard', () {
    test('monta o card a partir de um workout_session real', () {
      final event = _workoutSessionEvent(setsCount: 12, exerciseIds: ['supino-reto', 'triceps-corda']);

      final card = buildWorkoutShareCard(event, personalRecordSummary: 'novo recorde: supino 70 kg');

      expect(card.setsCount, 12);
      expect(card.exerciseNames, ['supino-reto', 'triceps-corda']);
      expect(card.personalRecordSummary, 'novo recorde: supino 70 kg');
    });

    test('personalRecordSummary é null quando não informado — nunca calculado escondido', () {
      final event = _workoutSessionEvent(setsCount: 3, exerciseIds: ['agachamento']);
      final card = buildWorkoutShareCard(event);
      expect(card.personalRecordSummary, isNull);
    });

    test('rejeita HealthEvent de tipo errado — nada clínico tem card, sem exceção', () {
      final clinicalEvent = HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.clinicalDoc,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 8, 15),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 15),
        payload: const {},
        confidence: 1.0,
      );

      expect(
        () => buildWorkoutShareCard(clinicalEvent),
        throwsA(isA<WrongEventTypeForShareCardException>()),
      );
    });
  });

  group('buildRunShareCard', () {
    test('monta o card com distância/duração/pace e rota ofuscada', () {
      final event = _gpsTrackEvent(distanceMeters: 5000, durationSeconds: 1800, averagePaceSecondsPerKm: 360);
      final points = [
        for (var m = 0; m <= 1000; m += 100) _point(eventId: event.id, seq: m ~/ 100, metersNorth: m.toDouble()),
      ];

      final card = buildRunShareCard(event, points);

      expect(card.distanceMeters, 5000);
      expect(card.duration, const Duration(minutes: 30));
      expect(card.averagePaceSecondsPerKm, 360);
      // Rota tem 1000 m — obfuscateRouteEnds corta os 300 m iniciais/finais.
      expect(card.route, isNotEmpty);
      expect(card.route.length, lessThan(points.length));
    });

    test('rota curta demais pra ofuscar com segurança sai vazia, não crua', () {
      final event = _gpsTrackEvent(distanceMeters: 400, durationSeconds: 200);
      final points = [
        _point(eventId: event.id, seq: 0, metersNorth: 0),
        _point(eventId: event.id, seq: 1, metersNorth: 400),
      ];

      final card = buildRunShareCard(event, points);
      expect(card.route, isEmpty);
    });

    test('rejeita HealthEvent de tipo errado', () {
      final wrongEvent = _workoutSessionEvent(setsCount: 1, exerciseIds: ['x']);
      expect(
        () => buildRunShareCard(wrongEvent, const []),
        throwsA(isA<WrongEventTypeForShareCardException>()),
      );
    });
  });
}
