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
import 'brain_text.dart';

sealed class _Msg {}

class _UserMsg extends _Msg {
  final String text;
  _UserMsg(this.text);
}

class _BotMsg extends _Msg {
  final String text;

  /// Resposta da IA: leva o aviso de que o app não diagnostica nem prescreve.
  final bool fromAi;
  _BotMsg(this.text, {this.fromAi = false});
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
}

class _AttachMsg extends _Msg {
  final AttachKind kind;
  final PickedDocument file;
  _AttachMsg(this.kind, this.file);
}

/// Receita ou exame lido: resumo e "Revisar e salvar" (abre o formulário já
/// preenchido; nada é salvo sem o "Salvar" de lá).
class _DocMsg extends _Msg {
  final AttachKind kind;
  final PickedDocument file;
  final String summary;
  final ExamReading? exam;
  final PrescriptionReading? prescription;
  bool saved = false;
  _DocMsg(this.kind, this.file, this.summary, {this.exam, this.prescription});
}

class _ProposalMsg extends _Msg {
  final String tool;

  /// Os mesmos parâmetros que o pipeline executa: editar o cartão muda
  /// este mapa, e o registro valida de novo antes de gravar.
  final Map<String, dynamic> params;
  final Completer<bool> decision = Completer();
  ProposalState state = ProposalState.pending;
  List<TextEditingController>? gramFields;
  _ProposalMsg(this.tool, this.params);

  bool get editable => tool == 'log_estimated_meal';

  void disposeFields() {
    for (final c in gramFields ?? const <TextEditingController>[]) {
      c.dispose();
    }
    gramFields = null;
  }
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
  final _scroll = ScrollController();
  /// Esperando a IA responder. Cartões pendentes não travam o campo: a
  /// pessoa pode mandar outra mensagem e decidir os cartões depois.
  bool _thinking = false;

  static const _examples = ['registrar água 500ml', 'resumo de hoje', 'quantos passos hoje', 'buscar alimento arroz'];
  static const _aiExamples = [
    'bebi 2 L de água, comi 3 ovos e tomei dipirona às 9h',
    'pressão 12 por 8 agora de manhã',
    'pesei 81,4 kg hoje',
    'resumo de hoje',
  ];

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
    setState(() => _messages.add(msg));
    _scrollToEnd();
    return msg.decision.future;
  }

  void _decide(_ProposalMsg m, bool ok) {
    if (m.decision.isCompleted) return;
    if (ok && m.state == ProposalState.editing && !_applyEdit(m)) return;
    m.disposeFields();
    setState(() => m.state = ok ? ProposalState.confirmed : ProposalState.discarded);
    m.decision.complete(ok);
  }

  void _startEdit(_ProposalMsg m) {
    final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
    setState(() {
      m.gramFields = [for (final i in items) TextEditingController(text: formatNumber(i['grams'] as num))];
      m.state = ProposalState.editing;
    });
  }

  void _cancelEdit(_ProposalMsg m) {
    m.disposeFields();
    setState(() => m.state = ProposalState.pending);
  }

  /// Novas gramas: kcal e macros acompanham na proporção (são estimativa
  /// para a porção). Item com 0 g sai da refeição.
  bool _applyEdit(_ProposalMsg m) {
    final items = (m.params['items'] as List).cast<Map<String, dynamic>>();
    final grams = [for (final c in m.gramFields!) double.tryParse(c.text.trim().replaceAll(',', '.'))];
    if (grams.any((g) => g == null || g < 0) || grams.every((g) => g == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Informe as gramas de cada alimento (0 tira o item).')));
      return false;
    }
    final next = <Map<String, dynamic>>[];
    for (var i = 0; i < items.length; i++) {
      final g = grams[i]!;
      if (g == 0) continue;
      final old = (items[i]['grams'] as num).toDouble();
      final f = g / old;
      next.add({
        ...items[i],
        'grams': g,
        for (final k in const ['kcal', 'protein_g', 'carbs_g', 'fat_g'])
          if (items[i][k] is num) k: (items[i][k] as num) * f,
      });
    }
    m.params['items'] = next;
    return true;
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send(String text) async {
    if (_thinking) return;
    final deps = widget.deps;
    setState(() => _messages.add(_UserMsg(text)));
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
      if (mounted) setState(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    if (!mounted) return;
    setState(() => _thinking = true);
    ToolCallPlan plan;
    try {
      plan = await ask(AiToolCaller(client: deps.ai.client, medications: deps.medicationRepository.listAll));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(_BotMsg(e is AiException && e.failure == AiFailure.invalidOutput
            ? 'Não entendi. Tente uma frase por registro, como "bebi 500 ml de água" ou "comi 2 ovos no café".'
            : aiFailureMessage(e)));
      });
      _scrollToEnd();
      return;
    }
    if (!mounted) return;
    setState(() {
      _thinking = false;
      for (final m in plan.messages) {
        _messages.add(_BotMsg(m, fromAi: true));
      }
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
          setState(() => _messages.add(_BotMsg('Para falar com o Cérebro, permita o microfone. '
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
      setState(() => _messages.add(_BotMsg('Segure o botão do microfone enquanto fala.')));
      return;
    }
    setState(() => _messages.add(_VoiceMsg(audio.duration)));
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
    setState(() => _messages.add(_AttachMsg(kind, file)));
    _scrollToEnd();
    if (!await ensureAiConsent(context, deps, sending: kind.sending)) {
      if (mounted) setState(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    if (!mounted) return;
    setState(() => _thinking = true);
    try {
      final client = await deps.ai.client();
      final part = AiPart.file(file.bytes, file.mimeType);
      switch (kind) {
        case AttachKind.plate:
          final estimate = await estimatePlate(client, part);
          if (!mounted) return;
          setState(() => _thinking = false);
          await _proposePlate(file, estimate);
        case AttachKind.prescription:
          final rx = await readPrescription(client, [part]);
          if (!mounted) return;
          setState(() {
            _thinking = false;
            _messages.add(_DocMsg(kind, file, describePrescriptionReading(rx), prescription: rx));
          });
        case AttachKind.exam:
          final exam = await readExam(client, [part]);
          if (!mounted) return;
          setState(() {
            _thinking = false;
            _messages.add(_DocMsg(kind, file, describeExamReading(exam), exam: exam));
          });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _thinking = false;
        _messages.add(_BotMsg(aiFailureMessage(e)));
      });
    }
    _scrollToEnd();
  }

  Future<void> _proposePlate(PickedDocument photo, PlateEstimate estimate) async {
    final deps = widget.deps;
    if (estimate.items.isEmpty) {
      setState(() => _messages.add(_BotMsg('Não reconheci alimentos nesta foto. Tente de cima, com o prato inteiro e boa luz.', fromAi: true)));
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
    if (saved) setState(() => m.saved = true);
  }

  void _showResults(List<PipelineResult> results) {
    widget.deps.notifyDataChanged();
    setState(() {
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
    setState(_messages.clear);
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
          editor: m.state == ProposalState.editing ? _gramsEditor(m) : null,
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
          if (m.saved)
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
          if (_messages.isNotEmpty)
            TextButton(key: const Key('brain_new'), onPressed: _newConversation, child: const Text('Nova conversa')),
        ]),
      ),
      Expanded(
        child: _messages.isEmpty
            ? ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
                Text('O que você quer registrar?', style: t.titleLarge),
                const SizedBox(height: RltSpace.s),
                Text(aiOn ? 'Escreva do seu jeito: cada registro vira um cartão para você conferir.' : 'Toque num exemplo ou escreva um comando.',
                    style: t.bodyMedium),
                const SizedBox(height: RltSpace.m),
                Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
                  for (final e in examples)
                    ActionChip(key: Key('brain_example_$e'), label: Text(e), onPressed: () => _send(e)),
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
