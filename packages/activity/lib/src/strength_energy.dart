import 'activity_mets.dart';

/// Gasto da musculação por série, pela carga e pelas repetições — não pelo
/// relógio (ADR-21). Ver `docs/adr/021-gasto-musculacao-por-carga.md`.
///
/// Fonte das retas: Reis VM et al. (2017) "Energy cost of isolated
/// resistance exercises across low- to high-intensities", PLOS ONE
/// 12(7):e0181311 (CC BY 4.0), Tabelas 1 e 2 — gasto (kcal/min, aeróbio +
/// anaeróbio durante o exercício) e carga absoluta (kg) a 12, 16, 20, 24 e
/// 80 % de 1RM, 58 homens treinados (78,67 kg), máquinas, cadência de 4 s
/// por repetição. Reta de mínimos quadrados com os 5 pontos de cada
/// exercício (R² ≥ 0,99): `kcal/min = a + b × carga`.
class StrengthLine {
  final double a;
  final double b;
  const StrengthLine(this.a, this.b);
}

/// Retas por exercício do estudo, ligadas aos exercícios equivalentes da
/// biblioteca do RLT.
const Map<String, StrengthLine> strengthLines = {
  'supino-reto': StrengthLine(2.36, 0.120), // supino horizontal
  'supino-inclinado': StrengthLine(2.70, 0.205), // supino 45°
  'agachamento': StrengthLine(4.20, 0.332), // meio agachamento
  'leg-press': StrengthLine(2.38, 0.072), // leg press 45°
  'cadeira-extensora': StrengthLine(2.86, 0.191),
  'puxada-frente': StrengthLine(2.14, 0.100),
  'rosca-direta': StrengthLine(1.77, 0.220), // rosca Scott com barra W
  'triceps-pulley': StrengthLine(1.93, 0.242),
};

/// Reta geral (sem estudo específico): média das 8 retas acima.
const StrengthLine generalStrengthLine = StrengthLine(2.54, 0.185);

/// Massa média dos participantes do estudo (kg): ajusta a parte do gasto
/// que não depende da carga ao peso da pessoa.
const double _studyBodyMassKg = 78.67;

/// Repouso: 3,5 ml O₂/kg/min × 5 kcal/L (o mesmo fator do estudo) — tirado
/// para o gasto ficar "acima do repouso", como o resto do app (ADR-15).
double _restingKcalPerMin(double bodyKg) => 3.5 * bodyKg * 5 / 1000;

/// Segundos por repetição (2 s descendo + 2 s subindo, cadência do estudo).
const double secondsPerRep = 4;

/// O gasto medido durante a série é só parte do total: na recuperação
/// (EPOC) vai mais. Knausenberger A et al. (2014), Central European Journal
/// of Sport Sciences and Medicine 8: durante o exercício 18 % (aeróbio) +
/// 31 % (anaeróbio), recuperação 51 % → total = durante ÷ 0,49. É isto que
/// faz o descanso não mudar a conta: descansar 1 ou 4 min dá o mesmo.
const double recoveryFactor = 1 / 0.49;

/// Peso do equipamento somado à carga digitada (a pessoa digita a carga
/// total das anilhas/halteres; a barra entra sozinha). Barra olímpica: 20 kg.
const Map<String, double> equipmentKg = {
  'supino-reto': 20,
  'supino-inclinado': 20,
  'agachamento': 20,
  'levantamento-terra': 20,
  'remada-curvada': 20,
  'stiff': 20,
};

/// Exercícios com o peso do corpo: sem carga, a conta usa o MET do
/// Compêndio para funcional moderado (ADR-15) pelo tempo padrão da série.
const Set<String> bodyweightExercises = {
  'flexao',
  'barra-fixa',
  'mergulho',
  'prancha',
  'abdominal-supra',
  'abdominal-infra',
  'burpee',
};

/// Gasto de uma série, em kcal acima do repouso.
double strengthSetKcal({required String exerciseId, required double loadKg, required int reps, required double bodyWeightKg}) {
  if (reps <= 0 || bodyWeightKg <= 0) return 0;
  final minutes = reps * secondsPerRep / 60;
  final load = (loadKg < 0 ? 0.0 : loadKg) + (equipmentKg[exerciseId] ?? 0);
  if (load <= 0) {
    final met = OtherActivity.functional.moderateMet;
    // Tempo padrão da série com o peso do corpo: repetições + 60 s.
    return (met - 1) * bodyWeightKg * (minutes + 1) / 60;
  }
  final line = strengthLines[exerciseId] ?? generalStrengthLine;
  final scale = bodyWeightKg / _studyBodyMassKg;
  final perMin = line.a * scale + line.b * load - _restingKcalPerMin(bodyWeightKg);
  return perMin <= 0 ? 0 : perMin * minutes * recoveryFactor;
}

/// Gasto de um treino: soma das séries.
double strengthSessionKcal(Iterable<({String exerciseId, double loadKg, int reps})> sets, double bodyWeightKg) =>
    sets.fold(0.0, (s, x) => s + strengthSetKcal(exerciseId: x.exerciseId, loadKg: x.loadKg, reps: x.reps, bodyWeightKg: bodyWeightKg));
