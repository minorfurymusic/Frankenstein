import 'dart:io';

import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_brain/brain.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';
import 'package:frankstein_nutrition/nutrition.dart';
import 'package:frankstein_profile/profile.dart';
import 'package:frankstein_summary/summary.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

import 'package:flutter/material.dart' show ThemeMode, ValueNotifier;

import 'card_image_capturer.dart';
import 'data/activity_read_model.dart';
import 'data/day_read_model.dart';
import 'data/health_read_model.dart';
import 'data/nutrition_store.dart';
import 'chat_router.dart';
import 'share_sheet.dart';
import 'step_tracking_controller.dart';

/// Junta tudo que o app precisa: os repositórios reais e o pipeline do
/// cérebro já com as ferramentas registradas (`docs/ARQUITETURA.md:81-82`).
/// Construído uma vez — em produção (`AppDependencies.open`, com
/// armazenamento real via `path_provider` resolvido em `main.dart`) ou em
/// teste (`AppDependencies.inMemory`, sem tocar disco).
///
/// `stepTracking` (`StepTrackingController`) liga o sensor de passos real
/// no Android (`step_sensor_android.dart`, `StepCounterService.kt`) ao
/// `stepsRepository` — construído aqui, mas `.start()` é chamado
/// separadamente em `main.dart` (depois do `runApp`, nunca antes — mesmo
/// cuidado do fix do `sqlite3_flutter_libs`: nada bloqueante antes do
/// primeiro frame).
///
/// **Não registradas aqui, por decisão, não por esquecimento:**
/// `start_run` (escrita — só faz sentido com captura de GPS real, WRAP
/// nativo do Android ainda não implementado, `docs/adr/009-gps.md`),
/// `sync_wearable`/`sync_wger`/`sync_fasten_records` (nenhuma tem fonte
/// real conectada ainda — `WearableDataSource`/`WgerClient`/`FastenClient`
/// concretos não existem, ligar o Fixture em produção seria desonesto) e
/// `query_health_record` (fora do escopo deste ciclo).
class AppDependencies {
  final HealthDataCore core;
  final FoodRepository foodRepository;
  final WorkoutRepository workoutRepository;
  final MedicationRepository medicationRepository;
  final MedicalHistoryRepository medicalHistory;
  final ToolRegistry registry;
  final BrainPipeline pipeline;
  final ConfirmationGate confirmationGate;
  final ShareSheet shareSheet;
  final CardImageCapturer imageCapturer;
  final StepsRepository stepsRepository;
  final StepTrackingController stepTracking;

  // Aba Saúde: telas gravam direto pelos loggers depois do toque em
  // "Salvar" (o toque é a confirmação humana; o cartão de confirmação do
  // pipeline é para o que a IA propõe — `.claude/rules/brain.md`).
  final MedicationDoseLogger doseLogger;
  final SymptomLogger symptomLogger;
  final VitalSignLogger vitalSignLogger;
  final BodyLogger bodyLogger;
  final HealthReadModel healthRead;

  final ProfileRepository profileRepository;
  final MealLogger mealLogger;
  final WaterLogger waterLogger;
  final NutritionStore nutrition;
  final WorkoutLogger workoutLogger;
  final ActivityLogger activityLogger;
  final ActivityReadModel activityRead;
  final DayReadModel dayRead;
  final GoalsService goals;

  /// Tema escolhido em Conta › Preferências (claro, escuro ou sistema).
  final ValueNotifier<ThemeMode> themeMode;

  void setThemeMode(ThemeMode mode) {
    profileRepository.setSetting('theme_mode', mode.name);
    themeMode.value = mode;
  }

  /// Sobe a cada gravação feita pelas telas; quem mostra dado escuta e
  /// recarrega.
  final ValueNotifier<int> dataVersion = ValueNotifier(0);
  void notifyDataChanged() => dataVersion.value++;

  int tzOffsetMinutesNow() => DateTime.now().timeZoneOffset.inMinutes;

  AppDependencies._({
    required this.core,
    required this.foodRepository,
    required this.workoutRepository,
    required this.medicationRepository,
    required this.medicalHistory,
    required this.registry,
    required this.pipeline,
    required this.confirmationGate,
    required this.shareSheet,
    required this.imageCapturer,
    required this.stepsRepository,
    required this.stepTracking,
    required this.doseLogger,
    required this.symptomLogger,
    required this.vitalSignLogger,
    required this.bodyLogger,
    required this.healthRead,
    required this.profileRepository,
    required this.mealLogger,
    required this.waterLogger,
    required this.nutrition,
    required this.workoutLogger,
    required this.activityLogger,
    required this.activityRead,
    required this.dayRead,
    required this.goals,
    required this.themeMode,
  });

  /// Pasta dos bancos em arquivo (`null` em memória/teste).
  String? dbDirectoryPath;

  bool _closed = false;

  void close() {
    if (_closed) return;
    _closed = true;
    dataVersion.dispose();
    themeMode.dispose();
    profileRepository.close();
    stepTracking.dispose();
    core.close();
    foodRepository.close();
    workoutRepository.close();
    medicationRepository.close();
    medicalHistory.close();
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
      dbDirectoryPath: dbDirectoryPath,
      core: HealthDataCore.open('$dbDirectoryPath/frankstein_health.sqlite3'),
      foodRepository: FoodRepository.open('$dbDirectoryPath/frankstein_food.sqlite3'),
      workoutRepository: WorkoutRepository.open('$dbDirectoryPath/frankstein_workout.sqlite3'),
      medicationRepository: MedicationRepository.open('$dbDirectoryPath/frankstein_medications.sqlite3'),
      medicalHistory: MedicalHistoryRepository.open('$dbDirectoryPath/frankstein_medications.sqlite3'),
      profileRepository: ProfileRepository.open('$dbDirectoryPath/frankstein_profile.sqlite3'),
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
      medicationRepository: MedicationRepository.openInMemory(),
      medicalHistory: MedicalHistoryRepository.openInMemory(),
      profileRepository: ProfileRepository.openInMemory(),
      confirmationGate: confirmationGate,
      shareSheet: shareSheet,
      imageCapturer: imageCapturer,
    );
  }

  /// Arquivos de banco do app — apagados juntos em "apagar todos os dados".
  static const dbFileNames = [
    'frankstein_health.sqlite3',
    'frankstein_food.sqlite3',
    'frankstein_workout.sqlite3',
    'frankstein_medications.sqlite3',
    'frankstein_profile.sqlite3',
  ];

  /// "Apagar todos os dados" (Conta › Privacidade; LGPD): fecha os bancos e
  /// apaga os arquivos. Não mexe na regra "só acrescenta" do Health Data
  /// Core — o banco inteiro deixa de existir; o app abre do zero depois.
  Future<void> eraseAllDataAndClose() async {
    final dir = dbDirectoryPath;
    close();
    if (dir == null) return;
    for (final name in dbFileNames) {
      for (final suffix in const ['', '-wal', '-shm', '-journal']) {
        final f = File('$dir/$name$suffix');
        if (f.existsSync()) await f.delete();
      }
    }
  }

  static AppDependencies _build({
    String? dbDirectoryPath,
    required HealthDataCore core,
    required FoodRepository foodRepository,
    required WorkoutRepository workoutRepository,
    required MedicationRepository medicationRepository,
    required MedicalHistoryRepository medicalHistory,
    required ProfileRepository profileRepository,
    required ConfirmationGate confirmationGate,
    required ShareSheet shareSheet,
    required CardImageCapturer imageCapturer,
  }) {
    final mealLogger = MealLogger(foodRepository: foodRepository, core: core);
    final workoutLogger = WorkoutLogger(core: core);
    final waterLogger = WaterLogger(core: core);
    final doseLogger = MedicationDoseLogger(core: core);
    final symptomLogger = SymptomLogger(core: core);
    final vitalSignLogger = VitalSignLogger(core: core);
    final bodyLogger = BodyLogger(core: core);
    final agenda = MedicationAgenda(repository: medicationRepository, core: core);

    // DateTime.now() (sem .toUtc()) é hora local de verdade no Dart —
    // diferente do bug já corrigido em StepsRepository.flush()
    // (docs/HISTORICO.md, Fase 4), que lia .timeZoneOffset de um DateTime
    // já em UTC (sempre zero). Aqui o receptor é local por padrão.
    int tzOffsetMinutesProvider() => DateTime.now().timeZoneOffset.inMinutes;

    // `deviceId` fixo — o app é single-device nesta fase (sync entre
    // aparelhos é ADR-3, ainda não implementado). Só existe pra
    // `StepsRepository.recordSample` rejeitar leitura de "outro
    // aparelho" (packages/activity/lib/src/steps_repository.dart:50-53),
    // não é usado pra nada além disso ainda.
    final stepsRepository = StepsRepository(core: core, deviceId: 'android-device');
    final stepTracking = StepTrackingController(
      repository: stepsRepository,
      tzOffsetMinutesProvider: tzOffsetMinutesProvider,
    );

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
      )
      ..register(
        logWaterSpec(),
        logWaterHandler(waterLogger, tzOffsetMinutesProvider: tzOffsetMinutesProvider),
      )
      // Aba Saúde (packages/health_records).
      ..register(addMedicationSpec(), addMedicationHandler(medicationRepository))
      ..register(
        logMedicationDoseSpec(),
        logMedicationDoseHandler(
          doseLogger,
          medicationRepository,
          tzOffsetMinutesProvider: tzOffsetMinutesProvider,
        ),
      )
      ..register(
        getMedicationAgendaSpec(),
        getMedicationAgendaHandler(agenda),
      )
      ..register(
        logSymptomSpec(),
        logSymptomHandler(symptomLogger, tzOffsetMinutesProvider: tzOffsetMinutesProvider),
      )
      ..register(
        logVitalSignSpec(),
        logVitalSignHandler(vitalSignLogger, tzOffsetMinutesProvider: tzOffsetMinutesProvider),
      )
      ..register(
        logBodyMeasurementSpec(),
        logBodyMeasurementHandler(bodyLogger, tzOffsetMinutesProvider: tzOffsetMinutesProvider),
      );

    final healthRead = HealthReadModel(core: core, medications: medicationRepository, agenda: agenda);
    final dayRead = DayReadModel(core: core);
    final activityRead = ActivityReadModel(days: dayRead, health: healthRead);

    final pipeline = BrainPipeline(
      registry: registry,
      callers: [buildChatRouter()],
      confirmationGate: confirmationGate,
    );

    return AppDependencies._(
      core: core,
      foodRepository: foodRepository,
      workoutRepository: workoutRepository,
      medicationRepository: medicationRepository,
      medicalHistory: medicalHistory,
      registry: registry,
      pipeline: pipeline,
      confirmationGate: confirmationGate,
      shareSheet: shareSheet,
      imageCapturer: imageCapturer,
      stepsRepository: stepsRepository,
      stepTracking: stepTracking,
      doseLogger: doseLogger,
      symptomLogger: symptomLogger,
      vitalSignLogger: vitalSignLogger,
      bodyLogger: bodyLogger,
      healthRead: healthRead,
      profileRepository: profileRepository,
      mealLogger: mealLogger,
      waterLogger: waterLogger,
      nutrition: NutritionStore(foods: foodRepository, settings: profileRepository, core: core),
      dayRead: dayRead,
      goals: GoalsService(
        profiles: profileRepository,
        health: healthRead,
        days: dayRead,
        exerciseKcalFor: activityRead.exerciseKcal,
      ),
      workoutLogger: workoutLogger,
      activityLogger: ActivityLogger(core: core),
      activityRead: activityRead,
      themeMode: ValueNotifier(
        ThemeMode.values.firstWhere(
          (m) => m.name == profileRepository.getSetting('theme_mode'),
          orElse: () => ThemeMode.system,
        ),
      ),
    )..dbDirectoryPath = dbDirectoryPath;
  }
}
