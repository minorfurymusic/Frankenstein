import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'screens/account_screen.dart';
import 'screens/brain/brain_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/exercise/exercise_tab.dart';
import 'screens/exercise/opentracks_screens.dart';
import 'screens/health/health_tab.dart';
import 'screens/nutrition/nutrition_tab.dart';
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

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  RltTab _tab = RltTab.inicio;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOpenTracks());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkOpenTracks();
  }

  /// O OpenTracks pode abrir o RLT com uma trilha ("mostrar no painel"):
  /// pergunta antes de trazer.
  Future<void> _checkOpenTracks() async {
    if (!mounted) return;
    await offerOpenTracksImport(context, widget.dependencies);
  }

  void _openAccount() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AccountScreen(deps: widget.dependencies)));
  }

  PreferredSizeWidget? _appBar() {
    // Início, Saúde, Nutrição e Exercícios têm cabeçalho próprio no corpo
    // (pranchetas Inicio, Saude, NutricaoHoje, ExerciciosHoje).
    if (_tab != RltTab.cerebro) return null;
    return AppBar(title: Text(_tab.label));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar(),
      body: SafeArea(bottom: false, top: _tab != RltTab.cerebro, child: IndexedStack(
        index: _tab.index,
        children: [
          HomeScreen(
            deps: widget.dependencies,
            onOpenAccount: _openAccount,
            onOpenTab: (tab) => setState(() => _tab = tab),
          ),
          HealthTab(deps: widget.dependencies),
          BrainScreen(deps: widget.dependencies),
          NutritionTab(deps: widget.dependencies),
          ExerciseTab(deps: widget.dependencies),
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
