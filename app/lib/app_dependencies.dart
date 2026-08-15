import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_summary/summary.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import 'card_image_capturer.dart';
import 'chat_router.dart';
import 'share_sheet.dart';

/// Junta tudo que o app precisa: os repositórios reais e o pipeline do
/// cérebro já com as ferramentas registradas (`docs/ARQUITETURA.md:81-82`).
/// Construído uma vez — em produção (`AppDependencies.open`, com
/// armazenamento real via `path_provider` resolvido em `main.dart`) ou em
/// teste (`AppDependencies.inMemory`, sem tocar disco).
///
/// **Não registradas aqui, por decisão, não por esquecimento:**
/// `start_run` (escrita — só faz sentido com captura de GPS real, WRAP
/// nativo do Android ainda não implementado, `docs/adr/009-gps.md`),
/// `sync_wearable` (F9 não iniciada) e `query_health_record` (fora do
/// escopo deste ciclo).
class AppDependencies {
  final HealthDataCore core;
  final FoodRepository foodRepository;
  final WorkoutRepository workoutRepository;
  final ToolRegistry registry;
  final BrainPipeline pipeline;
  final ShareSheet shareSheet;
  final CardImageCapturer imageCapturer;

  AppDependencies._({
    required this.core,
    required this.foodRepository,
    required this.workoutRepository,
    required this.registry,
    required this.pipeline,
    required this.shareSheet,
    required this.imageCapturer,
  });

  void close() {
    core.close();
    foodRepository.close();
    workoutRepository.close();
  }

  /// Produção: bancos reais em arquivo, um por módulo (mesma separação
  /// que cada `Repository`/`HealthDataCore` já usa isoladamente).
  /// [dbDirectoryPath] vem de `path_provider`
  /// (`getApplicationDocumentsDirectory()`), resolvido em `main.dart` —
  /// esta classe não sabe nada sobre plataforma nem canal nativo, só
  /// recebe o caminho já pronto. **`path_provider` em si não é
  /// verificável em `flutter test`/sem device real** — é a única parte
  /// desta classe que fica "não verificada" neste ambiente.
  factory AppDependencies.open({
    required String dbDirectoryPath,
    required ConfirmationGate confirmationGate,
    required ShareSheet shareSheet,
    required CardImageCapturer imageCapturer,
  }) {
    return _build(
      core: HealthDataCore.open('$dbDirectoryPath/frankstein_health.sqlite3'),
      foodRepository: FoodRepository.open('$dbDirectoryPath/frankstein_food.sqlite3'),
      workoutRepository: WorkoutRepository.open('$dbDirectoryPath/frankstein_workout.sqlite3'),
      confirmationGate: confirmationGate,
      shareSheet: shareSheet,
      imageCapturer: imageCapturer,
    );
  }

  /// Teste/demonstração: tudo em memória, sem tocar disco.
  factory AppDependencies.inMemory({
    required ConfirmationGate confirmationGate,
    required ShareSheet shareSheet,
    required CardImageCapturer imageCapturer,
  }) {
    return _build(
      core: HealthDataCore.openInMemory(),
      foodRepository: FoodRepository.openInMemory(seedTacoData: true),
      workoutRepository: WorkoutRepository.openInMemory(),
      confirmationGate: confirmationGate,
      shareSheet: shareSheet,
      imageCapturer: imageCapturer,
    );
  }

  static AppDependencies _build({
    required HealthDataCore core,
    required FoodRepository foodRepository,
    required WorkoutRepository workoutRepository,
    required ConfirmationGate confirmationGate,
    required ShareSheet shareSheet,
    required CardImageCapturer imageCapturer,
  }) {
    final mealLogger = MealLogger(foodRepository: foodRepository, core: core);
    final workoutLogger = WorkoutLogger(core: core);

    // DateTime.now() (sem .toUtc()) é hora local de verdade no Dart —
    // diferente do bug já corrigido em StepsRepository.flush()
    // (docs/HISTORICO.md, Fase 4), que lia .timeZoneOffset de um DateTime
    // já em UTC (sempre zero). Aqui o receptor é local por padrão.
    int tzOffsetMinutesProvider() => DateTime.now().timeZoneOffset.inMinutes;

    final registry = ToolRegistry()
      ..register(getStepsSpec(), getStepsHandler(core))
      ..register(getDailySummarySpec(), getDailySummaryHandler(core))
      ..register(getRunSummarySpec(), getRunSummaryHandler(core))
      ..register(getWorkoutPlanSpec(), getWorkoutPlanHandler(workoutRepository))
      ..register(
        logWorkoutSessionSpec(),
        logWorkoutSessionHandler(workoutLogger, tzOffsetMinutesProvider: tzOffsetMinutesProvider),
      )
      ..register(searchFoodSpec(), searchFoodHandler(foodRepository))
      ..register(
        logMealSpec(),
        logMealHandler(mealLogger, tzOffsetMinutesProvider: tzOffsetMinutesProvider),
      );

    final pipeline = BrainPipeline(
      registry: registry,
      callers: [buildChatRouter()],
      confirmationGate: confirmationGate,
    );

    return AppDependencies._(
      core: core,
      foodRepository: foodRepository,
      workoutRepository: workoutRepository,
      registry: registry,
      pipeline: pipeline,
      shareSheet: shareSheet,
      imageCapturer: imageCapturer,
    );
  }
}
