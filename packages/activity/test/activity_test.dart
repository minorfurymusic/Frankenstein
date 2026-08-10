import 'dart:async';

import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

class FakeStepSensor implements StepSensor {
  final _controller = StreamController<StepsSample>();

  @override
  Stream<StepsSample> get readings => _controller.stream;

  void emit(StepsSample sample) => _controller.add(sample);

  Future<void> close() => _controller.close();
}

StepsSample _sample(int cumulative, DateTime at, {String deviceId = 'device-1'}) {
  return StepsSample(
    deviceId: deviceId,
    timestampUtc: at,
    cumulativeSteps: cumulative,
    tzOffsetMinutes: -180,
  );
}

void main() {
  group('StepsSample — validação', () {
    test('rejeita timestamp fora de UTC', () {
      expect(
        () => StepsSample(
          deviceId: 'd',
          timestampUtc: DateTime(2026, 8, 9),
          cumulativeSteps: 10,
          tzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita cumulativeSteps negativo', () {
      expect(
        () => _sample(-1, DateTime.utc(2026, 8, 9)),
        throwsArgumentError,
      );
    });
  });

  group('StepsRepository — agregação de contador cumulativo', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('primeira leitura vira linha de base, sem evento gravado', () {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      repo.recordSample(_sample(1000, DateTime.utc(2026, 8, 9, 8, 0)));

      expect(repo.pendingDelta, 0);
      expect(core.queryByType(HealthEventType.steps), isEmpty);
    });

    test('leituras crescentes acumulam delta sem gravar até o flush', () {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      repo.recordSample(_sample(1000, DateTime.utc(2026, 8, 9, 8, 0)));
      repo.recordSample(_sample(1250, DateTime.utc(2026, 8, 9, 8, 30)));
      repo.recordSample(_sample(1400, DateTime.utc(2026, 8, 9, 9, 0)));

      expect(repo.pendingDelta, 400);
      expect(core.queryByType(HealthEventType.steps), isEmpty);
    });

    test('flush grava um HealthEvent steps com o delta e reinicia a janela',
        () {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      final start = DateTime.utc(2026, 8, 9, 8, 0);
      repo.recordSample(_sample(1000, start));
      repo.recordSample(_sample(1400, DateTime.utc(2026, 8, 9, 9, 0)));

      final flushAt = DateTime.utc(2026, 8, 9, 9, 0, 1);
      repo.flush(at: flushAt, tzOffsetMinutes: -180);

      final events = core.queryByType(HealthEventType.steps);
      expect(events, hasLength(1));
      expect(events.first.payload['count'], 400);
      expect(events.first.occurredAt, start);
      expect(events.first.recordedAt, flushAt);
      expect(events.first.occurredAtTzOffsetMinutes, -180);
      expect(events.first.deviceId, 'device-1');
      expect(repo.pendingDelta, 0);

      // Janela reiniciou — próxima leitura só soma a partir daqui.
      repo.recordSample(_sample(1450, DateTime.utc(2026, 8, 9, 9, 30)));
      expect(repo.pendingDelta, 50);
    });

    test('flush sem delta pendente não grava nada', () {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      repo.recordSample(_sample(1000, DateTime.utc(2026, 8, 9, 8, 0)));
      repo.flush(at: DateTime.utc(2026, 8, 9, 8, 1), tzOffsetMinutes: -180);

      expect(core.queryByType(HealthEventType.steps), isEmpty);
    });

    test('reset do contador (reinício do aparelho) faz flush automático do pendente',
        () {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      repo.recordSample(_sample(1000, DateTime.utc(2026, 8, 9, 8, 0)));
      repo.recordSample(_sample(1300, DateTime.utc(2026, 8, 9, 12, 0)));
      // Aparelho reiniciou: próxima leitura vem menor que a última vista.
      repo.recordSample(_sample(50, DateTime.utc(2026, 8, 9, 13, 0)));

      final events = core.queryByType(HealthEventType.steps);
      expect(events, hasLength(1));
      expect(events.first.payload['count'], 300);

      // A leitura pós-reset virou a nova linha de base.
      expect(repo.pendingDelta, 0);
      repo.recordSample(_sample(80, DateTime.utc(2026, 8, 9, 13, 30)));
      expect(repo.pendingDelta, 30);
    });

    test('sample de outro aparelho lança ArgumentError', () {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      repo.recordSample(_sample(1000, DateTime.utc(2026, 8, 9, 8, 0)));
      expect(
        () => repo.recordSample(
          _sample(1100, DateTime.utc(2026, 8, 9, 9, 0), deviceId: 'device-2'),
        ),
        throwsArgumentError,
      );
    });

    test('attachSensor liga as leituras da fonte ao recordSample', () async {
      final repo = StepsRepository(core: core, deviceId: 'device-1');
      final sensor = FakeStepSensor();
      final sub = repo.attachSensor(sensor);
      addTearDown(sub.cancel);
      addTearDown(sensor.close);

      sensor.emit(_sample(500, DateTime.utc(2026, 8, 9, 8, 0)));
      sensor.emit(_sample(700, DateTime.utc(2026, 8, 9, 9, 0)));
      await Future<void>.delayed(Duration.zero); // deixa o stream processar

      expect(repo.pendingDelta, 200);
    });
  });

  group('get_steps — soma eventos steps de um dia', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    void writeSteps(int count, DateTime occurredAt) {
      core.insertEvent(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.steps,
        source: HealthEventSource.pedometer,
        occurredAt: occurredAt,
        occurredAtTzOffsetMinutes: -180,
        recordedAt: occurredAt,
        payload: {'count': count},
        confidence: 1.0,
      ));
    }

    test('soma múltiplos eventos do dia pedido, ignora outros dias/tipos',
        () async {
      writeSteps(400, DateTime.utc(2026, 8, 9, 8, 0));
      writeSteps(350, DateTime.utc(2026, 8, 9, 18, 0));
      writeSteps(999, DateTime.utc(2026, 8, 10, 8, 0)); // outro dia
      core.insertEvent(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.weight,
        source: HealthEventSource.manual,
        occurredAt: DateTime.utc(2026, 8, 9),
        occurredAtTzOffsetMinutes: -180,
        recordedAt: DateTime.utc(2026, 8, 9),
        payload: {'kg': 70},
        confidence: 1.0,
      ));

      final handler = getStepsHandler(core);
      final result = await handler({'date': '2026-08-09'});

      expect(result.success, isTrue);
      expect(result.data!['total_steps'], 750);
      expect(result.data!['events_counted'], 2);
    });

    test('dia sem eventos devolve zero, não erro', () async {
      final handler = getStepsHandler(core);
      final result = await handler({'date': '2026-08-01'});

      expect(result.success, isTrue);
      expect(result.data!['total_steps'], 0);
    });

    test('getStepsSpec é ferramenta de leitura, sem confirmação', () {
      final spec = getStepsSpec();
      expect(spec.write, isFalse);
      expect(spec.confirm, isFalse);
      expect(spec.module, 'activity');
    });
  });
}
