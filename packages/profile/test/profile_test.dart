import 'package:frankstein_profile/profile.dart';
import 'package:test/test.dart';

void main() {
  final man = Profile(sex: BiologicalSex.male, birthDate: DateTime(1996, 1, 1), heightMeters: 1.75);
  final day = DateTime(2026, 10, 2);

  group('fórmulas (valores calculados à mão)', () {
    test('Mifflin-St Jeor: homem 70 kg, 175 cm, 30 anos = 1648,75; mulher 60 kg, 165 cm, 30 anos = 1320,25', () {
      expect(
        HealthFormulas.bmrMifflinStJeor(sex: BiologicalSex.male, weightKg: 70, heightCm: 175, ageYears: 30),
        closeTo(1648.75, 1e-9),
      );
      expect(
        HealthFormulas.bmrMifflinStJeor(sex: BiologicalSex.female, weightKg: 60, heightCm: 165, ageYears: 30),
        closeTo(1320.25, 1e-9),
      );
    });

    test('Katch-McArdle: 70 kg com 20% de gordura = 370 + 21,6 × 56 = 1579,6', () {
      expect(HealthFormulas.bmrKatchMcArdle(weightKg: 70, bodyFatFraction: 0.20), closeTo(1579.6, 1e-9));
    });

    test('atividade conta só acima do repouso: (MET − 1) × kg × horas', () {
      expect(HealthFormulas.activityKcal(met: 8, weightKg: 70, duration: const Duration(minutes: 30)), closeTo(245, 1e-9));
      expect(HealthFormulas.activityKcal(met: 0.9, weightKg: 70, duration: const Duration(hours: 1)), 0);
    });

    test('passos: 10.000 passos, homem de 1,75 m e 70 kg ≈ 294,8 kcal', () {
      expect(
        HealthFormulas.stepsKcal(steps: 10000, sex: BiologicalSex.male, heightMeters: 1.75, weightKg: 70),
        closeTo(294.82, 0.01),
      );
      expect(HealthFormulas.stepsKcal(steps: 0, sex: BiologicalSex.male, heightMeters: 1.75, weightKg: 70), 0);
    });

    test('água para beber: 80% de max(35 ml/kg, piso EFSA por sexo)', () {
      expect(HealthFormulas.drinkWaterMl(sex: BiologicalSex.male, weightKg: 70), closeTo(2000, 1e-9)); // piso 2,5 L
      expect(HealthFormulas.drinkWaterMl(sex: BiologicalSex.female, weightKg: 60), closeTo(1680, 1e-9)); // 2,1 L
      expect(HealthFormulas.drinkWaterMl(sex: BiologicalSex.male, weightKg: 90), closeTo(2520, 1e-9)); // 3,15 L
    });

    test('IMC e faixas da OMS; cintura/altura', () {
      final bmi = HealthFormulas.bmi(weightKg: 70, heightMeters: 1.75);
      expect(bmi, closeTo(22.857, 0.001));
      expect(HealthFormulas.bmiCategory(bmi), 'Peso adequado');
      expect(HealthFormulas.bmiCategory(18.4), 'Abaixo do peso');
      expect(HealthFormulas.bmiCategory(25), 'Sobrepeso');
      expect(HealthFormulas.bmiCategory(41), 'Obesidade grau III');
      expect(HealthFormulas.waistToHeight(waistMeters: 0.84, heightMeters: 1.75), closeTo(0.48, 1e-9));
    });

    test('US Navy (Hodgdon & Beckett): homem e mulher', () {
      expect(
        HealthFormulas.navyBodyFatPercent(sex: BiologicalSex.male, heightCm: 178, neckCm: 38, waistCm: 85),
        closeTo(16.436, 0.001),
      );
      expect(
        HealthFormulas.navyBodyFatPercent(sex: BiologicalSex.female, heightCm: 165, neckCm: 33, waistCm: 75, hipCm: 100),
        closeTo(29.434, 0.001),
      );
      expect(
        () => HealthFormulas.navyBodyFatPercent(sex: BiologicalSex.female, heightCm: 165, neckCm: 33, waistCm: 75),
        throwsArgumentError,
      );
    });
  });

  group('metas do dia', () {
    test('manter, sem atividade: basal × 1,2 e macros dentro das faixas', () {
      final g = computeDailyGoals(man, DayInputs(weightKg: 70, date: day));
      expect(g.basalFormula, 'Mifflin-St Jeor');
      expect(g.basalKcal, closeTo(1648.75, 1e-9));
      expect(g.caloriesKcal, closeTo(1978.5, 1e-9));
      expect(g.proteinGrams, closeTo(98, 1e-9)); // 1,4 g/kg
      expect(g.fatGrams, closeTo(1978.5 * 0.3 / 9, 1e-9));
      expect(g.carbsGrams * 4 + g.proteinGrams * 4 + g.fatGrams * 9, closeTo(1978.5, 1e-6));
      expect(g.warnings, isEmpty);
      expect(g.waterMl, closeTo(2000, 1e-9));
    });

    test('% de gordura informado troca para Katch-McArdle', () {
      final g = computeDailyGoals(man, DayInputs(weightKg: 70, bodyFatFraction: 0.2, date: day));
      expect(g.basalFormula, 'Katch-McArdle');
      expect(g.basalKcal, closeTo(1579.6, 1e-9));
    });

    test('perder 50 g/dia tira 385 kcal; sem atividade a meta para no basal e avisa', () {
      final lose = man.copyWith(objective: Objective.lose, rateGramsPerDay: 50);
      final g = computeDailyGoals(lose, DayInputs(weightKg: 70, date: day));
      expect(g.objectiveAdjustmentKcal, closeTo(-385, 1e-9));
      expect(g.flooredAtBasal, isTrue);
      expect(g.caloriesKcal, closeTo(1648.75, 1e-9));
      expect(g.warnings.first, contains('gasto em repouso'));
      expect(g.proteinGrams, closeTo(112, 1e-9)); // 1,6 g/kg
    });

    test('a meta sobe com passos e exercício do dia', () {
      final lose = man.copyWith(objective: Objective.lose, rateGramsPerDay: 50);
      final g = computeDailyGoals(lose, DayInputs(weightKg: 70, steps: 10000, exerciseKcal: 300, date: day));
      expect(g.flooredAtBasal, isFalse);
      expect(g.caloriesKcal, closeTo(1978.5 - 385 + 294.82 + 300, 0.01));
    });

    test('ganhar soma o superávit; sem teto de ritmo', () {
      final gain = man.copyWith(objective: Objective.gain, rateGramsPerDay: 200);
      final g = computeDailyGoals(gain, DayInputs(weightKg: 70, date: day));
      expect(g.caloriesKcal, closeTo(1978.5 + 1540, 1e-9));
    });

    test('ajuste manual vence o calculado e fica marcado', () {
      final g = computeDailyGoals(
        man,
        DayInputs(weightKg: 70, date: day),
        overrides: const GoalOverrides(caloriesKcal: 2200, waterMl: 3000),
      );
      expect(g.caloriesKcal, 2200);
      expect(g.waterMl, 3000);
      expect(g.manual, {'calories', 'water'});
    });

    test('macro fora da faixa AMDR gera aviso', () {
      final g = computeDailyGoals(man, DayInputs(weightKg: 70, date: day), overrides: const GoalOverrides(proteinGrams: 250));
      expect(g.warnings.any((w) => w.startsWith('Proteína')), isTrue);
    });

    test('bateu a meta: perder ≤, ganhar ≥, manter ±10%', () {
      expect(metCalorieGoal(Objective.lose, consumedKcal: 1800, goalKcal: 1900), isTrue);
      expect(metCalorieGoal(Objective.lose, consumedKcal: 2000, goalKcal: 1900), isFalse);
      expect(metCalorieGoal(Objective.gain, consumedKcal: 3000, goalKcal: 2900), isTrue);
      expect(metCalorieGoal(Objective.maintain, consumedKcal: 2150, goalKcal: 2000), isTrue);
      expect(metCalorieGoal(Objective.maintain, consumedKcal: 2250, goalKcal: 2000), isFalse);
    });
  });

  group('perfil', () {
    test('idade completa na data', () {
      final p = Profile(sex: BiologicalSex.female, birthDate: DateTime(1990, 10, 3), heightMeters: 1.6);
      expect(p.ageOn(DateTime(2026, 10, 2)), 35);
      expect(p.ageOn(DateTime(2026, 10, 3)), 36);
    });

    test('altura fora da faixa é recusada', () {
      expect(() => Profile(sex: BiologicalSex.male, birthDate: DateTime(1990), heightMeters: 3), throwsArgumentError);
    });

    test('repositório guarda perfil, ajustes e preferências', () {
      final repo = ProfileRepository.openInMemory();
      addTearDown(repo.close);
      expect(repo.load(), isNull);
      repo.save(man.copyWith(objective: Objective.lose, rateGramsPerDay: 50, stepsGoal: 9000));
      final back = repo.load()!;
      expect(back.sex, BiologicalSex.male);
      expect(back.birthDate, DateTime(1996, 1, 1));
      expect(back.heightMeters, 1.75);
      expect(back.objective, Objective.lose);
      expect(back.rateGramsPerDay, 50);
      expect(back.stepsGoal, 9000);

      repo.saveOverrides(const GoalOverrides(caloriesKcal: 2100));
      expect(repo.loadOverrides().caloriesKcal, 2100);
      repo.saveOverrides(GoalOverrides.none);
      expect(repo.loadOverrides().caloriesKcal, isNull);

      repo.setSetting('theme_mode', 'dark');
      expect(repo.getSetting('theme_mode'), 'dark');
    });
  });
}
