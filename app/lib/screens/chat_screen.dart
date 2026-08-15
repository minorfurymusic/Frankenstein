import 'package:flutter/material.dart';
import 'package:frankstein_brain/brain.dart';

class ChatMessage {
  final bool fromUser;
  final String text;
  ChatMessage({required this.fromUser, required this.text});
}

/// Chat com o cérebro (`docs/ARQUITETURA.md`: "UI única: chat +
/// dashboards"). Texto livre -> `BrainPipeline` -> roteador
/// determinístico (`chat_router.dart`) -> confirmação (se escrita) ->
/// execução. Sem LLM real nesta fase — texto fora do formato reconhecido
/// pelo roteador fica `unresolved`, não é escondido como se tivesse
/// funcionado.
class ChatScreen extends StatefulWidget {
  final BrainPipeline pipeline;
  const ChatScreen({super.key, required this.pipeline});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _messages.add(ChatMessage(fromUser: true, text: text));
      _sending = true;
    });
    _controller.clear();

    final result = await widget.pipeline.handle(text);
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(fromUser: false, text: _describe(result)));
      _sending = false;
    });
  }

  String _describe(PipelineResult result) {
    switch (result.outcome) {
      case PipelineOutcome.unresolved:
        return 'Não entendi. Tente "resumo de hoje" ou "quantos passos hoje".';
      case PipelineOutcome.rejected:
        return 'Parâmetros inválidos: ${result.validationErrors!.join('; ')}';
      case PipelineOutcome.abortedByUser:
        return 'Ok, não registrei nada.';
      case PipelineOutcome.executed:
        final toolResult = result.toolResult!;
        if (!toolResult.success) return 'Falhou: ${toolResult.error}';
        return '${result.toolName} → ${toolResult.data}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            key: const Key('chat_messages'),
            padding: const EdgeInsets.all(8),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return Align(
                alignment: message.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: message.fromUser
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(message.text),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('chat_input'),
                  controller: _controller,
                  enabled: !_sending,
                  onSubmitted: (_) => _send(),
                  decoration: const InputDecoration(hintText: 'Digite um comando...'),
                ),
              ),
              IconButton(
                key: const Key('chat_send'),
                icon: const Icon(Icons.send),
                onPressed: _sending ? null : _send,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
