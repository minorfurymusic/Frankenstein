import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_dependencies.dart';
import 'card_image_capturer.dart';
import 'confirmation_gate.dart';
import 'home_shell.dart';
import 'screens/onboarding/onboarding_screen.dart';
import 'share_sheet.dart';
import 'theme/rlt_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  final directory = await getApplicationDocumentsDirectory();
  final navigatorKey = GlobalKey<NavigatorState>();
  final dependencies = AppDependencies.open(
    dbDirectoryPath: directory.path,
    confirmationGate: AppConfirmationGate(navigatorKey),
    shareSheet: NativeShareSheet(),
    imageCapturer: RealCardImageCapturer(),
  );
  final firstUse = OnboardingScreen.shouldShow(dependencies);
  runApp(FrankstitApp(dependencies: dependencies, navigatorKey: navigatorKey, onboarding: firstUse));

  // Depois do runApp, nunca antes — mesmo cuidado do fix do
  // sqlite3_flutter_libs (docs/HISTORICO.md): nada bloqueante/assíncrono
  // longo pode atrasar o primeiro frame. Fire-and-forget: pede permissão,
  // liga o foreground service, atualiza `dependencies.stepTracking.status`
  // quando resolver — o Início e Exercícios › Passos escutam esse `ValueNotifier`.
  // No primeiro uso, quem pede a permissão é o onboarding, depois de explicar.
  if (!firstUse) unawaited(dependencies.stepTracking.start());
  // Replaneja os lembretes dos próximos 7 dias a cada abertura (as
  // janelas andam com o tempo).
  unawaited(dependencies.reminders.syncNow());
}

/// A OFL exige que a licença acompanhe a fonte: aparece em Conta > Sobre.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    final text = await rootBundle.loadString('assets/fonts/figtree/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Figtree'], text);
  });
}

/// Shell do app (ADR-1). `AppDependencies` é construído fora daqui — em
/// `main()` (produção, banco real via `path_provider`) ou por um teste
/// (`AppDependencies.inMemory`) — esta classe não sabe de onde veio,
/// então é testável com `flutter test` sem tocar disco nem depender de
/// nenhum platform channel.
class FrankstitApp extends StatefulWidget {
  final AppDependencies dependencies;
  final GlobalKey<NavigatorState> navigatorKey;

  /// Mostra o primeiro uso antes do app (decidido em `main()`; testes
  /// sobem direto no app).
  final bool onboarding;

  const FrankstitApp({
    super.key,
    required this.dependencies,
    required this.navigatorKey,
    this.onboarding = false,
  });

  @override
  State<FrankstitApp> createState() => _FrankstitAppState();
}

class _FrankstitAppState extends State<FrankstitApp> {
  late bool _onboarding = widget.onboarding;

  @override
  Widget build(BuildContext context) {
    final deps = widget.dependencies;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: deps.themeMode,
      builder: (context, mode, _) => MaterialApp(
        navigatorKey: widget.navigatorKey,
        title: 'RLT',
        theme: RltTheme.light(),
        darkTheme: RltTheme.dark(),
        themeMode: mode,
        home: _onboarding
            ? OnboardingScreen(deps: deps, onDone: () => setState(() => _onboarding = false))
            : HomeShell(dependencies: deps),
      ),
    );
  }
}
