import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import '../../ai/ai_consent.dart';
import '../../ai/ai_settings.dart';
import '../../ai/brain_ai.dart';
import '../../ai/voice_recorder.dart';
import '../../app_dependencies.dart';
import '../../confirmation_gate.dart';
import '../../data/brain_conversations.dart';
import '../../data/meal_plan.dart';
import '../../data/nutrition_store.dart';
import '../../documents/document_files.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/date_picker.dart';
import '../../widgets/message_composer.dart';
import '../../widgets/proposal_card.dart';
import '../health/documents_screens.dart';
import '../exercise/gym_screens.dart';
import '../nutrition/meal_labels.dart';
import '../nutrition/meal_plan_screens.dart';
import '../nutrition/plate_photo_screen.dart';
import 'brain_conversations_screen.dart';
import 'brain_text.dart';

/// Cada mensagem sabe virar o JSON guardado na conversa
/// (`BrainConversation`) e voltar dele.
sealed class _Msg {
  Map<String, dynamic> toJson();
}

class _UserMsg extends _Msg {
  final String text;
  _UserMsg(this.text);
  @override
  Map<String, dynamic> toJson() => {'t': 'user', 'text': text};
}

class _BotMsg extends _Msg {
  final String text;

  /// Resposta da IA: leva o aviso de que o app não diagnostica nem prescreve.
  final bool fromAi;

  /// Nome do modelo que respondeu (ex.: "Gemini 2.5 Flash").
  final String? model;
  _BotMsg(this.text, {this.fromAi = false, this.model});
  @override
  Map<String, dynamic> toJson() => {'t': 'bot', 'text': text, 'ai': fromAi, 'model': ?model};
}

/// Respostas rápidas da IA (prancheta CerebroCartoesEstados: "08:00 |
/// 12:00 | 20:00 | Outro horário"). Tocar manda o texto como mensagem.
class _SuggestMsg extends _Msg {
  final List<String> items;
  bool used;
  _SuggestMsg(this.items, {this.used = false});
  @override
  Map<String, dynamic> toJson() => {'t': 'suggest', 'items': items, 'used': used};
}

/// O que a pessoa anexou no Cérebro.
enum AttachKind {
  plate('Foto do prato', 'a foto do prato, para estimar alimentos e calorias', Icons.restaurant_outlined),
  prescription('Receita médica', 'a foto ou o PDF da receita, para ler médico, datas e remédios', Icons.description_outlined),
  exam('Exame', 'a foto ou o PDF do exame, para ler os valores', Icons.science_outlined),
  mealPlan('Plano alimentar', 'a foto ou o PDF do plano do nutricionista, para ler as refeições', Icons.restaurant_menu_outlined),
  workoutPlan('Ficha de treino', 'a foto ou o PDF da ficha da academia, para ler os exercícios', Icons.fitness_center_outlined),

  /// Vários arquivos de uma vez: a IA identifica cada um (ADR-19).
  document('Documento', 'os arquivos, para a IA identificar cada um e ler o que está escrito', Icons.attach_file);

  final String label;
  final String sending;
  final IconData icon;
  const AttachKind(this.label, this.sending, this.icon);
}

/// Mensagem de voz enviada (o áudio não fica guardado; só a duração).
class _VoiceMsg extends _Msg {
  final Duration duration;
  _VoiceMsg(this.duration);
  @override
  Map<String, dynamic> toJson() => {'t': 'voice', 'ms': duration.inMilliseconds};
}

/// Na conversa guardada fica só o nome e o tipo do anexo; o arquivo em si só
/// fica no celular se for salvo (Galeria, Receitas, Exames).
class _AttachMsg extends _Msg {
  final AttachKind kind;
  final PickedDocument file;
  _AttachMsg(this.kind, this.file);
  @override
  Map<String, dynamic> toJson() => {'t': 'attach', 'kind': kind.name, 'name': file.name, 'mime': file.mimeType, 'label': kind.label};
}

/// Receita ou exame lido: resumo e "Revisar e salvar" (abre o formulário já
/// preenchido; nada é salvo sem o "Salvar" de lá).
class _DocMsg extends _Msg {
  final AttachKind kind;
  final PickedDocument file;
  final String summary;
  final ExamReading? exam;
  final PrescriptionReading? prescription;
  final MealPlanDraft? mealPlan;
  final WorkoutPlanReading? workout;
  bool saved;

  /// Reaberta de uma conversa antiga: sem o arquivo nem a leitura.
  final bool restored;

  /// Nome do modelo que leu.
  final String? model;
  _DocMsg(this.kind, this.file, this.summary,
      {this.exam, this.prescription, this.mealPlan, this.workout, this.saved = false, this.restored = false, this.model});
  @override
  Map<String, dynamic> toJson() => {'t': 'doc', 'kind': kind.name, 'summary': summary, 'saved': saved, 'model': ?model};
}

class _ProposalMsg extends _Msg {
  final String tool;

  /// Os mesmos parâmetros que o pipeline executa: editar o cartão muda
  /// este mapa, e o registro valida de novo antes de gravar.
  final Map<String, dynamic> params;
  final Completer<bool> decision = Completer();
  ProposalState state = ProposalState.pending;

  /// Onde ficou salvo ("Nutrição › Água"), para o resumo da conversa.
  String? savedIn;

  /// Edição: gramas por alimento (refeição estimada) ou ml (água).
  List<TextEditingController>? gramFields;
  TextEditingController? amountField;

  /// Edição de refeição: nome de cada alimento, tipo de refeição e a
  /// observação que a IA usa para recalcular.
  List<TextEditingController>? nameFields;
  TextEditingController? noteField;
  String? mealType;
  bool refining = false;

  /// Edição de remédio novo: nome, dose, unidade, horários e início.
  TextEditingController? nameField;
  TextEditingController? unitField;
  TextEditingController? timesField;
  TextEditingController? startField;

  /// Edição de sintoma: intensidade e quando.
  int? intensity;
  DateTime? when;
  _ProposalMsg(this.tool, this.params);

  bool get editable => const {'log_estimated_meal', 'log_water', 'log_symptom', 'add_medication'}.contains(tool);

  void disposeFields() {
    for (final c in [...?gramFields, ...?nameFields, amountField, noteField, nameField, unitField, timesField, startField]) {
      c?.dispose();
    }
    gramFields = null;
    nameFields = null;
    amountField = null;
    noteField = null;
    nameField = null;
    unitField = null;
    timesField = null;
    startField = null;
  }

  @override
  Map<String, dynamic> toJson() => {
        't': 'card',
        'tool': tool,
        'params': params,
        // Cartão que ficou sem resposta não volta a valer: nada foi salvo.
        'state': state == ProposalState.confirmed ? 'confirmed' : 'discarded',
        'saved_in': savedIn,
      };
}

/// Mensagem guardada → mensagem da tela.
_Msg? _msgFromJson(Map<String, dynamic> m) {
  AttachKind kind() => AttachKind.values.where((k) => k.name == m['kind']).firstOrNull ?? AttachKind.plate;
  switch (m['t']) {
    case 'user':
      return _UserMsg(m['text'] as String);
    case 'bot':
      return _BotMsg(m['text'] as String, fromAi: m['ai'] == true, model: m['model'] as String?);
    case 'suggest':
      return _SuggestMsg([for (final x in m['items'] as List) x as String], used: true);
    case 'voice':
      return _VoiceMsg(Duration(milliseconds: (m['ms'] as num).toInt()));
    case 'attach':
      return _AttachMsg(kind(), PickedDocument(bytes: Uint8List(0), name: m['name'] as String, mimeType: m['mime'] as String));
    case 'doc':
      return _DocMsg(kind(), PickedDocument(bytes: Uint8List(0), name: '', mimeType: ''), m['summary'] as String,
          saved: m['saved'] == true, restored: true, model: m['model'] as String?);
    case 'card':
      final c = _ProposalMsg(m['tool'] as String, Map<String, dynamic>.from(m['params'] as Map))
        ..state = m['state'] == 'confirmed' ? ProposalState.confirmed : ProposalState.discarded
        ..savedIn = m['saved_in'] as String?;
      c.decision.complete(c.state == ProposalState.confirmed);
      return c;
  }
  return null;
}

/// Cérebro (pranchetas CerebroChat, CerebroEstados): conversa em que cada
/// registro entendido vira um cartão de proposta — nada é gravado antes do
/// "Confirmar" (`.claude/rules/brain.md`). Comandos exatos passam pelo
/// roteador determinístico, sem rede; o resto vai ao Gemini (ADR-11) só com
/// chave e consentimento — uma frase pode virar vários cartões. Sem chave,
/// modo básico.
class BrainScreen extends StatefulWidget {
  final AppDependencies deps;
  const BrainScreen({super.key, required this.deps});

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen> {
  final _messages = <_Msg>[];

  /// A conversa atual, guardada no celular a cada mudança.
  BrainConversation _conv = BrainConversation.start();
  final _scroll = ScrollController();
  final _composer = TextEditingController();
  /// Esperando a IA responder. Cartões pendentes não travam o campo: a
  /// pessoa pode mandar outra mensagem e decidir os cartões depois.
  bool _thinking = false;

  static const _examples = ['registrar água 500ml', 'resumo de hoje', 'quantos passos hoje', 'buscar alimento arroz'];
  static const _aiExamples = [
    'Bebi 500 ml de água',
    'bebi 2 L de água, comi 3 ovos e tomei dipirona às 9h',
    'fiz 3 séries de supino com 30 kg',
    'resumo de hoje',
  ];

  /// Muda a tela e guarda a conversa (conversa vazia não é guardada).
  void _changed(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
    _conv.messages
      ..clear()
      ..addAll(_messages.map((m) => m.toJson()));
    widget.deps.conversations.save(_conv);
  }

  /// O que já foi dito nesta conversa, para a IA entender a mensagem nova
  /// ("pode salvar", "foi às 9h mesmo"). Só esta conversa; a última
  /// mensagem (a que está indo agora) fica de fora.
  String _historyText() {
    final lines = <String>[];
    for (final m in _messages.take(_messages.length - 1)) {
      final line = switch (m) {
        _UserMsg(:final text) => 'Pessoa: $text',
        _BotMsg(:final text) => 'Cérebro: $text',
        _AttachMsg(:final kind) => 'Pessoa anexou: ${kind.label}',
        _DocMsg(:final summary) => 'Cérebro leu: $summary',
        final _ProposalMsg c => () {
            final v = describeProposal(widget.deps, c.tool, c.params);
            final st = switch (c.state) {
              ProposalState.confirmed => 'confirmado',
              ProposalState.discarded => 'descartado',
              _ => 'esperando confirmação',
            };
            return 'Cartão $st: ${v.title}${v.detail == null ? '' : ' (${v.detail})'}${v.when == null ? '' : ', ${v.when}'}';
          }(),
        _VoiceMsg() || _SuggestMsg() => null,
      };
      if (line != null) lines.add(line);
    }
    final recent = lines.length > 20 ? lines.sublist(lines.length - 20) : lines;
    final text = recent.join('\n');
    return text.length > 3000 ? text.substring(text.length - 3000) : text;
  }

  AppConfirmationGate? get _gate {
    final g = widget.deps.confirmationGate;
    return g is AppConfirmationGate ? g : null;
  }

  @override
  void initState() {
    super.initState();
    _gate?.presenter = _present;
  }

  /// Segurar uma mensagem: copiar o texto; nas suas, também trazer de volta
  /// para o campo, mudar e mandar de novo.
  Future<void> _attachMenu(AttachKind kind, PickedDocument file) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('brain_attach_resend'),
            leading: const Icon(Icons.replay_outlined),
            title: const Text('Mandar de novo'),
            subtitle: const Text('Volta para o campo; dá para escrever junto'),
            onTap: () => Navigator.pop(ctx, 'resend'),
          ),
        ]),
      ),
    );
    if (choice == 'resend' && mounted && !_thinking) _stage(kind, [file]);
  }

  Widget _pendingPreview((AttachKind, List<PickedDocument>) p) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final (kind, files) = p;
    final first = files.first;
    final isPdf = first.mimeType == 'application/pdf';
    return Container(
      key: const Key('chat_pending_attachment'),
      padding: const EdgeInsets.all(RltSpace.s),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(RltRadius.card)),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: isPdf
              ? Icon(Icons.picture_as_pdf_outlined, size: 40, color: c.onSurfaceVariant)
              : Image.memory(first.bytes, width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(kind.icon, size: 40, color: c.onSurfaceVariant)),
        ),
        const SizedBox(width: RltSpace.s),
        Expanded(
          child: Text(
            files.length == 1 ? '${kind.label} · ${first.name}' : '${kind.label} · ${files.length} arquivos',
            style: t.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          key: const Key('chat_pending_remove'),
          tooltip: 'Tirar o anexo',
          onPressed: () => _changed(() => _pending = null),
          icon: const Icon(Icons.close),
        ),
      ]),
    );
  }

  Future<void> _messageMenu(String text, {required bool mine}) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('brain_msg_copy'),
            leading: const Icon(Icons.copy_outlined),
            title: const Text('Copiar'),
            onTap: () => Navigator.pop(ctx, 'copy'),
          ),
          if (mine)
            ListTile(
              key: const Key('brain_msg_edit'),
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar e mandar de novo'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
        ]),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Mensagem copiada.')));
    } else {
      _composer.value = TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    if (_gate?.presenter == _present) _gate?.presenter = null;
    for (final m in _messages) {
      if (m is _ProposalMsg) {
        if (!m.decision.isCompleted) m.decision.complete(false);
        m.disposeFields();
      }
    }
    _scroll.dispose();
    super.dispose();
  }

  /// Foto ou arquivo escolhido, esperando o "Enviar": dá para escrever
  /// junto (ex.: "não comi a borda") antes de mandar.
  (AttachKind, List<PickedDocument>)? _pending;

  void _stage(AttachKind kind, List<PickedDocument> files) {
    if (files.isEmpty) return;
    _changed(() => _pending = (kind, files));
  }

  Future<bool> _present(ToolSpec spec, Map<String, dynamic> params) {
    final msg = _ProposalMsg(spec.name, params);
    _changed(() => _messages.add(msg));
    _scrollToEnd();
    return msg.decision.future;
  }

  void _decide(_ProposalMsg m, bool ok) {
    if (m.decision.isCompleted) return;
    if (ok && m.state == ProposalState.editing && !_applyEdit(m)) return;
    m.disposeFields();
    _changed(() {
      m.state = ok ? ProposalState.confirmed : ProposalState.discarded;
      if (ok) m.savedIn = describeProposal(widget.deps, m.tool, m.params).savedIn;
    });
    m.decision.complete(ok);
  }

  void _startEdit(_ProposalMsg m) {
    _changed(() {
      switch (m.tool) {
        case 'log_estimated_meal':
          _mealFields(m);
          m.noteField = TextEditingController();
          m.mealType = m.params['meal_type'] as String?;
        case 'add_medication':
          m.nameField = TextEditingController(text: '${m.params['name']}');
          m.amountField = TextEditingController(text: formatNumber(m.params['dose_amount'] as num));
          m.unitField = TextEditingController(text: '${m.params['dose_unit']}');
          m.timesField = TextEditingController(text: (m.params['times'] as List).join(', '));
          final start = DateTime.tryParse('${m.params['start_date']}');
          m.startField = TextEditingController(text: start == null ? '' : ddmmyyyy(start));
        case 'log_water':
          m.amountField = TextEditingController(text: formatNumber(m.params['amount_ml'] as num));
        case 'log_symptom':
          m.intensity = m.params['intensity'] as int?;
          final at = m.params['at'] as String?;
          m.when = at == null ? null : DateTime.parse(at).toLocal();
      }
      m.state = ProposalState.editing;
    });
  }

  void _mealFields(_ProposalMsg m) {
    for (final c in [...?m.gramFields, ...?m.nameFields]) {
      c.dispose();
    }
    final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
    m.gramFields = [for (final i in items) TextEditingController(text: formatNumber(i['grams'] as num))];
    m.nameFields = [for (final i in items) TextEditingController(text: '${i['name']}')];
  }

  /// Itens do cartão com os nomes e gramas digitados; `null` se faltar algo.
  List<Map<String, dynamic>>? _editedItems(_ProposalMsg m) {
    final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
    final grams = [for (final c in m.gramFields!) double.tryParse(c.text.trim().replaceAll(',', '.'))];
    if (grams.any((g) => g == null || g < 0) || grams.every((g) => g == 0)) return null;
    final next = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final g = grams[i]!;
      if (g == 0) continue;
      final name = m.nameFields![i].text.trim();
      final f = g / (items[i]['grams'] as num).toDouble();
      next.add({
        ...items[i],
        if (name.isNotEmpty) 'name': name,
        'grams': g,
        // Novas gramas: kcal e macros acompanham na proporção.
        for (final k in const ['kcal', 'protein_g', 'carbs_g', 'fat_g'])
          if (items[i][k] is num) k: (items[i][k] as num) * f,
      });
    }
    return next;
  }

  /// A IA refaz a estimativa com a observação da pessoa (só texto; a foto
  /// não vai de novo). O cartão continua esperando a confirmação.
  Future<void> _refine(_ProposalMsg m) async {
    final note = m.noteField!.text.trim();
    final items = _editedItems(m);
    if (note.isEmpty || items == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escreva a observação (ex.: "não comi a borda").')));
      return;
    }
    _changed(() => m.refining = true);
    try {
      final next = await refineMealItems(await widget.deps.ai.client(), [
        for (final i in items)
          PlateItem(
            name: i['name'] as String,
            grams: (i['grams'] as num).toDouble(),
            kcal: (i['kcal'] as num).toDouble(),
            proteinGrams: (i['protein_g'] as num?)?.toDouble() ?? 0,
            carbsGrams: (i['carbs_g'] as num?)?.toDouble() ?? 0,
            fatGrams: (i['fat_g'] as num?)?.toDouble() ?? 0,
            liquid: i['unit'] == 'ml',
          ),
      ], note);
      if (!mounted || m.state != ProposalState.editing) return;
      if (next.isEmpty) throw const AiException(AiFailure.invalidOutput);
      _changed(() {
        m.params['items'] = [
          for (final i in next)
            {
              'name': i.name,
              'grams': i.grams,
              if (i.liquid) 'unit': 'ml',
              'kcal': i.kcal,
              'protein_g': i.proteinGrams,
              'carbs_g': i.carbsGrams,
              'fat_g': i.fatGrams,
            },
        ];
        _mealFields(m);
        m.noteField!.clear();
        m.refining = false;
      });
      final model = _modelLabel;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Recalculado${model == null ? '' : ' ($model)'}. Confira e confirme.')));
    } catch (e) {
      if (!mounted) return;
      _changed(() => m.refining = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(aiFailureMessage(e))));
    }
  }

  void _cancelEdit(_ProposalMsg m) {
    m.disposeFields();
    _changed(() => m.state = ProposalState.pending);
  }

  double? _parse(String text) => double.tryParse(text.trim().replaceAll('.', '').replaceAll(',', '.'));

  /// Aplica a edição aos parâmetros do cartão; o registro valida de novo
  /// antes de gravar.
  bool _applyEdit(_ProposalMsg m) {
    void warn(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    switch (m.tool) {
      case 'log_estimated_meal':
        // Item com 0 g sai da refeição.
        final next = _editedItems(m);
        if (next == null) {
          warn('Informe as gramas de cada alimento (0 tira o item).');
          return false;
        }
        m.params['items'] = next;
        if (m.mealType != null) m.params['meal_type'] = m.mealType;
      case 'add_medication':
        final name = m.nameField!.text.trim();
        final dose = _parse(m.amountField!.text);
        final unit = m.unitField!.text.trim();
        final hhmm = RegExp(r'^([01]?\d|2[0-3])[:h]([0-5]\d)?$');
        final times = <String>[];
        for (final raw in m.timesField!.text.split(RegExp(r'[,;\s]+')).where((x) => x.isNotEmpty)) {
          final t = hhmm.firstMatch(raw.trim().toLowerCase());
          if (t == null) {
            warn('Horário "$raw" não entendido. Use 07:00, 18:00.');
            return false;
          }
          times.add('${t.group(1)!.padLeft(2, '0')}:${t.group(2) ?? '00'}');
        }
        final start = m.startField!.text.trim().isEmpty ? DateTime.now() : parseDdMmYyyy(m.startField!.text);
        if (name.isEmpty || dose == null || dose <= 0 || unit.isEmpty || times.isEmpty || start == null) {
          warn('Confira nome, dose, unidade, horários e a data de início (dd/mm/aaaa).');
          return false;
        }
        m.params
          ..['name'] = name
          ..['dose_amount'] = dose
          ..['dose_unit'] = unit
          ..['times'] = (times.toSet().toList()..sort())
          ..['start_date'] =
              '${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
      case 'log_water':
        final ml = _parse(m.amountField!.text);
        if (ml == null || ml <= 0 || ml > 5000) {
          warn('Informe a água em ml (até 5.000).');
          return false;
        }
        m.params['amount_ml'] = ml;
      case 'log_symptom':
        if (m.intensity != null) m.params['intensity'] = m.intensity;
        if (m.when != null) m.params['at'] = m.when!.toUtc().toIso8601String();
    }
    return true;
  }

  Widget _editor(_ProposalMsg m) {
    final t = Theme.of(context).textTheme;
    switch (m.tool) {
      case 'log_water':
        return TextField(
          key: const Key('proposal_ml'),
          controller: m.amountField,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
          decoration: const InputDecoration(labelText: 'Água', suffixText: 'ml', isDense: true),
        );
      case 'log_symptom':
        final w = m.when;
        String two(int v) => v.toString().padLeft(2, '0');
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Intensidade${m.intensity == null ? '' : ': ${m.intensity} de 10'}', style: t.labelLarge),
          Slider(
            key: const Key('proposal_intensity'),
            value: (m.intensity ?? 5).toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '${m.intensity ?? 5}',
            onChanged: (v) => _changed(() => m.intensity = v.round()),
          ),
          Text('Quando', style: t.labelLarge),
          TextButton.icon(
            key: const Key('proposal_when'),
            onPressed: () async {
              final base = m.when ?? DateTime.now();
              final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(base));
              if (picked == null) return;
              var at = DateTime(base.year, base.month, base.day, picked.hour, picked.minute);
              // Hora que ainda não chegou hoje = ontem.
              if (at.isAfter(DateTime.now())) at = at.subtract(const Duration(days: 1));
              _changed(() => m.when = at);
            },
            icon: const Icon(Icons.schedule, size: 18),
            label: Text(w == null ? 'Agora' : '${two(w.hour)}:${two(w.minute)}'),
          ),
        ]);
      case 'add_medication':
        return Column(children: [
          TextField(key: const Key('proposal_med_name'), controller: m.nameField, decoration: const InputDecoration(labelText: 'Remédio', isDense: true)),
          const SizedBox(height: RltSpace.s),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('proposal_med_dose'),
                controller: m.amountField,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Dose', isDense: true),
              ),
            ),
            const SizedBox(width: RltSpace.s),
            Expanded(
              child: TextField(
                  key: const Key('proposal_med_unit'), controller: m.unitField, decoration: const InputDecoration(labelText: 'Unidade', isDense: true)),
            ),
          ]),
          const SizedBox(height: RltSpace.s),
          TextField(
            key: const Key('proposal_med_times'),
            controller: m.timesField,
            decoration: const InputDecoration(labelText: 'Horários', helperText: 'Ex.: 07:00, 18:00 — um horário por dose', isDense: true),
          ),
          const SizedBox(height: RltSpace.s),
          TextField(
            key: const Key('proposal_med_start'),
            controller: m.startField,
            keyboardType: TextInputType.number,
            inputFormatters: [DateMaskFormatter()],
            decoration: const InputDecoration(labelText: 'Toma desde', hintText: 'dd/mm/aaaa', isDense: true),
          ),
        ]);
      default:
        return _gramsEditor(m);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send(String text) async {
    if (_thinking) return;
    final pending = _pending;
    if (pending != null) {
      _changed(() => _pending = null);
      if (pending.$1 == AttachKind.document) {
        await _readMany(pending.$2, note: text);
      } else {
        await _readAttachment(pending.$1, pending.$2.single, note: text);
      }
      return;
    }
    if (text.trim().isEmpty) return;
    final deps = widget.deps;
    _changed(() => _messages.add(_UserMsg(text)));
    _scrollToEnd();

    // Passo 1: o roteador determinístico, sem rede. Só o que ele não
    // resolve pode ir à IA.
    final routed = deps.pipeline.callers.any((c) => c.decide(text, deps.registry.specs) != null);
    if (routed || !deps.ai.hasKey.value) {
      final result = await deps.pipeline.handle(text);
      if (!mounted) return;
      _showResults([result]);
      return;
    }

    await _askAi('a sua mensagem', (caller) => caller.plan(text, deps.registry.specs));
  }

  /// Consentimento, IA, mensagens dela e um cartão por registro — o mesmo
  /// caminho para texto e voz.
  Future<void> _askAi(String sending, Future<ToolCallPlan> Function(AiToolCaller caller) ask) async {
    final deps = widget.deps;
    if (!await ensureAiConsent(context, deps, sending: sending)) {
      if (mounted) _changed(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    if (!mounted) return;
    _changed(() => _thinking = true);
    ToolCallPlan plan;
    try {
      final history = _historyText();
      plan = await ask(AiToolCaller(client: deps.ai.client, medications: deps.medicationRepository.listAll, history: () => history));
    } catch (e) {
      if (!mounted) return;
      _changed(() {
        _thinking = false;
        _messages.add(_BotMsg(e is AiException && e.failure == AiFailure.invalidOutput
            ? 'Não entendi. Tente uma frase por registro, como "bebi 500 ml de água" ou "comi 2 ovos no café".'
            : aiFailureMessage(e)));
      });
      _scrollToEnd();
      return;
    }
    if (!mounted) return;
    _changed(() {
      _thinking = false;
      for (final m in plan.messages) {
        _messages.add(_BotMsg(m, fromAi: true, model: _modelLabel));
      }
      if (plan.suggestions.isNotEmpty) _messages.add(_SuggestMsg(plan.suggestions));
    });
    _scrollToEnd();
    // Cada cartão segue sozinho: a resposta de uma pergunta aparece na hora,
    // sem esperar a pessoa decidir os outros cartões.
    await Future.wait([
      for (final call in plan.calls)
        deps.pipeline.runPlan(ToolCallPlan(calls: [call])).then((r) {
          if (mounted) _showResults(r);
        }),
    ]);
  }

  // --- Voz (prancheta CerebroEntradas: segurar para gravar) ---------------

  Future<bool>? _voiceStarting;

  void _voiceStart() {
    _voiceStarting = () async {
      final rec = widget.deps.voiceRecorder;
      var ok = await rec.hasPermission();
      if (!ok) ok = await rec.requestPermission();
      if (!ok) {
        if (mounted) {
          _changed(() => _messages.add(_BotMsg('Para falar com o Cérebro, permita o microfone. '
              'Você pode mudar isso em Conta › Permissões.')));
        }
        return false;
      }
      return rec.start();
    }();
  }

  Future<void> _voiceEnd(Duration held) async {
    final started = await (_voiceStarting ?? Future.value(false));
    _voiceStarting = null;
    if (!started) return;
    final audio = await widget.deps.voiceRecorder.stop();
    if (!mounted) return;
    if (audio == null || audio.duration < const Duration(milliseconds: 800)) {
      _changed(() => _messages.add(_BotMsg('Segure o botão do microfone enquanto fala.')));
      return;
    }
    _changed(() => _messages.add(_VoiceMsg(audio.duration)));
    _scrollToEnd();
    await _askAi('o áudio que você gravou',
        (caller) => caller.planVoice(audio.bytes, RecordedAudio.mimeType, widget.deps.registry.specs));
  }

  Future<void> _voiceCancel() async {
    final started = await (_voiceStarting ?? Future.value(false));
    _voiceStarting = null;
    if (started) await widget.deps.voiceRecorder.cancel();
  }

  /// Câmera no campo: atalho para a foto do prato.
  Future<void> _plateCamera() async {
    final file = await widget.deps.documentPicker.takePhoto();
    if (file != null && mounted) _stage(AttachKind.plate, [file]);
  }

  Future<void> _attach() async {
    final picked = await showModalBottomSheet<(AttachKind, List<PickedDocument>)>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final picker = widget.deps.documentPicker;
        Widget source(AttachKind kind, String id, String label, IconData icon, Future<PickedDocument?> Function() pick) =>
            OutlinedButton.icon(
              key: Key('attach_${kind.name}_$id'),
              onPressed: () async {
                final file = await pick();
                if (sheet.mounted) Navigator.of(sheet).pop(file == null ? null : (kind, [file]));
              },
              icon: Icon(icon, size: 18),
              label: Text(label),
            );
        return SafeArea(
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(RltSpace.l, 0, RltSpace.l, RltSpace.l), children: [
            Text('Anexar ao Cérebro', style: Theme.of(sheet).textTheme.titleMedium),
            const SizedBox(height: RltSpace.xs),
            Text('O arquivo só vai à IA depois que você escolher. Nada é salvo sem você conferir.',
                style: Theme.of(sheet).textTheme.bodySmall),
            const SizedBox(height: RltSpace.m),
            Row(children: [
              const Icon(Icons.auto_awesome_outlined, size: 20),
              const SizedBox(width: RltSpace.s),
              Expanded(child: Text('Vários documentos — a IA identifica cada um', style: Theme.of(sheet).textTheme.titleSmall)),
            ]),
            const SizedBox(height: RltSpace.xs),
            Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
              OutlinedButton.icon(
                key: const Key('attach_many_gallery'),
                onPressed: () async {
                  final files = await picker.pickImages();
                  if (sheet.mounted) Navigator.of(sheet).pop(files.isEmpty ? null : (AttachKind.document, files));
                },
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Fotos'),
              ),
              OutlinedButton.icon(
                key: const Key('attach_many_pdf'),
                onPressed: () async {
                  final files = await picker.pickPdfs();
                  if (sheet.mounted) Navigator.of(sheet).pop(files.isEmpty ? null : (AttachKind.document, files));
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('PDFs'),
              ),
              source(AttachKind.document, 'camera', 'Câmera', Icons.photo_camera_outlined, picker.takePhoto),
            ]),
            const SizedBox(height: RltSpace.s),
            const Divider(),
            for (final kind in AttachKind.values.where((k) => k != AttachKind.document)) ...[
              const SizedBox(height: RltSpace.m),
              Row(children: [Icon(kind.icon, size: 20), const SizedBox(width: RltSpace.s), Text(kind.label)]),
              const SizedBox(height: RltSpace.xs),
              Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
                source(kind, 'camera', 'Câmera', Icons.photo_camera_outlined, picker.takePhoto),
                source(kind, 'gallery', 'Galeria', Icons.photo_library_outlined, picker.pickImage),
                if (kind != AttachKind.plate) source(kind, 'pdf', 'PDF', Icons.picture_as_pdf_outlined, picker.pickPdf),
              ]),
            ],
          ]),
        );
      },
    );
    if (picked == null || picked.$2.isEmpty || !mounted) return;
    _stage(picked.$1, picked.$2);
  }

  /// Lê o anexo com a IA (só depois do consentimento). Prato vira cartão de
  /// refeição estimada; receita e exame viram um resumo com "Revisar e
  /// salvar".
  Future<void> _readAttachment(AttachKind kind, PickedDocument file, {String note = ''}) async {
    final deps = widget.deps;
    _changed(() {
      _messages.add(_AttachMsg(kind, file));
      if (note.trim().isNotEmpty) _messages.add(_UserMsg(note.trim()));
    });
    _scrollToEnd();
    if (!await ensureAiConsent(context, deps, sending: kind.sending)) {
      if (mounted) _changed(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    if (!mounted) return;
    _changed(() => _thinking = true);
    try {
      await _readOne(await deps.ai.client(), kind, file, note: note);
      if (mounted) _changed(() => _thinking = false);
    } catch (e) {
      if (!mounted) return;
      _changed(() {
        _thinking = false;
        _messages.add(_BotMsg(aiFailureMessage(e)));
      });
    }
    _scrollToEnd();
  }

  /// Lê um arquivo de tipo conhecido e põe o resultado na conversa.
  Future<void> _readOne(GeminiClient client, AttachKind kind, PickedDocument file, {String note = ''}) async {
    final part = AiPart.file(file.bytes, file.mimeType);
    switch (kind) {
      case AttachKind.plate:
        final estimate = await estimatePlate(client, part, note: note);
        if (!mounted) return;
        // O cartão espera a decisão da pessoa: a barra de "pensando" sai antes.
        _changed(() => _thinking = false);
        await _proposePlate(file, estimate);
      case AttachKind.prescription:
        final rx = await readPrescription(client, [part]);
        if (!mounted) return;
        _changed(() => _messages.add(_DocMsg(kind, file, describePrescriptionReading(rx), prescription: rx, model: _modelLabel)));
      case AttachKind.exam:
        final exam = await readExam(client, [part]);
        if (!mounted) return;
        _changed(() => _messages.add(_DocMsg(kind, file, describeExamReading(exam), exam: exam, model: _modelLabel)));
      case AttachKind.mealPlan:
        final plan = await readMealPlan(client, [part]);
        if (!mounted) return;
        _changed(() => _messages.add(_DocMsg(kind, file, describeMealPlanDraft(plan), mealPlan: plan, model: _modelLabel)));
      case AttachKind.workoutPlan:
        final plan = await readWorkoutPlan(client, [part]);
        if (!mounted) return;
        _changed(() => _messages.add(_DocMsg(kind, file, describeWorkoutPlanReading(plan), workout: plan, model: _modelLabel)));
      case AttachKind.document:
        await _sortAndRead(client, [file], note: note);
    }
  }

  /// Vários arquivos: consentimento uma vez, a IA separa e cada um segue
  /// para o leitor do seu tipo (ADR-19).
  Future<void> _readMany(List<PickedDocument> files, {String note = ''}) async {
    final deps = widget.deps;
    _changed(() {
      for (final f in files) {
        _messages.add(_AttachMsg(AttachKind.document, f));
      }
      if (note.trim().isNotEmpty) _messages.add(_UserMsg(note.trim()));
    });
    _scrollToEnd();
    final what = files.length == 1 ? 'o arquivo' : 'os ${files.length} arquivos';
    if (!await ensureAiConsent(context, deps, sending: '$what, para a IA identificar cada um e ler o que está escrito')) {
      if (mounted) _changed(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    if (!mounted) return;
    _changed(() => _thinking = true);
    try {
      await _sortAndRead(await deps.ai.client(), files, note: note);
    } catch (e) {
      if (mounted) _changed(() => _messages.add(_BotMsg(aiFailureMessage(e))));
    }
    if (mounted) _changed(() => _thinking = false);
    _scrollToEnd();
  }

  /// Modelo que deu a última resposta da IA.
  String? get _modelLabel => widget.deps.ai.lastModelLabel.value;

  Future<void> _sortAndRead(GeminiClient client, List<PickedDocument> files, {String note = ''}) async {
    final sorting = await sortDocuments(client, [for (final f in files) AiPart.file(f.bytes, f.mimeType)], note: note);
    if (!mounted) return;
    final many = files.length > 1;
    final calls = <ToolCallDecision>[];
    for (final s in sorting.files) {
      final file = files[s.index - 1];
      final label = many ? 'Arquivo ${s.index} (${file.name})' : 'Este arquivo';
      final kind = switch (s.kind) {
        SortedKind.plate => AttachKind.plate,
        SortedKind.prescription => AttachKind.prescription,
        SortedKind.exam => AttachKind.exam,
        SortedKind.mealPlan => AttachKind.mealPlan,
        SortedKind.workoutPlan => AttachKind.workoutPlan,
        SortedKind.medicalHistory || SortedKind.other => null,
      };
      if (kind != null) {
        try {
          await _readOne(client, kind, file, note: note);
        } catch (e) {
          if (mounted) _changed(() => _messages.add(_BotMsg('$label: ${aiFailureMessage(e)}')));
        }
      } else if (s.kind == SortedKind.medicalHistory) {
        _changed(() => _messages.add(_BotMsg('$label é um histórico médico. O que está escrito vira cartões abaixo, para você conferir.',
            fromAi: true, model: _modelLabel)));
      } else {
        _changed(() => _messages.add(_BotMsg(
            '$label: ${s.description ?? 'não parece um documento de saúde.'} Não há nada para registrar.',
            fromAi: true, model: _modelLabel)));
      }
      if (!mounted) return;
    }
    // Dados pessoais escritos nos documentos: um cartão por item.
    final at = sorting.body.date == null ? null : DateTime(sorting.body.date!.year, sorting.body.date!.month, sorting.body.date!.day, 12);
    final atIso = at?.toUtc().toIso8601String();
    if (sorting.body.weightKg != null) {
      calls.add(ToolCallDecision('log_body_measurement', {'kind': 'weight', 'value': sorting.body.weightKg, 'at': ?atIso}));
    }
    if (sorting.body.bodyFatPercent != null) {
      calls.add(ToolCallDecision('log_body_measurement', {'kind': 'body_fat', 'value': sorting.body.bodyFatPercent, 'at': ?atIso}));
    }
    if (sorting.body.heightCm != null) {
      calls.add(ToolCallDecision('update_height', {'height_cm': sorting.body.heightCm!.roundToDouble()}));
    }
    final known = {for (final i in widget.deps.medicalHistory.list()) '${i.kind.wireValue}|${_plain(i.title)}'};
    for (final h in sorting.history) {
      if (known.contains('${h.kind}|${_plain(h.title)}')) continue; // já está no histórico
      calls.add(ToolCallDecision('add_history_item', {
        'kind': h.kind,
        'title': h.title,
        if (h.date != null) 'date': _isoDay(h.date!),
        'professional': ?h.professional,
      }));
    }
    if (calls.isEmpty) return;
    _changed(() => _thinking = false);
    final results = await widget.deps.pipeline.runPlan(ToolCallPlan(calls: calls));
    if (mounted) _showResults(results);
  }

  static String _plain(String s) => s.toLowerCase().trim();
  static String _isoDay(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _proposePlate(PickedDocument photo, PlateEstimate estimate) async {
    final deps = widget.deps;
    if (estimate.items.isEmpty) {
      final seen = estimate.notFood;
      _changed(() => _messages.add(_BotMsg(
          seen == null
              ? 'Não reconheci alimentos nesta foto. Tente de cima, com o prato inteiro e boa luz.'
              : 'Não vi comida nesta foto: $seen Para receita, exame, plano ou ficha de treino, use Anexar › Vários documentos.',
          fromAi: true, model: _modelLabel)));
      return;
    }
    final now = DateTime.now();
    final meal = MealType.values.where((t) => t.name == estimate.mealType).firstOrNull ?? mealTypeForHour(now.hour);
    final call = ToolCallDecision('log_estimated_meal', {
      'meal_type': meal.wireValue,
      'items': [
        for (final i in estimate.items)
          {'name': i.name, 'grams': i.grams, 'kcal': i.kcal, 'protein_g': i.proteinGrams, 'carbs_g': i.carbsGrams, 'fat_g': i.fatGrams},
      ],
    });
    final results = await deps.pipeline.runPlan(ToolCallPlan(calls: [call]));
    final r = results.single;
    final eventId = r.toolResult?.data?['event_id'] as String?;
    if (r.outcome == PipelineOutcome.executed && r.toolResult!.success && eventId != null) {
      // Confirmado: a foto vai para a Galeria, como na tela Foto do prato.
      final stored = await deps.documentFiles.store(photo);
      deps.nutrition.addPlatePhoto(PlatePhoto(
        mealEventId: eventId,
        storedName: stored.storedName,
        mealType: MealType.fromWireValue(call.params['meal_type'] as String),
        atUtc: now.toUtc(),
        tzOffsetMinutes: now.timeZoneOffset.inMinutes,
      ));
    }
    if (mounted) _showResults(results);
  }

  Future<void> _reviewDocument(_DocMsg m) async {
    final deps = widget.deps;
    if (m.kind == AttachKind.mealPlan) {
      final before = deps.mealPlans.load()?.toJson().toString();
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => MealPlanEditScreen(
          deps: deps,
          initial: MealPlan.fromDraft(m.mealPlan ?? const MealPlanDraft(), source: MealPlanSource.imported, fallbackName: 'Plano do profissional'),
          source: MealPlanSource.imported,
          newAttachment: m.file,
        ),
      ));
      final after = deps.mealPlans.load()?.toJson().toString();
      if (mounted && after != null && after != before) _changed(() => m.saved = true);
      return;
    }
    if (m.kind == AttachKind.workoutPlan) {
      final before = deps.workoutRepository.listPlans().length;
      final w = m.workout ?? const WorkoutPlanReading();
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => PlanFormScreen(
          deps: deps,
          draft: WorkoutPlan(
            id: 'draft',
            name: w.name ?? 'Ficha da academia',
            exercises: [
              for (final e in w.exercises)
                () {
                  final known = matchExercise(e.name);
                  return PlannedExercise(
                    exerciseId: known?.id ?? 'livre-${e.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}',
                    exerciseName: known?.name ?? e.name,
                    targetSets: e.sets,
                    targetReps: e.reps,
                    targetLoadKg: e.loadKg,
                  );
                }(),
            ],
          ),
        ),
      ));
      if (mounted && deps.workoutRepository.listPlans().length > before) _changed(() => m.saved = true);
      return;
    }
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (_) => DocumentFormScreen(
        deps: widget.deps,
        kind: m.kind == AttachKind.exam ? HealthDocumentKind.exam : HealthDocumentKind.prescription,
        initialFile: m.file,
        examReading: m.exam,
        prescriptionReading: m.prescription,
      ),
    ));
    if (!mounted) return;
    final kind = m.kind == AttachKind.exam ? HealthDocumentKind.exam : HealthDocumentKind.prescription;
    final saved = widget.deps.documents.list(kind).any((d) => d.files.any((f) => f.originalName == m.file.name));
    if (saved) _changed(() => m.saved = true);
  }

  void _showResults(List<PipelineResult> results) {
    widget.deps.notifyDataChanged();
    _changed(() {
      for (final r in results) {
        final answer = describeOutcome(widget.deps, r);
        // Escrita confirmada: o próprio cartão já diz "Salvo em …".
        if (answer != 'Pronto, salvo.' && answer != 'Ok, não registrei nada.') _messages.add(_BotMsg(answer));
      }
    });
    _scrollToEnd();
  }

  void _newConversation() {
    for (final m in _messages) {
      if (m is _ProposalMsg) {
        if (!m.decision.isCompleted) m.decision.complete(false);
        m.disposeFields();
      }
    }
    setState(() {
      _messages.clear();
      _conv = BrainConversation.start();
    });
  }

  /// Abre uma conversa guardada para continuar (lista de conversas).
  void _openConversation(BrainConversation c) {
    _newConversation();
    setState(() {
      _conv = c;
      _messages.addAll([for (final m in c.messages) ?_msgFromJson(m)]);
    });
    _scrollToEnd();
  }

  Future<void> _showConversations() async {
    final picked = await Navigator.of(context).push<BrainConversation>(
      MaterialPageRoute(builder: (_) => BrainConversationsScreen(deps: widget.deps, currentId: _conv.id)),
    );
    if (picked == null || !mounted) return;
    if (picked.id == _conv.id) return;
    picked.isEmpty ? _newConversation() : _openConversation(picked);
  }


  Widget _proposal(_ProposalMsg m) {
    final view = describeProposal(widget.deps, m.tool, m.params);
    final pending = m.state == ProposalState.pending || m.state == ProposalState.editing;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: RltSpace.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (view.estimated && pending) ...[
          const RltBadge(RltBadgeKind.estimate, key: Key('proposal_estimate')),
          const SizedBox(height: RltSpace.xs),
        ],
        ProposalCard(
          area: view.area,
          title: view.title,
          detail: view.detail,
          whenLabel: view.when,
          state: m.state,
          savedIn: view.savedIn,
          confirmKey: pending ? const Key('confirmation_confirm') : null,
          discardKey: m.state == ProposalState.pending ? const Key('confirmation_cancel') : null,
          onConfirm: () => _decide(m, true),
          onDiscard: () => _decide(m, false),
          // Só a estimativa da IA se edita aqui; o resto é o que a pessoa
          // disse — se estiver errado, descarta e escreve de novo.
          onEdit: m.editable ? () => _startEdit(m) : null,
          onCancelEdit: () => _cancelEdit(m),
          editor: m.state == ProposalState.editing ? _editor(m) : null,
        ),
      ]),
    );
  }

  Widget _suggestions(_SuggestMsg m) {
    if (m.used) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: RltSpace.s),
      child: Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
        for (final x in m.items)
          ActionChip(
            key: Key('brain_reply_$x'),
            label: Text(x),
            onPressed: () {
              _changed(() => m.used = true);
              _send(x);
            },
          ),
      ]),
    );
  }

  Widget _docCard(_DocMsg m) {
    final t = Theme.of(context).textTheme;
    final c = RltColors.of(context);
    return Card(
      key: Key('brain_doc_${m.kind.name}'),
      margin: const EdgeInsets.symmetric(vertical: RltSpace.s),
      child: Padding(
        padding: const EdgeInsets.all(RltSpace.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(m.kind.icon, size: 20),
            const SizedBox(width: RltSpace.s),
            Expanded(child: Text(m.kind.label.toUpperCase(), style: t.labelSmall?.copyWith(letterSpacing: 0.6))),
            const RltBadge(RltBadgeKind.estimate),
          ]),
          const SizedBox(height: RltSpace.s),
          Text(m.summary, key: Key('brain_doc_summary_${m.kind.name}'), style: t.bodyMedium),
          const SizedBox(height: RltSpace.s),
          Text('${m.model == null ? '' : '${m.model} · '}Confira com o papel antes de salvar. O RLT registra; não diagnostica nem prescreve.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: RltSpace.s),
          if (m.restored && !m.saved)
            Text('Não foi salvo. Anexe de novo para revisar e salvar.', style: t.bodySmall)
          else if (m.saved)
            Row(children: [
              Icon(Icons.check, size: 18, color: c.success),
              const SizedBox(width: 6),
              Text(
                  switch (m.kind) {
                    AttachKind.exam => 'Salvo em Saúde › Exames',
                    AttachKind.mealPlan => 'Salvo em Nutrição › Plano de refeições',
                    AttachKind.workoutPlan => 'Salvo em Exercícios › Academia',
                    _ => 'Salvo em Saúde › Receitas médicas',
                  },
                  style: t.labelLarge?.copyWith(fontSize: 14, color: c.success)),
            ])
          else
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                key: Key('brain_doc_review_${m.kind.name}'),
                onPressed: () => _reviewDocument(m),
                icon: const Icon(Icons.edit_note, size: 18),
                label: const Text('Revisar e salvar'),
              ),
            ),
        ]),
      ),
    );
  }

  Widget _gramsEditor(_ProposalMsg m) {
    final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
    final aiOn = widget.deps.ai.hasKey.value;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DropdownButtonFormField<String>(
        key: const Key('proposal_meal_type'),
        initialValue: m.mealType,
        decoration: const InputDecoration(labelText: 'Refeição', isDense: true),
        items: [
          for (final t in MealType.values) DropdownMenuItem(value: t.wireValue, child: Text(mealTypeLabel(t))),
        ],
        onChanged: (v) => _changed(() => m.mealType = v),
      ),
      const SizedBox(height: RltSpace.s),
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: RltSpace.s),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                key: Key('proposal_name_$i'),
                controller: m.nameFields![i],
                decoration: const InputDecoration(labelText: 'Alimento', isDense: true),
              ),
            ),
            const SizedBox(width: RltSpace.s),
            Expanded(
              flex: 2,
              child: TextField(
                key: Key('proposal_grams_$i'),
                controller: m.gramFields![i],
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: InputDecoration(labelText: 'Quanto', suffixText: items[i]['unit'] == 'ml' ? 'ml' : 'g', isDense: true),
              ),
            ),
          ]),
        ),
      if (aiOn) ...[
        TextField(
          key: const Key('proposal_note'),
          controller: m.noteField,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Observação para a IA',
            hintText: 'Ex.: não comi a borda; tirei a gordura',
            isDense: true,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('proposal_refine'),
            onPressed: m.refining ? null : () => _refine(m),
            icon: m.refining
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('Recalcular com a observação'),
          ),
        ),
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(valueListenable: widget.deps.ai.hasKey, builder: (context, aiOn, _) => _build(context, aiOn));
  }

  Widget _build(BuildContext context, bool aiOn) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final examples = aiOn ? _aiExamples : _examples;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: RltSpace.l, right: RltSpace.xs),
        color: c.surfaceContainer,
        child: Row(children: [
          Icon(aiOn ? Icons.auto_awesome_outlined : Icons.offline_bolt_outlined, size: 18, color: c.onSurfaceVariant),
          const SizedBox(width: RltSpace.s),
          Expanded(
            child: aiOn
                ? Text(
                    'IA ativa · Gemini',
                    key: const Key('brain_ai_notice'),
                    style: t.labelLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : Text(
                    'Modo básico, sem internet. Ative a IA em Conta › Cérebro para entender fotos e texto livre.',
                    key: const Key('brain_basic_notice'),
                    style: t.bodySmall,
                  ),
          ),
          IconButton(
            key: const Key('brain_history'),
            tooltip: 'Conversas',
            onPressed: _showConversations,
            icon: const Icon(Icons.forum_outlined),
          ),
          if (_messages.isNotEmpty)
            IconButton(
              key: const Key('brain_new'),
              tooltip: 'Nova conversa',
              onPressed: _newConversation,
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ]),
      ),
      Expanded(
        child: _messages.isEmpty
            ? ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
                Text(aiOn ? 'Conte o que aconteceu' : 'O que você quer registrar?', style: t.titleLarge),
                const SizedBox(height: RltSpace.s),
                Text(
                    aiOn
                        ? 'Escreva, fale ou mande foto ou PDF. Eu mostro o que entendi e você confirma antes de salvar. '
                          'A IA usa a sua chave; comandos simples funcionam sem internet.'
                        : 'Toque num exemplo ou escreva um comando.',
                    style: t.bodyMedium),
                const SizedBox(height: RltSpace.m),
                Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
                  for (final e in examples)
                    ActionChip(key: Key('brain_example_$e'), label: Text(e), onPressed: () => _send(e)),
                  if (aiOn) ...[
                    ActionChip(
                      key: const Key('brain_example_plate'),
                      avatar: const Icon(Icons.photo_camera_outlined, size: 18),
                      label: const Text('Fotografar meu prato'),
                      onPressed: _plateCamera,
                    ),
                    ActionChip(
                      key: const Key('brain_example_prescription'),
                      avatar: const Icon(Icons.description_outlined, size: 18),
                      label: const Text('Ler uma receita médica'),
                      onPressed: () async {
                        final file = await widget.deps.documentPicker.pickImage();
                        if (file != null && mounted) _stage(AttachKind.prescription, [file]);
                      },
                    ),
                  ],
                ]),
                const SizedBox(height: RltSpace.xl),
                const HealthDisclaimer(),
              ])
            : ListView.builder(
                key: const Key('chat_messages'),
                controller: _scroll,
                padding: const EdgeInsets.all(RltSpace.l),
                itemCount: _messages.length,
                itemBuilder: (context, i) => switch (_messages[i]) {
                  _UserMsg(:final text) => _Bubble(text: text, mine: true, onLongPress: () => _messageMenu(text, mine: true)),
                  // Tocar ou segurar: no anexo, mandar de novo (volta para o
                  // campo, para escrever junto se quiser).
                  _AttachMsg(:final kind, :final file) when file.bytes.isNotEmpty && aiOn =>
                    _AttachBubble(kind: kind, file: file, onMenu: () => _attachMenu(kind, file)),
                  _BotMsg(:final text, :final fromAi, :final model) => _Bubble(
                      text: text, mine: false, disclaimer: fromAi, model: model, onLongPress: () => _messageMenu(text, mine: false)),
                  _AttachMsg(:final kind, :final file) => _AttachBubble(kind: kind, file: file),
                  _VoiceMsg(:final duration) => _VoiceBubble(duration: duration),
                  final _SuggestMsg m => _suggestions(m),
                  final _DocMsg m => _docCard(m),
                  final _ProposalMsg m => _proposal(m),
                },
              ),
      ),
      // "Pensando" só enquanto o app trabalha — não enquanto espera a pessoa
      // decidir um cartão.
      if (_thinking) const LinearProgressIndicator(key: Key('brain_thinking'), minHeight: 2),
      MessageComposer(
        controller: _composer,
        // Com a IA: campo completo (anexos, câmera do prato e voz). Sem ela:
        // só comandos de texto, sem rede.
        mode: aiOn ? ComposerMode.ai : ComposerMode.basic,
        hint: aiOn ? (_pending == null ? 'Escreva ou fale…' : 'Escreva algo sobre o anexo (opcional)') : null,
        attachment: _pending == null ? null : _pendingPreview(_pending!),
        attachKey: const Key('chat_attach'),
        micKey: const Key('chat_mic'),
        onCamera: aiOn && !_thinking ? _plateCamera : null,
        onRecordStart: aiOn && !_thinking ? _voiceStart : null,
        onRecordEnd: _voiceEnd,
        onRecordCancel: _voiceCancel,
        onAttach: aiOn && !_thinking ? _attach : null,
        fieldKey: const Key('chat_input'),
        sendKey: const Key('chat_send'),
        onSend: _send,
      ),
    ]);
  }
}

class _Bubble extends StatelessWidget {
  final String text;
  final bool mine;
  final bool disclaimer;
  final String? model;
  final VoidCallback? onLongPress;
  const _Bubble({required this.text, required this.mine, this.disclaimer = false, this.model, this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        // Na mensagem da pessoa, tocar também abre Copiar / Editar e mandar
        // de novo (segurar não era fácil de descobrir).
        onTap: mine ? onLongPress : null,
        onLongPress: onLongPress,
        child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: mine ? c.primaryContainer : c.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(RltRadius.card),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: mine ? c.onPrimaryContainer : c.onSurface)),
          if (disclaimer) ...[
            const SizedBox(height: 6),
            Text(
              '${model == null ? '' : '$model · '}O RLT registra; não diagnostica nem prescreve.',
              key: const Key('brain_ai_disclaimer'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ]),
        ),
      ),
    );
  }
}

class _AttachBubble extends StatelessWidget {
  final AttachKind kind;
  final PickedDocument file;
  final VoidCallback? onMenu;
  const _AttachBubble({required this.kind, required this.file, this.onMenu});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final isPdf = file.mimeType == 'application/pdf';
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: onMenu,
        onLongPress: onMenu,
        child: Container(
        key: Key('brain_attached_${kind.name}'),
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(RltSpace.s),
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(RltRadius.card)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
          if (!isPdf)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(file.bytes, height: 140, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink()),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(isPdf ? Icons.picture_as_pdf_outlined : kind.icon, size: 16, color: c.onPrimaryContainer),
              const SizedBox(width: 6),
              Flexible(child: Text('${kind.label} · ${file.name}', style: TextStyle(color: c.onPrimaryContainer))),
            ]),
          ),
        ]),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  final Duration duration;
  const _VoiceBubble({required this.duration});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final secs = duration.inSeconds;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        key: const Key('brain_voice_msg'),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(color: c.primaryContainer, borderRadius: BorderRadius.circular(RltRadius.card)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.graphic_eq, size: 20, color: c.onPrimaryContainer),
          const SizedBox(width: 8),
          Text('Mensagem de voz · ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')}',
              style: TextStyle(color: c.onPrimaryContainer)),
        ]),
      ),
    );
  }
}
