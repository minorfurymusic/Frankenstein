import 'dart:math' as math;

import 'profile.dart';

/// Fórmulas da ADR-15 (`docs/adr/015-formulas-saude.md`), aprovadas pelo
/// usuário em 2026-10-02. Cada constante cita a fonte; o que veio só de
/// fonte secundária está marcado.
abstract final class HealthFormulas {
  /// Mifflin MD, St Jeor ST et al., Am J Clin Nutr 1990;51:241–7.
  /// `10·kg + 6,25·cm − 5·idade + 5` (homem) / `− 161` (mulher).
  static double bmrMifflinStJeor({
    required BiologicalSex sex,
    required double weightKg,
    required double heightCm,
    required int ageYears,
  }) =>
      10 * weightKg + 6.25 * heightCm - 5 * ageYears + (sex == BiologicalSex.male ? 5 : -161);

  /// Katch-McArdle: `370 + 21,6 · massa magra (kg)`.
  static double bmrKatchMcArdle({required double weightKg, required double bodyFatFraction}) =>
      370 + 21.6 * weightKg * (1 - bodyFatFraction);

  /// Fator "sedentário": o dia a dia sem caminhada nem treino — esses
  /// entram por passos e METs, para não contar a mesma atividade duas vezes
  /// (ADR-15).
  static const double sedentaryFactor = 1.2;

  /// 7.700 kcal por kg (Hall 2008 mostra que superestima a perda no longo
  /// prazo; por isso a meta é recalculada a cada peso novo — ADR-15).
  static const double kcalPerGramBodyWeight = 7.7;

  /// Passada estimada pela altura (ACSM, citado em fonte secundária):
  /// 0,415 × altura (homem), 0,413 × altura (mulher).
  static double stepLengthMeters(BiologicalSex sex, double heightMeters) =>
      heightMeters * (sex == BiologicalSex.male ? 0.415 : 0.413);

  /// Caminhada em ritmo moderado: 3,0 mph ≈ 4,83 km/h, MET 3,8 (Compêndio
  /// de Atividades Físicas 2024, faixa 2,8–3,4 mph). NÃO VERIFICADO na
  /// fonte primária (pacompendium.com bloqueado pela rede no ciclo).
  static const double walkingSpeedKmh = 4.828;
  static const double walkingMet = 3.8;

  /// Gasto de uma atividade acima do repouso: `(MET − 1) · kg · horas`.
  /// O "− 1" tira o repouso, que já está no basal (ADR-15).
  static double activityKcal({required double met, required double weightKg, required Duration duration}) =>
      math.max(0, (met - 1) * weightKg * duration.inSeconds / 3600);

  static double stepsKcal({
    required int steps,
    required BiologicalSex sex,
    required double heightMeters,
    required double weightKg,
  }) {
    if (steps <= 0) return 0;
    final km = steps * stepLengthMeters(sex, heightMeters) / 1000;
    final hours = km / walkingSpeedKmh;
    return activityKcal(met: walkingMet, weightKg: weightKg, duration: Duration(seconds: (hours * 3600).round()));
  }

  /// Proteína em g/kg (ISSN 2017, doi:10.1186/s12970-017-0177-8: 1,4–2,0
  /// para quem treina). 1,6 ao perder ou ganhar, 1,4 ao manter (ADR-15).
  static double proteinPerKg(Objective o) => o == Objective.maintain ? 1.4 : 1.6;

  /// Gordura: 30% das calorias (ADR-15).
  static const double fatEnergyShare = 0.30;

  /// Faixas aceitáveis do Institute of Medicine (AMDR), em fração das
  /// calorias.
  static const amdrProtein = (0.10, 0.35);
  static const amdrFat = (0.20, 0.35);
  static const amdrCarbs = (0.45, 0.65);

  /// Água (EFSA 2010, doi:10.2903/j.efsa.2010.1459): água total =
  /// `max(kg × 35 ml, 2,0 L mulher | 2,5 L homem)`; meta de bebida = 80%
  /// (20–30% vem da comida). 35 ml/kg: regra clínica, fonte secundária.
  static double drinkWaterMl({required BiologicalSex sex, required double weightKg}) {
    final floor = sex == BiologicalSex.male ? 2500.0 : 2000.0;
    return math.max(weightKg * 35, floor) * 0.8;
  }

  static double bmi({required double weightKg, required double heightMeters}) =>
      weightKg / (heightMeters * heightMeters);

  /// Faixas da OMS para adultos.
  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return 'Abaixo do peso';
    if (bmi < 25) return 'Peso adequado';
    if (bmi < 30) return 'Sobrepeso';
    if (bmi < 35) return 'Obesidade grau I';
    if (bmi < 40) return 'Obesidade grau II';
    return 'Obesidade grau III';
  }

  static double waistToHeight({required double waistMeters, required double heightMeters}) =>
      waistMeters / heightMeters;

  /// US Navy (Hodgdon & Beckett 1984), medidas em cm, densidade convertida
  /// por Siri (495/D − 450). Mulher precisa do quadril.
  static double navyBodyFatPercent({
    required BiologicalSex sex,
    required double heightCm,
    required double neckCm,
    required double waistCm,
    double? hipCm,
  }) {
    double log10(double x) => math.log(x) / math.ln10;
    final double density;
    if (sex == BiologicalSex.male) {
      if (waistCm <= neckCm) throw ArgumentError('cintura precisa ser maior que o pescoço');
      density = 1.0324 - 0.19077 * log10(waistCm - neckCm) + 0.15456 * log10(heightCm);
    } else {
      if (hipCm == null) throw ArgumentError('a fórmula feminina precisa do quadril');
      if (waistCm + hipCm <= neckCm) throw ArgumentError('medidas inconsistentes');
      density = 1.29579 - 0.35004 * log10(waistCm + hipCm - neckCm) + 0.22100 * log10(heightCm);
    }
    return 495 / density - 450;
  }
}

/// Insumos do dia: o que veio do perfil, a medida mais recente e a
/// atividade já registrada hoje.
class DayInputs {
  final double weightKg;
  final double? bodyFatFraction;
  final int steps;

  /// Gasto dos treinos/corridas do dia já calculado por MET (acima do
  /// repouso).
  final double exerciseKcal;
  final DateTime date;

  const DayInputs({
    required this.weightKg,
    required this.date,
    this.bodyFatFraction,
    this.steps = 0,
    this.exerciseKcal = 0,
  });
}

/// Metas do dia, com o caminho do cálculo para a tela mostrar "de onde
/// veio o número".
class DailyGoals {
  final double basalKcal;
  final String basalFormula; // 'Mifflin-St Jeor' | 'Katch-McArdle'
  final double baseKcal; // basal × 1,2
  final double objectiveAdjustmentKcal; // negativo ao perder
  final double stepsKcal;
  final double exerciseKcal;
  final double caloriesKcal;
  final bool flooredAtBasal;
  final double proteinGrams;
  final double fatGrams;
  final double carbsGrams;
  final double waterMl;
  final int stepsGoal;
  final List<String> warnings;
  final Set<String> manual; // metas ajustadas à mão

  const DailyGoals({
    required this.basalKcal,
    required this.basalFormula,
    required this.baseKcal,
    required this.objectiveAdjustmentKcal,
    required this.stepsKcal,
    required this.exerciseKcal,
    required this.caloriesKcal,
    required this.flooredAtBasal,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbsGrams,
    required this.waterMl,
    required this.stepsGoal,
    required this.warnings,
    required this.manual,
  });
}

/// Monta as metas do dia (ADR-15):
/// `meta = basal × 1,2 − ajuste do objetivo + passos + exercícios`,
/// nunca abaixo do basal; proteína por g/kg, gordura 30%, carboidrato o
/// restante, conferidos pelas faixas AMDR; água por kg com piso EFSA.
DailyGoals computeDailyGoals(Profile profile, DayInputs day, {GoalOverrides overrides = GoalOverrides.none}) {
  final age = profile.ageOn(day.date);
  final heightCm = profile.heightMeters * 100;
  final useKatch = day.bodyFatFraction != null;
  final basal = useKatch
      ? HealthFormulas.bmrKatchMcArdle(weightKg: day.weightKg, bodyFatFraction: day.bodyFatFraction!)
      : HealthFormulas.bmrMifflinStJeor(sex: profile.sex, weightKg: day.weightKg, heightCm: heightCm, ageYears: age);
  final base = basal * HealthFormulas.sedentaryFactor;
  final adjustment = switch (profile.objective) {
    Objective.lose => -profile.rateGramsPerDay * HealthFormulas.kcalPerGramBodyWeight,
    Objective.gain => profile.rateGramsPerDay * HealthFormulas.kcalPerGramBodyWeight,
    Objective.maintain => 0.0,
  };
  final steps = HealthFormulas.stepsKcal(
    steps: day.steps,
    sex: profile.sex,
    heightMeters: profile.heightMeters,
    weightKg: day.weightKg,
  );
  final raw = base + adjustment + steps + day.exerciseKcal;
  final floored = raw < basal;
  final manual = <String>{};

  var calories = floored ? basal : raw;
  if (overrides.caloriesKcal != null) {
    calories = overrides.caloriesKcal!;
    manual.add('calories');
  }

  var protein = HealthFormulas.proteinPerKg(profile.objective) * day.weightKg;
  var fat = calories * HealthFormulas.fatEnergyShare / 9;
  if (overrides.proteinGrams != null) {
    protein = overrides.proteinGrams!;
    manual.add('protein');
  }
  if (overrides.fatGrams != null) {
    fat = overrides.fatGrams!;
    manual.add('fat');
  }
  var carbs = math.max(0.0, (calories - protein * 4 - fat * 9) / 4);
  if (overrides.carbsGrams != null) {
    carbs = overrides.carbsGrams!;
    manual.add('carbs');
  }

  final warnings = <String>[];
  if (floored) {
    warnings.add('A meta ficou no seu gasto em repouso: o app não propõe comer menos que isso.');
  }
  void check(String name, double kcal, (double, double) range) {
    if (calories <= 0) return;
    final share = kcal / calories;
    if (share < range.$1 || share > range.$2) {
      warnings.add('$name em ${(share * 100).round()}% das calorias, fora da faixa de '
          '${(range.$1 * 100).round()}–${(range.$2 * 100).round()}%.');
    }
  }

  check('Proteína', protein * 4, HealthFormulas.amdrProtein);
  check('Gordura', fat * 9, HealthFormulas.amdrFat);
  check('Carboidrato', carbs * 4, HealthFormulas.amdrCarbs);

  var water = HealthFormulas.drinkWaterMl(sex: profile.sex, weightKg: day.weightKg);
  if (overrides.waterMl != null) {
    water = overrides.waterMl!;
    manual.add('water');
  }

  return DailyGoals(
    basalKcal: basal,
    basalFormula: useKatch ? 'Katch-McArdle' : 'Mifflin-St Jeor',
    baseKcal: base,
    objectiveAdjustmentKcal: adjustment,
    stepsKcal: steps,
    exerciseKcal: day.exerciseKcal,
    caloriesKcal: calories,
    flooredAtBasal: floored,
    proteinGrams: protein,
    fatGrams: fat,
    carbsGrams: carbs,
    waterMl: water,
    stepsGoal: profile.stepsGoal,
    warnings: warnings,
    manual: manual,
  );
}

/// "Bateu a meta" (ADR-15): perder → consumo ≤ meta; ganhar → ≥ meta;
/// manter → dentro de ±10%.
bool metCalorieGoal(Objective objective, {required double consumedKcal, required double goalKcal}) => switch (objective) {
      Objective.lose => consumedKcal <= goalKcal,
      Objective.gain => consumedKcal >= goalKcal,
      Objective.maintain => (consumedKcal - goalKcal).abs() <= goalKcal * 0.10,
    };
