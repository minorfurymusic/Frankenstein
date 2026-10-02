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

  Profile({
    required this.sex,
    required DateTime birthDate,
    required this.heightMeters,
    this.objective = Objective.maintain,
    this.rateGramsPerDay = 0,
    this.stepsGoal = 8000,
  }) : birthDate = DateTime(birthDate.year, birthDate.month, birthDate.day) {
    if (heightMeters < 0.5 || heightMeters > 2.5) throw ArgumentError('altura fora de 50–250 cm');
    if (rateGramsPerDay < 0) throw ArgumentError('ritmo não pode ser negativo');
    if (stepsGoal <= 0) throw ArgumentError('meta de passos precisa ser maior que zero');
  }

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
  }) =>
      Profile(
        sex: sex ?? this.sex,
        birthDate: birthDate ?? this.birthDate,
        heightMeters: heightMeters ?? this.heightMeters,
        objective: objective ?? this.objective,
        rateGramsPerDay: rateGramsPerDay ?? this.rateGramsPerDay,
        stepsGoal: stepsGoal ?? this.stepsGoal,
      );
}

/// Ajustes manuais das metas (Conta › Metas: "toda meta aceita ajuste
/// manual", ADR-15). `null` = usar o calculado.
class GoalOverrides {
  final double? caloriesKcal;
  final double? proteinGrams;
  final double? fatGrams;
  final double? carbsGrams;
  final double? waterMl;

  const GoalOverrides({this.caloriesKcal, this.proteinGrams, this.fatGrams, this.carbsGrams, this.waterMl});

  static const none = GoalOverrides();

  Map<String, double> toMap() => {
        if (caloriesKcal != null) 'calories_kcal': caloriesKcal!,
        if (proteinGrams != null) 'protein_g': proteinGrams!,
        if (fatGrams != null) 'fat_g': fatGrams!,
        if (carbsGrams != null) 'carbs_g': carbsGrams!,
        if (waterMl != null) 'water_ml': waterMl!,
      };

  factory GoalOverrides.fromMap(Map<String, dynamic> m) => GoalOverrides(
        caloriesKcal: (m['calories_kcal'] as num?)?.toDouble(),
        proteinGrams: (m['protein_g'] as num?)?.toDouble(),
        fatGrams: (m['fat_g'] as num?)?.toDouble(),
        carbsGrams: (m['carbs_g'] as num?)?.toDouble(),
        waterMl: (m['water_ml'] as num?)?.toDouble(),
      );
}
