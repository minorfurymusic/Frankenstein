import 'package:frankstein_health_core/health_core.dart';

import 'medication.dart';
import 'medication_repository.dart';

enum DoseStatus {
  taken,
  skipped;

  String get wireValue => name;

  static DoseStatus fromWireValue(String value) => DoseStatus.values.firstWhere(
        (s) => s.name == value,
        orElse: () => throw ArgumentError('status de dose desconhecido: $value'),
      );
}

/// Grava uma dose tomada ou pulada como `HealthEvent` tipo `medication_dose`.
///
/// Aceita dose fora do catálogo (`medicationId` nulo): "tomei dipirona 500 mg
/// às 9h" sem a dipirona estar cadastrada como remédio em uso — caso comum,
/// pedido explicitamente pelo usuário (2026-10-02).
class MedicationDoseLogger {
  final HealthDataCore core;

  MedicationDoseLogger({required this.core});

  HealthEvent log({
    required String name,
    required double doseAmount,
    required String doseUnit,
    required DoseStatus status,
    required DateTime occurredAt,
    required int occurredAtTzOffsetMinutes,
    String? medicationId,
    String? scheduledLocal,
  }) {
    if (name.trim().isEmpty) throw ArgumentError('dose precisa do nome do remédio');
    if (doseAmount <= 0) throw ArgumentError('dose precisa ser maior que zero');
    if (!occurredAt.isUtc) throw ArgumentError('occurredAt precisa estar em UTC');

    final event = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.medicationDose,
      source: HealthEventSource.manual,
      occurredAt: occurredAt,
      occurredAtTzOffsetMinutes: occurredAtTzOffsetMinutes,
      recordedAt: DateTime.now().toUtc(),
      payload: {
        'name': name.trim(),
        'dose_amount': doseAmount,
        'dose_unit': doseUnit.trim(),
        'status': status.wireValue,
        if (medicationId != null) 'medication_id': medicationId,
        if (scheduledLocal != null) 'scheduled_local': scheduledLocal,
      },
      confidence: 1.0,
    );
    core.insertEvent(event);
    return event;
  }
}

/// Uma linha da agenda do dia: dose prevista + o que aconteceu com ela.
class AgendaEntry {
  final ScheduledDose dose;

  /// `null` = pendente (nem tomada nem pulada ainda).
  final DoseStatus? status;

  AgendaEntry(this.dose, this.status);
}

/// Junta o catálogo (o que estava previsto) com os eventos (o que aconteceu).
/// Leitura só — não grava nada.
class MedicationAgenda {
  final MedicationRepository repository;
  final HealthDataCore core;

  MedicationAgenda({required this.repository, required this.core});

  List<AgendaEntry> forDay(LocalDate date) {
    // Janela larga em UTC (dia ± 1) e filtro exato pela chave local gravada no
    // evento — o dia local e o dia UTC não coincidem fora de UTC+0.
    final dayUtc = DateTime.utc(date.year, date.month, date.day);
    final events = core.queryByType(
      HealthEventType.medicationDose,
      from: dayUtc.subtract(const Duration(days: 1)),
      to: dayUtc.add(const Duration(days: 2)),
    );

    // Se a mesma dose foi marcada mais de uma vez, vale a última (correção).
    final statusByKey = <String, DoseStatus>{};
    final sorted = [...events]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    for (final e in sorted) {
      final id = e.payload['medication_id'] as String?;
      final scheduled = e.payload['scheduled_local'] as String?;
      if (id == null || scheduled == null) continue;
      statusByKey['$id|$scheduled'] = DoseStatus.fromWireValue(e.payload['status'] as String);
    }

    return [
      for (final dose in repository.scheduleFor(date))
        AgendaEntry(dose, statusByKey['${dose.medication.id}|${dose.scheduledLocal}']),
    ];
  }
}
