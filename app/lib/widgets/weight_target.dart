import 'package:flutter/material.dart';
import 'package:frankstein_profile/profile.dart';

import '../app_dependencies.dart';
import '../format.dart';
import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// Peso desejado e previsão de chegada (ADR-17), para Corpo e Nutrição.
/// Some quando não há peso desejado ou pesagem.
class WeightTargetSummary extends StatelessWidget {
  final AppDependencies deps;
  const WeightTargetSummary({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final p = deps.profileRepository.load();
    final weights = deps.healthRead.weights();
    final target = p?.targetWeightKg;
    if (p == null || target == null || weights.isEmpty) return const SizedBox.shrink();
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final current = weights.first.value;
    final String text;
    if (p.reachedTarget(current)) {
      text = 'Você chegou ao peso desejado. As metas passaram para manutenção.';
    } else {
      final diff = (current - target).abs();
      final verb = current > target ? 'perder' : 'ganhar';
      final proj = projectTargetWeight(p, currentWeightKg: current, from: DateTime.now());
      text = 'Faltam ${formatNumber(diff, decimals: 1)} kg para $verb. '
          '${proj == null ? 'Escolha o ritmo em Conta › Perfil para ver a previsão.' : 'No ritmo de ${formatNumber(p.rateGramsPerDay)} g/dia, chega em ~${proj.weeks} semanas (por volta de ${ddmmyyyy(proj.date)}). Estimativa, não promessa.'}';
    }
    return Padding(
      key: const Key('weight_target_summary'),
      padding: const EdgeInsets.only(top: RltSpace.m),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(p.reachedTarget(current) ? Icons.emoji_events_outlined : Icons.flag_outlined, size: 20, color: c.tertiary),
        const SizedBox(width: RltSpace.s),
        Expanded(
          child: Text.rich(TextSpan(children: [
            TextSpan(text: 'Meta ${formatNumber(target, decimals: 1)} kg · ', style: RltTheme.tabular(t.titleSmall!)),
            TextSpan(text: text, style: t.bodyMedium),
          ])),
        ),
      ]),
    );
  }
}

/// Linha da meta no gráfico de peso (`null` sem peso desejado).
double? weightTargetLine(AppDependencies deps) => deps.profileRepository.load()?.targetWeightKg;
