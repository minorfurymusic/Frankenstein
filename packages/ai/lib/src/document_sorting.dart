import 'exam_reading.dart';
import 'gemini_client.dart';

/// Tipo de um arquivo anexado ao Cérebro (ADR-19).
enum SortedKind {
  plate,
  prescription,
  exam,
  mealPlan('meal_plan'),
  workoutPlan('workout_plan'),
  medicalHistory('medical_history'),
  other;

  final String? _wire;
  const SortedKind([this._wire]);
  String get wireValue => _wire ?? name;

  static SortedKind fromWire(Object? v) => SortedKind.values.firstWhere((k) => k.wireValue == v, orElse: () => SortedKind.other);
}

/// Um arquivo já separado: o tipo e, para "outro", o que a IA viu.
class SortedFile {
  final int index;
  final SortedKind kind;
  final String? description;
  const SortedFile(this.index, this.kind, {this.description});
}

/// Medidas escritas no documento (ex.: ficha do nutricionista).
class ReadBodyFacts {
  final double? weightKg;
  final double? heightCm;
  final double? bodyFatPercent;
  final DateTime? date;
  const ReadBodyFacts({this.weightKg, this.heightCm, this.bodyFatPercent, this.date});
  bool get isEmpty => weightKg == null && heightCm == null && bodyFatPercent == null;
}

/// Item de histórico escrito no documento — nunca deduzido de remédio.
class ReadHistoryFact {
  /// `condition`, `allergy`, `surgery`, `vaccine` ou `appointment`.
  final String kind;
  final String title;
  final DateTime? date;
  final String? professional;
  const ReadHistoryFact({required this.kind, required this.title, this.date, this.professional});
}

class DocumentSorting {
  final List<SortedFile> files;
  final ReadBodyFacts body;
  final List<ReadHistoryFact> history;
  const DocumentSorting({this.files = const [], this.body = const ReadBodyFacts(), this.history = const []});
}

const historyFactKinds = ['condition', 'allergy', 'surgery', 'vaccine', 'appointment'];

const documentSortingSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'files': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'index': {'type': 'integer'},
          'kind': {
            'type': 'string',
            'enum': ['plate', 'prescription', 'exam', 'meal_plan', 'workout_plan', 'medical_history', 'other'],
          },
          'description': {'type': 'string'},
        },
        'required': ['index', 'kind'],
      },
    },
    'body': {
      'type': 'object',
      'properties': {
        'weight_kg': {'type': 'number'},
        'height_cm': {'type': 'number'},
        'body_fat_percent': {'type': 'number'},
        'date': {'type': 'string', 'description': 'AAAA-MM-DD'},
      },
    },
    'history': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'kind': {'type': 'string', 'enum': historyFactKinds},
          'title': {'type': 'string'},
          'date': {'type': 'string', 'description': 'AAAA-MM-DD'},
          'professional': {'type': 'string'},
        },
        'required': ['kind', 'title'],
      },
    },
  },
  'required': ['files'],
};

const documentSortingInstruction = '''
Você separa os arquivos que uma pessoa mandou para um app de saúde pessoal. Cada arquivo vem depois de "Arquivo N:".

Para cada arquivo, devolva em files o index N e o kind:
- plate: foto de comida ou bebida para comer agora.
- prescription: receita médica.
- exam: resultado de exame (laboratório, imagem, laudo).
- meal_plan: plano alimentar ou dieta de nutricionista.
- workout_plan: ficha ou plano de treino de academia.
- medical_history: relatório, resumo ou histórico médico (doenças, alergias, cirurgias, vacinas, consultas).
- other: qualquer outra coisa (print de tela, paisagem, documento não relacionado). Em description, diga em uma frase curta, em português, o que é.

Além disso, transcreva SÓ o que estiver escrito nos documentos:
- body: peso (kg), altura (cm) e % de gordura da própria pessoa, com a data se houver.
- history: condições ou diagnósticos, alergias, cirurgias, vacinas e consultas escritos (ex.: "Comorbidades: hipertensão"), com data e profissional quando houver.

Regras:
- Nunca deduza doença a partir de remédio ou exame (enalapril não vira hipertensão; glicose alta não vira diabetes).
- Não comente, não interprete e não dê orientação de saúde. Na dúvida, deixe de fora.
''';

double? _num(Object? v, double min, double max) {
  if (v is! num) return null;
  final d = v.toDouble();
  return d.isFinite && d >= min && d <= max ? d : null;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

DocumentSorting parseDocumentSorting(Map<String, dynamic> json, int fileCount) {
  final files = <int, SortedFile>{};
  for (final raw in (json['files'] as List? ?? const [])) {
    final f = raw as Map<String, dynamic>;
    final i = f['index'];
    if (i is! int || i < 1 || i > fileCount) continue;
    files[i] = SortedFile(i, SortedKind.fromWire(f['kind']), description: _text(f['description']));
  }
  final body = (json['body'] as Map?)?.cast<String, dynamic>() ?? const {};
  var height = _num(body['height_cm'], 0.5, 260);
  if (height != null && height < 3) height *= 100; // escrito em metros
  if (height != null && height < 50) height = null;
  return DocumentSorting(
    files: [for (var i = 1; i <= fileCount; i++) files[i] ?? SortedFile(i, SortedKind.other)],
    body: ReadBodyFacts(
      weightKg: _num(body['weight_kg'], 20, 400),
      heightCm: height,
      bodyFatPercent: _num(body['body_fat_percent'], 2, 75),
      date: parseReadDate(body['date']),
    ),
    history: [
      for (final raw in (json['history'] as List? ?? const []))
        if (historyFactKinds.contains((raw as Map)['kind']) && _text(raw['title']) != null)
          ReadHistoryFact(
            kind: raw['kind'] as String,
            title: _text(raw['title'])!,
            date: parseReadDate(raw['date']),
            professional: _text(raw['professional']),
          ),
    ],
  );
}

/// Separa os arquivos anexados (ADR-19): uma chamada com todos eles.
///
/// [note]: o que a pessoa escreveu junto (ajuda a entender o arquivo).
Future<DocumentSorting> sortDocuments(GeminiClient client, List<AiPart> files, {String note = ''}) async {
  final json = await client.generateJson(
    system: documentSortingInstruction,
    parts: [
      for (var i = 0; i < files.length; i++) ...[AiPart.text('Arquivo ${i + 1}:'), files[i]],
      AiPart.text(note.trim().isEmpty ? 'Separe estes arquivos.' : 'Separe estes arquivos. A pessoa disse: "${note.trim()}".'),
    ],
    schema: documentSortingSchema,
  );
  return parseDocumentSorting(json, files.length);
}
