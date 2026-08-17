import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:frankstein_activity/activity.dart';

import 'step_sensor_android.dart';

enum StepTrackingStatus {
  /// Ainda não terminou de checar (permissão/sensor) — estado inicial.
  unknown,

  /// Plataforma sem implementação real ainda (iOS/desktop —
  /// `docs/PLATFORM-PARITY.md`).
  unsupportedPlatform,

  /// Aparelho Android sem sensor `TYPE_STEP_COUNTER` de hardware.
  noSensor,

  /// Usuário negou `ACTIVITY_RECOGNITION` — sem essa permissão o sensor
  /// não entrega leitura nenhuma (exigência do Android desde a API 29).
  permissionDenied,

  /// Sensor real ligado e ouvindo (`StepCounterService`, foreground
  /// service — `.claude/rules/activity.md`).
  active,
}

/// Decide a política de "quando persistir" que `StepsRepository`
/// deliberadamente não decide
/// (`packages/activity/lib/src/steps_repository.dart:19-23`): grava a
/// cada [flushInterval] e quando o app é pausado/finalizado
/// (`WidgetsBindingObserver`) — cobre tanto uso contínuo quanto o app
/// minimizado, sem depender só do timer (que não roda com o app morto,
/// mas o foreground service nativo continua contando de qualquer jeito;
/// o delta pendente entra no próximo flush quando o app voltar).
///
/// Só a leitura do sensor de verdade (o foreground service não parar com
/// a tela bloqueada) depende de device Android real pra confirmar — não
/// verificável neste ambiente de desenvolvimento. A lógica de status/
/// flush aqui é testável com o platform channel mockado
/// (`app/test/widget_test.dart`).
class StepTrackingController with WidgetsBindingObserver {
  final StepsRepository repository;
  final int Function() tzOffsetMinutesProvider;
  final Duration flushInterval;
  final AndroidStepSensor Function() sensorFactory;

  /// Testável separado de `Platform.isAndroid` de propósito: `flutter
  /// test` roda no host (Linux neste projeto, em qualquer CI) — nunca
  /// `Platform.isAndroid == true`, então esse branch nunca seria
  /// exercitado em teste nenhum se checasse `Platform` direto. Produção
  /// usa o default real; teste injeta `() => true` pra testar o resto da
  /// lógica com o platform channel mockado (`app/test/widget_test.dart`).
  final bool Function() isSupportedPlatform;

  final ValueNotifier<StepTrackingStatus> status = ValueNotifier(StepTrackingStatus.unknown);

  AndroidStepSensor? _sensor;
  StreamSubscription<StepsSample>? _subscription;
  Timer? _flushTimer;

  StepTrackingController({
    required this.repository,
    this.tzOffsetMinutesProvider = _defaultTzOffsetMinutes,
    this.flushInterval = const Duration(minutes: 5),
    AndroidStepSensor Function()? sensorFactory,
    bool Function()? isSupportedPlatform,
  })  : sensorFactory = sensorFactory ??
            (() => AndroidStepSensor(
                  deviceId: 'android-device',
                  tzOffsetMinutesProvider: tzOffsetMinutesProvider,
                )),
        isSupportedPlatform = isSupportedPlatform ?? (() => Platform.isAndroid);

  static int _defaultTzOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;

  Future<void> start() async {
    if (!isSupportedPlatform()) {
      status.value = StepTrackingStatus.unsupportedPlatform;
      return;
    }

    final sensor = _sensor ?? sensorFactory();
    _sensor = sensor;

    var granted = await sensor.hasPermission();
    if (!granted) granted = await sensor.requestPermission();
    if (!granted) {
      status.value = StepTrackingStatus.permissionDenied;
      return;
    }

    await sensor.startService();
    final hasSensor = await sensor.hasSensor();
    if (!hasSensor) {
      status.value = StepTrackingStatus.noSensor;
      return;
    }

    _subscription ??= repository.attachSensor(sensor);
    _flushTimer ??= Timer.periodic(flushInterval, (_) => _flush());
    WidgetsBinding.instance.addObserver(this);
    status.value = StepTrackingStatus.active;
  }

  void _flush() {
    repository.flush(at: DateTime.now().toUtc(), tzOffsetMinutes: tzOffsetMinutesProvider());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _flush();
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _flushTimer?.cancel();
    _subscription?.cancel();
    _sensor?.stopService();
  }
}
