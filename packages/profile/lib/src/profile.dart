/// Sexo biológico — entra nas fórmulas (Mifflin-St Jeor, US Navy, piso de
/// água da EFSA). Não é identidade de gênero; a tela diz isso.
enum BiologicalSex {
  female,
  male;

  String get wireValue => name;

  static BiologicalSex fromWireValue(String v) =>
      BiologicalSex.values.firstWhere((s) => s.name == v, orElse: () => throw ArgumentError('sexo desconhecido: $v'));
}

/// Objetivo escolhido no perfil (ADR-15, "Meta de calorias").
enum Objective {
  lose,
  maintain,
  gain;

  String get wireValue => name;

  static Objective fromWireValue(String v) =>
      Objective.values.firstWhere((o) => o.name == v, orElse: () => throw ArgumentError('objetivo desconhecido: $v'));
}

/// Dados da pessoa usados nas fórmulas. Peso e % de gordura **não** ficam
/// aqui: são séries no Health Data Core (`weight`, `body_measurement`) e o
/// cálculo usa a medida mais recente.
class Profile {
  final BiologicalSex sex;

  /// Data de nascimento (só a data, sem hora).
  final DateTime birthDate;

  /// Altura em metros (SI).
  final double heightMeters;

  final Objective objective;

  /// Ritmo de perda/ganho em gramas por dia (ex.: 50). Ignorado em
  /// `maintain`. Sem teto (decisão do usuário, ADR-15).
  final double rateGramsPerDay;

  /// Meta de passos do dia.
  final int stepsGoal;

  /// Faz musculação/academia com regularidade — sobe a proteína (ISSN).
  final bool strengthTraining;

  /// Quer mais proteína que o padrão — soma 0,4 g/kg.
  final bool highProtein;

  /// Peso desejado (kg). Preenchido, comanda o objetivo (ADR-17).
  final double? targetWeightKg;

  Profile({
    required this.sex,
    required DateTime birthDate,
    required this.heightMeters,
    this.objective = Objective.maintain,
    this.rateGramsPerDay = 0,
    this.stepsGoal = 8000,
    this.strengthTraining = false,
    this.highProtein = false,
    this.targetWeightKg,
  }) : birthDate = DateTime(birthDate.year, birthDate.month, birthDate.day) {
    if (heightMeters < 0.5 || heightMeters > 2.5) throw ArgumentError('altura fora de 50–250 cm');
    if (rateGramsPerDay < 0) throw ArgumentError('ritmo não pode ser negativo');
    if (stepsGoal <= 0) throw ArgumentError('meta de passos precisa ser maior que zero');
    if (targetWeightKg != null && (targetWeightKg! < 20 || targetWeightKg! > 400)) {
      throw ArgumentError('peso desejado fora de 20–400 kg');
    }
  }

  /// Faixa em torno do peso desejado em que o objetivo vira "manter"
  /// (ADR-17): a oscilação normal de um dia para o outro não troca o objetivo.
  static const double targetToleranceKg = 1.0;

  /// Objetivo que vale hoje: o do peso desejado, se houver; senão o
  /// escolhido à mão (ADR-17).
  Objective effectiveObjective(double currentWeightKg) {
    final target = targetWeightKg;
    if (target == null) return objective;
    final diff = currentWeightKg - target;
    if (diff > targetToleranceKg) return Objective.lose;
    if (diff < -targetToleranceKg) return Objective.gain;
    return Objective.maintain;
  }

  /// Chegou ao peso desejado (dentro de ±1 kg).
  bool reachedTarget(double currentWeightKg) =>
      targetWeightKg != null && (currentWeightKg - targetWeightKg!).abs() <= targetToleranceKg;

  /// Idade completa em anos na data [on].
  int ageOn(DateTime on) {
    var age = on.year - birthDate.year;
    if (on.month < birthDate.month || (on.month == birthDate.month && on.day < birthDate.day)) age--;
    return age;
  }

  Profile copyWith({
    BiologicalSex? sex,
    DateTime? birthDate,
    double? heightMeters,
    Objective? objective,
    double? rateGramsPerDay,
    int? stepsGoal,
    bool? strengthTraining,
    bool? highProtein,
    double? targetWeightKg,
    bool clearTargetWeight = false,
  }) =>
      Profile(
        sex: sex ?? this.sex,
        birthDate: birthDate ?? this.birthDate,
        heightMeters: heightMeters ?? this.heightMeters,
        objective: objective ?? this.objective,
        rateGramsPerDay: rateGramsPerDay ?? this.rateGramsPerDay,
        stepsGoal: stepsGoal ?? this.stepsGoal,
        strengthTraining: strengthTraining ?? this.strengthTraining,
        highProtein: highProtein ?? this.highProtein,
        targetWeightKg: clearTargetWeight ? null : (targetWeightKg ?? this.targetWeightKg),
      );
}

/// Previsão de chegada ao peso desejado pelo ritmo do perfil (ADR-17).
/// Conta simples, não promessa.
class WeightProjection {
  final int days;
  final DateTime date;
  const WeightProjection({required this.days, required this.date});

  int get weeks => (days / 7).ceil();
}

/// `null` sem peso desejado, sem ritmo ou já dentro da faixa.
WeightProjection? projectTargetWeight(Profile p, {required double currentWeightKg, required DateTime from}) {
  final target = p.targetWeightKg;
  if (target == null || p.rateGramsPerDay <= 0 || p.reachedTarget(currentWeightKg)) return null;
  final days = ((currentWeightKg - target).abs() * 1000 / p.rateGramsPerDay).ceil();
  final start = DateTime(from.year, from.month, from.day);
  return WeightProjection(days: days, date: start.add(Duration(days: days)));
}

/// Ajustes manuais das metas (Conta › Metas: "toda meta aceita ajuste
/// manual", ADR-15). `null` = usar o calculado.
class GoalOverrides {
  final double? caloriesKcal;
  final double? proteinGrams;
  final double? fatGrams;
  final double? carbsGrams;
  final double? waterMl;
  final double? fiberGrams;

  /// Meta de sono (minutos por noite). Sem ajuste, o app usa
  /// [defaultSleepGoalMinutes].
  final double? sleepMinutes;

  /// 8 h: a "Meta 8 h" da prancheta Sono (`docs/design/rlt-layout/
  /// Sono.dc.html`). Editável em Conta › Metas.
  static const double defaultSleepGoalMinutes = 480;

  const GoalOverrides({
    this.caloriesKcal,
    this.proteinGrams,
    this.fatGrams,
    this.carbsGrams,
    this.waterMl,
    this.fiberGrams,
    this.sleepMinutes,
  });

  double get sleepGoalMinutes => sleepMinutes ?? defaultSleepGoalMinutes;

  static const none = GoalOverrides();

  Map<String, double> toMap() => {
        if (caloriesKcal != null) 'calories_kcal': caloriesKcal!,
        if (proteinGrams != null) 'protein_g': proteinGrams!,
        if (fatGrams != null) 'fat_g': fatGrams!,
        if (carbsGrams != null) 'carbs_g': carbsGrams!,
        if (waterMl != null) 'water_ml': waterMl!,
        if (fiberGrams != null) 'fiber_g': fiberGrams!,
        if (sleepMinutes != null) 'sleep_min': sleepMinutes!,
      };

  factory GoalOverrides.fromMap(Map<String, dynamic> m) => GoalOverrides(
        caloriesKcal: (m['calories_kcal'] as num?)?.toDouble(),
        proteinGrams: (m['protein_g'] as num?)?.toDouble(),
        fatGrams: (m['fat_g'] as num?)?.toDouble(),
        carbsGrams: (m['carbs_g'] as num?)?.toDouble(),
        waterMl: (m['water_ml'] as num?)?.toDouble(),
        fiberGrams: (m['fiber_g'] as num?)?.toDouble(),
        sleepMinutes: (m['sleep_min'] as num?)?.toDouble(),
      );
}
