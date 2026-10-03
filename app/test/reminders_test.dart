import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/reminders/reminders.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_health_records/health_records.dart';

Medication med({bool reminders = true, List<int> times = const [8 * 60, 20 * 60], LocalDate? end}) => Medication(
      id: 'm1',
      name: 'Losartana',
      doseAmount: 50,
      doseUnit: 'mg',
      timesOfDay: times,
      startDate: LocalDate(2026, 10, 1),
      endDate: end,
      remindersEnabled: reminders,
    );

void main() {
  final now = DateTime(2026, 10, 3, 12, 0); // sábado, meio-dia (hora local)

  test('remédio: só horários futuros, 7 dias, texto com dose e horário', () {
    final r = planReminders(medications: [med()], prefs: const ReminderPrefs(), now: now);
    // hoje só 20:00 (08:00 já passou) + 6 dias × 2 horários
    expect(r, hasLength(13));
    expect(r.first.atUtc, DateTime(2026, 10, 3, 20).toUtc());
    expect(r.first.body, contains('Losartana 50 mg — 20:00'));
    expect(r.every((x) => x.atUtc.isAfter(now.toUtc())), isTrue);
    expect(r.map((x) => x.id).toSet(), hasLength(r.length)); // ids únicos
  });

  test('remédio com lembrete desligado ou tratamento acabado não agenda', () {
    expect(planReminders(medications: [med(reminders: false)], prefs: const ReminderPrefs(), now: now), isEmpty);
    final ending = planReminders(medications: [med(end: LocalDate(2026, 10, 4))], prefs: const ReminderPrefs(), now: now);
    expect(ending, hasLength(3)); // hoje 20:00, amanhã 08:00 e 20:00
  });

  test('água a cada 3 h das 8h às 22h e treino no horário escolhido', () {
    final r = planReminders(
      medications: const [],
      prefs: const ReminderPrefs(waterOn: true, waterEveryHours: 3, workoutOn: true, workoutMinutes: 18 * 60),
      now: now,
      days: 1,
    );
    final water = r.where((x) => x.title == 'Beber água').map((x) => x.atUtc.toLocal().hour).toList();
    expect(water, [14, 17, 20]); // 8, 11 já passaram
    expect(r.where((x) => x.title == 'Hora do treino').single.atUtc.toLocal().hour, 18);
  });

  testWidgets('cadastrar remédio com lembrete replaneja no agendador', (tester) async {
    final scheduler = NoopReminderScheduler();
    final deps = AppDependencies.inMemory(
      confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
      shareSheet: FakeShareSheet(),
      imageCapturer: FakeCardImageCapturer(),
      reminderScheduler: scheduler,
    );
    addTearDown(deps.close);
    final today = DateTime.now();
    deps.medicationRepository.save(Medication(
      id: 'x',
      name: 'Vitamina D',
      doseAmount: 2000,
      doseUnit: 'UI',
      timesOfDay: const [23 * 60 + 59],
      startDate: LocalDate(today.year, today.month, today.day),
    ));
    deps.notifyDataChanged();
    await tester.pump();
    expect(scheduler.last.where((r) => r.body.contains('Vitamina D')), isNotEmpty);
  });
}
