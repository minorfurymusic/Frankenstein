import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

HealthEvent _steps(int count, {bool daily = false, DateTime? recordedAt}) => HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.steps,
      source: daily ? HealthEventSource.wearable : HealthEventSource.pedometer,
      occurredAt: DateTime.utc(2026, 10, 16, 12),
      occurredAtTzOffsetMinutes: -180,
      recordedAt: recordedAt ?? DateTime.utc(2026, 10, 16, 12),
      payload: {'count': count, if (daily) 'daily_total': true},
      confidence: 1,
    );

void main() {
  test('contador do app: janelas se somam', () {
    expect(dailyStepCount([_steps(100), _steps(250)]), 350);
  });

  test('Health Connect: vale o total mais recente, não a soma das leituras', () {
    expect(
      dailyStepCount([
        _steps(900, daily: true, recordedAt: DateTime.utc(2026, 10, 16, 10)),
        _steps(1580, daily: true, recordedAt: DateTime.utc(2026, 10, 16, 13)),
      ]),
      1580,
    );
  });

  test('as duas fontes no mesmo dia: fica a maior, nunca a soma', () {
    expect(dailyStepCount([_steps(1580, daily: true), _steps(400)]), 1580);
    expect(dailyStepCount([_steps(300, daily: true), _steps(400), _steps(200)]), 600);
  });

  test('passos registrados à mão somam por cima das duas fontes', () {
    final manual = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.steps,
      source: HealthEventSource.manual,
      occurredAt: DateTime.utc(2026, 10, 16, 12),
      occurredAtTzOffsetMinutes: -180,
      recordedAt: DateTime.utc(2026, 10, 16, 12),
      payload: {'count': 1580},
      confidence: 1,
    );
    expect(dailyStepCount([_steps(400), manual]), 1980);
  });
}
