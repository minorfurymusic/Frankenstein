import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';
import 'package:frankstein_wearable/wearable.dart';

/// Estado do Health Connect neste celular.
enum HealthConnectStatus { available, notInstalled, updateRequired, unsupported }

/// O que o RLT lê do Health Connect.
enum HealthConnectData { sleep, heartRate, steps }

/// Conversa com o Health Connect do Android (`HealthConnectBridge.kt`).
/// Só leitura; local, sem internet.
abstract class HealthConnectBridge {
  Future<HealthConnectStatus> status();
  Future<Set<HealthConnectData>> grantedPermissions();
  Future<Set<HealthConnectData>> requestPermissions();
  Future<List<Map<String, dynamic>>> readSleep(DateTime fromUtc, DateTime toUtc);
  Future<List<Map<String, dynamic>>> readHeartRate(DateTime fromUtc, DateTime toUtc);

  /// Passos por dia local: `[{'day': 'AAAA-MM-DD', 'count': n}]` (ADR-20).
  Future<List<Map<String, dynamic>>> readDailySteps(DateTime fromUtc, DateTime toUtc);
  Future<bool> openSettings();
  Future<bool> openInstall();

  /// O Health Connect abriu o app para mostrar como os dados são usados.
  Future<bool> consumeRationaleLaunch();
}

/// Sem permissão de leitura no Health Connect.
class HealthConnectPermissionException implements Exception {
  const HealthConnectPermissionException();
}

Set<HealthConnectData> _dataFromKeys(List<Object?>? keys) => {
      for (final k in keys ?? const [])
        if (k == 'sleep')
          HealthConnectData.sleep
        else if (k == 'heart_rate')
          HealthConnectData.heartRate
        else if (k == 'steps')
          HealthConnectData.steps,
    };

class AndroidHealthConnectBridge implements HealthConnectBridge {
  static const _channel = MethodChannel('rlt/health_connect');

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      if (e.code == 'no_permission') throw const HealthConnectPermissionException();
      rethrow;
    }
  }

  @override
  Future<HealthConnectStatus> status() async {
    try {
      return switch (await _call<String>('status')) {
        'available' => HealthConnectStatus.available,
        'update_required' => HealthConnectStatus.updateRequired,
        'not_installed' => HealthConnectStatus.notInstalled,
        _ => HealthConnectStatus.unsupported,
      };
    } on MissingPluginException {
      return HealthConnectStatus.unsupported;
    }
  }

  @override
  Future<Set<HealthConnectData>> grantedPermissions() async => _dataFromKeys(await _call<List<Object?>>('grantedPermissions'));

  @override
  Future<Set<HealthConnectData>> requestPermissions() async => _dataFromKeys(await _call<List<Object?>>('requestPermissions'));

  Map<String, int> _range(DateTime from, DateTime to) =>
      {'from_millis': from.millisecondsSinceEpoch, 'to_millis': to.millisecondsSinceEpoch};

  @override
  Future<List<Map<String, dynamic>>> readSleep(DateTime fromUtc, DateTime toUtc) async => [
        for (final r in await _call<List<Object?>>('readSleep', _range(fromUtc, toUtc)) ?? const [])
          Map<String, dynamic>.from(r! as Map),
      ];

  @override
  Future<List<Map<String, dynamic>>> readHeartRate(DateTime fromUtc, DateTime toUtc) async => [
        for (final r in await _call<List<Object?>>('readHeartRate', _range(fromUtc, toUtc)) ?? const [])
          Map<String, dynamic>.from(r! as Map),
      ];

  @override
  Future<List<Map<String, dynamic>>> readDailySteps(DateTime fromUtc, DateTime toUtc) async => [
        for (final r in await _call<List<Object?>>('readDailySteps', _range(fromUtc, toUtc)) ?? const [])
          Map<String, dynamic>.from(r! as Map),
      ];

  @override
  Future<bool> openSettings() async => await _call<bool>('openSettings') ?? false;

  @override
  Future<bool> openInstall() async => await _call<bool>('openInstall') ?? false;

  @override
  Future<bool> consumeRationaleLaunch() async {
    try {
      return await _call<bool>('consumeRationaleLaunch') ?? false;
    } on MissingPluginException {
      return false;
    }
  }
}

/// Para testes e fora do Android.
class FakeHealthConnectBridge implements HealthConnectBridge {
  HealthConnectStatus currentStatus;
  Set<HealthConnectData> granted;
  Set<HealthConnectData> grantOnRequest;
  List<Map<String, dynamic>> sleepRecords;
  List<Map<String, dynamic>> heartRateRecords;
  List<Map<String, dynamic>> dailySteps = const [];
  bool failReads = false;

  /// Simula a tela de permissões que nunca devolve resposta.
  bool hangOnRequest = false;
  int requests = 0;
  (DateTime, DateTime)? lastRange;

  FakeHealthConnectBridge({
    this.currentStatus = HealthConnectStatus.unsupported,
    this.granted = const {},
    this.grantOnRequest = const {HealthConnectData.sleep, HealthConnectData.heartRate, HealthConnectData.steps},
    this.sleepRecords = const [],
    this.heartRateRecords = const [],
  });

  @override
  Future<HealthConnectStatus> status() async => currentStatus;
  @override
  Future<Set<HealthConnectData>> grantedPermissions() async => granted;
  @override
  Future<Set<HealthConnectData>> requestPermissions() async {
    requests++;
    if (hangOnRequest) return Completer<Set<HealthConnectData>>().future;
    granted = {...granted, ...grantOnRequest};
    return granted;
  }

  void _check(HealthConnectData d, DateTime from, DateTime to) {
    lastRange = (from, to);
    if (failReads) throw PlatformException(code: 'health_connect', message: 'sem resposta');
    if (!granted.contains(d)) throw const HealthConnectPermissionException();
  }

  @override
  Future<List<Map<String, dynamic>>> readSleep(DateTime fromUtc, DateTime toUtc) async {
    _check(HealthConnectData.sleep, fromUtc, toUtc);
    return sleepRecords;
  }

  @override
  Future<List<Map<String, dynamic>>> readHeartRate(DateTime fromUtc, DateTime toUtc) async {
    _check(HealthConnectData.heartRate, fromUtc, toUtc);
    return heartRateRecords;
  }

  @override
  Future<List<Map<String, dynamic>>> readDailySteps(DateTime fromUtc, DateTime toUtc) async {
    _check(HealthConnectData.steps, fromUtc, toUtc);
    return dailySteps;
  }

  @override
  Future<bool> openSettings() async => true;
  @override
  Future<bool> openInstall() async => true;
  @override
  Future<bool> consumeRationaleLaunch() async => false;
}

HealthConnectBridge defaultHealthConnectBridge() =>
    !kIsWeb && Platform.isAndroid ? AndroidHealthConnectBridge() : FakeHealthConnectBridge();

DateTime _utc(Object? millis) => DateTime.fromMillisecondsSinceEpoch((millis! as num).toInt(), isUtc: true);

/// [WearableDataSource] real sobre o Health Connect (ADR-4a). Lê só o que a
/// pessoa permitiu; o que não foi permitido volta vazio.
class HealthConnectDataSource implements WearableDataSource {
  final HealthConnectBridge bridge;
  final Set<HealthConnectData> allowed;
  HealthConnectDataSource(this.bridge, {required this.allowed});

  @override
  Future<List<HeartRateSample>> readHeartRate({required DateTime from, required DateTime to}) async {
    if (!allowed.contains(HealthConnectData.heartRate)) return const [];
    return [
      for (final r in await bridge.readHeartRate(from, to))
        if ((r['bpm'] as num) > 0)
          HeartRateSample(
            externalId: r['id'] as String,
            bpm: (r['bpm'] as num).toInt(),
            recordedAt: _utc(r['time_millis']),
            tzOffsetMinutes: (r['tz_offset_minutes'] as num).toInt(),
          ),
    ];
  }

  @override
  Future<List<SleepSessionSample>> readSleepSessions({required DateTime from, required DateTime to}) async {
    if (!allowed.contains(HealthConnectData.sleep)) return const [];
    final out = <SleepSessionSample>[];
    for (final r in await bridge.readSleep(from, to)) {
      final start = _utc(r['start_millis']);
      final end = _utc(r['end_millis']);
      if (!end.isAfter(start)) continue;
      out.add(SleepSessionSample(
        externalId: r['id'] as String,
        startedAt: start,
        endedAt: end,
        tzOffsetMinutes: (r['tz_offset_minutes'] as num).toInt(),
        stages: [
          for (final s in (r['stages'] as List? ?? const []))
            if (!_utc((s as Map)['end_millis']).isBefore(_utc(s['start_millis'])))
              SleepStageSample(
                stage: SleepStage.fromWireValue(s['stage'] as String),
                startedAt: _utc(s['start_millis']),
                endedAt: _utc(s['end_millis']),
              ),
        ],
      ));
    }
    return out;
  }
}

/// Resultado de uma sincronização, para a tela dizer o que aconteceu.
enum WearableSyncState { ok, notConnected, unavailable, noPermission, error, noResponse }

class WearableSyncOutcome {
  final WearableSyncState state;
  final WearableSyncResult? result;
  const WearableSyncOutcome(this.state, [this.result]);
}

/// Liga/desliga a leitura do Health Connect e sincroniza (Conta ›
/// Dispositivos, Sono, e a cada abertura do app quando ligado). O dado vira
/// `HealthEvent` com `source: wearable`; ler a mesma janela de novo não
/// duplica (dedup por `(source, external_id)`).
class WearableSync with WidgetsBindingObserver {
  final HealthConnectBridge bridge;
  final HealthDataCore core;
  final ProfileRepository settings;
  final VoidCallback onDataChanged;
  final DateTime Function() clock;

  /// Na primeira sincronização, quanto do passado buscar.
  static const firstSyncDays = 30;

  /// Sobreposição com a sincronização anterior (registros que chegam
  /// atrasados da pulseira).
  static const overlap = Duration(days: 2);

  WearableSync({
    required this.bridge,
    required this.core,
    required this.settings,
    required this.onDataChanged,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  bool get enabled => settings.getSetting('health_connect') == '1';

  Timer? _autoTimer;
  bool _autoSyncing = false;

  /// Com o app aberto: lê de novo a cada [every] e quando o app volta para
  /// a frente — passos e sono chegam sem tocar em botão (ADR-20). Com o app
  /// fechado não lê; ao abrir, atualiza.
  void startAutoSync({Duration every = const Duration(minutes: 5)}) {
    if (_autoTimer != null) return;
    WidgetsBinding.instance.addObserver(this);
    _autoTimer = Timer.periodic(every, (_) => _autoSync());
  }

  void stopAutoSync() {
    _autoTimer?.cancel();
    _autoTimer = null;
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _autoSync();
  }

  Future<void> _autoSync() async {
    if (!enabled || _autoSyncing) return;
    _autoSyncing = true;
    try {
      await syncNow();
    } finally {
      _autoSyncing = false;
    }
  }

  DateTime? get lastSyncUtc {
    final v = settings.getSetting('health_connect_last_sync');
    return v == null ? null : DateTime.parse(v);
  }

  /// "Conectar pelo Health Connect": pede a permissão de leitura e, se
  /// alguma for dada, liga e sincroniza.
  Future<WearableSyncOutcome> connect({Duration permissionTimeout = const Duration(seconds: 60), bool askMissing = true}) async {
    if (await bridge.status() != HealthConnectStatus.available) return const WearableSyncOutcome(WearableSyncState.unavailable);
    // Já permitido (ex.: pela tela do próprio Health Connect): liga direto.
    // Faltando algo (ex.: passos, novo), pede de novo — só quando a pessoa tocou.
    var granted = await bridge.grantedPermissions();
    if (granted.isEmpty || (askMissing && granted.length < HealthConnectData.values.length)) {
      try {
        granted = await bridge.requestPermissions().timeout(permissionTimeout);
      } on TimeoutException {
        // A tela de permissões não abriu ou não devolveu resposta.
        return const WearableSyncOutcome(WearableSyncState.noResponse);
      } on PlatformException {
        return const WearableSyncOutcome(WearableSyncState.noResponse);
      }
    }
    if (granted.isEmpty) return const WearableSyncOutcome(WearableSyncState.noPermission);
    settings.setSetting('health_connect', '1');
    return syncNow();
  }

  /// Para de ler. O que já foi lido continua no RLT; a permissão se tira no
  /// próprio Health Connect.
  void disconnect() {
    settings.setSetting('health_connect', '0');
    onDataChanged();
  }

  /// Passos do Health Connect (ADR-20): um evento por dia, só quando o
  /// total mudou. Fica guardado no RLT mesmo que o Health Connect apague.
  Future<int> _syncDailySteps(DateTime fromUtc, DateTime nowUtc) async {
    var added = 0;
    for (final r in await bridge.readDailySteps(fromUtc, nowUtc)) {
      final day = DateTime.tryParse('${r['day']}');
      final count = (r['count'] as num?)?.toInt() ?? 0;
      if (day == null || count <= 0) continue;
      final localMidnight = DateTime(day.year, day.month, day.day);
      final start = localMidnight.toUtc();
      final stored = core
          .queryByType(HealthEventType.steps, from: start, to: start.add(const Duration(hours: 23, minutes: 59)))
          .where((e) => isDailyStepTotal(e) && e.source == HealthEventSource.wearable)
          .fold<HealthEvent?>(null, (a, e) => a == null || e.recordedAt.isAfter(a.recordedAt) ? e : a);
      if (stored != null && (stored.payload['count'] as num).toInt() == count) continue;
      core.insertEvent(HealthEvent(
        id: HealthDataCore.newId(),
        type: HealthEventType.steps,
        source: HealthEventSource.wearable,
        occurredAt: start,
        occurredAtTzOffsetMinutes: localMidnight.timeZoneOffset.inMinutes,
        recordedAt: nowUtc,
        payload: {'count': count, 'day': r['day'], 'daily_total': true},
        confidence: 1.0,
        externalId: 'hc-steps-${r['day']}-${nowUtc.microsecondsSinceEpoch}',
      ));
      added++;
    }
    return added;
  }

  Future<WearableSyncOutcome> syncNow() async {
    if (!enabled) return const WearableSyncOutcome(WearableSyncState.notConnected);
    try {
      if (await bridge.status() != HealthConnectStatus.available) return const WearableSyncOutcome(WearableSyncState.unavailable);
      final allowed = await bridge.grantedPermissions();
      if (allowed.isEmpty) return const WearableSyncOutcome(WearableSyncState.noPermission);
      final now = clock().toUtc();
      final last = lastSyncUtc;
      final from = last == null ? now.subtract(const Duration(days: firstSyncDays)) : last.subtract(overlap);
      final result = await WearableSyncLogger(core: core, dataSource: HealthConnectDataSource(bridge, allowed: allowed))
          .sync(from: from, to: now);
      if (allowed.contains(HealthConnectData.steps)) await _syncDailySteps(from, now);
      settings.setSetting('health_connect_last_sync', now.toIso8601String());
      onDataChanged();
      return WearableSyncOutcome(WearableSyncState.ok, result);
    } on HealthConnectPermissionException {
      return const WearableSyncOutcome(WearableSyncState.noPermission);
    } on PlatformException {
      return const WearableSyncOutcome(WearableSyncState.error);
    } on MissingPluginException {
      return const WearableSyncOutcome(WearableSyncState.unavailable);
    }
  }
}
