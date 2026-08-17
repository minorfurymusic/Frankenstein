// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:frankstein_health_core/health_core.dart';

/// Registra o consumo de água: recebe uma quantidade em mililitros e grava
/// um `HealthEvent` tipo `water` no Health Data Core
/// (`docs/specs/nutricao.md`, seção "Modelo de dados" — "peso e água são
/// séries temporais simples").
///
/// Mesma origem de `MealLogger`: `source: HealthEventSource.manual`, sem
/// `external_id` (não há fonte externa a deduplicar aqui — cada registro
/// de água é um evento independente, mesmo que o usuário registre a mesma
/// quantidade duas vezes seguidas de propósito).
class WaterLogger {
  final HealthDataCore core;

  WaterLogger({required this.core});

  HealthEvent log({
    required double amountMl,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    DateTime? recordedAt,
  }) {
    if (amountMl <= 0) {
      throw ArgumentError('amountMl precisa ser maior que zero');
    }
    if (!occurredAt.isUtc) {
      throw ArgumentError('occurredAt precisa estar em UTC');
    }

    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.water,
      source: HealthEventSource.manual,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
      recordedAt: recordedAt ?? DateTime.now().toUtc(),
      payload: {'amount_ml': amountMl},
      confidence: 1.0,
    );

    core.insertEvent(event);
    return event;
  }
}
