import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'medication.dart';

/// Receita médica ou exame guardado pela pessoa (pranchetas Receitas e
/// Exames). O app guarda e mostra; não lê, não interpreta e não diagnostica
/// (`.claude/rules/brain.md`). Nunca vira cartão de compartilhamento
/// (`.claude/rules/share.md`).
enum HealthDocumentKind {
  prescription('Receita médica'),
  exam('Exame');

  final String label;
  const HealthDocumentKind(this.label);

  String get wireValue => name;

  static HealthDocumentKind fromWireValue(String v) =>
      HealthDocumentKind.values.firstWhere((k) => k.name == v, orElse: () => throw ArgumentError('tipo desconhecido: $v'));
}

/// Categorias de exame da prancheta Exames.
enum ExamCategory {
  blood('Sangue'),
  image('Imagem'),
  urine('Urina'),
  other('Outros');

  final String label;
  const ExamCategory(this.label);

  String get wireValue => name;

  static ExamCategory fromWireValue(String v) =>
      ExamCategory.values.firstWhere((k) => k.name == v, orElse: () => throw ArgumentError('categoria desconhecida: $v'));
}

/// Um arquivo anexado (foto ou PDF). [storedName] é o nome do arquivo na
/// pasta privada do app — o repositório não sabe onde fica a pasta.
class HealthDocumentFile {
  final String storedName;
  final String originalName;
  final String mimeType;
  final int sizeBytes;

  const HealthDocumentFile({
    required this.storedName,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
  });

  bool get isPdf => mimeType == 'application/pdf';

  Map<String, Object> toJson() => {
        'stored_name': storedName,
        'original_name': originalName,
        'mime_type': mimeType,
        'size_bytes': sizeBytes,
      };

  factory HealthDocumentFile.fromJson(Map<String, dynamic> m) => HealthDocumentFile(
        storedName: m['stored_name'] as String,
        originalName: m['original_name'] as String,
        mimeType: m['mime_type'] as String,
        sizeBytes: (m['size_bytes'] as num).toInt(),
      );
}

/// Um valor do exame, como está no laudo (ADR-16: unidade e faixa de
/// referência do próprio laboratório — exceção à regra de SI). O app
/// mostra; não classifica como alto, baixo ou normal.
class ExamMarker {
  final String name;
  final double value;
  final String unit;
  final double? referenceLow;
  final double? referenceHigh;

  ExamMarker({required this.name, required this.value, required this.unit, this.referenceLow, this.referenceHigh}) {
    if (name.trim().isEmpty) throw ArgumentError('dê o nome do valor (ex.: Glicemia)');
    if (!value.isFinite) throw ArgumentError('valor inválido');
    if (referenceLow != null && referenceHigh != null && referenceHigh! < referenceLow!) {
      throw ArgumentError('faixa de referência invertida');
    }
  }

  /// Chave para juntar o mesmo marcador entre exames: sem diferença de
  /// maiúscula ou espaço.
  String get key => normalizeMarkerName(name);

  Map<String, Object> toJson() => {
        'name': name.trim(),
        'value': value,
        'unit': unit.trim(),
        if (referenceLow != null) 'reference_low': referenceLow!,
        if (referenceHigh != null) 'reference_high': referenceHigh!,
      };

  factory ExamMarker.fromJson(Map<String, dynamic> m) => ExamMarker(
        name: m['name'] as String,
        value: (m['value'] as num).toDouble(),
        unit: m['unit'] as String? ?? '',
        referenceLow: (m['reference_low'] as num?)?.toDouble(),
        referenceHigh: (m['reference_high'] as num?)?.toDouble(),
      );
}

String normalizeMarkerName(String name) => name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

/// Uma medição de um marcador ao longo do tempo (para o gráfico).
class MarkerReading {
  final ExamMarker marker;
  final LocalDate? date;
  final String documentId;
  final String documentTitle;
  const MarkerReading({required this.marker, required this.date, required this.documentId, required this.documentTitle});
}

class HealthDocument {
  final String id;
  final HealthDocumentKind kind;

  /// Receita: nome do profissional. Exame: nome do exame.
  final String title;

  /// Data da receita ou do exame.
  final LocalDate? date;

  /// Receita: especialidade (opcional).
  final String? specialty;

  /// Receita: validade (opcional).
  final LocalDate? validUntil;

  /// Exame: categoria.
  final ExamCategory? category;

  /// Receita: remédios cadastrados vinculados (ids de [Medication]).
  final List<String> linkedMedicationIds;

  final List<HealthDocumentFile> files;
  final String? notes;

  /// Exame: valores transcritos do laudo.
  final List<ExamMarker> markers;

  HealthDocument({
    required this.id,
    required this.kind,
    required this.title,
    this.date,
    this.specialty,
    this.validUntil,
    this.category,
    this.linkedMedicationIds = const [],
    this.files = const [],
    this.notes,
    this.markers = const [],
  }) {
    if (title.trim().isEmpty) {
      throw ArgumentError(kind == HealthDocumentKind.prescription ? 'informe quem receitou' : 'dê um nome ao exame');
    }
    if (date != null && validUntil != null && validUntil!.isBefore(date!)) {
      throw ArgumentError('a validade não pode ser antes da data da receita');
    }
  }

  /// Receita vencida em [today] (sem validade = nunca vence).
  bool isExpiredOn(LocalDate today) => validUntil != null && validUntil!.isBefore(today);
}

const String _schemaSql = '''
CREATE TABLE IF NOT EXISTS health_documents (
  id TEXT PRIMARY KEY,
  kind TEXT NOT NULL,
  title TEXT NOT NULL,
  date TEXT,
  specialty TEXT,
  valid_until TEXT,
  category TEXT,
  linked_medication_ids TEXT NOT NULL DEFAULT '[]',
  files TEXT NOT NULL DEFAULT '[]',
  notes TEXT,
  markers TEXT NOT NULL DEFAULT '[]'
);
''';

/// Bancos criados antes dos valores de exame não têm a coluna `markers`.
void _migrate(Database db) {
  final cols = {for (final r in db.select('PRAGMA table_info(health_documents)')) r['name'] as String};
  if (!cols.contains('markers')) {
    db.execute("ALTER TABLE health_documents ADD COLUMN markers TEXT NOT NULL DEFAULT '[]'");
  }
}

Database _prepare(Database db) {
  db.execute(_schemaSql);
  _migrate(db);
  return db;
}

/// Receitas e exames guardados pela pessoa. Cadastro com arquivo anexado —
/// tabela própria no banco de remédios, como o histórico médico, não
/// `HealthEvent`: dá para apagar (a pessoa decide o que guarda) e os
/// arquivos ficam fora do banco.
class HealthDocumentRepository {
  final Database _db;
  HealthDocumentRepository._(this._db);

  factory HealthDocumentRepository.open(String path) => HealthDocumentRepository._(_prepare(sqlite3.open(path)));
  factory HealthDocumentRepository.openInMemory() => HealthDocumentRepository._(_prepare(sqlite3.openInMemory()));

  void close() => _db.dispose();

  void save(HealthDocument d) {
    _db.execute(
      'INSERT OR REPLACE INTO health_documents '
      '(id, kind, title, date, specialty, valid_until, category, linked_medication_ids, files, notes, markers) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        d.id,
        d.kind.wireValue,
        d.title.trim(),
        d.date?.toIso(),
        _blankToNull(d.specialty),
        d.validUntil?.toIso(),
        d.category?.wireValue,
        jsonEncode(d.linkedMedicationIds),
        jsonEncode([for (final f in d.files) f.toJson()]),
        _blankToNull(d.notes),
        jsonEncode([for (final m in d.markers) m.toJson()]),
      ],
    );
  }

  /// Todas as medições de cada marcador (chave normalizada), da mais
  /// recente para a mais antiga; sem data no fim.
  Map<String, List<MarkerReading>> markerHistory() {
    final out = <String, List<MarkerReading>>{};
    for (final d in list(HealthDocumentKind.exam)) {
      for (final m in d.markers) {
        out.putIfAbsent(m.key, () => []).add(MarkerReading(marker: m, date: d.date, documentId: d.id, documentTitle: d.title));
      }
    }
    return out;
  }

  void delete(String id) => _db.execute('DELETE FROM health_documents WHERE id = ?', [id]);

  HealthDocument? byId(String id) {
    final rows = _db.select('SELECT * FROM health_documents WHERE id = ?', [id]);
    return rows.isEmpty ? null : _fromRow(rows.first);
  }

  /// Documentos de um tipo (e categoria, para exames), mais recentes
  /// primeiro; sem data no fim.
  List<HealthDocument> list(HealthDocumentKind kind, {ExamCategory? category}) {
    final rows = category == null
        ? _db.select('SELECT * FROM health_documents WHERE kind = ?', [kind.wireValue])
        : _db.select('SELECT * FROM health_documents WHERE kind = ? AND category = ?', [kind.wireValue, category.wireValue]);
    final docs = [for (final r in rows) _fromRow(r)];
    docs.sort((a, b) {
      if (a.date == null && b.date == null) return a.title.compareTo(b.title);
      if (a.date == null) return 1;
      if (b.date == null) return -1;
      return b.date!.compareTo(a.date!);
    });
    return docs;
  }

  /// Todos os arquivos referenciados (para exportar e para apagar sobras).
  Set<String> allStoredNames() => {
        for (final r in _db.select('SELECT files FROM health_documents'))
          for (final f in (jsonDecode(r['files'] as String) as List)) (f as Map<String, dynamic>)['stored_name'] as String,
      };

  static String? _blankToNull(String? s) => s == null || s.trim().isEmpty ? null : s.trim();

  static HealthDocument _fromRow(Row r) => HealthDocument(
        id: r['id'] as String,
        kind: HealthDocumentKind.fromWireValue(r['kind'] as String),
        title: r['title'] as String,
        date: r['date'] == null ? null : LocalDate.parse(r['date'] as String),
        specialty: r['specialty'] as String?,
        validUntil: r['valid_until'] == null ? null : LocalDate.parse(r['valid_until'] as String),
        category: r['category'] == null ? null : ExamCategory.fromWireValue(r['category'] as String),
        linkedMedicationIds: [for (final id in jsonDecode(r['linked_medication_ids'] as String) as List) id as String],
        files: [
          for (final f in jsonDecode(r['files'] as String) as List) HealthDocumentFile.fromJson(f as Map<String, dynamic>),
        ],
        notes: r['notes'] as String?,
        markers: [
          for (final m in jsonDecode(r['markers'] as String) as List) ExamMarker.fromJson(m as Map<String, dynamic>),
        ],
      );
}
