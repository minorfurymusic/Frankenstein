import 'dart:async';

import 'package:flutter/material.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import '../../app_dependencies.dart';
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
  _BotMsg(this.text);
}

class _ProposalMsg extends _Msg {
  final ProposalView view;
  final Completer<bool> decision = Completer();
  ProposalState state = ProposalState.pending;
  _ProposalMsg(this.view);
}

/// Cérebro (pranchetas CerebroChat, CerebroEstados): conversa em que cada
/// registro entendido vira um cartão de proposta — nada é gravado antes do
/// "Confirmar" (`.claude/rules/brain.md`). Sem chave de IA (ADR-11) roda o
/// modo básico: só os comandos do roteador determinístico, sem rede.
class BrainScreen extends StatefulWidget {
  final AppDependencies deps;
  const BrainScreen({super.key, required this.deps});

  @override
  State<BrainScreen> createState() => _BrainScreenState();
}

class _BrainScreenState extends State<BrainScreen> {
  final _messages = <_Msg>[];
  final _scroll = ScrollController();
  bool _sending = false;

  static const _examples = ['registrar água 500ml', 'resumo de hoje', 'quantos passos hoje', 'buscar alimento arroz'];

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
      if (m is _ProposalMsg && !m.decision.isCompleted) m.decision.complete(false);
    }
    _scroll.dispose();
    super.dispose();
  }

  Future<bool> _present(ToolSpec spec, Map<String, dynamic> params) {
    final msg = _ProposalMsg(describeProposal(widget.deps, spec.name, params));
    setState(() => _messages.add(msg));
    _scrollToEnd();
    return msg.decision.future;
  }

  void _decide(_ProposalMsg m, bool ok) {
    if (m.decision.isCompleted) return;
    setState(() => m.state = ok ? ProposalState.confirmed : ProposalState.discarded);
    m.decision.complete(ok);
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    });
  }

  Future<void> _send(String text) async {
    if (_sending) return;
    setState(() {
      _messages.add(_UserMsg(text));
      _sending = true;
    });
    _scrollToEnd();
    final result = await widget.deps.pipeline.handle(text);
    if (!mounted) return;
    final answer = describeOutcome(widget.deps, result);
    widget.deps.notifyDataChanged();
    setState(() {
      // Escrita confirmada: o próprio cartão já diz "Salvo em …".
      if (answer != 'Pronto, salvo.' && answer != 'Ok, não registrei nada.') _messages.add(_BotMsg(answer));
      _sending = false;
    });
    _scrollToEnd();
  }

  void _newConversation() {
    for (final m in _messages) {
      if (m is _ProposalMsg && !m.decision.isCompleted) m.decision.complete(false);
    }
    setState(_messages.clear);
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Column(children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: RltSpace.l, vertical: RltSpace.s),
        color: c.surfaceContainer,
        child: Row(children: [
          Icon(Icons.offline_bolt_outlined, size: 18, color: c.onSurfaceVariant),
          const SizedBox(width: RltSpace.s),
          Expanded(
            child: Text(
              // TODO(frankstein): IA em nuvem com a chave do usuário (ADR-11) — escolha de provedor pendente; até lá, só modo básico.
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
                Text('Toque num exemplo ou escreva um comando.', style: t.bodyMedium),
                const SizedBox(height: RltSpace.m),
                Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
                  for (final e in _examples)
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
                  _BotMsg(:final text) => _Bubble(text: text, mine: false),
                  final _ProposalMsg m => Padding(
                      padding: const EdgeInsets.symmetric(vertical: RltSpace.s),
                      child: ProposalCard(
                        area: m.view.area,
                        title: m.view.title,
                        detail: m.view.detail,
                        state: m.state,
                        savedIn: m.view.savedIn,
                        confirmKey: m.state == ProposalState.pending ? const Key('confirmation_confirm') : null,
                        discardKey: m.state == ProposalState.pending ? const Key('confirmation_cancel') : null,
                        onConfirm: () => _decide(m, true),
                        onDiscard: () => _decide(m, false),
                        // Editar a proposta antes de confirmar entra com a IA (o
                        // modo básico só monta propostas a partir de comandos exatos).
                        onEdit: null,
                      ),
                    ),
                },
              ),
      ),
      // "Pensando" só enquanto o app trabalha — não enquanto espera a pessoa
      // decidir um cartão.
      if (_sending && !_messages.any((m) => m is _ProposalMsg && m.state == ProposalState.pending))
        const LinearProgressIndicator(minHeight: 2),
      MessageComposer(
        mode: ComposerMode.basic,
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
  const _Bubble({required this.text, required this.mine});

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
        child: Text(text, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: mine ? c.onPrimaryContainer : c.onSurface)),
      ),
    );
  }
}
