/// Diário alimentar por PORT do OpenNutriTracker — ver docs/specs/nutricao.md, .claude/rules/port.md e ADR-5. NUNCA implementar a partir do código-fonte ou da ficha de reconhecimento.
///
/// Fase 6: `Food`/`FoodRepository` (catálogo local sobre `sqlite3`,
/// populado por um dataset de fixture para teste e pelo catálogo real de
/// produção — TACO/NEPA-UNICAMP, `food_taco_dataset.dart`, no lugar do
/// Open Food Facts originalmente cogitado em `docs/OFFLINE-IA.md:31-35`,
/// que não é alcançável pela rede deste ambiente de desenvolvimento),
/// `MealLogger` (grava `HealthEvent` tipo `meal`), interface abstrata
/// `BarcodeDecoder` (a implementação concreta com câmera real fica para um
/// ciclo com dispositivo/emulador), e a ferramenta `log_meal` real,
/// registrável no `ToolRegistry` do cérebro.
///
/// `WaterLogger`/`log_water` (ciclo do dashboard mínimo): grava
/// `HealthEvent` tipo `water`, mesmo padrão de `MealLogger`/`log_meal`.
library;

export 'src/barcode_decoder.dart';
export 'src/food.dart';
export 'src/food_fixture_dataset.dart';
export 'src/food_repository.dart';
export 'src/food_taco_dataset.dart';
export 'src/meal.dart';
export 'src/meal_logger.dart';
export 'src/nutrition_tools.dart';
export 'src/water_logger.dart';
export 'src/water_tools.dart';
