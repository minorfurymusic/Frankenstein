import 'package:flutter/material.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../app_dependencies.dart';

/// Registro de refeição por busca + toque, em vez de digitar o comando
/// de chat inteiro na mão. Não duplica a lógica de `log_meal`: monta o
/// mesmo texto que `chat_router.dart` (`registrar refeição TIPO: id
/// gramasg`) e manda pro mesmo `BrainPipeline.handle` — a confirmação
/// que aparece é literalmente `AppConfirmationGate`, o mesmo diálogo do
/// chat (`.claude/rules/brain.md`, passo 4).
class LogMealScreen extends StatefulWidget {
  final AppDependencies dependencies;
  const LogMealScreen({super.key, required this.dependencies});

  @override
  State<LogMealScreen> createState() => _LogMealScreenState();
}

class _LogMealScreenState extends State<LogMealScreen> {
  final _searchController = TextEditingController();
  List<Food> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    setState(() {
      _results = query.trim().isEmpty
          ? []
          : widget.dependencies.foodRepository.searchByName(query.trim());
    });
  }

  Future<void> _openLogDialog(Food food) async {
    final gramsController = TextEditingController(text: '100');
    var mealType = 'lunch';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(food.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('log_meal_grams_field'),
                controller: gramsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Gramas'),
              ),
              DropdownButton<String>(
                key: const Key('log_meal_type_dropdown'),
                value: mealType,
                items: const [
                  DropdownMenuItem(value: 'breakfast', child: Text('Café da manhã')),
                  DropdownMenuItem(value: 'lunch', child: Text('Almoço')),
                  DropdownMenuItem(value: 'dinner', child: Text('Jantar')),
                  DropdownMenuItem(value: 'snack', child: Text('Lanche')),
                ],
                onChanged: (value) => setDialogState(() => mealType = value!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              key: const Key('log_meal_confirm_button'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    final grams = double.tryParse(gramsController.text.trim());
    if (grams == null || grams <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gramas inválidas')),
      );
      return;
    }

    final command = 'registrar refeição $mealType: ${food.id} ${grams}g';
    final result = await widget.dependencies.pipeline.handle(command);
    if (!mounted) return;

    switch (result.outcome) {
      case PipelineOutcome.executed:
        if (result.toolResult!.success) {
          Navigator.of(context).pop(true);
          return;
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Falhou: ${result.toolResult!.error}')));
      case PipelineOutcome.abortedByUser:
        break;
      case PipelineOutcome.rejected:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Parâmetros inválidos: ${result.validationErrors!.join('; ')}')),
        );
      case PipelineOutcome.unresolved:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comando não reconhecido')),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar refeição')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('log_meal_search_field'),
              controller: _searchController,
              onChanged: _search,
              decoration: const InputDecoration(
                labelText: 'Buscar alimento',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              key: const Key('log_meal_results'),
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final food = _results[index];
                return ListTile(
                  key: Key('log_meal_result_${food.id}'),
                  title: Text(food.name),
                  subtitle: Text('${food.energyKcalPer100g.toStringAsFixed(0)} kcal/100g'),
                  onTap: () => _openLogDialog(food),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
