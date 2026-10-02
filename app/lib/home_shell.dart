import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'screens/account_screen.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/health/health_tab.dart';
import 'screens/tab_under_construction.dart';
import 'theme/rlt_colors.dart';
import 'widgets/rlt_navigation_bar.dart';

/// Navegação do RLT: 5 abas (Início, Saúde, Cérebro, Nutrição, Exercícios —
/// ADR-12, `docs/PRODUTO.md`), Cérebro no centro com destaque, e Conta pelo
/// avatar no topo do Início (`docs/design/PROMPT-CLAUDE-DESIGN.md`,
/// "Navegação"). `IndexedStack` mantém o estado de cada aba (a conversa do
/// Cérebro não some ao trocar de aba).
class HomeShell extends StatefulWidget {
  final AppDependencies dependencies;
  const HomeShell({super.key, required this.dependencies});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  RltTab _tab = RltTab.inicio;

  void _openAccount() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountScreen(deps: widget.dependencies)));
  }

  PreferredSizeWidget? _appBar() {
    // Abas com título grande próprio no corpo (prancheta Saude).
    if (_tab == RltTab.saude) return null;
    if (_tab != RltTab.inicio) return AppBar(title: Text(_tab.label));
    final c = RltColors.of(context);
    return AppBar(
      leadingWidth: 64,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Center(
          child: Semantics(
            button: true,
            label: 'Conta e configurações',
            excludeSemantics: true,
            child: InkWell(
              key: const Key('account_avatar'),
              customBorder: const CircleBorder(),
              onTap: _openAccount,
              child: CircleAvatar(
                radius: 22,
                backgroundColor: c.primaryContainer,
                foregroundColor: c.onPrimaryContainer,
                // TODO(frankstein): iniciais e foto da conta Google quando o login existir (ADR-13).
                child: const Icon(Icons.person_outline),
              ),
            ),
          ),
        ),
      ),
      title: const Text('Início'),
      actions: [
        IconButton(
          key: const Key('reminders_button'),
          tooltip: 'Lembretes',
          // TODO(frankstein): abrir a tela Lembretes (prancheta Lembretes) no ciclo das telas do Início.
          onPressed: () => ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Lembretes: tela em construção.'))),
          icon: const Icon(Icons.notifications_none),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(bottom: false, top: _tab == RltTab.saude, child: IndexedStack(
        index: _tab.index,
        children: [
          DashboardScreen(dependencies: widget.dependencies),
          HealthTab(deps: widget.dependencies),
          ChatScreen(pipeline: widget.dependencies.pipeline),
          // TODO(frankstein): aba Nutrição (pranchetas Nutricao*, AdicionarAlimento, DetalheAlimento…).
          const TabUnderConstruction(tab: RltTab.nutricao),
          // TODO(frankstein): aba Exercícios (pranchetas Exercicios*, Passos, Academia, Corrida*…).
          const TabUnderConstruction(tab: RltTab.exercicios),
        ],
      )),
      bottomNavigationBar: RltNavigationBar(
        key: const Key('bottom_nav'),
        selected: _tab,
        onSelected: (tab) {
          setState(() => _tab = tab);
          // O chat grava por fora das telas; ao trocar de aba, quem mostra
          // dado recarrega.
          widget.dependencies.notifyDataChanged();
        },
      ),
    );
  }
}
