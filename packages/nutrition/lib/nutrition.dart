/// Diário alimentar por PORT do OpenNutriTracker — ver docs/specs/nutricao.md, .claude/rules/port.md e ADR-5. NUNCA implementar a partir do código-fonte ou da ficha de reconhecimento.
///
/// Fase 6: `Food`/`FoodRepository` (catálogo local sobre `sqlite3`, hoje
/// populado por um dataset de fixture — a importação real do subconjunto
/// brasileiro do Open Food Facts é trabalho futuro, `docs/OFFLINE-IA.md:31-35`),
/// `MealLogger` (grava `HealthEvent` tipo `meal`), interface abstrata
/// `BarcodeDecoder` (a implementação concreta com câmera real fica para um
/// ciclo com dispositivo/emulador), e a ferramenta `log_meal` real,
/// registrável no `ToolRegistry` do cérebro.
library;

export 'src/barcode_decoder.dart';
export 'src/food.dart';
export 'src/food_fixture_dataset.dart';
export 'src/food_repository.dart';
export 'src/meal.dart';
export 'src/meal_logger.dart';
export 'src/nutrition_tools.dart';
