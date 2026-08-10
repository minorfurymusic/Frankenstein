// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'food.dart';

/// Dataset de EXEMPLO/FIXTURE para teste — alguns alimentos brasileiros
/// comuns com macros plausíveis por 100 g. **Não é o subconjunto real do
/// Open Food Facts** (`docs/OFFLINE-IA.md:31-35`); a importação do dataset
/// completo é trabalho futuro de infraestrutura de dados (rede, tamanho,
/// pipeline de atualização delta), fora do escopo deste ciclo.
///
/// Os códigos de barras aqui são fabricados (não correspondem a produtos
/// reais) só para exercitar a busca por `barcode` em teste — formato
/// (13 dígitos numéricos) escolhido por ser o publicamente conhecido do
/// EAN-13/GTIN usado pelo Open Food Facts, conhecimento geral de formato,
/// não dado copiado de fonte nenhuma.
///
/// TODO(frankstein): trocar por importação real do subconjunto brasileiro
/// do Open Food Facts (CSV/JSON, campos `code`/`product_name`/`brands`/
/// `nutriments.*`) quando a infraestrutura de download existir.
final List<Food> fixtureFoods = [
  Food(
    id: 'fixture-arroz-branco-cozido',
    name: 'Arroz branco cozido',
    barcode: '7891000000013',
    source: FoodSource.offlineCatalog,
    energyKcalPer100g: 130,
    carbohydratesPer100g: 28.2,
    fatPer100g: 0.3,
    proteinPer100g: 2.7,
    fiberPer100g: 0.4,
    sodiumPer100g: 0.001,
  ),
  Food(
    id: 'fixture-feijao-carioca-cozido',
    name: 'Feijão carioca cozido',
    barcode: '7891000000037',
    source: FoodSource.offlineCatalog,
    energyKcalPer100g: 76,
    carbohydratesPer100g: 13.6,
    fatPer100g: 0.5,
    proteinPer100g: 4.8,
    fiberPer100g: 8.5,
    sodiumPer100g: 0.002,
  ),
  Food(
    id: 'fixture-frango-peito-grelhado',
    name: 'Peito de frango grelhado',
    barcode: '7891000000051',
    source: FoodSource.offlineCatalog,
    energyKcalPer100g: 159,
    carbohydratesPer100g: 0,
    fatPer100g: 2.5,
    proteinPer100g: 32.0,
    saturatedFatPer100g: 0.7,
    sodiumPer100g: 0.06,
  ),
  Food(
    id: 'fixture-banana-prata',
    name: 'Banana prata',
    barcode: '7891000000075',
    source: FoodSource.offlineCatalog,
    energyKcalPer100g: 98,
    carbohydratesPer100g: 26.0,
    fatPer100g: 0.1,
    proteinPer100g: 1.3,
    sugarPer100g: 14.0,
    fiberPer100g: 2.0,
  ),
  Food(
    id: 'fixture-ovo-cozido',
    name: 'Ovo de galinha cozido',
    barcode: '7891000000099',
    source: FoodSource.offlineCatalog,
    energyKcalPer100g: 146,
    carbohydratesPer100g: 0.6,
    fatPer100g: 9.5,
    proteinPer100g: 13.3,
    saturatedFatPer100g: 3.1,
    sodiumPer100g: 0.124,
  ),
  Food(
    id: 'fixture-pao-frances',
    name: 'Pão francês',
    barcode: '7891000000112',
    source: FoodSource.offlineCatalog,
    energyKcalPer100g: 300,
    carbohydratesPer100g: 58.6,
    fatPer100g: 3.1,
    proteinPer100g: 8.0,
    fiberPer100g: 2.3,
    sodiumPer100g: 0.643,
  ),
];
