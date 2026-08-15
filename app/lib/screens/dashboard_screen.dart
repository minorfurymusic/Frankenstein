import 'package:flutter/material.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

/// Resumo do dia — chama `get_daily_summary` direto no [registry] (não
/// passa pelo roteador/chat: é uma tela que carrega dado ao abrir, não
/// uma conversa). `docs/ARQUITETURA.md:81-82`.
class DashboardScreen extends StatefulWidget {
  final ToolRegistry registry;
  const DashboardScreen({super.key, required this.registry});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _summary;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final now = DateTime.now().toUtc();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final date = '${now.year}-$month-$day';

    final result = await widget.registry.execute('get_daily_summary', {'date': date});
    if (!mounted) return;
    setState(() {
      if (result.success) {
        _summary = result.data;
      } else {
        _error = result.error;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    if (error != null) {
      return Center(child: Text('Não deu pra carregar o resumo: $error'));
    }
    final summary = _summary;
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final steps = summary['steps'] as Map<String, dynamic>;
    final meals = summary['meals'] as Map<String, dynamic>;
    final workouts = summary['workouts'] as Map<String, dynamic>;
    final runs = summary['runs'] as Map<String, dynamic>;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        key: const Key('dashboard_list'),
        padding: const EdgeInsets.all(16),
        children: [
          _SummaryCard(
            key: const Key('dashboard_steps'),
            label: 'Passos',
            value: '${steps['total']}',
          ),
          _SummaryCard(
            key: const Key('dashboard_meals'),
            label: 'Refeições',
            value: '${meals['count']} (${meals['total_energy_kcal']} kcal)',
          ),
          _SummaryCard(
            key: const Key('dashboard_workouts'),
            label: 'Treinos',
            value: '${workouts['count']} (${workouts['total_sets']} séries)',
          ),
          _SummaryCard(
            key: const Key('dashboard_runs'),
            label: 'Corridas',
            value: '${runs['count']} (${runs['total_distance_meters']} m)',
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryCard({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(value),
      ),
    );
  }
}
