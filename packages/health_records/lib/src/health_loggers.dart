import 'package:frankstein_health_core/health_core.dart';

import 'units.dart';

HealthEvent _event(
  HealthEventType type,
  Map<String, dynamic> payload,
  DateTime occurredAt,
  int tzOffsetMinutes,
) {
  if (!occurredAt.isUtc) throw ArgumentError('occurredAt precisa estar em UTC');
  return HealthEvent(
    id: HealthDataCore.newId(),
    type: type,
    source: HealthEventSource.manual,
    occurredAt: occurredAt,
    occurredAtTzOffsetMinutes: tzOffsetMinutes,
    recordedAt: DateTime.now().toUtc(),
    payload: payload,
    confidence: 1.0,
  );
}

/// Sintoma relatado pela pessoa (diário de sintomas da aba Saúde). Registra o
/// que foi dito — não interpreta nem classifica (`.claude/rules/brain.md`:
/// o app não diagnostica).
class SymptomLogger {
  final HealthDataCore core;

  SymptomLogger({required this.core});

  HealthEvent log({
    required String name,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    int? intensity,
    DateTime? endedAt,
    String? notes,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('sintoma precisa de nome');
    if (intensity != null && (intensity < 0 || intensity > 10)) {
      throw ArgumentError('intensidade vai de 0 a 10');
    }
    if (endedAt != null && (!endedAt.isUtc || endedAt.isBefore(occurredAt))) {
      throw ArgumentError('fim do sintoma precisa ser UTC e depois do início');
    }
    final e = _event(
      HealthEventType.symptom,
      {
        'name': name.trim(),
        if (intensity != null) 'intensity': intensity,
        if (endedAt != null) 'ended_at': endedAt.toIso8601String(),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      },
      occurredAt,
      occurredAtTzOffsetMinutes,
    );
    core.insertEvent(e);
    return e;
  }
}

/// Sinais vitais. Entrada em unidade clínica (como a pessoa e o médico falam);
/// gravação em SI. Frequência cardíaca manual vai no tipo `heart_rate`, em bpm,
/// igual ao que o wearable já grava (`packages/wearable`) — mesma série.
class VitalSignLogger {
  final HealthDataCore core;

  VitalSignLogger({required this.core});

  HealthEvent bloodPressure({
    required double systolicMmHg,
    required double diastolicMmHg,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (systolicMmHg <= 0 || diastolicMmHg <= 0) throw ArgumentError('pressão precisa ser positiva');
    if (diastolicMmHg >= systolicMmHg) throw ArgumentError('diastólica precisa ser menor que sistólica');
    return _save(HealthEventType.vitalSign, {
      'kind': 'blood_pressure',
      'systolic_kpa': mmHgToKpa(systolicMmHg),
      'diastolic_kpa': mmHgToKpa(diastolicMmHg),
    }, occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent glucose({
    required double mgDl,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    String? context,
  }) {
    if (mgDl <= 0) throw ArgumentError('glicemia precisa ser positiva');
    return _save(HealthEventType.vitalSign, {
      'kind': 'glucose',
      'mmol_per_l': glucoseMgDlToMmolL(mgDl),
      if (context != null && context.trim().isNotEmpty) 'context': context.trim(),
    }, occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent temperature({
    required double celsius,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (celsius < 25 || celsius > 45) throw ArgumentError('temperatura corporal fora de 25–45 °C');
    return _save(HealthEventType.vitalSign, {'kind': 'temperature', 'celsius': celsius}, occurredAt,
        occurredAtTzOffsetMinutes);
  }

  HealthEvent spo2({
    required double percent,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (percent <= 0 || percent > 100) throw ArgumentError('saturação vai de 0 a 100%');
    return _save(HealthEventType.vitalSign, {'kind': 'spo2', 'fraction': percentToFraction(percent)},
        occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent heartRate({
    required int bpm,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (bpm <= 0) throw ArgumentError('frequência cardíaca precisa ser positiva');
    return _save(HealthEventType.heartRate, {'bpm': bpm}, occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent _save(HealthEventType type, Map<String, dynamic> payload, DateTime at, int tz) {
    final e = _event(type, payload, at, tz);
    core.insertEvent(e);
    return e;
  }
}

enum BodyMeasurementKind {
  waist,
  hip,
  chest,
  neck,
  arm,
  thigh,
  calf;

  String get wireValue => name;
}

/// Peso e medidas corporais. Peso vai no tipo `weight` (já existente, em kg);
/// circunferências e % de gordura vão em `body_measurement` (metros e fração).
class BodyLogger {
  final HealthDataCore core;

  BodyLogger({required this.core});

  HealthEvent weight({
    required double kg,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (kg <= 0 || kg > 500) throw ArgumentError('peso fora de 0–500 kg');
    return _save(HealthEventType.weight, {'kg': kg}, occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent circumference({
    required BodyMeasurementKind kind,
    required double centimeters,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (centimeters <= 0 || centimeters > 300) throw ArgumentError('medida fora de 0–300 cm');
    return _save(HealthEventType.bodyMeasurement,
        {'kind': kind.wireValue, 'meters': centimetersToMeters(centimeters)}, occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent bodyFat({
    required double percent,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
  }) {
    if (percent <= 0 || percent >= 100) throw ArgumentError('% de gordura fora de 0–100');
    return _save(HealthEventType.bodyMeasurement, {'kind': 'body_fat', 'fraction': percentToFraction(percent)},
        occurredAt, occurredAtTzOffsetMinutes);
  }

  HealthEvent _save(HealthEventType type, Map<String, dynamic> payload, DateTime at, int tz) {
    final e = _event(type, payload, at, tz);
    core.insertEvent(e);
    return e;
  }
}
