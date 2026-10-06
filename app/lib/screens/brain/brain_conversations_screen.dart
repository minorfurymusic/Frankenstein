import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../data/brain_conversations.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/state_views.dart';

/// Lista de conversas do Cérebro (prancheta CerebroConversas): título,
/// o que foi salvo e quando. Tocar abre a conversa para continuar;
/// "Nova conversa" começa outra. Tudo guardado só no celular.
class BrainConversationsScreen extends StatefulWidget {
  final AppDependencies deps;
  final String? currentId;
  const BrainConversationsScreen({super.key, required this.deps, this.currentId});

  @override
  State<BrainConversationsScreen> createState() => _BrainConversationsScreenState();
}

class _BrainConversationsScreenState extends State<BrainConversationsScreen> {
  late List<BrainConversation> _list = widget.deps.conversations.list();

  String _when(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    String two(int v) => v.toString().padLeft(2, '0');
    final diff = today.difference(day).inDays;
    if (diff == 0) return '${two(d.hour)}:${two(d.minute)}';
    if (diff == 1) return 'Ontem';
    if (diff < 7) return const ['Seg.', 'Ter.', 'Qua.', 'Qui.', 'Sex.', 'Sáb.', 'Dom.'][d.weekday - 1];
    return '${two(d.day)}/${two(d.month)}';
  }

  Future<void> _delete(BrainConversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar conversa?'),
        content: const Text('Some só a conversa. O que você confirmou nela continua salvo nas áreas do app.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(key: const Key('conversation_delete_confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    widget.deps.conversations.delete(c.id);
    setState(() => _list = widget.deps.conversations.list());
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Conversas')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('conversation_new'),
        onPressed: () => Navigator.of(context).pop(BrainConversation.start()),
        icon: const Icon(Icons.add),
        label: const Text('Nova conversa'),
      ),
      body: _list.isEmpty
          ? const Padding(
              padding: EdgeInsets.all(RltSpace.l),
              child: StateCard(
                key: Key('conversations_empty'),
                icon: Icons.forum_outlined,
                title: 'Nenhuma conversa ainda',
                message: 'O que você conversar com o Cérebro fica guardado aqui, só no seu celular.',
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, 96),
              itemCount: _list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final conv = _list[i];
                final current = conv.id == widget.currentId;
                return ListTile(
                  key: Key('conversation_${conv.id}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(conv.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: t.titleSmall),
                  subtitle: Text(current ? 'Conversa aberta · ${conv.summary}' : conv.summary,
                      style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(_when(conv.updatedAt), style: t.bodySmall),
                    IconButton(
                      key: Key('conversation_delete_${conv.id}'),
                      tooltip: 'Apagar conversa',
                      onPressed: () => _delete(conv),
                      icon: const Icon(Icons.delete_outline, size: 20),
                    ),
                  ]),
                  onTap: () => Navigator.of(context).pop(conv),
                );
              },
            ),
    );
  }
}
