// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';
import 'package:test/test.dart';

void main() {
  group('WaterLogger — grava HealthEvent tipo water', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('grava evento com amount_ml e source manual', () {
      final logger = WaterLogger(core: core);

      final event = logger.log(
        amountMl: 250,
        occurredAt: DateTime.utc(2026, 8, 17, 12, 0),
        occurredAtTzOffsetMinutes: -180,
      );

      expect(event.type, HealthEventType.water);
      expect(event.source, HealthEventSource.manual);
      expect(event.payload['amount_ml'], 250);

      final stored = core.queryByType(HealthEventType.water);
      expect(stored, hasLength(1));
      expect(stored.single.id, event.id);
    });

    test('dois registros seguidos não são deduplicados — cada um é independente', () {
      final logger = WaterLogger(core: core);
      logger.log(
        amountMl: 200,
        occurredAt: DateTime.utc(2026, 8, 17, 12, 0),
        occurredAtTzOffsetMinutes: -180,
      );
      logger.log(
        amountMl: 200,
        occurredAt: DateTime.utc(2026, 8, 17, 12, 1),
        occurredAtTzOffsetMinutes: -180,
      );

      expect(core.queryByType(HealthEventType.water), hasLength(2));
    });

    test('rejeita amountMl <= 0', () {
      final logger = WaterLogger(core: core);
      expect(
        () => logger.log(
          amountMl: 0,
          occurredAt: DateTime.utc(2026, 8, 17),
          occurredAtTzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita occurredAt fora de UTC', () {
      final logger = WaterLogger(core: core);
      expect(
        () => logger.log(
          amountMl: 250,
          occurredAt: DateTime(2026, 8, 17),
          occurredAtTzOffsetMinutes: -180,
        ),
        throwsArgumentError,
      );
    });
  });

  group('log_water — ferramenta do cérebro', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('logWaterSpec é ferramenta de escrita com confirmação', () {
      final spec = logWaterSpec();
      expect(spec.write, isTrue);
      expect(spec.confirm, isTrue);
      expect(spec.module, 'nutrition');
    });

    test('handler grava evento real e devolve event_id + amount_ml', () async {
      final logger = WaterLogger(core: core);
      final handler = logWaterHandler(logger, tzOffsetMinutesProvider: () => -180);

      final result = await handler({'amount_ml': 300});

      expect(result.success, isTrue);
      expect(result.data!['amount_ml'], 300);
      expect(core.queryByType(HealthEventType.water), hasLength(1));
    });

    test('ToolRegistry.execute rejeita amount_ml ausente (schema)', () async {
      final logger = WaterLogger(core: core);
      final registry = ToolRegistry()
        ..register(logWaterSpec(), logWaterHandler(logger, tzOffsetMinutesProvider: () => -180));

      expect(
        () => registry.execute('log_water', {}),
        throwsA(isA<ToolValidationException>()),
      );
    });
  });
}
