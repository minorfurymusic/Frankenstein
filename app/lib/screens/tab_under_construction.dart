import 'package:flutter/material.dart';

import '../theme/rlt_theme.dart';
import '../widgets/rlt_navigation_bar.dart';
import '../widgets/state_views.dart';

// TODO(frankstein): temporário — some quando a última aba ganhar suas telas
// (etapa B da ordem em docs/design/REVISAO-LAYOUT.md).
/// Aba que ainda não tem tela. Diz isso com todas as letras em vez de
/// fingir conteúdo.
class TabUnderConstruction extends StatelessWidget {
  final RltTab tab;
  const TabUnderConstruction({super.key, required this.tab});

  @override
  Widget build(BuildContext context) {
    return ListView(
      key: Key('tab_${tab.name}'),
      padding: const EdgeInsets.all(RltSpace.l),
      children: [
        StateCard(
          icon: tab.icon,
          title: '${tab.label}: em construção',
          message: 'As telas desta aba entram nos próximos ciclos. Nada aqui ainda grava ou mostra dados.',
        ),
      ],
    );
  }
}
