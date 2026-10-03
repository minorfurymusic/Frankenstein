import 'package:sqlite3/sqlite3.dart';

import 'medication.dart';

/// Tipos de item do histórico médico (prancheta Historico). São informados
/// pela pessoa — o app guarda, não diagnostica (`.claude/rules/brain.md`).
enum MedicalHistoryKind {
  condition('Condição ou diagnóstico informado'),
  allergy('Alergia'),
  surgery('Cirurgia'),
  vaccine('Vacina'),
  appointment('Consulta');

  final String label;
  const MedicalHistoryKind(this.label);

  String get wireValue => name;

  static MedicalHistoryKind fromWireValue(String v) =>
      MedicalHistoryKind.values.firstWhere((k) => k.name == v, orElse: () => throw ArgumentError('tipo desconhecido: $v'));
}

class MedicalHistoryItem {
  final String id;
  final MedicalHistoryKind kind;

  /// Nome da condição/alergia/cirurgia/vacina, ou a especialidade da consulta.
  final String title;

  /// Data (sem hora): diagnóstico, cirurgia, dose da vacina ou consulta.
  final LocalDate? date;

  /// Profissional (consultas) — opcional.
  final String? professional;
  final String? notes;

  MedicalHistoryItem({
    required this.id,
    required this.kind,
    required this.title,
    this.date,
    this.professional,
    this.notes,
  }) {
    if (title.trim().isEmpty) throw ArgumentError('dê um nome ao item');
  }
}

const String _schemaSql = '''
CREATE TABLE IF NOT EXISTS medical_history (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  date TEXT,
  professional TEXT,
  notes TEXT
);
''';

/// Histórico médico informado pela pessoa. Tabela própria no banco de
/// remédios (mesmo módulo), não `HealthEvent` — é cadastro, não medição.
class MedicalHistoryRepository {
  final Database _db;
  MedicalHistoryRepository._(this._db);

  factory MedicalHistoryRepository.open(String path) => MedicalHistoryRepository._(sqlite3.open(path)..execute(_schemaSql));
  factory MedicalHistoryRepository.openInMemory() => MedicalHistoryRepository._(sqlite3.openInMemory()..execute(_schemaSql));

  void close() => _db.dispose();

  void save(MedicalHistoryItem i) {
    _db.execute(
      'INSERT OR REPLACE INTO medical_history (id, kind, title, date, professional, notes) VALUES (?, ?, ?, ?, ?, ?)',
      [i.id, i.kind.wireValue, i.title.trim(), i.date?.toIso(), i.professional?.trim(), i.notes?.trim()],
    );
  }

  void delete(String id) => _db.execute('DELETE FROM medical_history WHERE id = ?', [id]);

  /// Itens de um tipo (ou todos), mais recentes primeiro; sem data no fim.
  List<MedicalHistoryItem> list({MedicalHistoryKind? kind}) {
    final rows = kind == null
        ? _db.select('SELECT * FROM medical_history')
        : _db.select('SELECT * FROM medical_history WHERE kind = ?', [kind.wireValue]);
    final items = [
      for (final r in rows)
        MedicalHistoryItem(
          id: r['id'] as String,
          kind: MedicalHistoryKind.fromWireValue(r['kind'] as String),
          title: r['title'] as String,
          date: r['date'] == null ? null : LocalDate.parse(r['date'] as String),
          professional: r['professional'] as String?,
          notes: r['notes'] as String?,
        ),
    ];
    items.sort((a, b) {
      if (a.date == null && b.date == null) return a.title.compareTo(b.title);
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return items;
  }
}
