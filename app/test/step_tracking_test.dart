import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/step_sensor_android.dart';
import 'package:frankstein/step_tracking_controller.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

/// Testa a parte que dá pra testar sem device Android real: parsing dos
/// canais e a lógica de status/flush de `StepTrackingController`. O
/// sensor de verdade — `TYPE_STEP_COUNTER` de fato disparando, o
/// foreground service sobrevivendo à tela bloqueada
/// (`.claude/rules/activity.md`) — não é verificável neste ambiente
/// (sem `adb`/device); esses testes mockam os platform channels
/// (`MethodChannel`/`EventChannel`), técnica oficial do `flutter_test`
/// (`TestDefaultBinaryMessengerBinding`), não simulam o sensor em si.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const methodChannel = MethodChannel('frankstein/steps');
  const eventChannel = EventChannel('frankstein/steps/stream');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(methodChannel, null);
    messenger.setMockStreamHandler(eventChannel, null);
  });

  group('AndroidStepSensor — parsing dos canais mockados', () {
    test('hasSensor/hasPermission/requestPermission repassam a resposta do canal', () async {
      final calls = <String>[];
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        calls.add(call.method);
        return switch (call.method) {
          'hasSensor' => true,
          'hasActivityRecognitionPermission' => false,
          'requestActivityRecognitionPermission' => true,
          _ => null,
        };
      });

      final sensor = AndroidStepSensor(deviceId: 'dev-1');
      expect(await sensor.hasSensor(), isTrue);
      expect(await sensor.hasPermission(), isFalse);
      expect(await sensor.requestPermission(), isTrue);
      expect(calls, ['hasSensor', 'hasActivityRecognitionPermission', 'requestActivityRecognitionPermission']);
    });

    test('getCurrentReading() null quando o service não tem leitura ainda', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async => null);
      final sensor = AndroidStepSensor(deviceId: 'dev-1');
      expect(await sensor.getCurrentReading(), isNull);
    });

    test('getCurrentReading() converte o map do canal em StepsSample', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async => {
            'cumulative_steps': 4200,
            'timestamp_utc_millis': DateTime.utc(2026, 8, 18, 10, 0).millisecondsSinceEpoch,
          });
      final sensor = AndroidStepSensor(
        deviceId: 'dev-1',
        tzOffsetMinutesProvider: () => -180,
      );

      final sample = await sensor.getCurrentReading();
      expect(sample, isNotNull);
      expect(sample!.cumulativeSteps, 4200);
      expect(sample.timestampUtc, DateTime.utc(2026, 8, 18, 10, 0));
      expect(sample.tzOffsetMinutes, -180);
      expect(sample.deviceId, 'dev-1');
    });

    test('readings converte cada evento do stream em StepsSample', () async {
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'cumulative_steps': 10,
              'timestamp_utc_millis': DateTime.utc(2026, 8, 18, 9, 0).millisecondsSinceEpoch,
            });
            events.success({
              'cumulative_steps': 25,
              'timestamp_utc_millis': DateTime.utc(2026, 8, 18, 9, 5).millisecondsSinceEpoch,
            });
          },
        ),
      );

      final sensor = AndroidStepSensor(deviceId: 'dev-1', tzOffsetMinutesProvider: () => -180);
      final samples = await sensor.readings.take(2).toList();

      expect(samples[0].cumulativeSteps, 10);
      expect(samples[1].cumulativeSteps, 25);
      expect(samples.every((s) => s.deviceId == 'dev-1'), isTrue);
    });
  });

  group('StepTrackingController — status e flush', () {
    late HealthDataCore core;
    setUp(() => core = HealthDataCore.openInMemory());
    tearDown(() => core.close());

    test('plataforma sem suporte não chama nenhum platform channel', () async {
      final repository = StepsRepository(core: core, deviceId: 'dev-1');
      final controller = StepTrackingController(
        repository: repository,
        isSupportedPlatform: () => false,
      );

      await controller.start();

      expect(controller.status.value, StepTrackingStatus.unsupportedPlatform);
      expect(core.queryByType(HealthEventType.steps), isEmpty);
    });

    test('permissão negada duas vezes (checar + pedir) vira permissionDenied', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        return switch (call.method) {
          'hasActivityRecognitionPermission' => false,
          'requestActivityRecognitionPermission' => false,
          _ => null,
        };
      });

      final repository = StepsRepository(core: core, deviceId: 'dev-1');
      final controller = StepTrackingController(
        repository: repository,
        isSupportedPlatform: () => true,
      );

      await controller.start();

      expect(controller.status.value, StepTrackingStatus.permissionDenied);
    });

    test('aparelho sem sensor de hardware vira noSensor', () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        return switch (call.method) {
          'hasActivityRecognitionPermission' => true,
          'startService' => null,
          'hasSensor' => false,
          _ => null,
        };
      });

      final repository = StepsRepository(core: core, deviceId: 'dev-1');
      final controller = StepTrackingController(
        repository: repository,
        isSupportedPlatform: () => true,
      );

      await controller.start();

      expect(controller.status.value, StepTrackingStatus.noSensor);
    });

    test('permissão concedida + sensor presente: fica active e leituras chegam no repositório real',
        () async {
      messenger.setMockMethodCallHandler(methodChannel, (call) async {
        return switch (call.method) {
          'hasActivityRecognitionPermission' => true,
          'startService' => null,
          'hasSensor' => true,
          'stopService' => null,
          _ => null,
        };
      });
      messenger.setMockStreamHandler(
        eventChannel,
        MockStreamHandler.inline(
          onListen: (arguments, events) {
            events.success({
              'cumulative_steps': 100,
              'timestamp_utc_millis': DateTime.utc(2026, 8, 18, 9, 0).millisecondsSinceEpoch,
            });
            events.success({
              'cumulative_steps': 150,
              'timestamp_utc_millis': DateTime.utc(2026, 8, 18, 9, 10).millisecondsSinceEpoch,
            });
          },
        ),
      );

      final repository = StepsRepository(core: core, deviceId: 'android-device');
      final controller = StepTrackingController(
        repository: repository,
        isSupportedPlatform: () => true,
        tzOffsetMinutesProvider: () => -180,
      );

      await controller.start();
      // Deixa o stream de leituras (Future/microtasks do EventChannel) fluir.
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.status.value, StepTrackingStatus.active);
      expect(repository.pendingDelta, 50); // 150 - baseline(100)

      // Política de flush em `didChangeAppLifecycleState` — mesmo caminho
      // usado quando o app é minimizado de verdade.
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);

      final events = core.queryByType(HealthEventType.steps);
      expect(events, hasLength(1));
      expect(events.single.payload['count'], 50);

      controller.dispose();
    });
  });
}
