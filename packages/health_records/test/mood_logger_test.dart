import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:test/test.dart';

void main() {
  late HealthDataCore core;
  setUp(() => core = HealthDataCore.openInMemory());
  tearDown(() => core.close());

  test('humor do dia vira evento mood com o que a pessoa marcou', () {
    final at = DateTime.utc(2026, 10, 18, 11);
    MoodLogger(core: core).log(
      mood: 2,
      energy: 1,
      anxiety: 4,
      feelings: const ['triste', 'cansado'],
      notes: '  dormi mal  ',
      occurredAt: at,
      occurredAtTzOffsetMinutes: -180,
    );
    final e = core.queryByType(HealthEventType.mood).single;
    expect(e.payload, {
      'mood': 2,
      'energy': 1,
      'anxiety': 4,
      'feelings': ['triste', 'cansado'],
      'notes': 'dormi mal',
    });
    expect(e.occurredAtTzOffsetMinutes, -180);
  });

  test('só o humor basta; fora de 1 a 5 é recusado', () {
    final logger = MoodLogger(core: core);
    final at = DateTime.utc(2026, 10, 18);
    logger.log(mood: 5, occurredAt: at, occurredAtTzOffsetMinutes: 0);
    expect(core.queryByType(HealthEventType.mood).single.payload, {'mood': 5});
    expect(() => logger.log(mood: 0, occurredAt: at, occurredAtTzOffsetMinutes: 0), throwsArgumentError);
    expect(() => logger.log(mood: 3, anxiety: 6, occurredAt: at, occurredAtTzOffsetMinutes: 0), throwsArgumentError);
  });

  test('questionário: respostas de 0 a 3, soma gravada; número de itens conferido', () {
    final logger = ScreeningLogger(core: core);
    final at = DateTime.utc(2026, 10, 18);
    logger.log(instrument: 'gad7', answers: const [1, 2, 0, 3, 1, 1, 0], difficulty: 1, occurredAt: at, occurredAtTzOffsetMinutes: 0);
    expect(core.queryByType(HealthEventType.screening).single.payload,
        {'instrument': 'gad7', 'answers': [1, 2, 0, 3, 1, 1, 0], 'score': 8, 'difficulty': 1});
    expect(() => logger.log(instrument: 'phq9', answers: const [1, 2], occurredAt: at, occurredAtTzOffsetMinutes: 0), throwsArgumentError);
    expect(() => logger.log(instrument: 'gad7', answers: const [4, 0, 0, 0, 0, 0, 0], occurredAt: at, occurredAtTzOffsetMinutes: 0),
        throwsArgumentError);
  });
}
