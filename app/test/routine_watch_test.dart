import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/home_shell.dart';
import 'package:frankstein/insights/routine_watch.dart';
import 'package:frankstein/reminders/reminders.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein/theme/rlt_theme.dart';

import 'support/fonts.dart';

/// Um registro por dia, às 18h, nos dias [days] antes de [last].
List<DateTime> daily(DateTime last, Iterable<int> days) => [for (final d in days) DateTime(last.year, last.month, last.day - d, 18)];

void main() {
  final last = DateTime(2026, 10, 10);

  group('planRoutineNudge (lógica pura)', () {
    test('caminha quase todo dia e parou: aviso às 19h do 3º dia', () {
      final n = planRoutineNudge(
        activityLocal: daily(last, [for (var i = 0; i < 28; i++) if (i % 7 != 3) i]),
        mealLocal: const [],
        moodLocal: const [],
        now: DateTime(2026, 10, 11, 9),
      )!;
      expect(n.kind, 'activity');
      expect(n.atLocal, DateTime(2026, 10, 13, 19));
      expect(n.question, contains('3 dias sem caminhada'));
    });

    test('quem não tem hábito não recebe aviso', () {
      final n = planRoutineNudge(
        activityLocal: daily(last, [0, 5, 12, 20]),
        mealLocal: const [],
        moodLocal: const [],
        now: DateTime(2026, 10, 11),
      );
      expect(n, isNull);
    });

    test('aviso velho (mais de um dia depois da hora) não volta', () {
      final n = planRoutineNudge(
        activityLocal: daily(last, [for (var i = 0; i < 28; i++) i]),
        mealLocal: const [],
        moodLocal: const [],
        now: DateTime(2026, 10, 20),
      );
      expect(n, isNull);
    });

    test('refeições: 2 dias sem registrar quem registra todo dia', () {
      final n = planRoutineNudge(
        activityLocal: const [],
        mealLocal: daily(last, [for (var i = 0; i < 14; i++) i]),
        moodLocal: const [],
        now: DateTime(2026, 10, 11),
      )!;
      expect(n.kind, 'meals');
      expect(n.atLocal, DateTime(2026, 10, 12, 20));
    });

    test('humor baixo 3 vezes seguidas vem antes de tudo e cita o CVV', () {
      final n = planRoutineNudge(
        activityLocal: daily(last, [for (var i = 0; i < 28; i++) i]),
        mealLocal: const [],
        moodLocal: [(DateTime(2026, 10, 8, 21), 2), (DateTime(2026, 10, 9, 21), 1), (DateTime(2026, 10, 10, 21), 2)],
        now: DateTime(2026, 10, 10, 22),
      )!;
      expect(n.kind, 'mood');
      expect(n.atLocal, DateTime(2026, 10, 11, 10));
      expect(n.question, contains('188'));
    });

    test('remédio que a pessoa sempre marca, 2 dias sem marcar: aviso às 21h com o nome', () {
      final n = planRoutineNudge(
        activityLocal: daily(last, [for (var i = 0; i < 28; i++) i]),
        mealLocal: const [],
        moodLocal: const [],
        medsTakenLocal: [('Enalapril', daily(last, [for (var i = 0; i < 8; i++) i]))],
        now: DateTime(2026, 10, 11, 9),
      )!;
      expect(n.kind, 'meds'); // vem antes da atividade
      expect(n.atLocal, DateTime(2026, 10, 12, 21));
      expect(n.question, contains('Enalapril'));
      expect(n.question, contains('só com o seu médico'));
    });

    test('tipo desligado pula para o próximo', () {
      final n = planRoutineNudge(
        activityLocal: daily(last, [for (var i = 0; i < 28; i++) i]),
        mealLocal: const [],
        moodLocal: const [],
        medsTakenLocal: [('Enalapril', daily(last, [for (var i = 0; i < 8; i++) i]))],
        now: DateTime(2026, 10, 11, 9),
        skip: const {'meds'},
      )!;
      expect(n.kind, 'activity');
    });

    test('humor misto não avisa', () {
      final n = planRoutineNudge(
        activityLocal: const [],
        mealLocal: const [],
        moodLocal: [(DateTime(2026, 10, 8), 2), (DateTime(2026, 10, 9), 4), (DateTime(2026, 10, 10), 1)],
        now: DateTime(2026, 10, 10, 22),
      );
      expect(n, isNull);
    });
  });

  group('no app', () {
    setUpAll(loadFigtree);

    late AppDependencies deps;
    late NoopReminderScheduler scheduler;
    setUp(() {
      scheduler = NoopReminderScheduler();
      deps = AppDependencies.inMemory(
        confirmationGate: AppConfirmationGate(GlobalKey<NavigatorState>()),
        shareSheet: FakeShareSheet(),
        imageCapturer: FakeCardImageCapturer(),
        reminderScheduler: scheduler,
      );
    });
    tearDown(() => deps.close());

    void mood(int value, DateTime local) =>
        deps.moodLogger.log(mood: value, occurredAt: local.toUtc(), occurredAtTzOffsetMinutes: local.timeZoneOffset.inMinutes);

    testWidgets('aviso que chegou abre o Cérebro com a pergunta, uma vez só; desligar tira o agendamento', (tester) async {
      final today = DateTime.now();
      final base = DateTime(today.year, today.month, today.day);
      for (var d = 3; d >= 1; d--) {
        mood(1, base.subtract(Duration(days: d)).add(const Duration(hours: 9)));
      }
      // Ontem às 8h: o aviso é para hoje às 10h e entra no agendamento.
      deps.routineWatch.clock = () => base.subtract(const Duration(hours: 16));
      await deps.reminders.syncNow();
      expect(deps.routineWatch.due(), isNull); // ainda não chegou a hora

      // Hoje às 11h: a hora chegou; abrir o app mostra a pergunta no Cérebro.
      deps.routineWatch.clock = () => base.add(const Duration(hours: 11));
      tester.view.physicalSize = const Size(420, 2000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: RltTheme.light(), home: HomeShell(dependencies: deps)));
      await tester.pumpAndSettle();
      expect(find.textContaining('últimos registros de humor'), findsOneWidget);
      expect(deps.routineWatch.due(), isNull); // não repete

      deps.routineWatch.enabled = false;
      await deps.reminders.syncNow();
      expect(scheduler.last.where((r) => r.id == 400000), isEmpty);
    });

    test('cada tipo de aviso liga e desliga sozinho', () {
      expect(deps.routineWatch.kindEnabled('meds'), isTrue);
      deps.routineWatch.setKind('meds', false);
      deps.routineWatch.setKind('meals', false);
      expect(deps.routineWatch.disabledKinds, {'meds', 'meals'});
      deps.routineWatch.setKind('meds', true);
      expect(deps.routineWatch.kindEnabled('meds'), isTrue);
      expect(deps.routineWatch.kindEnabled('meals'), isFalse);
    });

    test('agendamento do Android leva o aviso futuro', () async {
      final today = DateTime.now();
      final base = DateTime(today.year, today.month, today.day);
      for (var d = 2; d >= 0; d--) {
        mood(2, base.subtract(Duration(days: d)).add(const Duration(minutes: 30)));
      }
      deps.routineWatch.clock = () => base.add(const Duration(hours: 1));
      await deps.reminders.syncNow();
      final r = scheduler.last.where((r) => r.id == 400000).single;
      expect(r.atUtc, base.add(const Duration(days: 1, hours: 10)).toUtc());
      expect(r.body, contains('humor'));
    });
  });
}
