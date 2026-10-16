import 'package:flutter/material.dart';

import '../format.dart';

/// Menu "Editar / Excluir" de um registro. Excluir pede confirmação.
class RecordMenu extends StatelessWidget {
  final String keyPrefix;
  final String what;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  const RecordMenu({super.key, required this.keyPrefix, required this.what, this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      key: Key('${keyPrefix}_menu'),
      tooltip: 'Editar ou excluir',
      onSelected: (v) async {
        if (v == 'edit') {
          onEdit?.call();
        } else if (await confirmDelete(context, what)) {
          onDelete();
        }
      },
      itemBuilder: (_) => [
        if (onEdit != null) PopupMenuItem(key: Key('${keyPrefix}_edit'), value: 'edit', child: const Text('Editar')),
        PopupMenuItem(key: Key('${keyPrefix}_delete'), value: 'delete', child: const Text('Excluir')),
      ],
    );
  }
}

Future<bool> confirmDelete(BuildContext context, String what) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('Excluir $what?'),
        content: const Text('Some das telas e das contas. Fica só no histórico da exportação.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(key: const Key('confirm_delete'), onPressed: () => Navigator.pop(c, true), child: const Text('Excluir')),
        ],
      ),
    ) ??
    false;

/// Pede um ou mais números (ex.: carga e repetições). Devolve `null` se cancelar.
Future<List<double>?> askNumbers(BuildContext context, String title, List<(String label, double value, String? suffix)> fields) {
  final controllers = [for (final f in fields) TextEditingController(text: formatNumber(f.$2, decimals: f.$2 % 1 == 0 ? 0 : 1))];
  return showDialog<List<double>>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (var i = 0; i < fields.length; i++)
          TextField(
            key: Key('edit_field_$i'),
            controller: controllers[i],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: fields[i].$1, suffixText: fields[i].$3),
          ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('edit_save'),
          onPressed: () {
            final values = [for (final t in controllers) parseNumber(t.text)];
            if (values.every((v) => v != null && v >= 0)) Navigator.pop(c, values.cast<double>());
          },
          child: const Text('Salvar'),
        ),
      ],
    ),
  );
}
