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
  steps_goal INTEGER NOT NULL
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

  factory ProfileRepository.open(String path) => ProfileRepository._(sqlite3.open(path)..execute(_schemaSql));
  factory ProfileRepository.openInMemory() => ProfileRepository._(sqlite3.openInMemory()..execute(_schemaSql));

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
    );
  }

  void save(Profile p) {
    final d = p.birthDate;
    _db.execute(
      'INSERT OR REPLACE INTO profile (id, sex, birth_date, height_m, objective, rate_g_per_day, steps_goal) '
      'VALUES (1, ?, ?, ?, ?, ?, ?)',
      [
        p.sex.wireValue,
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
        p.heightMeters,
        p.objective.wireValue,
        p.rateGramsPerDay,
        p.stepsGoal,
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
