import 'gemini_client.dart';
import 'plate_estimate.dart';

/// Uma refeição citada na conversa ("comi 3 ovos"), com porção e valores
/// estimados pela IA — sempre estimativa, conferida no cartão.
class ChatMeal {
  /// `breakfast`, `lunch`, `dinner` ou `snack`.
  final String mealType;

  /// Instante em UTC (ISO 8601), quando a pessoa disse quando.
  final String? at;
  final List<PlateItem> items;
  const ChatMeal({required this.mealType, this.at, this.items = const []});
}

/// Um remédio que a pessoa disse ter tomado ou pulado. A dose só vem se a
/// pessoa disse — a IA não completa dose (`.claude/rules/brain.md`).
class ChatDose {
  final String name;
  final double? doseAmount;
  final String? doseUnit;

  /// `taken` ou `skipped`.
  final String status;
  final String? at;
  const ChatDose({required this.name, this.doseAmount, this.doseUnit, this.status = 'taken', this.at});
}

/// O que a IA entendeu de uma mensagem livre no Cérebro. Cada registro vira
/// um cartão de proposta; nada é gravado aqui.
class ChatReading {
  /// Resposta curta (pergunta quando falta algo, ou recusa educada).
  final String? reply;

  /// A mensagem descreve algo que pede atenção profissional (ex.: dor no
  /// peito, falta de ar). O app mostra o aviso fixo dele, não um texto da IA.
  final bool seekCare;
  /// Já no formato dos parâmetros de `log_water`.
  final List<Map<String, dynamic>> water;
  final List<ChatMeal> meals;
  final List<ChatDose> doses;

  /// Já no formato dos parâmetros de `log_symptom`, `log_vital_sign` e
  /// `log_body_measurement` (com `at` em UTC).
  final List<Map<String, dynamic>> symptoms;
  final List<Map<String, dynamic>> vitalSigns;
  final List<Map<String, dynamic>> bodyMeasurements;

  /// Perguntas sobre os próprios dados que o app responde **localmente**
  /// (`daily_summary`, `steps`, `medication_agenda`) — o dado não vai à IA.
  final List<String> questions;

  const ChatReading({
    this.reply,
    this.seekCare = false,
    this.water = const [],
    this.meals = const [],
    this.doses = const [],
    this.symptoms = const [],
    this.vitalSigns = const [],
    this.bodyMeasurements = const [],
    this.questions = const [],
  });

  bool get isEmpty =>
      water.isEmpty &&
      meals.isEmpty &&
      doses.isEmpty &&
      symptoms.isEmpty &&
      vitalSigns.isEmpty &&
      bodyMeasurements.isEmpty &&
      questions.isEmpty;
}

const _at = {'type': 'string', 'description': 'ISO 8601 com fuso, ex.: 2026-10-05T09:00:00-03:00. Omita se a pessoa não disse quando.'};

const chatReadingSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'reply': {'type': 'string'},
    'seek_care': {'type': 'boolean'},
    'water': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {'amount_ml': {'type': 'number'}, 'at': _at},
        'required': ['amount_ml'],
      },
    },
    'meals': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'meal_type': {
            'type': 'string',
            'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
          },
          'at': _at,
          'items': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'grams': {'type': 'number'},
                'kcal': {'type': 'number'},
                'protein_g': {'type': 'number'},
                'carbs_g': {'type': 'number'},
                'fat_g': {'type': 'number'},
              },
              'required': ['name', 'grams', 'kcal'],
            },
          },
        },
        'required': ['meal_type', 'items'],
      },
    },
    'medication_doses': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'dose_amount': {'type': 'number'},
          'dose_unit': {'type': 'string'},
          'status': {
            'type': 'string',
            'enum': ['taken', 'skipped'],
          },
          'at': _at,
        },
        'required': ['name', 'status'],
      },
    },
    'symptoms': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'intensity': {'type': 'integer'},
          'at': _at,
          'notes': {'type': 'string'},
        },
        'required': ['name'],
      },
    },
    'vital_signs': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['blood_pressure', 'glucose', 'temperature', 'spo2', 'heart_rate'],
          },
          'systolic_mmhg': {'type': 'number'},
          'diastolic_mmhg': {'type': 'number'},
          'glucose_mg_dl': {'type': 'number'},
          'glucose_context': {'type': 'string'},
          'celsius': {'type': 'number'},
          'spo2_percent': {'type': 'number'},
          'bpm': {'type': 'integer'},
          'at': _at,
        },
        'required': ['kind'],
      },
    },
    'body_measurements': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['weight', 'body_fat', 'waist', 'hip', 'chest', 'neck', 'arm', 'thigh', 'calf'],
          },
          'value': {'type': 'number'},
          'at': _at,
        },
        'required': ['kind', 'value'],
      },
    },
    'questions': {
      'type': 'array',
      'items': {
        'type': 'string',
        'enum': ['daily_summary', 'steps', 'medication_agenda'],
      },
    },
  },
  'required': ['reply'],
};

const chatReadingInstruction = '''
Você é o Cérebro do RLT, um app de saúde pessoal no Brasil. Você só ANOTA o que a pessoa conta; o app mostra cada anotação num cartão e a pessoa confirma antes de salvar.
Regras:
- Separe cada coisa num item próprio: "bebi 2 L de água, comi 3 ovos e tomei dipirona às 9h" = 1 água + 1 refeição + 1 remédio.
- Água em mililitros (1 copo = 250 ml, 1 garrafa pequena = 500 ml, 1 L = 1000 ml).
- Refeição: um item por alimento, com gramas estimadas pela quantidade dita (1 ovo ≈ 50 g) e kcal, protein_g, carbs_g e fat_g estimados para essas gramas. meal_type pelo que a pessoa disse ou pela hora.
- Remédio: copie o nome e, SÓ se a pessoa disse, a dose e a unidade. Nunca complete, sugira ou corrija dose. "Esqueci/pulei" = skipped.
- Sintoma: nome curto; intensidade de 0 a 10 só se a pessoa deu. Não interprete nem dê diagnóstico.
- Sinais vitais: pressão "12 por 8" = 120/80 mmHg; temperatura em °C; glicemia em mg/dL; saturação em %; frequência em bpm.
- Medidas: peso em kg, gordura em %, circunferências em cm.
- at: use a hora que a pessoa disse, no fuso dela (veja "Agora"). "Às 9h" de hoje que ainda não chegou = ontem. Sem hora dita, omita.
- Perguntas sobre os próprios dados ("quantos passos dei?", "resumo do dia", "que remédios tenho hoje?") vão em questions; não responda você.
- Nunca diagnostique, prescreva ou recomende remédio, dose, dieta ou tratamento. Se pedirem, diga em reply que o app só registra e que um profissional pode orientar.
- seek_care = true se a pessoa descreve algo que pede atenção profissional rápida (dor no peito, falta de ar, desmaio, sangramento forte, pensamentos de se machucar, febre muito alta, pressão ou glicemia muito altas ou baixas).
- reply: uma frase curta em português. Se faltar algo essencial para registrar, pergunte. Não repita os valores dos itens.
''';

String? _iso(Object? raw) {
  if (raw is! String) return null;
  final d = DateTime.tryParse(raw.trim());
  return d?.toUtc().toIso8601String();
}

double? _pos(Object? v) {
  if (v is! num) return null;
  final d = v.toDouble();
  return d.isFinite && d > 0 ? d : null;
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v.trim() : null;

ChatReading parseChatReading(Map<String, dynamic> json) {
  List<Map<String, dynamic>> list(String key) => [for (final e in (json[key] as List? ?? const [])) e as Map<String, dynamic>];


  final meals = <ChatMeal>[];
  for (final m in list('meals')) {
    final items = <PlateItem>[];
    for (final i in (m['items'] as List? ?? const []).cast<Map<String, dynamic>>()) {
      final name = _text(i['name']);
      final grams = _pos(i['grams']);
      final kcal = (i['kcal'] as num?)?.toDouble();
      if (name == null || grams == null || kcal == null || !kcal.isFinite || kcal < 0) continue;
      double g(String k) => _pos(i[k]) ?? 0;
      items.add(PlateItem(name: name, grams: grams, kcal: kcal, proteinGrams: g('protein_g'), carbsGrams: g('carbs_g'), fatGrams: g('fat_g')));
    }
    if (items.isEmpty) continue;
    meals.add(ChatMeal(mealType: m['meal_type'] as String, at: _iso(m['at']), items: items));
  }

  final doses = <ChatDose>[];
  for (final d in list('medication_doses')) {
    final name = _text(d['name']);
    if (name == null) continue;
    final amount = _pos(d['dose_amount']);
    final unit = _text(d['dose_unit']);
    doses.add(ChatDose(
      name: name,
      // Dose só vale inteira (número e unidade); meia dose é descartada.
      doseAmount: unit == null ? null : amount,
      doseUnit: amount == null ? null : unit,
      status: d['status'] as String,
      at: _iso(d['at']),
    ));
  }

  Map<String, dynamic> withAt(Map<String, dynamic> raw, Iterable<String> keys) {
    final out = <String, dynamic>{
      for (final k in keys)
        if (raw[k] != null && !(raw[k] is String && (raw[k] as String).trim().isEmpty)) k: raw[k],
    };
    final at = _iso(raw['at']);
    if (at != null) out['at'] = at;
    return out;
  }

  final symptoms = [
    for (final s in list('symptoms'))
      if (_text(s['name']) != null) withAt(s, const ['name', 'intensity', 'notes']),
  ];
  final vitals = [
    for (final v in list('vital_signs'))
      withAt(v, const ['kind', 'systolic_mmhg', 'diastolic_mmhg', 'glucose_mg_dl', 'glucose_context', 'celsius', 'spo2_percent', 'bpm']),
  ];
  final body = [
    for (final b in list('body_measurements'))
      if (_pos(b['value']) != null) withAt(b, const ['kind', 'value']),
  ];

  return ChatReading(
    reply: _text(json['reply']),
    seekCare: json['seek_care'] == true,
    water: [
      for (final w in list('water'))
        if (_pos(w['amount_ml']) != null) withAt(w, const ['amount_ml']),
    ],
    meals: meals,
    doses: doses,
    symptoms: symptoms,
    vitalSigns: vitals,
    bodyMeasurements: body,
    questions: [for (final q in (json['questions'] as List? ?? const [])) q as String],
  );
}

/// "2026-10-05T14:30:00-03:00 (domingo)" — a IA precisa de agora e do fuso
/// para transformar "às 9h" em instante.
String describeNow(DateTime local) {
  String two(int v) => v.toString().padLeft(2, '0');
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final abs = off.abs();
  const days = ['segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  return '${local.year}-${two(local.month)}-${two(local.day)}T${two(local.hour)}:${two(local.minute)}:00'
      '$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)} (${days[local.weekday - 1]})';
}

/// Envia **só o texto que a pessoa escreveu** e a hora atual — nenhum dado
/// guardado vai junto (`.claude/rules/brain.md`).
Future<ChatReading> readChatMessage(GeminiClient client, String text, {required DateTime now}) async {
  final json = await client.generateJson(
    system: chatReadingInstruction,
    parts: [AiPart.text('Agora: ${describeNow(now)}\nMensagem: $text')],
    schema: chatReadingSchema,
  );
  return parseChatReading(json);
}
