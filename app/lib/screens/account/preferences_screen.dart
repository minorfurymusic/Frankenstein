import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';

/// Conta › Preferências (prancheta ContaPreferencias): tema, unidades e
/// idioma. Unidades são sempre métricas (SI no banco,
/// `.claude/rules/00-inviolaveis.md`) e o idioma é português.
class PreferencesScreen extends StatelessWidget {
  final AppDependencies deps;
  const PreferencesScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Preferências')),
      body: ValueListenableBuilder<ThemeMode>(
        valueListenable: deps.themeMode,
        builder: (context, mode, _) => ListView(
          padding: const EdgeInsets.all(RltSpace.l),
          children: [
            const RltSectionHeader('Tema'),
            SegmentedButton<ThemeMode>(
              key: const Key('theme_mode'),
              segments: const [
                ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
                ButtonSegment(value: ThemeMode.dark, label: Text('Escuro')),
                ButtonSegment(value: ThemeMode.system, label: Text('Sistema')),
              ],
              selected: {mode},
              onSelectionChanged: (s) => deps.setThemeMode(s.first),
            ),
            const RltSectionHeader('Unidades'),
            Text('Métricas: kg, cm, ml, km, °C.', style: t.bodyLarge),
            const RltSectionHeader('Idioma'),
            Text('Português (Brasil)', style: t.bodyLarge),
          ],
        ),
      ),
    );
  }
}
