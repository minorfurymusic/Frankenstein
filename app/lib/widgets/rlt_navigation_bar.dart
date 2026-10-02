import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';

/// As 5 abas, nesta ordem (`docs/PRODUTO.md`, navegação; ADR-12).
enum RltTab {
  inicio('Início', Icons.home_outlined, Icons.home),
  saude('Saúde', Icons.favorite_border, Icons.favorite),
  cerebro('Cérebro', Icons.psychology_outlined, Icons.psychology),
  nutricao('Nutrição', Icons.restaurant_outlined, Icons.restaurant),
  exercicios('Exercícios', Icons.fitness_center_outlined, Icons.fitness_center);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  const RltTab(this.label, this.icon, this.selectedIcon);
}

/// Barra inferior com o Cérebro no centro, em destaque (prancheta
/// Componentes, "Barra de navegação").
class RltNavigationBar extends StatelessWidget {
  final RltTab selected;
  final ValueChanged<RltTab> onSelected;
  const RltNavigationBar({super.key, required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Semantics(
      container: true,
      label: 'Navegação principal',
      child: Container(
        decoration: BoxDecoration(color: c.surfaceContainer),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Row(
              children: [
                for (final tab in RltTab.values)
                  Expanded(
                    child: tab == RltTab.cerebro
                        ? _CenterItem(selected: selected == tab, onTap: () => onSelected(tab))
                        : _Item(tab: tab, selected: selected == tab, onTap: () => onSelected(tab)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final RltTab tab;
  final bool selected;
  final VoidCallback onTap;
  const _Item({required this.tab, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      key: Key('nav_${tab.name}'),
      button: true,
      selected: selected,
      label: tab.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 56,
              height: 32,
              decoration: BoxDecoration(
                color: selected ? c.secondaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(selected ? tab.selectedIcon : tab.icon, color: selected ? c.onSecondaryContainer : c.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            // Flexible + FittedBox: com fonte grande do sistema o rótulo
            // encolhe em vez de estourar a barra.
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(tab.label, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700, color: selected ? c.onSurface : c.onSurfaceVariant)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterItem extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _CenterItem({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Semantics(
      key: const Key('nav_cerebro'),
      button: true,
      selected: selected,
      label: RltTab.cerebro.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selected ? c.primary : c.primaryContainer,
                borderRadius: BorderRadius.circular(RltRadius.navigation),
                boxShadow: [BoxShadow(color: c.shadow, blurRadius: 6, offset: const Offset(0, 2))],
              ),
              child: Icon(RltTab.cerebro.icon, size: 28, color: selected ? c.onPrimary : c.onPrimaryContainer),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(RltTab.cerebro.label, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: c.onSurface)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
