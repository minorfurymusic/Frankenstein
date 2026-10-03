import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_profile/profile.dart';

/// Um lembrete agendado: instante (UTC) e o texto da notificação.
class PlannedReminder {
  final int id;
  final DateTime atUtc;
  final String title;
  final String body;
  const PlannedReminder({required this.id, required this.atUtc, required this.title, required this.body});

  Map<String, Object> toChannel() => {
        'id': id,
        'at_millis': atUtc.millisecondsSinceEpoch,
        'title': title,
        'body': body,
      };
}

/// Preferências de lembrete guardadas em Conta › Lembretes.
class ReminderPrefs {
  final bool waterOn;
  final int waterEveryHours;
  final bool workoutOn;
  final int workoutMinutes; // minutos desde 00:00
  const ReminderPrefs({
    this.waterOn = false,
    this.waterEveryHours = 2,
    this.workoutOn = false,
    this.workoutMinutes = 18 * 60,
  });

  factory ReminderPrefs.fromSettings(ProfileRepository settings) {
    final raw = settings.getSetting('reminders');
    if (raw == null) return const ReminderPrefs();
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return ReminderPrefs(
      waterOn: m['water_on'] as bool? ?? false,
      waterEveryHours: (m['water_every_hours'] as num?)?.toInt() ?? 2,
      workoutOn: m['workout_on'] as bool? ?? false,
      workoutMinutes: (m['workout_time'] as num?)?.toInt() ?? 18 * 60,
    );
  }
}

/// Planeja os lembretes dos próximos [days] dias a partir de [now] (hora
/// local do aparelho): cada horário de remédio com lembrete ligado, água a
/// cada N horas das 8h às 22h, treino no horário escolhido. Lógica pura —
/// o agendamento de verdade é do Android (`Reminders.kt`).
List<PlannedReminder> planReminders({
  required List<Medication> medications,
  required ReminderPrefs prefs,
  required DateTime now,
  int days = 7,
}) {
  final out = <PlannedReminder>[];
  final today = DateTime(now.year, now.month, now.day);
  var seq = 0;
  int nextId(int kind) => kind * 100000 + (seq++);

  for (var d = 0; d < days; d++) {
    final day = today.add(Duration(days: d));
    final localDate = LocalDate(day.year, day.month, day.day);
    DateTime at(int minutes) => DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

    for (final m in medications) {
      if (!m.remindersEnabled || !m.isActiveOn(localDate)) continue;
      for (final t in m.timesOfDay) {
        final when = at(t);
        if (!when.isAfter(now)) continue;
        final amount = m.doseAmount == m.doseAmount.roundToDouble() ? m.doseAmount.toInt().toString() : '${m.doseAmount}';
        out.add(PlannedReminder(
          id: nextId(1),
          atUtc: when.toUtc(),
          title: 'Hora do remédio',
          body: '${m.name} $amount ${m.doseUnit} — ${formatTimeOfDay(t)}. Toque para marcar "tomei".',
        ));
      }
    }
    if (prefs.waterOn && prefs.waterEveryHours > 0) {
      for (var h = 8; h <= 22; h += prefs.waterEveryHours) {
        final when = at(h * 60);
        if (!when.isAfter(now)) continue;
        out.add(PlannedReminder(id: nextId(2), atUtc: when.toUtc(), title: 'Beber água', body: 'Que tal um copo de água agora?'));
      }
    }
    if (prefs.workoutOn) {
      final when = at(prefs.workoutMinutes);
      if (when.isAfter(now)) {
        out.add(PlannedReminder(id: nextId(3), atUtc: when.toUtc(), title: 'Hora do treino', body: 'Seu treino de hoje está esperando.'));
      }
    }
  }
  out.sort((a, b) => a.atUtc.compareTo(b.atUtc));
  // O Android limita alarmes por app; 7 dias cabem com folga, mas corta
  // por segurança.
  return out.length > 400 ? out.sublist(0, 400) : out;
}

/// Quem agenda de verdade. Em teste/desktop é um no-op.
abstract class ReminderScheduler {
  Future<void> sync(List<PlannedReminder> reminders);
  Future<bool> hasPermission();
  Future<bool> requestPermission();
}

class NoopReminderScheduler implements ReminderScheduler {
  List<PlannedReminder> last = const [];
  @override
  Future<void> sync(List<PlannedReminder> reminders) async => last = reminders;
  @override
  Future<bool> hasPermission() async => true;
  @override
  Future<bool> requestPermission() async => true;
}

class AndroidReminderScheduler implements ReminderScheduler {
  static const _channel = MethodChannel('rlt/reminders');

  @override
  Future<void> sync(List<PlannedReminder> reminders) =>
      _channel.invokeMethod<int>('sync', [for (final r in reminders) r.toChannel()]);

  @override
  Future<bool> hasPermission() async => await _channel.invokeMethod<bool>('hasNotificationPermission') ?? false;

  @override
  Future<bool> requestPermission() async => await _channel.invokeMethod<bool>('requestNotificationPermission') ?? false;
}

ReminderScheduler defaultReminderScheduler() =>
    !kIsWeb && Platform.isAndroid ? AndroidReminderScheduler() : NoopReminderScheduler();

/// Mantém os lembretes do Android em dia: replaneja quando os dados mudam
/// (remédio novo, lembrete ligado/desligado) e ao abrir o app.
class ReminderSync {
  final ReminderScheduler scheduler;
  final List<Medication> Function() medications;
  final ReminderPrefs Function() prefs;
  final DateTime Function() clock;
  bool _pending = false;
  bool _disposed = false;

  ReminderSync({required this.scheduler, required this.medications, required this.prefs, DateTime Function()? clock})
      : clock = clock ?? DateTime.now;

  Future<void> syncNow() async {
    try {
      await scheduler.sync(planReminders(medications: medications(), prefs: prefs(), now: clock()));
    } on PlatformException {
      // Sem canal nativo (ex.: build sem o código Android) — lembrete é
      // melhor esforço, nunca derruba o app.
    } on MissingPluginException {
      // idem
    }
  }

  /// Agrupa várias mudanças seguidas numa sincronização só, na mesma volta
  /// do laço de eventos (sem timer).
  void schedule() {
    if (_pending || _disposed) return;
    _pending = true;
    scheduleMicrotask(() {
      _pending = false;
      if (!_disposed) syncNow();
    });
  }

  void dispose() => _disposed = true;
}
