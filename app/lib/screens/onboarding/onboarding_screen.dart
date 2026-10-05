import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../step_tracking_controller.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../account/brain_settings_screen.dart';
import '../account/profile_screen.dart';

/// Primeiro uso (pranchetas Main, OnbPrivacidade, OnbPerfil, OnbMetas,
/// OnbPermissoes, OnbIA). O passo "Entrar com Google" entra com o login, na
/// rodada de testes (ADR-13).
class OnboardingScreen extends StatefulWidget {
  final AppDependencies deps;
  final VoidCallback onDone;
  const OnboardingScreen({super.key, required this.deps, required this.onDone});

  static bool shouldShow(AppDependencies deps) =>
      deps.profileRepository.getSetting('onboarding_done') == null && deps.profileRepository.load() == null;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pages = PageController();
  int _page = 0;
  static const _count = 6;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _next() {
    if (_page == _count - 1) {
      _finish();
      return;
    }
    _pages.nextPage(duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  }

  void _finish() {
    widget.deps.profileRepository.setSetting('onboarding_done', '1');
    // A permissão de passos só é pedida no "Permitir" do passo dela. Com
    // "Agora não", o app pergunta de novo no próximo início (o Android para
    // de perguntar depois de duas recusas) e o Início mostra o atalho.
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(RltSpace.l),
            child: Row(children: [
              for (var i = 0; i < _count; i++)
                Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i <= _page ? c.primary : c.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
            ]),
          ),
          Expanded(
            child: PageView(
              controller: _pages,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                _Step(
                  icon: Icons.favorite_outline,
                  title: 'RLT — Real Life Track',
                  text: 'Remédios, refeições, treinos, passos, sono e exames num lugar só. '
                      'Você registra tocando ou conversando com o Cérebro.',
                  primary: 'Começar',
                  onPrimary: _next,
                  keyName: 'onb_welcome',
                ),
                _Step(
                  icon: Icons.lock_outline,
                  title: 'Seus dados ficam no seu celular',
                  text: 'Nada de saúde vai para a internet sem uma ação sua. Sem anúncios, sem telemetria. '
                      'Você pode exportar ou apagar tudo quando quiser, sem custo.',
                  primary: 'Entendi',
                  onPrimary: _next,
                  keyName: 'onb_privacy',
                ),
                _Step(
                  icon: Icons.person_outline,
                  title: 'Seu perfil',
                  text: 'Sexo biológico, nascimento, altura, peso e objetivo entram nas fórmulas das metas. '
                      'Leva um minuto e dá para mudar depois.',
                  primary: 'Preencher perfil',
                  onPrimary: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(deps: widget.deps)));
                    if (mounted) _next();
                  },
                  secondary: 'Depois',
                  onSecondary: _next,
                  keyName: 'onb_profile',
                ),
                _GoalsStep(deps: widget.deps, onNext: _next),
                _Step(
                  icon: Icons.directions_walk_outlined,
                  title: 'Contar seus passos',
                  text: 'Para contar passos, o Android pede a permissão "atividade física". A contagem continua com a '
                      'tela bloqueada e aparece uma notificação fixa "RLT contando seus passos".',
                  primary: 'Permitir',
                  onPrimary: () async {
                    await widget.deps.stepTracking.start();
                    if (mounted) _next();
                  },
                  secondary: 'Agora não',
                  onSecondary: _next,
                  keyName: 'onb_permissions',
                  footer: ValueListenableBuilder<StepTrackingStatus>(
                    valueListenable: widget.deps.stepTracking.status,
                    builder: (context, s, _) => s == StepTrackingStatus.active
                        ? Text('Contagem ativa.', style: TextStyle(color: c.success))
                        : const SizedBox.shrink(),
                  ),
                ),
                _Step(
                  icon: Icons.psychology_outlined,
                  title: 'Quer ativar a IA?',
                  text: 'Você usa a sua própria chave de IA. Sem ela, o Cérebro funciona no modo básico, sem internet.',
                  primary: 'Depois',
                  onPrimary: _finish,
                  secondary: 'Saber mais',
                  onSecondary: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BrainSettingsScreen(deps: widget.deps))),
                  keyName: 'onb_ai',
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;
  final String primary;
  final VoidCallback onPrimary;
  final String? secondary;
  final VoidCallback? onSecondary;
  final String keyName;
  final Widget? footer;

  const _Step({
    required this.icon,
    required this.title,
    required this.text,
    required this.primary,
    required this.onPrimary,
    required this.keyName,
    this.secondary,
    this.onSecondary,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Padding(
      key: Key(keyName),
      padding: const EdgeInsets.all(RltSpace.xl),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Spacer(),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: c.primaryContainer, shape: BoxShape.circle),
            child: Icon(icon, size: 44, color: c.onPrimaryContainer),
          ),
        ),
        const SizedBox(height: RltSpace.xl),
        Text(title, style: t.headlineSmall, textAlign: TextAlign.center),
        const SizedBox(height: RltSpace.m),
        Text(text, style: t.bodyLarge, textAlign: TextAlign.center),
        if (footer != null) ...[const SizedBox(height: RltSpace.m), Center(child: footer!)],
        const Spacer(),
        FilledButton(key: Key('${keyName}_primary'), onPressed: onPrimary, child: Text(primary)),
        if (secondary != null) ...[
          const SizedBox(height: RltSpace.s),
          TextButton(key: Key('${keyName}_secondary'), onPressed: onSecondary, child: Text(secondary!)),
        ],
      ]),
    );
  }
}

class _GoalsStep extends StatelessWidget {
  final AppDependencies deps;
  final VoidCallback onNext;
  const _GoalsStep({required this.deps, required this.onNext});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ValueListenableBuilder<int>(
      valueListenable: deps.dataVersion,
      builder: (context, _, _) {
        final g = deps.goals.goalsFor(DateTime.now());
        return Padding(
          key: const Key('onb_goals'),
          padding: const EdgeInsets.all(RltSpace.xl),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Spacer(),
            Text('Suas metas sugeridas', style: t.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: RltSpace.m),
            if (g == null)
              Text('Sem perfil ainda — as metas aparecem quando você preencher em Conta › Perfil.',
                  style: t.bodyLarge, textAlign: TextAlign.center)
            else ...[
              for (final (label, value) in [
                ('Calorias', '${formatNumber(g.caloriesKcal)} kcal'),
                ('Proteína', '${formatNumber(g.proteinGrams)} g'),
                ('Carboidrato', '${formatNumber(g.carbsGrams)} g'),
                ('Gordura', '${formatNumber(g.fatGrams)} g'),
                ('Fibra', '${formatNumber(g.fiberGrams)} g'),
                ('Água para beber', '${formatNumber(g.waterMl)} ml'),
                ('Passos', formatNumber(g.stepsGoal)),
              ])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  trailing: Text(value, style: RltTheme.tabular(t.titleSmall!)),
                ),
              Text('Calculado pelo seu perfil. Tudo editável em Conta › Metas.', style: t.bodySmall, textAlign: TextAlign.center),
            ],
            const Spacer(),
            FilledButton(key: const Key('onb_goals_primary'), onPressed: onNext, child: const Text('Continuar')),
          ]),
        );
      },
    );
  }
}
