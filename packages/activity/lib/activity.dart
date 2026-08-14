/// Sensores e atividade — pedômetro, BLE wearable, treino, GPS de
/// corrida (`.claude/rules/activity.md`, ADR-9 aceita).
///
/// Fase 4: passos. `StepsRepository` agrega leituras cumulativas do
/// sensor em `HealthEvent`s tipo `steps`. **O foreground service Android
/// real (contagem que não para com a tela bloqueada) não está
/// implementado aqui** — exige aparelho/emulador de verdade para validar,
/// que este ambiente não tem; entra depois como implementação concreta
/// de [StepSensor], sem mudar `StepsRepository`. `get_steps` (Fase 5,
/// ferramenta do cérebro) já lê os eventos gravados.
///
/// Fase 7: Academia. `WorkoutRepository` (catálogo local de planos sobre
/// `sqlite3`, mesmo padrão de `FoodRepository`) + `WorkoutLogger` (grava
/// `workout_session` + `set_log`, recorde calculado por consulta) +
/// `get_workout_plan`/`log_workout_session` (ferramentas do cérebro). Sem
/// dependência de hardware — tudo testável sem ressalva.
///
/// Fase 8: Corrida/caminhada. `RunCalculator` (distância por Haversine,
/// splits por km, ganho de elevação, filtro de ruído por precisão) +
/// `RunLogger` (grava `gps_track` + `gps_track_points`) + GPX
/// import/export + `obfuscateRouteEnds` (privacidade de rota) +
/// `get_run_summary` (ferramenta do cérebro, leitura). **A captura de GPS
/// em si não está aqui** — é WRAP nativo do OpenTracks no Android
/// (`docs/adr/009-gps.md`), sem SDK/device Android neste ambiente;
/// `start_run` (ferramenta de escrita) fica documentada como pendente,
/// não fingida.
library;

export 'src/activity_tools.dart';
export 'src/gpx.dart';
export 'src/route_privacy.dart';
export 'src/run_calculator.dart';
export 'src/run_logger.dart';
export 'src/run_point.dart';
export 'src/run_tools.dart';
export 'src/step_sensor.dart';
export 'src/steps_repository.dart';
export 'src/steps_sample.dart';
export 'src/workout_logger.dart';
export 'src/workout_plan.dart';
export 'src/workout_repository.dart';
export 'src/workout_session.dart';
export 'src/workout_tools.dart';
