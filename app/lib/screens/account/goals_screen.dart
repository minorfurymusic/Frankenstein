import 'package:flutter/material.dart';
import 'package:frankstein_profile/profile.dart';

import '../../app_dependencies.dart';
import '../../data/day_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/progress.dart';
import '../../widgets/state_views.dart';
import 'profile_screen.dart';

/// Conta › Metas (pranchetas ContaMetas e DietaMetas): a meta do dia com o
/// caminho do cálculo ("de onde veio o número", ADR-15) e ajuste manual de
/// cada uma.
class GoalsScreen extends StatelessWidget {
  final AppDependencies deps;
  const GoalsScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Metas')),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) {
          final missing = deps.goals.missing();
          if (missing != null) {
            return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
              StateCard(
                icon: Icons.flag_outlined,
                title: 'Preencha seu perfil',
                message: missing == GoalsMissing.profile
                    ? 'As metas são calculadas com sexo biológico, nascimento, altura e peso.'
                    : 'Falta o peso para calcular as metas.',
                actionLabel: 'Abrir perfil',
                onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(deps: deps))),
              ),
            ]);
          }
          final g = deps.goals.goalsFor(DateTime.now())!;
          return _GoalsBody(deps: deps, goals: g);
        },
      ),
    );
  }
}

class _GoalsBody extends StatelessWidget {
  final AppDependencies deps;
  final DailyGoals goals;
  const _GoalsBody({required this.deps, required this.goals});

  String _kcal(double v) => '${formatNumber(v)} kcal';

  Future<void> _edit(BuildContext context, String label, String unit, double current, GoalOverrides Function(double?) apply) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _GoalEditDialog(label: label, unit: unit, initial: formatNumber(current)),
    );
    if (result == null) return;
    deps.profileRepository.saveOverrides(apply(result.value));
    deps.notifyDataChanged();
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final o = deps.profileRepository.loadOverrides();
    final p = deps.profileRepository.load()!;
    Widget row(String label, String value, {String? keyName, bool manual = false, VoidCallback? onTap}) => ListTile(
          key: keyName == null ? null : Key(keyName),
          contentPadding: EdgeInsets.zero,
          title: Text(label, style: t.bodyLarge),
          subtitle: manual ? Text('Ajustada por você', style: t.bodySmall?.copyWith(color: c.tertiary)) : null,
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(value, style: RltTheme.tabular(t.titleSmall!)),
            if (onTap != null) ...[const SizedBox(width: 8), Icon(Icons.edit_outlined, size: 18, color: c.onSurfaceVariant)],
          ]),
          onTap: onTap,
        );
    GoalOverrides copy({
      Object? cal = _keep,
      Object? prot = _keep,
      Object? fat = _keep,
      Object? carb = _keep,
      Object? water = _keep,
      Object? fiber = _keep,
    }) =>
        GoalOverrides(
          caloriesKcal: identical(cal, _keep) ? o.caloriesKcal : cal as double?,
          proteinGrams: identical(prot, _keep) ? o.proteinGrams : prot as double?,
          fatGrams: identical(fat, _keep) ? o.fatGrams : fat as double?,
          carbsGrams: identical(carb, _keep) ? o.carbsGrams : carb as double?,
          waterMl: identical(water, _keep) ? o.waterMl : water as double?,
          fiberGrams: identical(fiber, _keep) ? o.fiberGrams : fiber as double?,
        );
    String pct(double share) => '${(share * 100).round()}%';

    return ListView(
      padding: const EdgeInsets.all(RltSpace.l),
      children: [
        const RltSectionHeader('Hoje'),
        row('Calorias', _kcal(goals.caloriesKcal),
            keyName: 'goal_calories',
            manual: goals.manual.contains('calories'),
            onTap: () => _edit(context, 'calorias', 'kcal', goals.caloriesKcal, (v) => copy(cal: v))),
        row('Proteína · ${pct(goals.proteinShare)}', '${formatNumber(goals.proteinGrams)} g',
            manual: goals.manual.contains('protein'),
            onTap: () => _edit(context, 'proteína', 'g', goals.proteinGrams, (v) => copy(prot: v))),
        row('Carboidrato · ${pct(goals.carbsShare)}', '${formatNumber(goals.carbsGrams)} g',
            manual: goals.manual.contains('carbs'),
            onTap: () => _edit(context, 'carboidrato', 'g', goals.carbsGrams, (v) => copy(carb: v))),
        row('Gordura · ${pct(goals.fatShare)}', '${formatNumber(goals.fatGrams)} g',
            manual: goals.manual.contains('fat'),
            onTap: () => _edit(context, 'gordura', 'g', goals.fatGrams, (v) => copy(fat: v))),
        row('Água para beber', '${formatNumber(goals.waterMl)} ml',
            keyName: 'goal_water',
            manual: goals.manual.contains('water'),
            onTap: () => _edit(context, 'água', 'ml', goals.waterMl, (v) => copy(water: v))),
        row('Fibra', '${formatNumber(goals.fiberGrams)} g',
            keyName: 'goal_fiber',
            manual: goals.manual.contains('fiber'),
            onTap: () => _edit(context, 'fibra', 'g', goals.fiberGrams, (v) => copy(fiber: v))),
        row('Passos', formatNumber(goals.stepsGoal)),
        const RltSectionHeader('De onde veio a meta de calorias'),
        row('Gasto em repouso (${goals.basalFormula})', _kcal(goals.basalKcal)),
        row('Dia a dia parado (× 1,2)', _kcal(goals.baseKcal)),
        if (p.objective != Objective.maintain)
          row(
            p.objective == Objective.lose ? 'Perder ${formatNumber(p.rateGramsPerDay)} g/dia' : 'Ganhar ${formatNumber(p.rateGramsPerDay)} g/dia',
            '${goals.objectiveAdjustmentKcal >= 0 ? '+' : '−'}${_kcal(goals.objectiveAdjustmentKcal.abs())}',
          ),
        row('Passos de hoje', '+${_kcal(goals.stepsKcal)}'),
        row('Exercícios de hoje', '+${_kcal(goals.exerciseKcal)}'),
        if (goals.belowBasal)
          Text('A meta está abaixo do seu gasto em repouso. Você decide; o app só informa.', style: t.bodySmall),
        const SizedBox(height: RltSpace.s),
        Text(
          'A meta sobe ao longo do dia conforme você caminha e treina. '
          'Proteína: ${formatNumber(goals.proteinPerKg, decimals: 1)} g por kg — sobe com academia, em dieta e se você '
          'pedir mais proteína (Conta › Perfil). Gordura: 30% das calorias. Carboidrato: o restante, por isso cai na '
          'dieta. Fibra: 14 g por 1.000 kcal, no mínimo 25 g — só alimento vegetal tem fibra (feijão, lentilha, grão-de-bico '
          'contam; carne, ovo e whey não) e ela já está dentro do carboidrato. As faixas de referência são proteína '
          '10–35%, gordura 20–35% e carboidrato 45–65% das calorias; o app mostra, não trava. Água: 35 ml por kg, com '
          'mínimo da EFSA por sexo; 80% para beber.',
          style: t.bodySmall,
        ),
        const SizedBox(height: RltSpace.l),
        OutlinedButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(deps: deps))),
          child: const Text('Editar perfil'),
        ),
      ],
    );
  }
}

const Object _keep = Object();

/// Valor novo, ou `null` = voltar ao calculado.
class _EditResult {
  final double? value;
  const _EditResult(this.value);
}

/// O diálogo é dono do próprio campo: o controlador só é descartado quando
/// o diálogo termina de fechar.
class _GoalEditDialog extends StatefulWidget {
  final String label;
  final String unit;
  final String initial;
  const _GoalEditDialog({required this.label, required this.unit, required this.initial});

  @override
  State<_GoalEditDialog> createState() => _GoalEditDialogState();
}

class _GoalEditDialogState extends State<_GoalEditDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Ajustar ${widget.label}'),
      content: TextField(
        key: const Key('goal_edit_value'),
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(suffixText: widget.unit),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, const _EditResult(null)), child: const Text('Voltar ao calculado')),
        FilledButton(
          key: const Key('goal_edit_save'),
          onPressed: () {
            final v = parseNumber(_controller.text);
            if (v == null || v <= 0) return;
            Navigator.pop(context, _EditResult(v));
          },
          child: const Text('Salvar'),
        ),
      ],
    );
  }
}
