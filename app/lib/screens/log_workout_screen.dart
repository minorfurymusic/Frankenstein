import 'package:flutter/material.dart';
import 'package:frankstein_brain/brain.dart';

import '../app_dependencies.dart';

/// Registro de treino por formulário, em vez de digitar o comando de
/// chat inteiro na mão. Mesma simplificação já registrada em
/// `chat_router.dart` (`exercise_name = exercise_id` — um campo de texto
/// plano não distingue os dois sem ambiguidade) e mesma lógica: monta o
/// texto `registrar treino: id 1xREPSxKG, id 2xREPSxKG, ...` (uma
/// entrada por série, todas com a mesma repetição/carga — quem quiser
/// séries diferentes ainda pode usar o chat direto) e manda pro mesmo
/// `BrainPipeline.handle`, reaproveitando a confirmação existente.
class LogWorkoutScreen extends StatefulWidget {
  final AppDependencies dependencies;
  const LogWorkoutScreen({super.key, required this.dependencies});

  @override
  State<LogWorkoutScreen> createState() => _LogWorkoutScreenState();
}

class _LogWorkoutScreenState extends State<LogWorkoutScreen> {
  final _exerciseController = TextEditingController();
  final _setsController = TextEditingController(text: '3');
  final _repsController = TextEditingController(text: '10');
  final _loadController = TextEditingController(text: '20');
  bool _sending = false;

  @override
  void dispose() {
    _exerciseController.dispose();
    _setsController.dispose();
    _repsController.dispose();
    _loadController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final exerciseId = _exerciseController.text.trim();
    final sets = int.tryParse(_setsController.text.trim());
    final reps = int.tryParse(_repsController.text.trim());
    final load = double.tryParse(_loadController.text.trim());

    if (exerciseId.isEmpty || sets == null || sets <= 0 || reps == null || load == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha exercício, séries, repetições e carga')),
      );
      return;
    }

    final setEntries =
        List.generate(sets, (i) => '$exerciseId ${i + 1}x${reps}x$load').join(', ');
    final command = 'registrar treino: $setEntries';

    setState(() => _sending = true);
    final result = await widget.dependencies.pipeline.handle(command);
    if (!mounted) return;
    setState(() => _sending = false);

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
      appBar: AppBar(title: const Text('Registrar treino')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              key: const Key('log_workout_exercise_field'),
              controller: _exerciseController,
              decoration: const InputDecoration(labelText: 'Id do exercício'),
            ),
            TextField(
              key: const Key('log_workout_sets_field'),
              controller: _setsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Séries'),
            ),
            TextField(
              key: const Key('log_workout_reps_field'),
              controller: _repsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Repetições por série'),
            ),
            TextField(
              key: const Key('log_workout_load_field'),
              controller: _loadController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Carga (kg)'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('log_workout_submit_button'),
              onPressed: _sending ? null : _submit,
              child: const Text('Registrar'),
            ),
          ],
        ),
      ),
    );
  }
}
