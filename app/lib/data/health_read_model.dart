import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../format.dart';

/// Leitura dos dados da aba Saúde para as telas: converte de SI (como está
/// no banco) para a unidade clínica que a pessoa lê, e devolve a hora local
/// de quando aconteceu. Só leitura — quem grava são os loggers de
/// `packages/health_records`.
class HealthReadModel {
  final HealthDataCore core;
  final MedicationRepository medications;
  final MedicationAgenda agenda;
  final DateTime Function() clock;

  HealthReadModel({
    required this.core,
    required this.medications,
    required this.agenda,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  DateTime get _nowUtc => clock().toUtc();

  List<HealthEvent> _lastDays(HealthEventType type, int days) =>
      core.queryByType(type, from: _nowUtc.subtract(Duration(days: days)), to: _nowUtc.add(const Duration(days: 1)));

  // ---------- Remédios ----------

  List<Medication> activeMedications() {
    final today = LocalDate.fromDateTime(clock());
    return medications.listAll().where((m) => m.isActiveOn(today) || m.startDate.isAfter(today)).toList();
  }

  List<Medication> endedMedications() {
    final today = LocalDate.fromDateTime(clock());
    return medications.listAll().where((m) => m.endDate != null && m.endDate!.isBefore(today)).toList();
  }

  /// Doses de hoje com estado: tomada/pulada (marcada), atrasada (passou da
  /// hora sem marcação) ou pendente.
  List<DoseView> dosesToday() {
    final now = clock();
    final nowMinutes = now.hour * 60 + now.minute;
    return [
      for (final e in agenda.forDay(LocalDate.fromDateTime(now)))
        DoseView(
          entry: e,
          overdue: e.status == null && e.dose.timeOfDay < nowMinutes,
        ),
    ];
  }

  /// Próxima dose ainda não marcada hoje (atrasadas primeiro).
  DoseView? nextDose() {
    final pending = dosesToday().where((d) => d.entry.status == null).toList();
    return pending.isEmpty ? null : pending.first;
  }

  /// Adesão: doses marcadas "tomei" sobre doses previstas nos últimos [days]
  /// dias, sem contar hoje (o dia ainda não acabou).
  Adherence adherence({int days = 30}) {
    final today = LocalDate.fromDateTime(clock());
    var expected = 0;
    var taken = 0;
    for (var i = 1; i <= days; i++) {
      final d = DateTime(today.year, today.month, today.day).subtract(Duration(days: i));
      for (final e in agenda.forDay(LocalDate.fromDateTime(d))) {
        expected++;
        if (e.status == DoseStatus.taken) taken++;
      }
    }
    return Adherence(taken: taken, expected: expected);
  }

  // ---------- Sintomas ----------

  List<SymptomView> symptoms({int days = 365}) => [
        for (final e in _lastDays(HealthEventType.symptom, days).reversed)
          SymptomView(
            name: e.payload['name'] as String,
            intensity: (e.payload['intensity'] as num?)?.toInt(),
            startedLocal: localOf(e.occurredAt, e.occurredAtTzOffsetMinutes),
            endedLocal: e.payload['ended_at'] == null
                ? null
                : localOf(DateTime.parse(e.payload['ended_at'] as String), e.occurredAtTzOffsetMinutes),
            notes: e.payload['notes'] as String?,
          ),
      ];

  // ---------- Sinais vitais ----------

  List<VitalReading> vitals(VitalKind kind, {int days = 365}) {
    if (kind == VitalKind.heartRate) {
      return [
        for (final e in _lastDays(HealthEventType.heartRate, days).reversed)
          VitalReading(
            kind: kind,
            value: (e.payload['bpm'] as num).toDouble(),
            local: localOf(e.occurredAt, e.occurredAtTzOffsetMinutes),
            fromWearable: e.source == HealthEventSource.wearable,
          ),
      ];
    }
    final readings = <VitalReading>[];
    for (final e in _lastDays(HealthEventType.vitalSign, days).reversed) {
      if (e.payload['kind'] != kind.wireValue) continue;
      final local = localOf(e.occurredAt, e.occurredAtTzOffsetMinutes);
      final wearable = e.source == HealthEventSource.wearable;
      readings.add(switch (kind) {
        VitalKind.bloodPressure => VitalReading(
            kind: kind,
            value: kpaToMmHg((e.payload['systolic_kpa'] as num).toDouble()),
            secondary: kpaToMmHg((e.payload['diastolic_kpa'] as num).toDouble()),
            local: local,
            fromWearable: wearable,
          ),
        VitalKind.glucose => VitalReading(
            kind: kind,
            value: glucoseMmolLToMgDl((e.payload['mmol_per_l'] as num).toDouble()),
            local: local,
            note: e.payload['context'] as String?,
            fromWearable: wearable,
          ),
        VitalKind.temperature =>
          VitalReading(kind: kind, value: (e.payload['celsius'] as num).toDouble(), local: local, fromWearable: wearable),
        VitalKind.spo2 => VitalReading(
            kind: kind,
            value: fractionToPercent((e.payload['fraction'] as num).toDouble()),
            local: local,
            fromWearable: wearable,
          ),
        VitalKind.heartRate => throw StateError('tratado acima'),
      });
    }
    return readings;
  }

  // ---------- Corpo ----------

  List<BodyReading> weights({int days = 3650}) => [
        for (final e in _lastDays(HealthEventType.weight, days).reversed)
          BodyReading(value: (e.payload['kg'] as num).toDouble(), local: localOf(e.occurredAt, e.occurredAtTzOffsetMinutes)),
      ];

  /// Medidas (cintura, quadril…) em centímetros; `body_fat` em %.
  List<BodyReading> measurements(String kind, {int days = 3650}) {
    final out = <BodyReading>[];
    for (final e in _lastDays(HealthEventType.bodyMeasurement, days).reversed) {
      if (e.payload['kind'] != kind) continue;
      final local = localOf(e.occurredAt, e.occurredAtTzOffsetMinutes);
      final value = kind == 'body_fat'
          ? fractionToPercent((e.payload['fraction'] as num).toDouble())
          : metersToCentimeters((e.payload['meters'] as num).toDouble());
      out.add(BodyReading(value: value, local: local));
    }
    return out;
  }

  // ---------- Sono ----------

  List<SleepView> sleeps({int days = 30}) => [
        for (final e in _lastDays(HealthEventType.sleep, days).reversed)
          SleepView(
            startLocal: localOf(DateTime.parse(e.payload['started_at'] as String), e.occurredAtTzOffsetMinutes),
            endLocal: localOf(DateTime.parse(e.payload['ended_at'] as String), e.occurredAtTzOffsetMinutes),
            minutes: (e.payload['duration_minutes'] as num).toInt(),
            stageMinutes: {
              for (final st in ((e.payload['stage_minutes'] as Map?) ?? const {}).entries)
                st.key as String: (st.value as num).toInt(),
            },
            stages: [
              for (final st in (e.payload['stages'] as List?) ?? const [])
                SleepStageView(
                  stage: (st as Map)['stage'] as String,
                  startLocal: localOf(DateTime.parse(st['started_at'] as String), e.occurredAtTzOffsetMinutes),
                  endLocal: localOf(DateTime.parse(st['ended_at'] as String), e.occurredAtTzOffsetMinutes),
                ),
            ],
          ),
      ];
}

class DoseView {
  final AgendaEntry entry;
  final bool overdue;
  DoseView({required this.entry, required this.overdue});

  Medication get medication => entry.dose.medication;
  String get time => formatTimeOfDay(entry.dose.timeOfDay);
}

class Adherence {
  final int taken;
  final int expected;
  Adherence({required this.taken, required this.expected});

  /// `null` quando não havia dose prevista no período.
  double? get ratio => expected == 0 ? null : taken / expected;
}

class SymptomView {
  final String name;
  final int? intensity;
  final DateTime startedLocal;
  final DateTime? endedLocal;
  final String? notes;
  SymptomView({required this.name, required this.intensity, required this.startedLocal, this.endedLocal, this.notes});
}

enum VitalKind {
  bloodPressure('Pressão', 'blood_pressure', 'mmHg'),
  glucose('Glicemia', 'glucose', 'mg/dL'),
  heartRate('Coração', 'heart_rate', 'bpm'),
  temperature('Temperatura', 'temperature', '°C'),
  spo2('Saturação', 'spo2', '%');

  final String label;
  final String wireValue;
  final String unit;
  const VitalKind(this.label, this.wireValue, this.unit);
}

class VitalReading {
  final VitalKind kind;
  final double value;
  final double? secondary; // diastólica, na pressão
  final DateTime local;
  final String? note;
  final bool fromWearable;
  VitalReading({
    required this.kind,
    required this.value,
    required this.local,
    this.secondary,
    this.note,
    this.fromWearable = false,
  });

  /// Texto do valor na unidade clínica: "122/81", "98", "36,7".
  String get display => switch (kind) {
        VitalKind.bloodPressure => '${value.round()}/${secondary!.round()}',
        VitalKind.temperature => value.toStringAsFixed(1).replaceAll('.', ','),
        _ => value.round().toString(),
      };
}

class BodyReading {
  final double value;
  final DateTime local;
  BodyReading({required this.value, required this.local});
}

class SleepView {
  final DateTime startLocal;
  final DateTime endLocal;
  final int minutes;

  /// Minutos por fase ('awake', 'light', 'deep', 'rem', 'sleeping'), quando
  /// a pulseira informa.
  final Map<String, int> stageMinutes;
  final List<SleepStageView> stages;
  SleepView({
    required this.startLocal,
    required this.endLocal,
    required this.minutes,
    this.stageMinutes = const {},
    this.stages = const [],
  });

  /// Tempo dormindo: total menos acordado (quando há fases).
  int get asleepMinutes => minutes - (stageMinutes['awake'] ?? 0);

  String get durationLabel => '${minutes ~/ 60} h ${two(minutes % 60)} min';
}

class SleepStageView {
  final String stage;
  final DateTime startLocal;
  final DateTime endLocal;
  SleepStageView({required this.stage, required this.startLocal, required this.endLocal});
}
