import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import '../../ai/ai_consent.dart';
import '../../ai/ai_settings.dart';
import '../../ai/brain_ai.dart';
import '../../app_dependencies.dart';
import '../../format.dart';
import '../../confirmation_gate.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/message_composer.dart';
import '../../widgets/proposal_card.dart';
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

    if (!await ensureAiConsent(context, deps, sending: 'a sua mensagem')) {
      if (mounted) setState(() => _messages.add(_BotMsg('Ok, não enviei nada.')));
      return;
    }
    setState(() => _thinking = true);
    ToolCallPlan plan;
    try {
      final caller = AiToolCaller(client: deps.ai.client, medications: deps.medicationRepository.listAll);
      plan = await caller.plan(text, deps.registry.specs);
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
                  final _ProposalMsg m => _proposal(m),
                },
              ),
      ),
      // "Pensando" só enquanto o app trabalha — não enquanto espera a pessoa
      // decidir um cartão.
      if (_thinking) const LinearProgressIndicator(key: Key('brain_thinking'), minHeight: 2),
      MessageComposer(
        mode: ComposerMode.basic,
        hint: aiOn ? 'Escreva o que comeu, bebeu, tomou ou sentiu' : null,
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
