import 'dart:io';

import 'package:frankstein_profile/profile.dart';
import 'package:sqlite3/sqlite3.dart';
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
      expect(g.proteinGrams, closeTo(56, 1e-9)); // 0,8 g/kg (não treina)
      expect(g.fatGrams, closeTo(1978.5 * 0.3 / 9, 1e-9));
      expect(g.carbsGrams * 4 + g.proteinGrams * 4 + g.fatGrams * 9, closeTo(1978.5, 1e-6));
      expect(g.fiberGrams, closeTo(14 * 1.9785, 1e-9)); // 27,7 g
      expect(g.waterMl, closeTo(2000, 1e-9));
      expect(g.belowBasal, isFalse);
    });

    test('% de gordura informado troca para Katch-McArdle', () {
      final g = computeDailyGoals(man, DayInputs(weightKg: 70, bodyFatFraction: 0.2, date: day));
      expect(g.basalFormula, 'Katch-McArdle');
      expect(g.basalKcal, closeTo(1579.6, 1e-9));
    });

    test('perder 50 g/dia tira 385 kcal, mesmo abaixo do gasto em repouso (sem trava)', () {
      final lose = man.copyWith(objective: Objective.lose, rateGramsPerDay: 50);
      final g = computeDailyGoals(lose, DayInputs(weightKg: 70, date: day));
      expect(g.objectiveAdjustmentKcal, closeTo(-385, 1e-9));
      expect(g.caloriesKcal, closeTo(1978.5 - 385, 1e-9));
      expect(g.belowBasal, isTrue); // só informação
      expect(g.proteinGrams, closeTo(84, 1e-9)); // 1,2 g/kg
      expect(g.fiberGrams, 25); // piso EFSA
    });

    test('ritmo enorme não deixa a meta negativa', () {
      final lose = man.copyWith(objective: Objective.lose, rateGramsPerDay: 1000);
      expect(computeDailyGoals(lose, DayInputs(weightKg: 70, date: day)).caloriesKcal, 0);
    });

    test('proteína: academia e "quero mais proteína" sobem a meta; dieta baixa o carboidrato', () {
      expect(HealthFormulas.proteinPerKg(Objective.maintain), 0.8);
      expect(HealthFormulas.proteinPerKg(Objective.lose), 1.2);
      expect(HealthFormulas.proteinPerKg(Objective.maintain, strengthTraining: true), 1.6);
      expect(HealthFormulas.proteinPerKg(Objective.gain, strengthTraining: true), 1.8);
      expect(HealthFormulas.proteinPerKg(Objective.lose, strengthTraining: true), 2.0);
      expect(HealthFormulas.proteinPerKg(Objective.lose, strengthTraining: true, highProtein: true), closeTo(2.4, 1e-9));

      final keep = computeDailyGoals(man.copyWith(strengthTraining: true), DayInputs(weightKg: 70, date: day));
      final diet = computeDailyGoals(
        man.copyWith(strengthTraining: true, objective: Objective.lose, rateGramsPerDay: 50),
        DayInputs(weightKg: 70, date: day),
      );
      expect(diet.proteinGrams, greaterThan(keep.proteinGrams));
      expect(diet.carbsGrams, lessThan(keep.carbsGrams));
      expect(keep.carbsGrams - diet.carbsGrams, greaterThan(keep.fatGrams - diet.fatGrams)); // carbo cai mais que gordura
    });

    test('a meta sobe com passos e exercício do dia', () {
      final lose = man.copyWith(objective: Objective.lose, rateGramsPerDay: 50);
      final g = computeDailyGoals(lose, DayInputs(weightKg: 70, steps: 10000, exerciseKcal: 300, date: day));
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

    test('frações das calorias por macro somam 100%', () {
      final g = computeDailyGoals(man, DayInputs(weightKg: 70, date: day));
      expect(g.proteinShare + g.fatShare + g.carbsShare, closeTo(1, 1e-9));
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
      repo.save(man.copyWith(objective: Objective.lose, rateGramsPerDay: 50, stepsGoal: 9000, strengthTraining: true));
      final back = repo.load()!;
      expect(back.sex, BiologicalSex.male);
      expect(back.birthDate, DateTime(1996, 1, 1));
      expect(back.heightMeters, 1.75);
      expect(back.objective, Objective.lose);
      expect(back.rateGramsPerDay, 50);
      expect(back.stepsGoal, 9000);
      expect(back.strengthTraining, isTrue);
      expect(back.highProtein, isFalse);

      repo.saveOverrides(const GoalOverrides(caloriesKcal: 2100));
      expect(repo.loadOverrides().caloriesKcal, 2100);
      repo.saveOverrides(GoalOverrides.none);
      expect(repo.loadOverrides().caloriesKcal, isNull);
      expect(repo.loadOverrides().sleepGoalMinutes, 480);
      repo.saveOverrides(const GoalOverrides(sleepMinutes: 450));
      expect(repo.loadOverrides().sleepGoalMinutes, 450);

      repo.setSetting('theme_mode', 'dark');
      expect(repo.getSetting('theme_mode'), 'dark');
    });
  });

  group('peso desejado (ADR-17)', () {
    final day = DateTime(2026, 10, 5);
    final p = Profile(
      sex: BiologicalSex.female,
      birthDate: DateTime(1990, 1, 1),
      heightMeters: 1.65,
      objective: Objective.gain, // escolhido à mão; o peso desejado manda
      rateGramsPerDay: 50,
      targetWeightKg: 60,
    );

    test('objetivo segue o peso: acima perde, dentro de ±1 kg mantém, abaixo ganha', () {
      expect(p.effectiveObjective(70), Objective.lose);
      expect(p.effectiveObjective(61), Objective.maintain);
      expect(p.effectiveObjective(59.2), Objective.maintain);
      expect(p.effectiveObjective(58.5), Objective.gain);
      expect(p.copyWith(clearTargetWeight: true).effectiveObjective(70), Objective.gain);
      expect(p.reachedTarget(60.8), isTrue);
      expect(p.reachedTarget(62), isFalse);
    });

    test('metas usam o objetivo efetivo: déficit e proteína de quem perde; manutenção ao chegar', () {
      final losing = computeDailyGoals(p, DayInputs(weightKg: 70, date: day));
      expect(losing.objective, Objective.lose);
      expect(losing.objectiveAdjustmentKcal, closeTo(-50 * HealthFormulas.kcalPerGramBodyWeight, 1e-9));
      expect(losing.proteinPerKg, HealthFormulas.proteinPerKg(Objective.lose));
      final arrived = computeDailyGoals(p, DayInputs(weightKg: 60.5, date: day));
      expect(arrived.objective, Objective.maintain);
      expect(arrived.objectiveAdjustmentKcal, 0);
      expect(arrived.targetReached, isTrue);
    });

    test('previsão: diferença em gramas ÷ ritmo; nada sem ritmo ou já na faixa', () {
      final proj = projectTargetWeight(p, currentWeightKg: 66, from: day)!;
      expect(proj.days, 120); // 6000 g ÷ 50 g/dia
      expect(proj.weeks, 18);
      expect(proj.date, DateTime(2026, 10, 5).add(const Duration(days: 120)));
      expect(projectTargetWeight(p.copyWith(rateGramsPerDay: 0), currentWeightKg: 66, from: day), isNull);
      expect(projectTargetWeight(p, currentWeightKg: 60.4, from: day), isNull);
      expect(() => p.copyWith(targetWeightKg: 10), throwsArgumentError);
    });

    test('guarda e lê o peso desejado; banco antigo ganha a coluna', () {
      final dir = Directory.systemTemp.createTempSync('rlt_profile_target');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/profile.sqlite3';
      final old = sqlite3.open(path);
      old.execute('''
CREATE TABLE profile (
  id INTEGER PRIMARY KEY CHECK (id = 1), sex TEXT NOT NULL, birth_date TEXT NOT NULL, height_m REAL NOT NULL,
  objective TEXT NOT NULL, rate_g_per_day REAL NOT NULL, steps_goal INTEGER NOT NULL,
  strength_training INTEGER NOT NULL DEFAULT 0, high_protein INTEGER NOT NULL DEFAULT 0
);''');
      old.execute("INSERT INTO profile VALUES (1, 'male', '1985-03-02', 1.8, 'lose', 40, 9000, 1, 0)");
      old.dispose();
      final repo = ProfileRepository.open(path);
      addTearDown(repo.close);
      final loaded = repo.load()!;
      expect(loaded.targetWeightKg, isNull);
      expect(loaded.strengthTraining, isTrue);
      repo.save(loaded.copyWith(targetWeightKg: 78.5));
      expect(repo.load()!.targetWeightKg, 78.5);
      repo.save(repo.load()!.copyWith(clearTargetWeight: true));
      expect(repo.load()!.targetWeightKg, isNull);
    });
  });
}
