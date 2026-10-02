import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// Tom do estado: vazio (neutro, ícone em verde-claro) ou sem permissão
/// (ícone em terciária-clara), como na prancheta Componentes.
enum StateTone { empty, permission }

/// Estado vazio / sem permissão: ícone grande, título, texto e uma ação.
class StateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final StateTone tone;

  const StateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.tone = StateTone.empty,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final (Color bg, Color fg) = tone == StateTone.empty
        ? (c.secondaryContainer, c.onSecondaryContainer)
        : (c.tertiaryContainer, c.onTertiaryContainer);
    return Container(
      padding: const EdgeInsets.all(RltSpace.l),
      decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: RltSpace.s),
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 36, color: fg),
          ),
          const SizedBox(height: RltSpace.l),
          Text(title, style: t.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: RltSpace.s),
          Text(message, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant), textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: RltSpace.l),
            SizedBox(
              width: double.infinity,
              child: actionIcon == null
                  ? FilledButton(onPressed: onAction, child: Text(actionLabel!))
                  : FilledButton.icon(onPressed: onAction, icon: Icon(actionIcon), label: Text(actionLabel!)),
            ),
          ],
        ],
      ),
    );
  }
}

/// Faixa de aviso sem internet ("Sem internet. Só o modo básico do Cérebro
/// funciona.").
class OfflineBanner extends StatelessWidget {
  final String message;
  const OfflineBanner({super.key, this.message = 'Sem internet. Só o modo básico do Cérebro funciona.'});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: c.tertiaryContainer, borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: c.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.onTertiaryContainer)),
          ),
        ],
      ),
    );
  }
}

/// Carregando: barra fina indeterminada sobre um esqueleto de cartão.
class LoadingCard extends StatelessWidget {
  const LoadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(6)),
        );
    return Semantics(
      label: 'Carregando',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: RltSpace.m),
          Container(
            padding: const EdgeInsets.all(RltSpace.l),
            decoration: BoxDecoration(color: c.surfaceContainerLow, borderRadius: BorderRadius.circular(RltRadius.card)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [bar(40, 40), const SizedBox(width: 16), Column(crossAxisAlignment: CrossAxisAlignment.start, children: [bar(150, 12), const SizedBox(height: 8), bar(100, 10)])]),
                const SizedBox(height: 16),
                bar(220, 10),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
