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

/// Um exercício de academia que a pessoa disse ter feito ("3 séries de
/// supino com 30 kg, 10 repetições"). O app casa o nome com a biblioteca de
/// exercícios no aparelho.
class ChatWorkout {
  final String exercise;
  final int sets;
  final int reps;
  final double loadKg;
  final String? at;
  const ChatWorkout({required this.exercise, required this.sets, required this.reps, this.loadKg = 0, this.at});
}

/// Um remédio novo que a pessoa disse que começou a tomar, **com** dose e
/// horários ditos por ela — sem isso, a IA pergunta em vez de cadastrar.
class ChatNewMedication {
  final String name;
  final double doseAmount;
  final String doseUnit;

  /// "HH:MM".
  final List<String> times;

  /// Desde quando toma ("AAAA-MM-DD"), só se a pessoa disse.
  final String? startDate;
  const ChatNewMedication({required this.name, required this.doseAmount, required this.doseUnit, required this.times, this.startDate});
}

/// O que a IA entendeu de uma mensagem livre no Cérebro. Cada registro vira
/// um cartão de proposta; nada é gravado aqui.
class ChatReading {
  /// Resposta curta (pergunta quando falta algo, ou recusa educada).
  final String? reply;

  /// Mensagem de voz: o que a pessoa falou, como a IA ouviu — o app mostra
  /// para ela conferir.
  final String? transcript;

  /// A mensagem descreve algo que pede atenção profissional (ex.: dor no
  /// peito, falta de ar). O app mostra o aviso fixo dele, não um texto da IA.
  final bool seekCare;
  /// Já no formato dos parâmetros de `log_water`.
  final List<Map<String, dynamic>> water;
  final List<ChatMeal> meals;
  final List<ChatDose> doses;
  final List<ChatWorkout> workouts;
  final List<ChatNewMedication> newMedications;

  /// Respostas curtas para tocar (ex.: horários "08:00", "20:00"); o app
  /// descarta qualquer uma que pareça dose.
  final List<String> suggestions;

  /// Já no formato dos parâmetros de `log_symptom`, `log_vital_sign` e
  /// `log_body_measurement` (com `at` em UTC).
  final List<Map<String, dynamic>> symptoms;
  final List<Map<String, dynamic>> vitalSigns;
  final List<Map<String, dynamic>> bodyMeasurements;

  /// Pedidos de troca no plano de refeições ou na ficha de treino (ADR-26):
  /// `plan` (`meal` ou `workout`), `item`, e `replacement`/`meal_type` se ditos.
  final List<Map<String, dynamic>> planSwaps;

  /// Atividades contadas sem gravar ("caminhei 700 m", "brinquei 1 hora"):
  /// `activity`, `label`, `minutes`, `distance_m`, `effort` (1–10), `at`.
  final List<Map<String, dynamic>> activities;

  /// Humor que a pessoa contou ("tô muito pra baixo"), já no formato de
  /// `log_mood` — vira cartão, só salva se ela confirmar (ADR-23/27).
  final Map<String, dynamic>? mood;

  /// Avisos do app sobre o que a IA entendeu mas faltou dado para virar
  /// cartão (ex.: remédio sem horário).
  final List<String> incomplete;

  /// Itens do histórico médico ditos pela pessoa ("tenho hipertensão"), já
  /// no formato de `add_history_item`.
  final List<Map<String, dynamic>> history;

  /// Perguntas sobre os próprios dados que o app responde **localmente**
  /// (`daily_summary`, `steps`, `medication_agenda`) — o dado não vai à IA.
  final List<String> questions;

  const ChatReading({
    this.reply,
    this.transcript,
    this.seekCare = false,
    this.water = const [],
    this.meals = const [],
    this.doses = const [],
    this.workouts = const [],
    this.newMedications = const [],
    this.suggestions = const [],
    this.symptoms = const [],
    this.vitalSigns = const [],
    this.bodyMeasurements = const [],
    this.questions = const [],
    this.history = const [],
    this.incomplete = const [],
    this.planSwaps = const [],
    this.activities = const [],
    this.mood,
  });

  bool get isEmpty =>
      water.isEmpty &&
      meals.isEmpty &&
      doses.isEmpty &&
      workouts.isEmpty &&
      newMedications.isEmpty &&
      symptoms.isEmpty &&
      vitalSigns.isEmpty &&
      bodyMeasurements.isEmpty &&
      history.isEmpty &&
      planSwaps.isEmpty &&
      activities.isEmpty &&
      mood == null &&
      questions.isEmpty;
}

/// Códigos de `OtherActivity` (pacote de atividade), para o esquema.
const activityCodes = ['walking', 'running', 'cycling', 'swimming', 'soccer', 'dance', 'yoga', 'functional', 'strength', 'other'];

/// Os mesmos sentimentos da tela Saúde mental (`MoodLogger.feelings`).
const moodFeelings = ['feliz', 'calmo', 'grato', 'cansado', 'triste', 'ansioso', 'irritado', 'sem vontade', 'sozinho', 'agitado'];

const _at = {'type': 'string', 'description': 'ISO 8601 com fuso, ex.: 2026-10-05T09:00:00-03:00. Omita se a pessoa não disse quando.'};

const chatReadingSchema = <String, dynamic>{
  'type': 'object',
  'properties': {
    'reply': {'type': 'string'},
    'transcript': {'type': 'string', 'description': 'Só para mensagem de voz: o que a pessoa falou.'},
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
                'liquid': {'type': 'boolean'},
                'kcal': {'type': 'number'},
                'protein_g': {'type': 'number'},
                'carbs_g': {'type': 'number'},
                'fat_g': {'type': 'number'},
                'sugar_g': {'type': 'number'},
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
    'workouts': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'exercise': {'type': 'string'},
          'sets': {'type': 'integer'},
          'reps': {'type': 'integer'},
          'load_kg': {'type': 'number'},
          'at': _at,
        },
        'required': ['exercise', 'sets', 'reps'],
      },
    },
    'new_medications': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'dose_amount': {'type': 'number'},
          'dose_unit': {'type': 'string'},
          'times': {
            'type': 'array',
            'items': {'type': 'string', 'description': 'HH:MM'},
          },
          'start_date': {'type': 'string', 'description': 'AAAA-MM-DD; só se a pessoa disse desde quando toma.'},
        },
        'required': ['name'],
      },
    },
    'suggestions': {
      'type': 'array',
      'items': {'type': 'string'},
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
    'activities': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'activity': {
            'type': 'string',
            'enum': activityCodes,
          },
          'label': {'type': 'string', 'description': 'Como a pessoa disse (ex.: "Brincar com a filha").'},
          'minutes': {'type': 'number'},
          'distance_m': {'type': 'number', 'description': 'A distância de UM trecho, como a pessoa disse.'},
          'round_trip': {'type': 'boolean', 'description': 'Foi e voltou fazendo a mesma atividade.'},
          'effort': {'type': 'integer', 'description': 'Esforço de 1 a 10, só se a pessoa disse.'},
          'at': _at,
        },
        'required': ['activity'],
      },
    },
    'mood': {
      'type': 'object',
      'description': 'Só quando a pessoa conta como está se sentindo.',
      'properties': {
        'mood': {'type': 'integer', 'description': '1 muito mal, 2 mal, 3 mais ou menos, 4 bem, 5 muito bem'},
        'feelings': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum': moodFeelings,
          },
        },
        'notes': {'type': 'string', 'description': 'Resumo curto do que aconteceu, nas palavras dela.'},
      },
      'required': ['mood'],
    },
    'history_items': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'kind': {
            'type': 'string',
            'enum': ['condition', 'allergy', 'surgery', 'vaccine', 'appointment'],
          },
          'title': {'type': 'string'},
          'date': {'type': 'string', 'description': 'AAAA-MM-DD; só se a pessoa disse.'},
        },
        'required': ['kind', 'title'],
      },
    },
    'plan_swaps': {
      'type': 'array',
      'items': {
        'type': 'object',
        'properties': {
          'plan': {
            'type': 'string',
            'enum': ['meal', 'workout'],
          },
          'item': {'type': 'string', 'description': 'O que a pessoa quer tirar, como está no plano (ex.: "ovo", "supino").'},
          'replacement': {'type': 'string', 'description': 'Só se a pessoa disse pelo que quer trocar.'},
          'meal_type': {
            'type': 'string',
            'enum': ['breakfast', 'lunch', 'dinner', 'snack'],
          },
        },
        'required': ['plan', 'item'],
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
Você é o Cérebro do RLT, um app de saúde pessoal no Brasil, com a IA da própria pessoa. Você faz duas coisas:
1. ANOTA o que a pessoa conta (água, refeição, remédio, treino…): cada anotação vira um cartão que ela confirma antes de salvar.
2. CONVERSA como um assistente de IA comum: responde perguntas gerais, explica remédios e doenças como a bula e as fontes de saúde explicam (para que serve, como age, efeitos comuns), fala de alimentação e exercício, motiva e acolhe.
Regras:
- Separe cada coisa num item próprio: "bebi 2 L de água, comi 3 ovos e tomei dipirona às 9h" = 1 água + 1 refeição + 1 remédio.
- Água em mililitros (1 copo = 250 ml, 1 garrafa pequena = 500 ml, 1 L = 1000 ml).
- Refeição: um item por alimento, com gramas estimadas pela quantidade dita (1 ovo ≈ 50 g) e kcal, protein_g, carbs_g, fat_g e sugar_g (açúcares totais) estimados para essas gramas. Bebida (suco, refrigerante, energético, leite, café, chá, cerveja): liquid = true e grams = mililitros (1 L = 1000). kcal e macros são o TOTAL do item nas gramas/ml dele (2 copos = a soma dos dois), nunca por unidade. O que se põe na bebida ou na comida (açúcar, adoçante, leite, mel, azeite) é um item próprio, e o item da bebida conta só a bebida: "café com 15 g de açúcar" = "Café" (sem açúcar, ≈ 2 kcal por 100 ml) + "Açúcar" 15 g. Nunca conte o mesmo ingrediente duas vezes. Água pura vai em water, não em meals. meal_type pelo que a pessoa disse ou pela hora.
- Remédio: copie o nome e, SÓ se a pessoa disse, a dose e a unidade. Nunca complete, sugira ou corrija dose. "Esqueci/pulei" = skipped.
- Treino de academia: um item por exercício, com o nome em português (ex.: "Supino reto", "Agachamento livre", "Leg press"), séries, repetições e carga em kg (0 se for peso do corpo). Corrida e caminhada não entram aqui.
- Remédio de uso (novo ou que a pessoa já toma: "comecei a tomar", "tomo", "faço uso", "uso todo dia") vai em new_medications, um item por remédio, com nome, dose e horários ditos. medication_doses é só para uma dose tomada ou pulada agora ("tomei a dipirona"). "Desde 01/02/2026" vai em start_date. Horário dito em relação a outro remédio ("30 min antes do enalapril pela manhã", com o enalapril às 07:00) vira o horário calculado ("06:30"), só nas doses que a pessoa disse. Se faltar dose ou horário, ponha o remédio mesmo assim com o que foi dito e pergunte o que falta em reply; em suggestions ofereça só horários comuns (ex.: "08:00", "12:00", "20:00") — nunca ofereça dose.
- Atividade sem gravar: caminhada ou corrida que a pessoa conta ("caminhei até a praia, uns 700 m"), bicicleta, natação, futebol, dança, brincar com os filhos, faxina pesada… vão em activities (um item por atividade), com a distância em metros e/ou o tempo em minutos que ela disse e o esforço de 1 a 10 se ela disse. Brincadeira, faxina e o que não tiver código vai como other, com label. Não calcule passos nem calorias: o app calcula pela passada e pelo peso dela. Ida e volta ("fui e voltei", "ida e volta", "voltei a pé"): round_trip = true e distance_m é a de um trecho. Se ela disse só "até um lugar" e não disse como voltou, deixe round_trip de fora e pergunte em reply se a volta também foi a pé (no cartão dá para marcar "ida e volta").
- Sentimentos: quando a pessoa desabafa ou conta como está ("tô muito pra baixo", "hoje foi um dia ótimo"), CONVERSE com acolhimento em reply (ouça, valide, ajude a pensar, sem julgar) e preencha mood com o humor dela (1 a 5), sentimentos e um resumo curto; o app oferece salvar no diário de saúde mental. Não rotule transtorno. Se houver risco (pensar em se machucar, desespero), seek_care = true.
- Histórico: doença, alergia, cirurgia, vacina ou consulta que a pessoa diz ter ou ter tido ("tenho hipertensão", "sou alérgico a dipirona") vai em history_items, com o nome como ela disse. Remédio citado junto continua indo em new_medications. Nunca deduza doença a partir de remédio (enalapril sozinho não vira hipertensão).
- Sintoma: nome curto; intensidade de 0 a 10 só se a pessoa deu. Não interprete nem dê diagnóstico.
- Sinais vitais: pressão "12 por 8" = 120/80 mmHg; temperatura em °C; glicemia em mg/dL; saturação em %; frequência em bpm.
- Medidas: peso em kg, gordura em %, circunferências em cm.
- at: use a hora que a pessoa disse, no fuso dela (veja "Agora"). "Às 9h" de hoje que ainda não chegou = ontem. Sem hora dita, omita.
- Perguntas sobre os próprios dados ("quantos passos dei?", "resumo do dia", "que remédios tenho hoje?") vão em questions; não responda você. Só use questions quando a pessoa PERGUNTA; contar o que toma não é perguntar.
- Remédio com dose ou horário faltando: ponha em new_medications mesmo assim, com o que foi dito; o app pergunta o que falta. Em reply, não repita essa pergunta e não diga que anotou o que ficou faltando.
- Limites (ADR-27): não diga que a pessoa TEM uma doença; não mande a pessoa começar, parar, trocar ou mudar a dose de remédio ou tratamento — pode explicar tudo, mas decisão de tratamento é com o médico, e diga isso quando a pergunta for sobre o caso dela. Sem dieta nova restritiva (troca equivalente no plano pode, via plan_swaps).
- seek_care = true se a pessoa descreve algo que pede atenção profissional rápida (dor no peito, falta de ar, desmaio, sangramento forte, pensamentos de se machucar, febre muito alta, pressão ou glicemia muito altas ou baixas).
- Mensagem de voz (áudio anexo): escreva em transcript o que a pessoa falou e entenda o áudio como a mensagem.
- "Conversa até agora" (quando houver) é o que já foi dito e o que a pessoa confirmou ou descartou nesta conversa. Use para entender a mensagem nova (ex.: "pode salvar a dipirona" = registrar de novo o remédio descartado). Não repita registros já confirmados.
- Troca no plano: quando a pessoa enjoou ou não quer mais algo do plano de refeições ("não aguento mais ovo", "troca o ovo da janta por bife") ou da ficha de treino ("troca o supino por outro"), vá em plan_swaps (plan = meal ou workout, item, replacement se ela disse, meal_type se ela disse). Não registre isso como refeição nem como treino; o app calcula a troca equivalente.
- Mensagem longa com várias coisas (doença, remédios, refeição, água): registre TODAS, nenhuma fica de fora.
- reply: em português, no tom de uma conversa. Para anotação, uma frase curta, sem repetir os valores dos itens. Para pergunta ou conversa, responda de verdade, claro e direto (até uns 8 parágrafos curtos; listas quando ajudar). Se faltar algo essencial para registrar, pergunte.
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

String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');

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
      items.add(PlateItem(
        name: name,
        grams: grams,
        kcal: kcal,
        proteinGrams: g('protein_g'),
        carbsGrams: g('carbs_g'),
        fatGrams: g('fat_g'),
        sugarGrams: (i['sugar_g'] as num?) == null ? null : g('sugar_g'),
        liquid: i['liquid'] == true,
      ));
    }
    if (items.isEmpty) continue;
    meals.add(ChatMeal(mealType: m['meal_type'] as String, at: _iso(m['at']), items: items));
  }

  final workouts = <ChatWorkout>[];
  for (final w in list('workouts')) {
    final name = _text(w['exercise']);
    final sets = w['sets'];
    final reps = w['reps'];
    if (name == null || sets is! int || reps is! int || sets < 1 || sets > 20 || reps < 1 || reps > 200) continue;
    final load = (w['load_kg'] as num?)?.toDouble() ?? 0;
    workouts.add(ChatWorkout(exercise: name, sets: sets, reps: reps, loadKg: load.isFinite && load >= 0 ? load : 0, at: _iso(w['at'])));
  }

  final ymd = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  final newMeds = <ChatNewMedication>[];
  final incomplete = <String>[];
  final hhmm = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  for (final m in list('new_medications')) {
    final name = _text(m['name']);
    final amount = _pos(m['dose_amount']);
    final unit = _text(m['dose_unit']);
    final times = [for (final t in (m['times'] as List? ?? const [])) if (t is String && hhmm.hasMatch(t.trim())) t.trim()];
    if (name == null) continue;
    if (amount == null || unit == null || times.isEmpty) {
      // Sem dose ou horário não vira cartão, mas não some calado.
      // Exemplo sem número de dose: o app nunca sugere dose.
      final dose = amount != null && unit != null ? ' ${_fmt(amount)} $unit' : '';
      incomplete.add(dose.isEmpty
          ? 'Para cadastrar $name, me diga a dose (como está na receita ou na embalagem)'
              '${times.isEmpty ? ' e os horários' : ''}.'
          : 'Para cadastrar $name$dose, me diga os horários (ex.: "às 08:00 e às 20:00").');
      continue;
    }
    final start = _text(m['start_date']);
    newMeds.add(ChatNewMedication(
        name: name, doseAmount: amount, doseUnit: unit, times: times, startDate: start != null && ymd.hasMatch(start) ? start : null));
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
    transcript: _text(json['transcript']),
    seekCare: json['seek_care'] == true,
    water: [
      for (final w in list('water'))
        if (_pos(w['amount_ml']) != null) withAt(w, const ['amount_ml']),
    ],
    meals: meals,
    doses: doses,
    workouts: workouts,
    newMedications: newMeds,
    incomplete: incomplete,
    suggestions: [
      for (final x in (json['suggestions'] as List? ?? const []))
        if (_text(x) != null && _text(x)!.length <= 30) _text(x)!,
    ].take(4).toList(),
    symptoms: symptoms,
    vitalSigns: vitals,
    bodyMeasurements: body,
    questions: [for (final q in (json['questions'] as List? ?? const [])) q as String],
    mood: () {
      final m = json['mood'];
      if (m is! Map) return null;
      final v = m['mood'];
      if (v is! int || v < 1 || v > 5) return null;
      return <String, dynamic>{
        'mood': v,
        'feelings': [for (final f in (m['feelings'] as List? ?? const [])) if (moodFeelings.contains(f)) f as String],
        if (_text(m['notes']) != null) 'notes': _text(m['notes']),
      };
    }(),
    activities: [
      for (final a in list('activities'))
        if (activityCodes.contains(a['activity']) && (_pos(a['minutes']) != null || _pos(a['distance_m']) != null))
          {
            'activity': a['activity'],
            if (_text(a['label']) != null) 'label': _text(a['label']),
            if (_pos(a['minutes']) != null) 'minutes': _pos(a['minutes']),
            if (_pos(a['distance_m']) != null) 'distance_m': _pos(a['distance_m'])! * (a['round_trip'] == true ? 2 : 1),
            if (a['round_trip'] == true) 'round_trip': true,
            if (a['effort'] is int && (a['effort'] as int) >= 1 && (a['effort'] as int) <= 10) 'effort': a['effort'],
            if (_iso(a['at']) != null) 'at': _iso(a['at']),
          },
    ],
    planSwaps: [
      for (final p in list('plan_swaps'))
        if ((p['plan'] == 'meal' || p['plan'] == 'workout') && _text(p['item']) != null)
          {
            'plan': p['plan'],
            'item': _text(p['item']),
            if (_text(p['replacement']) != null) 'replacement': _text(p['replacement']),
            if (const ['breakfast', 'lunch', 'dinner', 'snack'].contains(p['meal_type'])) 'meal_type': p['meal_type'],
          },
    ],
    history: [
      for (final h in list('history_items'))
        if (const ['condition', 'allergy', 'surgery', 'vaccine', 'appointment'].contains(h['kind']) && _text(h['title']) != null)
          {
            'kind': h['kind'],
            'title': _text(h['title']),
            if (_text(h['date']) != null && ymd.hasMatch(_text(h['date'])!)) 'date': _text(h['date']),
          },
    ],
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

/// Envia **só o que a pessoa mandou** — o texto ou o áudio gravado — e a
/// hora atual; nenhum dado guardado vai junto (`.claude/rules/brain.md`).
///
/// [history]: o que já foi dito **nesta conversa** (mensagens da pessoa, do
/// Cérebro e o estado dos cartões), para entender "pode salvar" ou "foi às
/// 9h mesmo". Nada de fora da conversa vai junto.
Future<ChatReading> readChatMessage(GeminiClient client, String text, {required DateTime now, AiPart? audio, String? history}) async {
  final context = history == null || history.trim().isEmpty ? '' : 'Conversa até agora:\n${history.trim()}\n\n';
  final json = await client.generateJson(
    system: chatReadingInstruction,
    parts: [
      ?audio,
      AiPart.text('${context}Agora: ${describeNow(now)}\nMensagem: ${audio == null ? text : '(mensagem de voz no áudio anexo)'}'),
    ],
    schema: chatReadingSchema,
  );
  return parseChatReading(json);
}
