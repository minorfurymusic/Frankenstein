import 'package:flutter/material.dart';

import '../theme/rlt_colors.dart';
import '../theme/rlt_theme.dart';
import 'badges.dart';

/// Título grande no topo das abas (prancheta Saude: "Saúde" em Título 1).
class RltPageTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const RltPageTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.xl, RltSpace.l, RltSpace.l),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.headlineMedium))),
          ?trailing,
        ],
      ),
    );
  }
}

/// Título de seção ("Seções", "Registros", "Medidas").
class RltSectionHeader extends StatelessWidget {
  final String text;
  final Widget? action;
  const RltSectionHeader(this.text, {super.key, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: RltSpace.xl, bottom: RltSpace.s),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(text, style: Theme.of(context).textTheme.titleMedium))),
          ?action,
        ],
      ),
    );
  }
}

/// Bloco de resumo em grade de 2 (prancheta Saude: "Próximo remédio",
/// "Último sintoma"…).
class RltStatTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String? unit;
  final String? caption;
  final VoidCallback? onTap;

  const RltStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.unit,
    this.caption,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Material(
      color: c.surfaceContainerLow,
      borderRadius: BorderRadius.circular(RltRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(RltRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(RltSpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Expanded(child: Text(label, style: t.labelMedium?.copyWith(fontWeight: FontWeight.w700))),
              ]),
              const SizedBox(height: 4),
              Text.rich(
                TextSpan(children: [
                  TextSpan(text: value, style: RltTheme.tabular(t.titleMedium!)),
                  if (unit != null) TextSpan(text: ' $unit', style: t.bodyMedium),
                ]),
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(caption!, style: t.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Grade de 2 colunas que acompanha a altura do maior bloco da linha.
class RltTwoColumnGrid extends StatelessWidget {
  final List<Widget> children;
  const RltTwoColumnGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: RltSpace.s),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ));
      if (i + 2 < children.length) rows.add(const SizedBox(height: RltSpace.s));
    }
    return Column(children: rows);
  }
}

/// Linha de navegação para uma seção (ícone em quadrado, título, resumo e
/// seta).
class RltSectionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool premium;

  const RltSectionTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.premium = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(RltRadius.chip),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RltSpace.s),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(RltRadius.icon)),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: RltSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.bodyLarge),
                  Text(subtitle, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                ],
              ),
            ),
            if (premium) const Padding(padding: EdgeInsets.only(right: 4), child: RltBadge(RltBadgeKind.premium)),
            Icon(Icons.chevron_right, color: c.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Mostra erro de validação vindo dos loggers (`ArgumentError`) em
/// português, do jeito que o logger escreveu.
void showRltError(BuildContext context, Object error) {
  final message = error is ArgumentError ? '${error.message}' : '$error';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Não salvei: $message')));
}

void showRltSaved(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
