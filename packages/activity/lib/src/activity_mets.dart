/// Intensidade escolhida no registro manual de atividade.
enum ActivityIntensity {
  light('Leve'),
  moderate('Moderada'),
  vigorous('Intensa');

  final String label;
  const ActivityIntensity(this.label);
}

/// Atividades da tela "Outras atividades" e o MET de cada intensidade.
///
/// Valores do Compêndio de Atividades Físicas (2024/2011) **conferidos só em
/// fonte secundária** — pacompendium.com bloqueado pela rede no ciclo em que
/// isto foi escrito. NÃO VERIFICADO na fonte primária; ver ADR-15.
enum OtherActivity {
  strength('strength', 'Musculação', 3.5, 5.0, 6.0),
  walking('walking', 'Caminhada', 3.0, 3.8, 4.8),
  running('running', 'Corrida', 7.0, 9.8, 11.5),
  cycling('cycling', 'Bicicleta', 4.0, 8.0, 10.0),
  swimming('swimming', 'Natação', 5.8, 8.3, 9.8),
  soccer('soccer', 'Futebol', 7.0, 7.0, 10.0),
  dance('dance', 'Dança', 3.5, 5.0, 7.3),
  yoga('yoga', 'Yoga e alongamento', 2.5, 3.0, 4.0),
  functional('functional', 'Funcional / HIIT', 4.3, 6.0, 8.0),
  other('other', 'Outra', 3.0, 4.5, 6.0);

  final String code;
  final String label;
  final double lightMet;
  final double moderateMet;
  final double vigorousMet;
  const OtherActivity(this.code, this.label, this.lightMet, this.moderateMet, this.vigorousMet);

  double met(ActivityIntensity i) => switch (i) {
        ActivityIntensity.light => lightMet,
        ActivityIntensity.moderate => moderateMet,
        ActivityIntensity.vigorous => vigorousMet,
      };

  static OtherActivity fromCode(String code) =>
      OtherActivity.values.firstWhere((a) => a.code == code, orElse: () => OtherActivity.other);
}

/// MET de caminhada/corrida pela velocidade média (equações metabólicas do
/// ACSM, terreno plano): caminhada `VO2 = 0,1·v + 3,5`, corrida
/// `VO2 = 0,2·v + 3,5` (v em m/min, VO2 em ml/kg/min); MET = VO2 / 3,5.
/// Abaixo de 100 m/min (6 km/h) usa a de caminhada. O ACSM avisa que a de
/// corrida tende a superestimar.
double acsmMetForSpeed(double metersPerMinute) {
  final vo2 = metersPerMinute < 100 ? 0.1 * metersPerMinute + 3.5 : 0.2 * metersPerMinute + 3.5;
  return vo2 / 3.5;
}

/// Musculação típica (Compêndio 2024: "resistance training, multiple
/// exercises, 8–15 reps", fonte secundária): MET 3,5.
const double strengthTrainingMet = 3.5;
