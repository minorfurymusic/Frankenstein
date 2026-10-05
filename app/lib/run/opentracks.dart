import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';

/// Uma trilha lida do OpenTracks (API de dados).
class OpenTracksTrack {
  final int id;
  final String? name;
  final String? activityType;
  final String? uuid;
  final int? tzOffsetMinutes;
  final bool recording;
  final List<RunPointInput> points;
  const OpenTracksTrack({
    required this.id,
    this.name,
    this.activityType,
    this.uuid,
    this.tzOffsetMinutes,
    this.recording = false,
    this.points = const [],
  });

  /// running → corrida; walking/hiking → caminhada; outros tipos ficam sem
  /// tipo (o título sai pela velocidade).
  RunKind? get kind => switch (activityType) {
        'running' => RunKind.run,
        'walking' || 'hiking' => RunKind.walk,
        _ => null,
      };

  String get externalId => uuid ?? 'track-$id';
}

/// Tipos de ponto do OpenTracks (`TrackPoint.Type`): -2 início manual de
/// trecho, -1 início automático, 0 ponto, 1 fim de trecho, 3 parado.
OpenTracksTrack trackFromChannel(Map<Object?, Object?> m) {
  final points = <RunPointInput>[];
  var segment = 0;
  var sawStart = false;
  for (final raw in (m['points'] as List?) ?? const []) {
    final p = raw! as Map<Object?, Object?>;
    final type = (p['type'] as num?)?.toInt() ?? 0;
    if (type == -2 || type == -1) {
      if (sawStart || points.isNotEmpty) segment++;
      sawStart = true;
    }
    final lat = (p['lat'] as num?)?.toDouble();
    final lon = (p['lon'] as num?)?.toDouble();
    if (lat == null || lon == null || type == 1 || type == 3) continue;
    if (lat.abs() > 90 || lon.abs() > 180) continue;
    points.add(RunPointInput(
      latitude: lat,
      longitude: lon,
      recordedAt: DateTime.fromMillisecondsSinceEpoch((p['t']! as num).toInt(), isUtc: true),
      elevationMeters: (p['alt'] as num?)?.toDouble(),
      accuracyMeters: (p['acc'] as num?)?.toDouble(),
      segment: segment,
    ));
  }
  // Trechos renumerados a partir de 0, sem buracos.
  final remap = <int, int>{};
  final normalized = [
    for (final p in points)
      RunPointInput(
        latitude: p.latitude,
        longitude: p.longitude,
        recordedAt: p.recordedAt,
        elevationMeters: p.elevationMeters,
        accuracyMeters: p.accuracyMeters,
        segment: remap.putIfAbsent(p.segment, () => remap.length),
      ),
  ];
  final offsetSeconds = (m['tz_offset_seconds'] as num?)?.toInt();
  return OpenTracksTrack(
    id: (m['id']! as num).toInt(),
    name: m['name'] as String?,
    activityType: m['activity_type'] as String?,
    uuid: m['uuid'] as String?,
    tzOffsetMinutes: offsetSeconds == null ? null : offsetSeconds ~/ 60,
    recording: m['recording'] == true,
    points: normalized,
  );
}

/// Sessão aberta pelo OpenTracks (trilha em gravação ou escolhida em
/// "mostrar no painel").
class OpenTracksSession {
  final bool recording;
  final DateTime receivedAt;
  const OpenTracksSession({required this.recording, required this.receivedAt});
}

abstract class OpenTracksBridge {
  Future<bool> installed();

  /// Pede ao OpenTracks para começar a gravar (API pública).
  Future<bool> start(RunKind kind);
  Future<bool> stop();
  Future<OpenTracksSession?> session();

  /// Lê as trilhas da sessão (API de dados). `null` sem sessão.
  Future<List<OpenTracksTrack>?> read();
  Future<void> clear();
}

class AndroidOpenTracksBridge implements OpenTracksBridge {
  static const _channel = MethodChannel('rlt/opentracks');

  @override
  Future<bool> installed() async {
    try {
      return await _channel.invokeMethod<bool>('installed') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> start(RunKind kind) async => await _channel.invokeMethod<bool>('start', {'kind': kind.wireValue}) ?? false;
  @override
  Future<bool> stop() async => await _channel.invokeMethod<bool>('stop') ?? false;

  @override
  Future<OpenTracksSession?> session() async {
    try {
      final m = await _channel.invokeMapMethod<String, Object?>('session');
      if (m == null) return null;
      return OpenTracksSession(
        recording: m['recording'] == true,
        receivedAt: DateTime.fromMillisecondsSinceEpoch((m['received_at']! as num).toInt()),
      );
    } on MissingPluginException {
      return null;
    }
  }

  @override
  Future<List<OpenTracksTrack>?> read() async {
    final list = await _channel.invokeListMethod<Object?>('read');
    return list?.map((e) => trackFromChannel(e! as Map<Object?, Object?>)).toList();
  }

  @override
  Future<void> clear() => _channel.invokeMethod<bool>('clear');
}

/// Para testes e fora do Android.
class FakeOpenTracksBridge implements OpenTracksBridge {
  bool isInstalled;
  bool answersStart;
  OpenTracksSession? current;
  List<OpenTracksTrack> tracks = [];
  RunKind? startedKind;
  bool stopped = false;

  FakeOpenTracksBridge({this.isInstalled = false, this.answersStart = true});

  @override
  Future<bool> installed() async => isInstalled;
  @override
  Future<bool> start(RunKind kind) async {
    startedKind = kind;
    if (answersStart) current = OpenTracksSession(recording: true, receivedAt: DateTime.now());
    return true;
  }

  @override
  Future<bool> stop() async {
    stopped = true;
    return true;
  }

  @override
  Future<OpenTracksSession?> session() async => current;
  @override
  Future<List<OpenTracksTrack>?> read() async => current == null ? null : tracks;
  @override
  Future<void> clear() async {
    current = null;
    tracks = [];
  }
}

OpenTracksBridge defaultOpenTracksBridge() =>
    !kIsWeb && Platform.isAndroid ? AndroidOpenTracksBridge() : FakeOpenTracksBridge();

/// Grava uma trilha do OpenTracks como `gps_track` (origem `opentracks`,
/// sem duplicar: `externalId` = UUID da trilha). `null` se já estava no RLT
/// ou se não há pontos bons para formar rota.
HealthEvent? saveOpenTracksTrack(HealthDataCore core, OpenTracksTrack t, {required int fallbackTzOffsetMinutes}) {
  try {
    return RunLogger(core: core).logRun(
      t.points,
      occurredAtTzOffsetMinutes: t.tzOffsetMinutes ?? fallbackTzOffsetMinutes,
      kind: t.kind,
      source: HealthEventSource.opentracks,
      externalId: t.externalId,
    );
  } on DuplicateEventException {
    return null;
  } on InsufficientRunDataException {
    return null;
  }
}
