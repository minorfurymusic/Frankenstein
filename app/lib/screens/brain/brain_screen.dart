import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../data/nutrition_store.dart';
import '../../documents/document_files.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/message_composer.dart';
import '../../widgets/proposal_card.dart';
import '../health/documents_screens.dart';
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
  _BotMsg(this.text, {this.fromAi = false});
  @override
  Map<String, dynamic> toJson() => {'t': 'bot', 'text': text, 'ai': fromAi};
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
  exam('Exame', 'a foto ou o PDF do exame, para ler os valores', Icons.science_outlined);

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
  bool saved;

  /// Reaberta de uma conversa antiga: sem o arquivo nem a leitura.
  final bool restored;
  _DocMsg(this.kind, this.file, this.summary, {this.exam, this.prescription, this.saved = false, this.restored = false});
  @override
  Map<String, dynamic> toJson() => {'t': 'doc', 'kind': kind.name, 'summary': summary, 'saved': saved};
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

  /// Edição de sintoma: intensidade e quando.
  int? intensity;
  DateTime? when;
  _ProposalMsg(this.tool, this.params);

  bool get editable => const {'log_estimated_meal', 'log_water', 'log_symptom'}.contains(tool);

  void disposeFields() {
    for (final c in gramFields ?? const <TextEditingController>[]) {
      c.dispose();
    }
    gramFields = null;
    amountField?.dispose();
    amountField = null;
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
      return _BotMsg(m['text'] as String, fromAi: m['ai'] == true);
    case 'suggest':
      return _SuggestMsg([for (final x in m['items'] as List) x as String], used: true);
    case 'voice':
      return _VoiceMsg(Duration(milliseconds: (m['ms'] as num).toInt()));
    case 'attach':
      return _AttachMsg(kind(), PickedDocument(bytes: Uint8List(0), name: m['name'] as String, mimeType: m['mime'] as String));
    case 'doc':
      return _DocMsg(kind(), PickedDocument(bytes: Uint8List(0), name: '', mimeType: ''), m['summary'] as String,
          saved: m['saved'] == true, restored: true);
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

  @override
  void dispose() {
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
          final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
          m.gramFields = [for (final i in items) TextEditingController(text: formatNumber(i['grams'] as num))];
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
        // Novas gramas: kcal e macros acompanham na proporção (são
        // estimativa para a porção). Item com 0 g sai da refeição.
        final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
        final grams = [for (final c in m.gramFields!) double.tryParse(c.text.trim().replaceAll(',', '.'))];
        if (grams.any((g) => g == null || g < 0) || grams.every((g) => g == 0)) {
          warn('Informe as gramas de cada alimento (0 tira o item).');
          return false;
        }
        final next = <Map<String, dynamic>>[];
        for (var i = 0; i < items.length; i++) {
          final g = grams[i]!;
          if (g == 0) continue;
          final f = g / (items[i]['grams'] as num).toDouble();
          next.add({
            ...items[i],
            'grams': g,
            for (final k in const ['kcal', 'protein_g', 'carbs_g', 'fat_g'])
              if (items[i][k] is num) k: (items[i][k] as num) * f,
          });
        }
        m.params['items'] = next;
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
        _messages.add(_BotMsg(m, fromAi: true));
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
    if (file != null && mounted) await _readAttachment(AttachKind.plate, file);
  }

  Future<void> _attach() async {
    final picked = await showModalBottomSheet<(AttachKind, PickedDocument?)>(
      context: context,
      showDragHandle: true,
      builder: (sheet) {
        final picker = widget.deps.documentPicker;
        Widget source(AttachKind kind, String id, String label, IconData icon, Future<PickedDocument?> Function() pick) =>
            OutlinedButton.icon(
              key: Key('attach_${kind.name}_$id'),
              onPressed: () async {
                final file = await pick();
                if (sheet.mounted) Navigator.of(sheet).pop((kind, file));
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
            for (final kind in AttachKind.values) ...[
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
    if (picked == null || picked.$2 == null || !mounted) return;
    await _readAttachment(picked.$1, picked.$2!);
  }

  /// Lê o anexo com a IA (só depois do consentimento). Prato vira cartão de
  /// refeição estimada; receita e exame viram um resumo com "Revisar e
  /// salvar".
  Future<void> _readAttachment(AttachKind kind, PickedDocument file) async {
    final deps = widget.deps;
    _changed(() => _messages.add(_AttachMsg(kind, file)));
    _scrollToEnd();
    if (!await ensureAiConsent(context, deps, sending: kind.sending)) {
      if (mounted) _changed(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    if (!mounted) return;
    _changed(() => _thinking = true);
    try {
      final client = await deps.ai.client();
      final part = AiPart.file(file.bytes, file.mimeType);
      switch (kind) {
        case AttachKind.plate:
          final estimate = await estimatePlate(client, part);
          if (!mounted) return;
          _changed(() => _thinking = false);
          await _proposePlate(file, estimate);
        case AttachKind.prescription:
          final rx = await readPrescription(client, [part]);
          if (!mounted) return;
          _changed(() {
            _thinking = false;
            _messages.add(_DocMsg(kind, file, describePrescriptionReading(rx), prescription: rx));
          });
        case AttachKind.exam:
          final exam = await readExam(client, [part]);
          if (!mounted) return;
          _changed(() {
            _thinking = false;
            _messages.add(_DocMsg(kind, file, describeExamReading(exam), exam: exam));
          });
      }
    } catch (e) {
      if (!mounted) return;
      _changed(() {
        _thinking = false;
        _messages.add(_BotMsg(aiFailureMessage(e)));
      });
    }
    _scrollToEnd();
  }

  Future<void> _proposePlate(PickedDocument photo, PlateEstimate estimate) async {
    final deps = widget.deps;
    if (estimate.items.isEmpty) {
      _changed(() => _messages.add(_BotMsg('Não reconheci alimentos nesta foto. Tente de cima, com o prato inteiro e boa luz.', fromAi: true)));
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
          Text('Confira com o papel antes de salvar. O RLT registra; não diagnostica nem prescreve.',
              style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          const SizedBox(height: RltSpace.s),
          if (m.restored && !m.saved)
            Text('Não foi salvo. Anexe de novo para revisar e salvar.', style: t.bodySmall)
          else if (m.saved)
            Row(children: [
              Icon(Icons.check, size: 18, color: c.success),
              const SizedBox(width: 6),
              Text(m.kind == AttachKind.exam ? 'Salvo em Saúde › Exames' : 'Salvo em Saúde › Receitas médicas',
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
    return Column(children: [
      for (var i = 0; i < items.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: RltSpace.s),
          child: TextField(
            key: Key('proposal_grams_$i'),
            controller: m.gramFields![i],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            decoration: InputDecoration(labelText: '${items[i]['name']}', suffixText: 'g', isDense: true),
          ),
        ),
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
        padding: const EdgeInsets.symmetric(horizontal: RltSpace.l, vertical: RltSpace.s),
        color: c.surfaceContainer,
        child: Row(children: [
          Icon(aiOn ? Icons.auto_awesome_outlined : Icons.offline_bolt_outlined, size: 18, color: c.onSurfaceVariant),
          const SizedBox(width: RltSpace.s),
          Expanded(
            child: aiOn
                ? Text(
                    'IA ativa (Gemini, com a sua chave). Comandos simples continuam sem internet.',
                    key: const Key('brain_ai_notice'),
                    style: t.bodySmall,
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
            TextButton(key: const Key('brain_new'), onPressed: _newConversation, child: const Text('Nova conversa')),
        ]),
      ),
      Expanded(
        child: _messages.isEmpty
            ? ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
                Text(aiOn ? 'Conte o que aconteceu' : 'O que você quer registrar?', style: t.titleLarge),
                const SizedBox(height: RltSpace.s),
                Text(
                    aiOn
                        ? 'Escreva, fale ou mande foto ou PDF. Eu mostro o que entendi e você confirma antes de salvar.'
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
                        if (file != null && mounted) await _readAttachment(AttachKind.prescription, file);
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
                  _UserMsg(:final text) => _Bubble(text: text, mine: true),
                  _BotMsg(:final text, :final fromAi) => _Bubble(text: text, mine: false, disclaimer: fromAi),
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
        // Com a IA: campo completo (anexos, câmera do prato e voz). Sem ela:
        // só comandos de texto, sem rede.
        mode: aiOn ? ComposerMode.ai : ComposerMode.basic,
        hint: aiOn ? 'Escreva ou fale…' : null,
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
  const _Bubble({required this.text, required this.mine, this.disclaimer = false});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
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
              'O RLT registra; não diagnostica nem prescreve.',
              key: const Key('brain_ai_disclaimer'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: c.onSurfaceVariant),
            ),
          ],
        ]),
      ),
    );
  }
}

class _AttachBubble extends StatelessWidget {
  final AttachKind kind;
  final PickedDocument file;
  const _AttachBubble({required this.kind, required this.file});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final isPdf = file.mimeType == 'application/pdf';
    return Align(
      alignment: Alignment.centerRight,
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
