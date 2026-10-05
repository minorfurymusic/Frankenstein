import 'gemini_client.dart';

/// Um valor lido do laudo, como está escrito (ADR-16: unidade e faixa do
/// laboratório, sem conversão).
class ReadMarker {
  final String name;
  final double value;
  final String unit;
  final double? referenceLow;
  final double? referenceHigh;
  const ReadMarker({required this.name, required this.value, required this.unit, this.referenceLow, this.referenceHigh});
}

/// O que a IA leu de um exame. Sempre **estimativa**: a pessoa confere com
/// o papel antes de salvar (`.claude/rules/brain.md`).
class ExamReading {
  final String? title;
  final DateTime? date;

  /// `blood`, `image`, `urine` ou `other` (as categorias da tela Exames).
  final String? category;
  final List<ReadMarker> markers;
  const ExamReading({this.title, this.date, this.category, this.markers = const []});
}

const examReadingSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'title': {'type': 'string', 'description': 'Nome do exame como aparece no laudo (ex.: Hemograma completo).'},
    'date': {'type': 'string', 'description': 'Data da coleta ou do resultado, AAAA-MM-DD.'},
    'category': {
      'type': 'string',
      'enum': ['blood', 'image', 'urine', 'other'],
    },
    'markers': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'value': {'type': 'number'},
          'unit': {'type': 'string'},
          'reference_low': {'type': 'number'},
          'reference_high': {'type': 'number'},
        },
        'required': ['name', 'value', 'unit'],
      },
    },
  },
  'required': ['markers'],
};

const examReadingInstruction = '''
Você transcreve laudos de exames (foto ou PDF) para um app de saúde pessoal.
Regras:
- Copie cada resultado numérico com o nome, o valor e a UNIDADE exatamente como estão no laudo. Não converta unidades.
- Use ponto como separador decimal no JSON (5,9 no laudo = 5.9). Ignore separador de milhar (4.500 no laudo = 4500).
- Se o laudo trouxer a faixa de referência do laboratório para aquele valor, preencha reference_low e/ou reference_high. Não invente faixa.
- Resultado que não é número (ex.: "Negativo", "Ausente") fica de fora.
- Não interprete: não diga se está alto, baixo, normal ou alterado, e não dê diagnóstico.
- title: o nome do exame. date: a data da coleta (ou do resultado), no formato AAAA-MM-DD.
- category: blood (sangue), urine (urina), image (imagem, como ultrassom, raio-x, tomografia) ou other.
- Se o documento não for um exame, devolva markers vazio.
''';

/// "AAAA-MM-DD" lido de um documento; data impossível (2026-02-31) é
/// descartada em vez de virar outra.
DateTime? parseReadDate(Object? raw) {
  if (raw is! String) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(raw.trim());
  if (m == null) return null;
  final d = DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  return d.month == int.parse(m[2]!) && d.day == int.parse(m[3]!) ? d : null;
}

ExamReading parseExamReading(Map<String, dynamic> json) {
  final date = parseReadDate(json['date']);
  final markers = <ReadMarker>[];
  for (final item in (json['markers'] as List? ?? const [])) {
    final m = item as Map<String, dynamic>;
    final name = (m['name'] as String).trim();
    final value = (m['value'] as num).toDouble();
    if (name.isEmpty || !value.isFinite) continue;
    var low = (m['reference_low'] as num?)?.toDouble();
    var high = (m['reference_high'] as num?)?.toDouble();
    if (low != null && high != null && high < low) {
      low = null;
      high = null;
    }
    markers.add(ReadMarker(name: name, value: value, unit: (m['unit'] as String).trim(), referenceLow: low, referenceHigh: high));
  }
  final title = (json['title'] as String?)?.trim();
  return ExamReading(
    title: title == null || title.isEmpty ? null : title,
    date: date,
    category: json['category'] as String?,
    markers: markers,
  );
}

/// Lê um exame (fotos e/ou PDF anexados pela pessoa).
Future<ExamReading> readExam(GeminiClient client, List<AiPart> files) async {
  final json = await client.generateJson(
    system: examReadingInstruction,
    parts: [...files, const AiPart.text('Transcreva os resultados deste exame.')],
    schema: examReadingSchema,
  );
  return parseExamReading(json);
}
