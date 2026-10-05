import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'profile.dart';

const String _schemaSql = '''
CREATE TABLE IF NOT EXISTS profile (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  sex TEXT NOT NULL,
  birth_date TEXT NOT NULL,
  height_m REAL NOT NULL,
  objective TEXT NOT NULL,
  rate_g_per_day REAL NOT NULL,
  steps_goal INTEGER NOT NULL,
  strength_training INTEGER NOT NULL DEFAULT 0,
  high_protein INTEGER NOT NULL DEFAULT 0,
  target_weight_kg REAL
);
CREATE TABLE IF NOT EXISTS settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);
''';

/// Perfil (uma linha só — o app é de uma pessoa), ajustes manuais das
/// metas e preferências do app. Fica no aparelho, como todo dado de saúde.
class ProfileRepository {
  final Database _db;
  ProfileRepository._(this._db);

  factory ProfileRepository.open(String path) => ProfileRepository._(_migrate(sqlite3.open(path)));
  factory ProfileRepository.openInMemory() => ProfileRepository._(_migrate(sqlite3.openInMemory()));

  /// Banco criado antes das colunas novas (APK de teste antigo) ganha as
  /// colunas com o valor padrão, sem perder o perfil.
  static Database _migrate(Database db) {
    db.execute(_schemaSql);
    final columns = db.select('PRAGMA table_info(profile)').map((r) => r['name'] as String).toSet();
    if (!columns.contains('strength_training')) {
      db.execute('ALTER TABLE profile ADD COLUMN strength_training INTEGER NOT NULL DEFAULT 0');
    }
    if (!columns.contains('high_protein')) {
      db.execute('ALTER TABLE profile ADD COLUMN high_protein INTEGER NOT NULL DEFAULT 0');
    }
    if (!columns.contains('target_weight_kg')) {
      db.execute('ALTER TABLE profile ADD COLUMN target_weight_kg REAL');
    }
    return db;
  }

  void close() => _db.dispose();

  Profile? load() {
    final rows = _db.select('SELECT * FROM profile WHERE id = 1');
    if (rows.isEmpty) return null;
    final r = rows.first;
    return Profile(
      sex: BiologicalSex.fromWireValue(r['sex'] as String),
      birthDate: DateTime.parse(r['birth_date'] as String),
      heightMeters: (r['height_m'] as num).toDouble(),
      objective: Objective.fromWireValue(r['objective'] as String),
      rateGramsPerDay: (r['rate_g_per_day'] as num).toDouble(),
      stepsGoal: r['steps_goal'] as int,
      strengthTraining: (r['strength_training'] as int) == 1,
      highProtein: (r['high_protein'] as int) == 1,
      targetWeightKg: (r['target_weight_kg'] as num?)?.toDouble(),
    );
  }

  void save(Profile p) {
    final d = p.birthDate;
    _db.execute(
      'INSERT OR REPLACE INTO profile '
      '(id, sex, birth_date, height_m, objective, rate_g_per_day, steps_goal, strength_training, high_protein, target_weight_kg) '
      'VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        p.sex.wireValue,
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        p.heightMeters,
        p.objective.wireValue,
        p.rateGramsPerDay,
        p.stepsGoal,
        p.strengthTraining ? 1 : 0,
        p.highProtein ? 1 : 0,
        p.targetWeightKg,
      ],
    );
  }

  String? getSetting(String key) {
    final rows = _db.select('SELECT value FROM settings WHERE key = ?', [key]);
    return rows.isEmpty ? null : rows.first['value'] as String;
  }

  void setSetting(String key, String? value) {
    if (value == null) {
      _db.execute('DELETE FROM settings WHERE key = ?', [key]);
    } else {
      _db.execute('INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)', [key, value]);
    }
  }

  GoalOverrides loadOverrides() {
    final raw = getSetting('goal_overrides');
    if (raw == null) return GoalOverrides.none;
    return GoalOverrides.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  void saveOverrides(GoalOverrides o) {
    final m = o.toMap();
    setSetting('goal_overrides', m.isEmpty ? null : jsonEncode(m));
  }
}
