import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'medication.dart';

const String _medicationsSchemaSql = '''
CREATE TABLE IF NOT EXISTS medications (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  dose_amount REAL NOT NULL,
  dose_unit TEXT NOT NULL,
  form TEXT NOT NULL,
  times_of_day TEXT NOT NULL,
  start_date TEXT NOT NULL,
  end_date TEXT,
  notes TEXT,
  reminders_enabled INTEGER NOT NULL
);
''';

/// Catálogo local de remédios em uso. É plano, não histórico: editar ou
/// encerrar um remédio aqui é permitido (diferente de `HealthEvent`, que é
/// append-only). O histórico do que foi tomado fica nos eventos
/// `medication_dose`, que nunca mudam.
///
/// Sobre `sqlite3` (FFI Dart puro), mesmo padrão de `WorkoutRepository`
/// (`packages/activity/lib/src/workout_repository.dart`).
class MedicationRepository {
  final Database _db;

  MedicationRepository._(this._db);

  factory MedicationRepository.open(String path) {
    final db = sqlite3.open(path);
    db.execute(_medicationsSchemaSql);
    return MedicationRepository._(db);
  }

  factory MedicationRepository.openInMemory() {
    final db = sqlite3.openInMemory();
    db.execute(_medicationsSchemaSql);
    return MedicationRepository._(db);
  }

  void close() => _db.dispose();

  /// Insere ou substitui (editar um remédio = gravar de novo com o mesmo id).
  void save(Medication m) {
    _db.execute(
      '''
      INSERT OR REPLACE INTO medications (
        id, name, dose_amount, dose_unit, form, times_of_day, start_date,
        end_date, notes, reminders_enabled
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        m.id,
        m.name,
        m.doseAmount,
        m.doseUnit,
        m.form.wireValue,
        jsonEncode(m.timesOfDay),
        m.startDate.toIso(),
        m.endDate?.toIso(),
        m.notes,
        m.remindersEnabled ? 1 : 0,
      ],
    );
  }

  Medication? findById(String id) {
    final rows = _db.select('SELECT * FROM medications WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  List<Medication> listAll() =>
      _db.select('SELECT * FROM medications ORDER BY name COLLATE NOCASE').map(_fromRow).toList();

  /// Encerra um remédio a partir de [lastDay] (inclusive), sem apagar nada.
  void endOn(String id, LocalDate lastDay) {
    final m = findById(id);
    if (m == null) throw ArgumentError('remédio não encontrado: $id');
    save(Medication(
      id: m.id,
      name: m.name,
      doseAmount: m.doseAmount,
      doseUnit: m.doseUnit,
      form: m.form,
      timesOfDay: m.timesOfDay,
      startDate: m.startDate,
      endDate: lastDay.isBefore(m.startDate) ? m.startDate : lastDay,
      notes: m.notes,
      remindersEnabled: m.remindersEnabled,
    ));
  }

  /// Doses previstas para [date], em ordem de horário.
  List<ScheduledDose> scheduleFor(LocalDate date) {
    final doses = <ScheduledDose>[
      for (final m in listAll())
        if (m.isActiveOn(date))
          for (final t in m.timesOfDay) ScheduledDose(medication: m, date: date, timeOfDay: t),
    ];
    doses.sort((a, b) => a.timeOfDay.compareTo(b.timeOfDay));
    return doses;
  }

  Medication _fromRow(Row r) {
    final end = r['end_date'] as String?;
    return Medication(
      id: r['id'] as String,
      name: r['name'] as String,
      doseAmount: (r['dose_amount'] as num).toDouble(),
      doseUnit: r['dose_unit'] as String,
      form: MedicationForm.fromWireValue(r['form'] as String),
      timesOfDay: (jsonDecode(r['times_of_day'] as String) as List).cast<int>(),
      startDate: LocalDate.parse(r['start_date'] as String),
      endDate: end == null ? null : LocalDate.parse(end),
      notes: r['notes'] as String?,
      remindersEnabled: (r['reminders_enabled'] as int) == 1,
    );
  }
}
