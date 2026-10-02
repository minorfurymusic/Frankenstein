/// Conversões entre a unidade clínica usada na tela/conversa e a unidade SI
/// gravada no banco (`.claude/rules/00-inviolaveis.md`: "Unidades sempre em
/// SI"). O banco nunca guarda mmHg ou mg/dL; a tela nunca mostra kPa ou mmol/L
/// se o usuário não pedir.
library;

/// 1 mmHg = 133,322387415 Pa (definição convencional do milímetro de mercúrio).
const double _kpaPerMmHg = 0.133322387415;

/// Massa molar da glicose: 180,156 g/mol → 1 mmol/L = 18,0156 mg/dL.
const double _mgDlPerMmolL = 18.0156;

double mmHgToKpa(double mmHg) => mmHg * _kpaPerMmHg;
double kpaToMmHg(double kpa) => kpa / _kpaPerMmHg;

double glucoseMgDlToMmolL(double mgDl) => mgDl / _mgDlPerMmolL;
double glucoseMmolLToMgDl(double mmolL) => mmolL * _mgDlPerMmolL;

double centimetersToMeters(double cm) => cm / 100.0;
double metersToCentimeters(double m) => m * 100.0;

double percentToFraction(double percent) => percent / 100.0;
double fractionToPercent(double fraction) => fraction * 100.0;
