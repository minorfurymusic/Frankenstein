import 'dart:convert';

import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_profile/profile.dart';

/// Um aviso de quebra de rotina (ADR-24): quando dispara e o que pergunta.
/// O texto é do app; a IA só entra se a pessoa responder no Cérebro.
class RoutineNudge {
  /// `mood`, `meds`, `activity` ou `meals` — um tipo por vez.
  final String kind;

  /// Hora local em que o aviso aparece, se nada mudar até lá.
  final DateTime atLocal;
  final String title;
  final String question;
  const RoutineNudge({required this.kind, required this.atLocal, required this.title, required this.question});

  /// Identifica o aviso (o mesmo aviso não aparece duas vezes no Cérebro).
  String get key => '$kind@${atLocal.toIso8601String()}';
}

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// Decide o próximo aviso a partir dos dias com registro (hora local).
/// Lógica pura, testada sem relógio real.
///
/// - Humor: os 3 últimos registros, em até 5 dias, todos "mal" ou "muito
///   mal" → pergunta no dia seguinte às 10h.
/// - Atividade (treino, corrida ou caminhada gravada): com hábito de pelo
///   menos 3 dias por semana nas 4 semanas antes do último registro, 3 dias
///   sem nada → pergunta às 19h do 3º dia.
/// - Refeições: com registro em pelo menos 11 dos 14 dias antes do último,
///   2 dias sem registrar → pergunta às 20h do 2º dia.
///
/// - Remédio de uso contínuo que a pessoa costuma marcar (pelo menos 5 dos
///   7 dias antes da última marcação): 2 dias sem marcar → pergunta às 21h
///   do 2º dia, com o nome do remédio (a notificação é local).
///
/// Prioridade: humor, remédio, atividade, refeições. No máximo um aviso.
/// [skip]: tipos que a pessoa desligou.
RoutineNudge? planRoutineNudge({
  required List<DateTime> activityLocal,
  required List<DateTime> mealLocal,
  required List<(DateTime, int)> moodLocal,
  required DateTime now,
  List<(String, List<DateTime>)> medsTakenLocal = const [],
  Set<String> skip = const {},
}) {
  // Humor em queda.
  final moods = [...moodLocal]..sort((a, b) => b.$1.compareTo(a.$1));
  if (!skip.contains('mood') && moods.length >= 3) {
    final last3 = moods.take(3).toList();
    final span = last3.first.$1.difference(last3.last.$1);
    if (last3.every((m) => m.$2 <= 2) && span <= const Duration(days: 5)) {
      final at = _day(last3.first.$1).add(const Duration(days: 1, hours: 10));
      if (now.difference(at) < const Duration(days: 1)) {
        return RoutineNudge(
          kind: 'mood',
          atLocal: at,
          title: 'Como você está?',
          question: 'Seus últimos registros de humor foram baixos. Quer me contar o que está acontecendo? '
              'Se precisar conversar agora, o CVV atende no 188, 24 h.',
        );
      }
    }
  }

  RoutineNudge? gap(List<DateTime> local, {required int windowDays, required int minDays, required int gapDays, required int hour,
      required String kind, required String title, required String question}) {
    if (local.isEmpty) return null;
    final days = {for (final d in local) _day(d)};
    final last = days.reduce((a, b) => a.isAfter(b) ? a : b);
    final from = last.subtract(Duration(days: windowDays));
    final inWindow = days.where((d) => !d.isBefore(from) && d.isBefore(last)).length;
    if (inWindow < minDays) return null; // sem hábito, sem aviso
    final at = last.add(Duration(days: gapDays, hours: hour));
    // Aviso que já passou há mais de um dia não volta.
    if (now.difference(at) >= const Duration(days: 1)) return null;
    return RoutineNudge(kind: kind, atLocal: at, title: title, question: question);
  }

  if (!skip.contains('meds')) {
    for (final (name, taken) in medsTakenLocal) {
      final n = gap(
        taken,
        windowDays: 7,
        minDays: 5,
        gapDays: 2,
        hour: 21,
        kind: 'meds',
        title: 'Remédio',
        question: 'Faz 2 dias que você não marca o $name como tomado. Está tudo bem? '
            'Se só esqueceu de marcar, dá para registrar agora. Mudança no remédio, só com o seu médico.',
      );
      if (n != null) return n;
    }
  }
  return (skip.contains('activity')
          ? null
          : gap(
              activityLocal,
        windowDays: 28,
        minDays: 12,
        gapDays: 3,
        hour: 19,
        kind: 'activity',
        title: 'Está tudo bem?',
              question: 'Faz 3 dias sem caminhada ou treino, e você costuma se mexer quase todo dia. '
                  'Está tudo bem? Me conte como você está.',
            )) ??
      (skip.contains('meals')
          ? null
          : gap(
        mealLocal,
        windowDays: 14,
        minDays: 11,
        gapDays: 2,
        hour: 20,
        kind: 'meals',
        title: 'Está tudo bem?',
        question: 'Faz 2 dias sem registro de refeição. Aconteceu alguma coisa? Se quiser, me conte como você está.',
      ));
}

/// Liga a lógica ao banco e guarda o que já foi mostrado.
class RoutineWatch {
  final HealthDataCore core;
  final ProfileRepository settings;
  /// Trocável nos testes.
  DateTime Function() clock;
  RoutineWatch({required this.core, required this.settings, DateTime Function()? clock}) : clock = clock ?? DateTime.now;

  /// Pode desligar em Conta › Lembretes (todos ou por tipo).
  bool get enabled => settings.getSetting('routine_nudges') != 'off';
  set enabled(bool on) => settings.setSetting('routine_nudges', on ? 'on' : 'off');

  static const kinds = {
    'mood': 'Humor baixo 3 vezes seguidas',
    'meds': 'Remédio sem marcar por 2 dias',
    'activity': '3 dias sem caminhada ou treino',
    'meals': '2 dias sem registrar comida',
  };

  Set<String> get disabledKinds {
    final raw = settings.getSetting('routine_nudges_off');
    return raw == null || raw.isEmpty ? <String>{} : raw.split(',').toSet();
  }

  bool kindEnabled(String kind) => !disabledKinds.contains(kind);
  void setKind(String kind, bool on) {
    final off = disabledKinds;
    on ? off.remove(kind) : off.add(kind);
    settings.setSetting('routine_nudges_off', off.join(','));
  }

  List<DateTime> _local(HealthEventType type, {int days = 60}) {
    final now = clock().toUtc();
    return [
      for (final e in core.queryByType(type, from: now.subtract(Duration(days: days)), to: now.add(const Duration(days: 1))))
        e.occurredAt.add(Duration(minutes: e.occurredAtTzOffsetMinutes)),
    ];
  }

  RoutineNudge? next() {
    if (!enabled) return null;
    final now = clock();
    final moods = [
      for (final e in core.queryByType(HealthEventType.mood,
          from: now.toUtc().subtract(const Duration(days: 14)), to: now.toUtc().add(const Duration(days: 1))))
        (e.occurredAt.add(Duration(minutes: e.occurredAtTzOffsetMinutes)), (e.payload['mood'] as num).toInt()),
    ];
    final nudge = planRoutineNudge(
      activityLocal: [..._local(HealthEventType.workoutSession), ..._local(HealthEventType.gpsTrack)],
      mealLocal: _local(HealthEventType.meal, days: 30),
      moodLocal: moods,
      now: now,
      medsTakenLocal: _medsTaken(now),
      skip: disabledKinds,
    );
    if (nudge == null || _shown.contains(nudge.key)) return null;
    return nudge;
  }

  /// Marcações "tomei" por remédio cadastrado (uso contínuo, com horário).
  List<(String, List<DateTime>)> _medsTaken(DateTime now) {
    final doses = core.queryByType(HealthEventType.medicationDose,
        from: now.toUtc().subtract(const Duration(days: 30)), to: now.toUtc().add(const Duration(days: 1)));
    final byMed = <String, (String, List<DateTime>)>{};
    for (final e in doses) {
      final id = e.payload['medication_id'] as String?;
      if (id == null || e.payload['status'] != 'taken') continue;
      final entry = byMed.putIfAbsent(id, () => ('${e.payload['name']}', <DateTime>[]));
      entry.$2.add(e.occurredAt.add(Duration(minutes: e.occurredAtTzOffsetMinutes)));
    }
    final active = activeMedicationIds?.call();
    return [for (final MapEntry(:key, :value) in byMed.entries) if (active == null || active.contains(key)) value];
  }

  /// Remédios ainda em uso (o que foi encerrado não gera aviso).
  Set<String> Function()? activeMedicationIds;

  Set<String> get _shown {
    final raw = settings.getSetting('routine_nudges_shown');
    return raw == null ? <String>{} : {for (final k in jsonDecode(raw) as List) '$k'};
  }

  /// Aviso cuja hora chegou e que ainda não apareceu no Cérebro.
  RoutineNudge? due() {
    final n = next();
    if (n == null || clock().isBefore(n.atLocal)) return null;
    return n;
  }

  void markShown(RoutineNudge n) {
    final shown = [..._shown, n.key];
    settings.setSetting('routine_nudges_shown', jsonEncode(shown.length > 30 ? shown.sublist(shown.length - 30) : shown));
  }
}
