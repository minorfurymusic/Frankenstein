import 'package:flutter/services.dart';
import 'package:frankstein_activity/activity.dart';

/// Implementação real de [StepSensor] sobre o foreground service Android
/// (`app/android/app/src/main/kotlin/.../StepCounterService.kt`,
/// `MainActivity.kt`) — `.claude/rules/activity.md`: contagem não pode
/// parar com a tela bloqueada, por isso o sensor de verdade vive num
/// `Service`, não em código Dart preso ao ciclo de vida da UI.
///
/// [StepsRepository] (`packages/activity`) continua sem saber nada disso
/// — só recebe [StepsSample] por [readings], igual à `FakeStepSensor` de
/// teste. `tzOffsetMinutesProvider` é injetável por teste, mesmo padrão
/// de `app_dependencies.dart` (`tzOffsetMinutesProvider`).
class AndroidStepSensor implements StepSensor {
  static const _methodChannel = MethodChannel('frankstein/steps');
  static const _eventChannel = EventChannel('frankstein/steps/stream');

  final String deviceId;
  final int Function() tzOffsetMinutesProvider;

  AndroidStepSensor({
    required this.deviceId,
    this.tzOffsetMinutesProvider = _defaultTzOffsetMinutes,
  });

  static int _defaultTzOffsetMinutes() => DateTime.now().timeZoneOffset.inMinutes;

  Future<bool> hasSensor() async =>
      (await _methodChannel.invokeMethod<bool>('hasSensor')) ?? false;

  Future<bool> hasPermission() async =>
      (await _methodChannel.invokeMethod<bool>('hasActivityRecognitionPermission')) ?? false;

  Future<bool> requestPermission() async =>
      (await _methodChannel.invokeMethod<bool>('requestActivityRecognitionPermission')) ?? false;

  Future<void> startService() => _methodChannel.invokeMethod('startService');

  Future<void> stopService() => _methodChannel.invokeMethod('stopService');

  /// Leitura atual sob demanda — útil ao reabrir o app, sem esperar o
  /// próximo evento do sensor (que no `TYPE_STEP_COUNTER` só dispara
  /// quando o contador muda, pode ficar minutos em silêncio). `null` se o
  /// service ainda não recebeu nenhuma leitura.
  Future<StepsSample?> getCurrentReading() async {
    final raw = await _methodChannel.invokeMethod<Map>('getCurrentReading');
    if (raw == null) return null;
    return _toSample(raw);
  }

  @override
  Stream<StepsSample> get readings =>
      _eventChannel.receiveBroadcastStream().map((event) => _toSample(event as Map));

  StepsSample _toSample(Map raw) {
    final map = Map<String, dynamic>.from(raw);
    final timestampMillis = map['timestamp_utc_millis'] as int;
    return StepsSample(
      deviceId: deviceId,
      timestampUtc: DateTime.fromMillisecondsSinceEpoch(timestampMillis, isUtc: true),
      cumulativeSteps: map['cumulative_steps'] as int,
      tzOffsetMinutes: tzOffsetMinutesProvider(),
    );
  }
}
