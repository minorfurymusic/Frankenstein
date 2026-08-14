// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:sqlite3/sqlite3.dart';

import 'food.dart';
import 'food_fixture_dataset.dart';
import 'food_taco_dataset.dart';

const String _foodsSchemaSql = '''
CREATE TABLE IF NOT EXISTS foods (
  id TEXT PRIMARY KEY,
  barcode TEXT UNIQUE,
  name TEXT NOT NULL,
  brand TEXT,
  source TEXT NOT NULL,
  energy_kcal_100g REAL NOT NULL,
  carbohydrates_100g REAL NOT NULL,
  fat_100g REAL NOT NULL,
  protein_100g REAL NOT NULL,
  saturated_fat_100g REAL,
  sugar_100g REAL,
  fiber_100g REAL,
  sodium_100g REAL
);

CREATE INDEX IF NOT EXISTS idx_foods_name ON foods(name);
''';

/// Lançada ao tentar inserir um alimento personalizado com
/// `source != FoodSource.custom` (a distinção existe para não deixar o
/// catálogo se confundir sobre a origem do dado — `docs/specs/nutricao.md`).
class InvalidFoodSourceException implements Exception {
  final String message;
  InvalidFoodSourceException(this.message);

  @override
  String toString() => message;
}

/// Catálogo local de alimentos — busca por código de barras e por nome
/// (`docs/specs/nutricao.md`, tela "Adicionar alimento": "busca por nome,
/// escaneamento de código de barras, ou 'adição rápida'").
///
/// Sobre `sqlite3` (bindings FFI Dart puro), mesmo padrão de
/// `packages/health_core/lib/src/health_data_core.dart` — mantém o
/// pacote testável com `dart test` puro, sem virar pacote Flutter.
///
/// **Fonte dos dados de catálogo:** dois datasets embarcados, estáticos
/// (sem chamada de rede em tempo de execução — `.claude/rules/00-inviolaveis.md`).
/// `food_fixture_dataset.dart` é um punhado de itens de EXEMPLO/TESTE,
/// mantido pequeno e estável porque outros pacotes testam contra valores
/// exatos dele. `food_taco_dataset.dart` é o catálogo real de produção —
/// a Tabela Brasileira de Composição de Alimentos (TACO, NEPA/UNICAMP),
/// ~578 alimentos brasileiros reais (ver o próprio arquivo para
/// atribuição completa). `seedFixtureData`/`seedTacoData` controlam quais
/// datasets são inseridos na abertura; produção abre com o TACO ligado
/// (é o catálogo real) e o fixture desligado.
class FoodRepository {
  final Database _db;

  FoodRepository._(this._db);

  /// Abre (ou cria) o catálogo no caminho de arquivo dado. Produção: o
  /// catálogo real (`seedTacoData: true` por padrão) é o objetivo deste
  /// construtor — `seedFixtureData` fica desligado por padrão porque o
  /// fixture é só para teste.
  factory FoodRepository.open(String path, {bool seedFixtureData = false, bool seedTacoData = true}) {
    final db = sqlite3.open(path);
    db.execute(_foodsSchemaSql);
    final repo = FoodRepository._(db);
    if (seedFixtureData) repo._seedFixtureData();
    if (seedTacoData) repo._seedTacoData();
    return repo;
  }

  /// Catálogo em memória — uso em teste. `seedFixtureData` é `true` por
  /// padrão aqui porque é o caso de uso mais comum em teste (valores
  /// pequenos e estáveis, sem os ~578 itens do TACO poluindo a busca).
  /// `seedTacoData` fica desligado por padrão para não mudar o
  /// comportamento de nenhum teste existente; passe `seedTacoData: true`
  /// explicitamente para testar contra o catálogo real.
  factory FoodRepository.openInMemory({bool seedFixtureData = true, bool seedTacoData = false}) {
    final db = sqlite3.openInMemory();
    db.execute(_foodsSchemaSql);
    final repo = FoodRepository._(db);
    if (seedFixtureData) repo._seedFixtureData();
    if (seedTacoData) repo._seedTacoData();
    return repo;
  }

  void close() => _db.dispose();

  void _seedFixtureData() {
    for (final food in fixtureFoods) {
      _insertIgnoreDuplicate(food);
    }
  }

  void _seedTacoData() {
    for (final food in tacoFoods) {
      _insertIgnoreDuplicate(food);
    }
  }

  void _insert(Food food) {
    _db.execute(
      '''
      INSERT INTO foods (
        id, barcode, name, brand, source, energy_kcal_100g,
        carbohydrates_100g, fat_100g, protein_100g, saturated_fat_100g,
        sugar_100g, fiber_100g, sodium_100g
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        food.id,
        food.barcode,
        food.name,
        food.brand,
        food.source.wireValue,
        food.energyKcalPer100g,
        food.carbohydratesPer100g,
        food.fatPer100g,
        food.proteinPer100g,
        food.saturatedFatPer100g,
        food.sugarPer100g,
        food.fiberPer100g,
        food.sodiumPer100g,
      ],
    );
  }

  /// Mesma inserção de `_insert`, mas com `INSERT OR IGNORE`: usada só para
  /// reseeding de catálogo estático (fixture/TACO). Reabrir um
  /// `FoodRepository.open()` num arquivo já semeado chama `_seedFixtureData`/
  /// `_seedTacoData` de novo — sem `OR IGNORE` isso violava a PRIMARY KEY
  /// de `foods.id` na segunda abertura do mesmo arquivo (linha de produção
  /// normal: app reaberto numa segunda sessão). A linha já existe com o
  /// mesmo conteúdo estático, então ignorar o conflito é o comportamento
  /// correto aqui — ao contrário de `insertCustomFood`, que precisa
  /// continuar estourando alto em duplicata real de dado do usuário.
  void _insertIgnoreDuplicate(Food food) {
    _db.execute(
      '''
      INSERT OR IGNORE INTO foods (
        id, barcode, name, brand, source, energy_kcal_100g,
        carbohydrates_100g, fat_100g, protein_100g, saturated_fat_100g,
        sugar_100g, fiber_100g, sodium_100g
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        food.id,
        food.barcode,
        food.name,
        food.brand,
        food.source.wireValue,
        food.energyKcalPer100g,
        food.carbohydratesPer100g,
        food.fatPer100g,
        food.proteinPer100g,
        food.saturatedFatPer100g,
        food.sugarPer100g,
        food.fiberPer100g,
        food.sodiumPer100g,
      ],
    );
  }

  /// Cadastra um alimento personalizado do usuário — "adição rápida"
  /// (nome + kcal, macros opcionais) ou refeição/receita personalizada
  /// nomeada (`docs/specs/nutricao.md`). Exige `source == FoodSource.custom`;
  /// o catálogo embarcado não é escrito por este método.
  void insertCustomFood(Food food) {
    if (food.source != FoodSource.custom) {
      throw InvalidFoodSourceException(
          'insertCustomFood só aceita FoodSource.custom (recebeu ${food.source.wireValue}) — use o dataset de fixture/importação para o catálogo offline');
    }
    _insert(food);
  }

  Food? findById(String id) {
    final rows = _db.select('SELECT * FROM foods WHERE id = ?', [id]);
    if (rows.isEmpty) return null;
    return _rowToFood(rows.first);
  }

  Food? findByBarcode(String barcode) {
    final rows = _db.select('SELECT * FROM foods WHERE barcode = ?', [barcode]);
    if (rows.isEmpty) return null;
    return _rowToFood(rows.first);
  }

  /// Busca por nome (substring, sem diferenciar maiúsculas/minúsculas),
  /// ordenada por nome. `docs/specs/nutricao.md`, fluxo "Registrar
  /// refeição por busca".
  List<Food> searchByName(String query, {int limit = 20}) {
    final rows = _db.select(
      'SELECT * FROM foods WHERE name LIKE ? ORDER BY name ASC LIMIT ?',
      ['%$query%', limit],
    );
    return rows.map(_rowToFood).toList();
  }

  Food _rowToFood(Row r) {
    return Food(
      id: r['id'] as String,
      barcode: r['barcode'] as String?,
      name: r['name'] as String,
      brand: r['brand'] as String?,
      source: FoodSource.fromWireValue(r['source'] as String),
      energyKcalPer100g: (r['energy_kcal_100g'] as num).toDouble(),
      carbohydratesPer100g: (r['carbohydrates_100g'] as num).toDouble(),
      fatPer100g: (r['fat_100g'] as num).toDouble(),
      proteinPer100g: (r['protein_100g'] as num).toDouble(),
      saturatedFatPer100g: (r['saturated_fat_100g'] as num?)?.toDouble(),
      sugarPer100g: (r['sugar_100g'] as num?)?.toDouble(),
      fiberPer100g: (r['fiber_100g'] as num?)?.toDouble(),
      sodiumPer100g: (r['sodium_100g'] as num?)?.toDouble(),
    );
  }
}
