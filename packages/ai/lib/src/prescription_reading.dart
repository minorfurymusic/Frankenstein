import 'exam_reading.dart';
import 'gemini_client.dart';

/// Um remédio como está escrito na receita. O app só registra o que a
/// receita diz — nada aqui é sugestão de dose (`.claude/rules/brain.md`).
class ReadPrescribedMedicine {
  /// Nome com a concentração, como escrito ("Amoxicilina 500 mg").
  final String name;

  /// Quanto tomar por vez ("1 comprimido" = 1 unidade; "20 gotas").
  final double? doseAmount;

  /// Uma de [prescriptionDoseUnits].
  final String? doseUnit;

  /// `tablet`, `capsule`, `drops`, `liquid`, `injection`, `topical`,
  /// `inhaler` ou `other`.
  final String? form;

  /// A posologia copiada do papel ("1 comprimido de 8 em 8 horas por 7 dias").
  final String? instructions;

  /// 24, 12, 8 ou 6 — só quando a receita diz o intervalo ou as vezes por dia.
  final int? intervalHours;

  /// Dias de tratamento, quando escritos.
  final int? durationDays;

  /// "Uso contínuo" escrito na receita.
  final bool continuous;

  const ReadPrescribedMedicine({
    required this.name,
    this.doseAmount,
    this.doseUnit,
    this.form,
    this.instructions,
    this.intervalHours,
    this.durationDays,
    this.continuous = false,
  });
}

/// O que a IA leu de uma receita. Sempre **estimativa**: a pessoa confere
/// com o papel antes de salvar.
class PrescriptionReading {
  final String? doctor;
  final String? specialty;
  final DateTime? date;

  /// Só quando a validade está escrita; o app não calcula validade.
  final DateTime? validUntil;
  final List<ReadPrescribedMedicine> medicines;
  const PrescriptionReading({this.doctor, this.specialty, this.date, this.validUntil, this.medicines = const []});
}

/// As unidades do cadastro de remédio do app.
const prescriptionDoseUnits = ['mg', 'g', 'mcg', 'ml', 'gotas', 'UI', 'unidade'];
const _forms = ['tablet', 'capsule', 'drops', 'liquid', 'injection', 'topical', 'inhaler', 'other'];
const _intervals = [24, 12, 8, 6];

const prescriptionReadingSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'doctor': {'type': 'string', 'description': 'Nome de quem receitou.'},
    'specialty': {'type': 'string'},
    'date': {'type': 'string', 'description': 'Data da receita, AAAA-MM-DD.'},
    'valid_until': {'type': 'string', 'description': 'Validade escrita na receita, AAAA-MM-DD.'},
    'medicines': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'dose_amount': {'type': 'number'},
          'dose_unit': {'type': 'string', 'enum': prescriptionDoseUnits},
          'form': {'type': 'string', 'enum': _forms},
          'instructions': {'type': 'string'},
          'interval_hours': {'type': 'integer', 'enum': _intervals},
          'duration_days': {'type': 'integer'},
          'continuous': {'type': 'boolean'},
        },
        'required': ['name'],
      },
    },
  },
  'required': ['medicines'],
};

const prescriptionReadingInstruction = '''
Você transcreve receitas médicas (foto ou PDF) para um app de saúde pessoal. Você só copia o que está escrito.
Regras:
- doctor: nome de quem receitou (sem CRM). specialty: se estiver escrita. date: data da receita, AAAA-MM-DD.
- valid_until: SÓ se a validade estiver escrita (data ou "válida por N dias" a partir da data da receita). Não deduza pelo tipo de receita.
- Um item em medicines por remédio. name: nome e concentração como escritos (ex.: "Amoxicilina 500 mg").
- dose_amount e dose_unit: quanto tomar POR VEZ, como escrito: "1 comprimido" ou "1 cápsula" = 1 unidade; "20 gotas" = 20 gotas; "5 ml" = 5 ml. Se não estiver claro, omita. Nunca calcule, ajuste ou complete dose.
- form: comprimido = tablet, cápsula = capsule, gotas = drops, xarope/suspensão/solução oral = liquid, injeção = injection, pomada/creme = topical, bombinha/spray = inhaler, outro = other.
- instructions: a posologia copiada do papel, sem mudar o sentido.
- interval_hours: 24, 12, 8 ou 6, só se a receita disser o intervalo ("de 8 em 8 horas") ou as vezes por dia (3 vezes ao dia = 8). Senão, omita.
- duration_days: só se estiver escrito ("por 7 dias" = 7). continuous: true se estiver escrito "uso contínuo".
- Letra ilegível: deixe o campo de fora em vez de adivinhar.
- Não comente, não interprete e não dê orientação de saúde. Se não for uma receita, devolva medicines vazio.
''';

PrescriptionReading parsePrescriptionReading(Map<String, dynamic> json) {
  String? text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;
  final meds = <ReadPrescribedMedicine>[];
  for (final raw in (json['medicines'] as List? ?? const [])) {
    final m = raw as Map<String, dynamic>;
    final name = text(m['name']);
    if (name == null) continue;
    final amount = (m['dose_amount'] as num?)?.toDouble();
    final unit = m['dose_unit'] as String?;
    final validDose = amount != null && amount.isFinite && amount > 0 && prescriptionDoseUnits.contains(unit);
    final interval = m['interval_hours'] as int?;
    final days = m['duration_days'] as int?;
    meds.add(ReadPrescribedMedicine(
      name: name,
      doseAmount: validDose ? amount : null,
      doseUnit: validDose ? unit : null,
      form: _forms.contains(m['form']) ? m['form'] as String : null,
      instructions: text(m['instructions']),
      intervalHours: _intervals.contains(interval) ? interval : null,
      durationDays: days != null && days > 0 && days <= 366 ? days : null,
      continuous: m['continuous'] == true,
    ));
  }
  final date = parseReadDate(json['date']);
  var validUntil = parseReadDate(json['valid_until']);
  if (date != null && validUntil != null && validUntil.isBefore(date)) validUntil = null;
  return PrescriptionReading(
    doctor: text(json['doctor']),
    specialty: text(json['specialty']),
    date: date,
    validUntil: validUntil,
    medicines: meds,
  );
}

/// Lê uma receita (fotos e/ou PDF anexados pela pessoa).
Future<PrescriptionReading> readPrescription(GeminiClient client, List<AiPart> files) async {
  final json = await client.generateJson(
    system: prescriptionReadingInstruction,
    parts: [...files, const AiPart.text('Transcreva esta receita.')],
    schema: prescriptionReadingSchema,
  );
  return parsePrescriptionReading(json);
}
