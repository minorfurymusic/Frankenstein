import 'dart:async';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app_dependencies.dart';
import 'card_image_capturer.dart';
import 'confirmation_gate.dart';
import 'home_shell.dart';
import 'share_sheet.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final directory = await getApplicationDocumentsDirectory();
  final navigatorKey = GlobalKey<NavigatorState>();
  final dependencies = AppDependencies.open(
    dbDirectoryPath: directory.path,
    confirmationGate: AppConfirmationGate(navigatorKey),
    shareSheet: NativeShareSheet(),
    imageCapturer: RealCardImageCapturer(),
  );
  runApp(FrankstitApp(dependencies: dependencies, navigatorKey: navigatorKey));

  // Depois do runApp, nunca antes — mesmo cuidado do fix do
  // sqlite3_flutter_libs (docs/HISTORICO.md): nada bloqueante/assíncrono
  // longo pode atrasar o primeiro frame. Fire-and-forget: pede permissão,
  // liga o foreground service, atualiza `dependencies.stepTracking.status`
  // quando resolver — `DashboardScreen` escuta esse `ValueNotifier`.
  unawaited(dependencies.stepTracking.start());
}

/// Shell do app (ADR-1). `AppDependencies` é construído fora daqui — em
/// `main()` (produção, banco real via `path_provider`) ou por um teste
/// (`AppDependencies.inMemory`) — esta classe não sabe de onde veio,
/// então é testável com `flutter test` sem tocar disco nem depender de
/// nenhum platform channel.
class FrankstitApp extends StatelessWidget {
  final AppDependencies dependencies;
  final GlobalKey<NavigatorState> navigatorKey;

  const FrankstitApp({
    super.key,
    required this.dependencies,
    required this.navigatorKey,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Frankstein',
      home: HomeShell(dependencies: dependencies),
    );
  }
}
