import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_activity/activity.dart';

/// Estado do gravador de corrida/caminhada (`RunRecorderService.kt`).
enum RunRecorderState { idle, recording, paused, autoPaused, interrupted, finished, noPermission, noGps, unsupported }

RunRecorderState _stateFrom(String? s) => switch (s) {
      'recording' => RunRecorderState.recording,
      'paused' => RunRecorderState.paused,
      'auto_paused' => RunRecorderState.autoPaused,
      'interrupted' => RunRecorderState.interrupted,
      'finished' => RunRecorderState.finished,
      'no_permission' => RunRecorderState.noPermission,
      'no_gps' => RunRecorderState.noGps,
      _ => RunRecorderState.idle,
    };

class RunRecorderStatus {
  final RunRecorderState state;
  final RunKind kind;
  final Duration active;
  final int points;

  /// Precisão do último sinal, em metros (`null` sem sinal ainda).
  final double? lastAccuracyMeters;
  final Duration? lastFixAge;

  const RunRecorderStatus({
    required this.state,
    this.kind = RunKind.run,
    this.active = Duration.zero,
    this.points = 0,
    this.lastAccuracyMeters,
    this.lastFixAge,
  });

  /// "GPS bom" (prancheta CorridaAoVivo): sinal recente e até 20 m.
  bool get gpsGood =>
      lastAccuracyMeters != null &&
      lastAccuracyMeters! <= RunCalculator.defaultMaxAccuracyMeters &&
      (lastFixAge == null || lastFixAge! < const Duration(seconds: 10));
}

/// Gravador de GPS do Android, pelo canal `rlt/run`. A gravação é sempre
/// iniciada pela pessoa; nada sai do aparelho.
abstract class RunRecorder {
  Future<bool> hasPermission();
  Future<bool> requestPermission();
  Future<bool> gpsEnabled();
  Future<void> start(RunKind kind, {required bool autoPause});
  Future<void> pause();
  Future<void> resume();
  Future<void> finish();
  Future<RunRecorderStatus> status();

  /// Pontos a partir do índice [from] (o app pede só os novos).
  Future<List<RunPointInput>> points({int from = 0});

  /// Apaga o arquivo da gravação (depois de salvar, ou se a pessoa
  /// descartar uma gravação interrompida).
  Future<void> discard();
}

RunPointInput pointFromChannel(Map<Object?, Object?> m) => RunPointInput(
      latitude: (m['lat']! as num).toDouble(),
      longitude: (m['lon']! as num).toDouble(),
      recordedAt: DateTime.fromMillisecondsSinceEpoch((m['t']! as num).toInt(), isUtc: true),
      elevationMeters: (m['alt'] as num?)?.toDouble(),
      accuracyMeters: (m['acc'] as num?)?.toDouble(),
      segment: (m['seg'] as num?)?.toInt() ?? 0,
    );

class AndroidRunRecorder implements RunRecorder {
  static const _channel = MethodChannel('rlt/run');

  @override
  Future<bool> hasPermission() async => await _channel.invokeMethod<bool>('hasPermission') ?? false;
  @override
  Future<bool> requestPermission() async => await _channel.invokeMethod<bool>('requestPermission') ?? false;
  @override
  Future<bool> gpsEnabled() async => await _channel.invokeMethod<bool>('gpsEnabled') ?? false;
  @override
  Future<void> start(RunKind kind, {required bool autoPause}) =>
      _channel.invokeMethod<bool>('start', {'kind': kind.wireValue, 'auto_pause': autoPause});
  @override
  Future<void> pause() => _channel.invokeMethod<bool>('pause');
  @override
  Future<void> resume() => _channel.invokeMethod<bool>('resume');
  @override
  Future<void> finish() => _channel.invokeMethod<bool>('finish');
  @override
  Future<void> discard() => _channel.invokeMethod<bool>('discard');

  @override
  Future<RunRecorderStatus> status() async {
    final m = await _channel.invokeMapMethod<String, Object?>('status') ?? const {};
    return RunRecorderStatus(
      state: _stateFrom(m['state'] as String?),
      kind: RunKind.fromWireValue(m['kind']) ?? RunKind.run,
      active: Duration(milliseconds: (m['active_ms'] as num?)?.toInt() ?? 0),
      points: (m['points'] as num?)?.toInt() ?? 0,
      lastAccuracyMeters: (m['last_accuracy'] as num?)?.toDouble(),
      lastFixAge: m['last_fix_age_ms'] == null ? null : Duration(milliseconds: (m['last_fix_age_ms']! as num).toInt()),
    );
  }

  @override
  Future<List<RunPointInput>> points({int from = 0}) async => [
        for (final p in await _channel.invokeListMethod<Object?>('points', {'from': from}) ?? const [])
          pointFromChannel(p! as Map<Object?, Object?>),
      ];
}

/// Fora do Android: não há GPS.
class UnsupportedRunRecorder implements RunRecorder {
  @override
  Future<bool> hasPermission() async => false;
  @override
  Future<bool> requestPermission() async => false;
  @override
  Future<bool> gpsEnabled() async => false;
  @override
  Future<void> start(RunKind kind, {required bool autoPause}) async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
  @override
  Future<void> finish() async {}
  @override
  Future<void> discard() async {}
  @override
  Future<RunRecorderStatus> status() async => const RunRecorderStatus(state: RunRecorderState.unsupported);
  @override
  Future<List<RunPointInput>> points({int from = 0}) async => const [];
}

/// Para testes: o teste empurra pontos com [addPoint].
class FakeRunRecorder implements RunRecorder {
  bool permission;
  bool gps;
  RunRecorderState state;
  RunKind kind = RunKind.run;
  bool autoPause = true;
  Duration active = Duration.zero;
  double? accuracy = 5;
  final List<RunPointInput> recorded = [];
  int segment = 0;
  bool discarded = false;

  FakeRunRecorder({this.permission = true, this.gps = true, this.state = RunRecorderState.idle});

  void addPoint(double lat, double lon, DateTime utc, {double? accuracy = 5}) {
    if (state != RunRecorderState.recording) return;
    recorded.add(RunPointInput(latitude: lat, longitude: lon, recordedAt: utc, accuracyMeters: accuracy, segment: segment));
  }

  @override
  Future<bool> hasPermission() async => permission;
  @override
  Future<bool> requestPermission() async => permission = true;
  @override
  Future<bool> gpsEnabled() async => gps;
  @override
  Future<void> start(RunKind k, {required bool autoPause}) async {
    kind = k;
    this.autoPause = autoPause;
    state = RunRecorderState.recording;
  }

  @override
  Future<void> pause() async => state = RunRecorderState.paused;
  @override
  Future<void> resume() async {
    segment++;
    state = RunRecorderState.recording;
  }

  @override
  Future<void> finish() async => state = RunRecorderState.finished;
  @override
  Future<void> discard() async {
    discarded = true;
    recorded.clear();
    state = RunRecorderState.idle;
  }

  @override
  Future<RunRecorderStatus> status() async => RunRecorderStatus(
        state: state,
        kind: kind,
        active: active,
        points: recorded.length,
        lastAccuracyMeters: accuracy,
      );

  @override
  Future<List<RunPointInput>> points({int from = 0}) async => recorded.skip(from).toList();
}

RunRecorder defaultRunRecorder() => !kIsWeb && Platform.isAndroid ? AndroidRunRecorder() : UnsupportedRunRecorder();

/// Números ao vivo a partir dos pontos (mesmo filtro e cálculo do resumo
/// salvo).
class LiveRunStats {
  final double distanceMeters;
  final double? averagePaceSecondsPerKm;
  final double? currentPaceSecondsPerKm;
  const LiveRunStats({required this.distanceMeters, this.averagePaceSecondsPerKm, this.currentPaceSecondsPerKm});

  /// Ritmo atual: últimos ~30 s do trecho em andamento.
  static LiveRunStats from(List<RunPointInput> raw, Duration active) {
    final pts = RunCalculator.filterSpeedOutliers(RunCalculator.filterByAccuracy(raw));
    final distance = RunCalculator.totalDistanceMeters(pts);
    final avg = distance < 50 ? null : active.inMilliseconds / 1000 / (distance / 1000);
    double? current;
    if (pts.length >= 2) {
      final last = pts.last;
      final window = [
        for (final p in pts)
          if (p.segment == last.segment && last.recordedAt.difference(p.recordedAt) <= const Duration(seconds: 30)) p,
      ];
      final d = RunCalculator.totalDistanceMeters(window);
      final secs = window.length < 2 ? 0 : window.last.recordedAt.difference(window.first.recordedAt).inMilliseconds / 1000;
      if (d >= 20 && secs > 0) current = secs / (d / 1000);
    }
    return LiveRunStats(distanceMeters: distance, averagePaceSecondsPerKm: avg, currentPaceSecondsPerKm: current);
  }
}
