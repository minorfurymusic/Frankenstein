import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';

import '../app_dependencies.dart';
import '../format.dart';
import '../theme/rlt_theme.dart';
import '../widgets/record_actions.dart';
import '../widgets/state_views.dart';

/// Como um tipo de registro aparece e qual número se edita.
class RecordKind {
  final HealthEventType type;
  final String Function(HealthEvent e) title;

  /// Campo numérico editável (`payload[key]`), ou `null` (só excluir).
  final (String label, String key, String? unit)? editable;
  final bool Function(HealthEvent e) include;
  const RecordKind(this.type, this.title, {this.editable, this.include = _all});
  static bool _all(HealthEvent _) => true;
}

/// Registros recentes (90 dias) com editar e excluir — correção, não
/// apagamento (append-only, `.claude/rules/datacore.md`).
class RecordsScreen extends StatelessWidget {
  final AppDependencies deps;
  final String title;
  final List<RecordKind> kinds;
  const RecordsScreen({super.key, required this.deps, required this.title, required this.kinds});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) {
          final from = DateTime.now().toUtc().subtract(const Duration(days: 90));
          final rows = [
            for (final k in kinds)
              for (final e in deps.core.queryByType(k.type, from: from).where(k.include)) (k, e),
          ]..sort((a, b) => b.$2.occurredAt.compareTo(a.$2.occurredAt));
          if (rows.isEmpty) {
            return ListView(padding: const EdgeInsets.all(RltSpace.l), children: const [
              StateCard(icon: Icons.history, title: 'Nada registrado', message: 'Os registros dos últimos 90 dias aparecem aqui.'),
            ]);
          }
          return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
            for (final (k, e) in rows)
              ListTile(
                key: Key('record_${e.rootId}'),
                contentPadding: EdgeInsets.zero,
                title: Text(k.title(e), style: t.bodyLarge),
                subtitle: Text(relativeDayTime(localOf(e.occurredAt, e.occurredAtTzOffsetMinutes))),
                trailing: RecordMenu(
                  keyPrefix: 'record_${e.rootId}',
                  what: 'este registro',
                  onEdit: k.editable == null
                      ? null
                      : () async {
                          final (label, key, unit) = k.editable!;
                          final v = await askNumbers(context, label, [(label, (e.payload[key] as num).toDouble(), unit)]);
                          if (v == null || v.first <= 0) return;
                          deps.core.editEvent(e.id, payload: {...e.payload, key: v.first});
                          deps.notifyDataChanged();
                        },
                  onDelete: () {
                    deps.core.deleteEvent(e.id);
                    deps.notifyDataChanged();
                  },
                ),
              ),
          ]);
        },
      ),
    );
  }
}
