import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:test/test.dart';

WorkoutPlan _samplePlan({String id = 'plano-a'}) => WorkoutPlan(
      id: id,
      name: 'Treino A — peito e tríceps',
      exercises: [
        PlannedExercise(
          exerciseId: 'supino-reto',
          exerciseName: 'Supino reto',
          targetSets: 4,
          targetReps: 8,
          targetLoadKg: 60,
        ),
        PlannedExercise(
          exerciseId: 'triceps-corda',
          exerciseName: 'Tríceps corda',
          targetSets: 3,
          targetReps: 12,
        ),
      ],
    );

void main() {
  group('PlannedExercise/WorkoutPlan — validação', () {
    test('rejeita targetSets <= 0', () {
      expect(
        () => PlannedExercise(
          exerciseId: 'x',
          exerciseName: 'x',
          targetSets: 0,
          targetReps: 8,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita plano sem exercícios', () {
      expect(
        () => WorkoutPlan(id: 'p', name: 'vazio', exercises: []),
        throwsArgumentError,
      );
    });
  });

  group('SetEntry/WorkoutSessionInput — validação', () {
    test('rejeita rpe fora de 1-10', () {
      expect(
        () => SetEntry(
          exerciseId: 'x',
          exerciseName: 'x',
          setNumber: 1,
          reps: 8,
          loadKg: 40,
          rpe: 11,
        ),
        throwsArgumentError,
      );
    });

    test('rejeita sessão sem séries', () {
      expect(
        () => WorkoutSessionInput(sets: []),
        throwsArgumentError,
      );
    });
  });

  group('WorkoutRepository', () {
    late WorkoutRepository repo;
    setUp(() => repo = WorkoutRepository.openInMemory());
    tearDown(() => repo.close());

    test('insertPlan + findPlanById devolve o plano com exercícios na ordem', () {
      repo.insertPlan(_samplePlan());

      final found = repo.findPlanById('plano-a');
      expect(found, isNotNull);
      expect(found!.name, 'Treino A — peito e tríceps');
      expect(found.exercises, hasLength(2));
      expect(found.exercises[0].exerciseId, 'supino-reto');
      expect(found.exercises[0].targetLoadKg, 60);
      expect(found.exercises[1].exerciseId, 'triceps-corda');
      expect(found.exercises[1].targetLoadKg, isNull);
    });

    test('findPlanById de plano inexistente devolve null', () {
      expect(repo.findPlanById('nao-existe'), isNull);
    });
  });

  group('WorkoutLogger', () {
    late HealthDataCore core;
    late WorkoutLogger logger;
    setUp(() {
      core = HealthDataCore.openInMemory();
      logger = WorkoutLogger(core: core);
    });
    tearDown(() => core.close());

    test('logSession grava 1 workout_session + N set_log referenciando a sessão', () {
      final input = WorkoutSessionInput(
        planId: 'plano-a',
        notes: 'Boa sessão',
        sets: [
          SetEntry(
            exerciseId: 'supino-reto',
            exerciseName: 'Supino reto',
            setNumber: 1,
            reps: 8,
            loadKg: 60,
            rpe: 8,
          ),
          SetEntry(
            exerciseId: 'supino-reto',
            exerciseName: 'Supino reto',
            setNumber: 2,
            reps: 6,
            loadKg: 65,
          ),
        ],
      );

      final event = logger.logSession(
        input,
        occurredAt: DateTime.utc(2026, 8, 10, 18, 0),
        occurredAtTzOffsetMinutes: -180,
      );

      expect(event.type, HealthEventType.workoutSession);
      expect(event.payload['plan_id'], 'plano-a');
      expect(event.payload['sets_count'], 2);

      final sessions = core.queryByType(HealthEventType.workoutSession);
      expect(sessions, hasLength(1));

      final setLogs = core.queryByType(HealthEventType.setLog);
      expect(setLogs, hasLength(2));
      expect(setLogs[0].payload['session_event_id'], event.id);
      expect(setLogs[0].payload['load_kg'], 60);
      expect(setLogs[1].payload['load_kg'], 65);
      expect(setLogs[1].payload['rpe'], isNull);
    });

    test('personalRecord devolve a maior carga já registrada do exercício', () {
      logger.logSession(
        WorkoutSessionInput(sets: [
          SetEntry(exerciseId: 'supino-reto', exerciseName: 'Supino reto', setNumber: 1, reps: 8, loadKg: 60),
        ]),
        occurredAt: DateTime.utc(2026, 8, 1),
        occurredAtTzOffsetMinutes: -180,
      );
      logger.logSession(
        WorkoutSessionInput(sets: [
          SetEntry(exerciseId: 'supino-reto', exerciseName: 'Supino reto', setNumber: 1, reps: 5, loadKg: 70),
          SetEntry(exerciseId: 'triceps-corda', exerciseName: 'Tríceps corda', setNumber: 1, reps: 12, loadKg: 20),
        ]),
        occurredAt: DateTime.utc(2026, 8, 10),
        occurredAtTzOffsetMinutes: -180,
      );

      final pr = logger.personalRecord('supino-reto');
      expect(pr, isNotNull);
      expect(pr!.loadKg, 70);
      expect(pr.reps, 5);
    });

    test('personalRecord de exercício nunca registrado devolve null', () {
      expect(logger.personalRecord('nunca-fiz'), isNull);
    });
  });

  group('get_workout_plan / log_workout_session — ferramentas do cérebro', () {
    late WorkoutRepository repo;
    late HealthDataCore core;
    late WorkoutLogger logger;
    setUp(() {
      repo = WorkoutRepository.openInMemory();
      repo.insertPlan(_samplePlan());
      core = HealthDataCore.openInMemory();
      logger = WorkoutLogger(core: core);
    });
    tearDown(() {
      repo.close();
      core.close();
    });

    test('getWorkoutPlanSpec é ferramenta de leitura, sem confirmação', () {
      final spec = getWorkoutPlanSpec();
      expect(spec.write, isFalse);
      expect(spec.confirm, isFalse);
      expect(spec.module, 'activity');
    });

    test('get_workout_plan devolve o plano encontrado', () async {
      final handler = getWorkoutPlanHandler(repo);
      final result = await handler({'plan_id': 'plano-a'});

      expect(result.success, isTrue);
      expect(result.data!['name'], 'Treino A — peito e tríceps');
      expect(result.data!['exercises'], hasLength(2));
    });

    test('get_workout_plan de plano inexistente devolve falha', () async {
      final handler = getWorkoutPlanHandler(repo);
      final result = await handler({'plan_id': 'nao-existe'});

      expect(result.success, isFalse);
    });

    test('logWorkoutSessionSpec é ferramenta de escrita com confirmação', () {
      final spec = logWorkoutSessionSpec();
      expect(spec.write, isTrue);
      expect(spec.confirm, isTrue);
      expect(spec.module, 'activity');
    });

    test('log_workout_session grava a sessão real no health_core', () async {
      final handler = logWorkoutSessionHandler(logger, tzOffsetMinutesProvider: () => -180);
      final result = await handler({
        'plan_id': 'plano-a',
        'sets': [
          {
            'exercise_id': 'supino-reto',
            'exercise_name': 'Supino reto',
            'set_number': 1,
            'reps': 8,
            'load_kg': 60,
          },
        ],
        'at': '2026-08-10T18:00:00Z',
      });

      expect(result.success, isTrue);
      expect(result.data!['sets_count'], 1);
      expect(core.queryByType(HealthEventType.workoutSession), hasLength(1));
      expect(core.queryByType(HealthEventType.setLog), hasLength(1));
    });
  });
}
