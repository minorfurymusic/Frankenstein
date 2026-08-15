import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'screens/chat_screen.dart';
import 'screens/dashboard_screen.dart';

/// Navegação entre as duas telas do MVP (`docs/ARQUITETURA.md`: "UI
/// única: chat + dashboards"). `IndexedStack` mantém o estado do chat
/// (mensagens já trocadas) ao alternar de aba, em vez de reconstruir do
/// zero.
class HomeShell extends StatefulWidget {
  final AppDependencies dependencies;
  const HomeShell({super.key, required this.dependencies});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _titles = ['Resumo', 'Chat'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_index])),
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(registry: widget.dependencies.registry),
          ChatScreen(pipeline: widget.dependencies.pipeline),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        key: const Key('bottom_nav'),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Resumo'),
          NavigationDestination(icon: Icon(Icons.chat_outlined), label: 'Chat'),
        ],
      ),
    );
  }
}
