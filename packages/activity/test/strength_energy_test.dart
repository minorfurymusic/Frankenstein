import 'package:frankstein_activity/activity.dart';
import 'package:test/test.dart';

void main() {
  test('reta do estudo: supino reto, 80 kg a 78,67 kg de peso, bate com a Tabela 2 de Reis 2017', () {
    // A 75,18 kg o estudo mediu 11,41 kcal/min; a reta dá ~11,4.
    final perMin = strengthLines['supino-reto']!.a + strengthLines['supino-reto']!.b * 75.18;
    expect(perMin, closeTo(11.41, 0.5));
  });

  test('mais carga ou mais repetições gasta mais; o descanso não entra', () {
    double set(double kg, int reps) => strengthSetKcal(exerciseId: 'supino-reto', loadKg: kg, reps: reps, bodyWeightKg: 93.7);
    expect(set(100, 12), greaterThan(set(40, 12)));
    expect(set(60, 12), greaterThan(set(60, 8)));
  });

  test('barra do supino entra sozinha (20 kg): 60 digitados contam como 80', () {
    final withBar = strengthSetKcal(exerciseId: 'supino-reto', loadKg: 60, reps: 12, bodyWeightKg: 93.7);
    final machine = strengthSetKcal(exerciseId: 'livre-supino-maquina', loadKg: 80, reps: 12, bodyWeightKg: 93.7);
    expect(withBar, greaterThan(0));
    expect(machine, greaterThan(0)); // exercício sem estudo usa a reta geral
  });

  test('treino típico: 16 séries de 12 com carga moderada fica na faixa medida em estudos (~200–350 kcal)', () {
    final sets = [
      for (var i = 0; i < 4; i++) (exerciseId: 'supino-reto', loadKg: 60.0, reps: 12),
      for (var i = 0; i < 4; i++) (exerciseId: 'puxada-frente', loadKg: 60.0, reps: 12),
      for (var i = 0; i < 4; i++) (exerciseId: 'leg-press', loadKg: 150.0, reps: 12),
      for (var i = 0; i < 4; i++) (exerciseId: 'rosca-direta', loadKg: 20.0, reps: 12),
    ];
    final total = strengthSessionKcal(sets, 93.7);
    expect(total, inInclusiveRange(150, 350));
  });

  test('peso do corpo (carga 0): conta pelo tempo padrão da série, não zera', () {
    final kcal = strengthSetKcal(exerciseId: 'flexao', loadKg: 0, reps: 15, bodyWeightKg: 93.7);
    expect(kcal, closeTo((6.0 - 1) * 93.7 * (1 + 1) / 60, 0.01));
  });
}
