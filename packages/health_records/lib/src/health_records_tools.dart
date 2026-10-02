import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import 'health_loggers.dart';
import 'medication.dart';
import 'medication_dose_logger.dart';
import 'medication_repository.dart';

/// Ferramentas do cérebro para a aba Saúde. Todas as de escrita exigem
/// confirmação humana (`ToolSpec` já recusa `write` sem `confirm`).
/// A IA registra o que a pessoa ou a receita disse — nenhuma ferramenta aqui
/// sugere dose, troca ou suspensão de remédio (`.claude/rules/brain.md`).

const _module = 'health_records';

DateTime _at(Map<String, dynamic> params) {
  final raw = params['at'] as String?;
  return raw == null ? DateTime.now().toUtc() : DateTime.parse(raw).toUtc();
}

double? _num(Map<String, dynamic> params, String key) => (params[key] as num?)?.toDouble();

// --- add_medication -------------------------------------------------------

final Map<String, dynamic> addMedicationSchema = {
  'type': 'object',
  'properties': {
    'name': {'type': 'string', 'minLength': 1},
    'dose_amount': {'type': 'number', 'exclusiveMinimum': 0},
    'dose_unit': {'type': 'string', 'minLength': 1},
    'form': {'enum': MedicationForm.values.map((f) => f.wireValue).toList()},
    'times': {
      'type': 'array',
      'minItems': 1,
      'items': {'type': 'string', 'pattern': r'^([01]\d|2[0-3]):[0-5]\d$'},
    },
    'start_date': {'type': 'string', 'pattern': r'^\d{4}-\d{2}-\d{2}$'},
    'end_date': {'type': 'string', 'pattern': r'^\d{4}-\d{2}-\d{2}$'},
    'notes': {'type': 'string'},
  },
  'required': ['name', 'dose_amount', 'dose_unit', 'times', 'start_date'],
};

ToolSpec addMedicationSpec() => ToolSpec(
      name: 'add_medication',
      description: 'Cadastra um remédio em uso com horários (sem end_date = uso contínuo)',
      write: true,
      confirm: true,
      module: _module,
      parametersSchema: addMedicationSchema,
    );

ToolHandler addMedicationHandler(MedicationRepository repository) {
  return (params) async {
    try {
      final endRaw = params['end_date'] as String?;
      final m = Medication(
        id: HealthDataCore.newId(),
        name: params['name'] as String,
        doseAmount: _num(params, 'dose_amount')!,
        doseUnit: params['dose_unit'] as String,
        form: MedicationForm.fromWireValue((params['form'] as String?) ?? 'other'),
        timesOfDay: (params['times'] as List).cast<String>().map(parseTimeOfDay).toList(),
        startDate: LocalDate.parse(params['start_date'] as String),
        endDate: endRaw == null ? null : LocalDate.parse(endRaw),
        notes: params['notes'] as String?,
      );
      repository.save(m);
      return ToolResult.ok({'medication_id': m.id, 'continuous': m.isContinuous});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}

// --- log_medication_dose --------------------------------------------------

final Map<String, dynamic> logMedicationDoseSchema = {
  'type': 'object',
  'properties': {
    'medication_id': {'type': 'string'},
    'name': {'type': 'string'},
    'dose_amount': {'type': 'number', 'exclusiveMinimum': 0},
    'dose_unit': {'type': 'string'},
    'status': {
      'enum': DoseStatus.values.map((s) => s.wireValue).toList(),
    },
    'scheduled_local': {'type': 'string', 'pattern': r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$'},
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['status'],
};

ToolSpec logMedicationDoseSpec() => ToolSpec(
      name: 'log_medication_dose',
      description: 'Registra uma dose de remédio tomada ou pulada (cadastrado ou avulso)',
      write: true,
      confirm: true,
      module: _module,
      parametersSchema: logMedicationDoseSchema,
    );

ToolHandler logMedicationDoseHandler(
  MedicationDoseLogger logger,
  MedicationRepository repository, {
  required int Function() tzOffsetMinutesProvider,
}) {
  return (params) async {
    final id = params['medication_id'] as String?;
    final catalog = id == null ? null : repository.findById(id);
    if (id != null && catalog == null) return ToolResult.failure('remédio não encontrado: $id');

    final name = (params['name'] as String?) ?? catalog?.name;
    final amount = _num(params, 'dose_amount') ?? catalog?.doseAmount;
    final unit = (params['dose_unit'] as String?) ?? catalog?.doseUnit;
    if (name == null || amount == null || unit == null) {
      return ToolResult.failure('informe medication_id ou nome, dose e unidade');
    }
    try {
      final e = logger.log(
        name: name,
        doseAmount: amount,
        doseUnit: unit,
        status: DoseStatus.fromWireValue(params['status'] as String),
        occurredAt: _at(params),
        occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
        medicationId: id,
        scheduledLocal: params['scheduled_local'] as String?,
      );
      return ToolResult.ok({'event_id': e.id});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}

// --- get_medication_agenda ------------------------------------------------

final Map<String, dynamic> getMedicationAgendaSchema = {
  'type': 'object',
  'properties': {
    'date': {'type': 'string', 'pattern': r'^\d{4}-\d{2}-\d{2}$'},
  },
  'required': ['date'],
};

ToolSpec getMedicationAgendaSpec() => ToolSpec(
      name: 'get_medication_agenda',
      description: 'Agenda de remédios de um dia, com o que já foi tomado ou pulado',
      write: false,
      confirm: false,
      module: _module,
      parametersSchema: getMedicationAgendaSchema,
    );

ToolHandler getMedicationAgendaHandler(MedicationAgenda agenda) {
  return (params) async {
    final date = LocalDate.parse(params['date'] as String);
    final entries = agenda.forDay(date);
    return ToolResult.ok({
      'date': date.toIso(),
      'doses': [
        for (final e in entries)
          {
            'medication_id': e.dose.medication.id,
            'name': e.dose.medication.name,
            'dose_amount': e.dose.medication.doseAmount,
            'dose_unit': e.dose.medication.doseUnit,
            'time': formatTimeOfDay(e.dose.timeOfDay),
            'scheduled_local': e.dose.scheduledLocal,
            'status': e.status?.wireValue ?? 'pending',
          },
      ],
    });
  };
}

// --- log_symptom ----------------------------------------------------------

final Map<String, dynamic> logSymptomSchema = {
  'type': 'object',
  'properties': {
    'name': {'type': 'string', 'minLength': 1},
    'intensity': {'type': 'integer', 'minimum': 0, 'maximum': 10},
    'at': {'type': 'string', 'format': 'date-time'},
    'ended_at': {'type': 'string', 'format': 'date-time'},
    'notes': {'type': 'string'},
  },
  'required': ['name'],
};

ToolSpec logSymptomSpec() => ToolSpec(
      name: 'log_symptom',
      description: 'Registra um sintoma relatado (sem interpretar nem diagnosticar)',
      write: true,
      confirm: true,
      module: _module,
      parametersSchema: logSymptomSchema,
    );

ToolHandler logSymptomHandler(SymptomLogger logger, {required int Function() tzOffsetMinutesProvider}) {
  return (params) async {
    final endedRaw = params['ended_at'] as String?;
    try {
      final e = logger.log(
        name: params['name'] as String,
        intensity: params['intensity'] as int?,
        occurredAt: _at(params),
        occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
        endedAt: endedRaw == null ? null : DateTime.parse(endedRaw).toUtc(),
        notes: params['notes'] as String?,
      );
      return ToolResult.ok({'event_id': e.id});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}

// --- log_vital_sign -------------------------------------------------------

final Map<String, dynamic> logVitalSignSchema = {
  'type': 'object',
  'properties': {
    'kind': {
      'enum': ['blood_pressure', 'glucose', 'temperature', 'spo2', 'heart_rate'],
    },
    'systolic_mmhg': {'type': 'number'},
    'diastolic_mmhg': {'type': 'number'},
    'glucose_mg_dl': {'type': 'number'},
    'glucose_context': {'type': 'string'},
    'celsius': {'type': 'number'},
    'spo2_percent': {'type': 'number'},
    'bpm': {'type': 'integer'},
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['kind'],
};

ToolSpec logVitalSignSpec() => ToolSpec(
      name: 'log_vital_sign',
      description: 'Registra um sinal vital (pressão, glicemia, temperatura, saturação, frequência cardíaca)',
      write: true,
      confirm: true,
      module: _module,
      parametersSchema: logVitalSignSchema,
    );

ToolHandler logVitalSignHandler(VitalSignLogger logger, {required int Function() tzOffsetMinutesProvider}) {
  return (params) async {
    final at = _at(params);
    final tz = tzOffsetMinutesProvider();
    try {
      final HealthEvent e;
      switch (params['kind'] as String) {
        case 'blood_pressure':
          final s = _num(params, 'systolic_mmhg');
          final d = _num(params, 'diastolic_mmhg');
          if (s == null || d == null) return ToolResult.failure('pressão precisa de sistólica e diastólica');
          e = logger.bloodPressure(systolicMmHg: s, diastolicMmHg: d, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case 'glucose':
          final g = _num(params, 'glucose_mg_dl');
          if (g == null) return ToolResult.failure('glicemia precisa de glucose_mg_dl');
          e = logger.glucose(
              mgDl: g, context: params['glucose_context'] as String?, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case 'temperature':
          final c = _num(params, 'celsius');
          if (c == null) return ToolResult.failure('temperatura precisa de celsius');
          e = logger.temperature(celsius: c, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        case 'spo2':
          final p = _num(params, 'spo2_percent');
          if (p == null) return ToolResult.failure('saturação precisa de spo2_percent');
          e = logger.spo2(percent: p, occurredAt: at, occurredAtTzOffsetMinutes: tz);
        default: // heart_rate (enum já validado pelo schema)
          final bpm = params['bpm'] as int?;
          if (bpm == null) return ToolResult.failure('frequência cardíaca precisa de bpm');
          e = logger.heartRate(bpm: bpm, occurredAt: at, occurredAtTzOffsetMinutes: tz);
      }
      return ToolResult.ok({'event_id': e.id, 'type': e.type.wireValue});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}

// --- log_body_measurement -------------------------------------------------

final Map<String, dynamic> logBodyMeasurementSchema = {
  'type': 'object',
  'properties': {
    'kind': {
      'enum': ['weight', 'body_fat', ...BodyMeasurementKind.values.map((k) => k.wireValue)],
    },
    'value': {'type': 'number', 'exclusiveMinimum': 0},
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['kind', 'value'],
};

ToolSpec logBodyMeasurementSpec() => ToolSpec(
      name: 'log_body_measurement',
      description: 'Registra peso (kg), % de gordura ou circunferência (cm)',
      write: true,
      confirm: true,
      module: _module,
      parametersSchema: logBodyMeasurementSchema,
    );

ToolHandler logBodyMeasurementHandler(BodyLogger logger, {required int Function() tzOffsetMinutesProvider}) {
  return (params) async {
    final at = _at(params);
    final tz = tzOffsetMinutesProvider();
    final value = _num(params, 'value')!;
    final kind = params['kind'] as String;
    try {
      final HealthEvent e = switch (kind) {
        'weight' => logger.weight(kg: value, occurredAt: at, occurredAtTzOffsetMinutes: tz),
        'body_fat' => logger.bodyFat(percent: value, occurredAt: at, occurredAtTzOffsetMinutes: tz),
        _ => logger.circumference(
            kind: BodyMeasurementKind.values.firstWhere((k) => k.wireValue == kind),
            centimeters: value,
            occurredAt: at,
            occurredAtTzOffsetMinutes: tz),
      };
      return ToolResult.ok({'event_id': e.id, 'type': e.type.wireValue});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}
