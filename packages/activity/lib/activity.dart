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
library;

export 'src/activity_tools.dart';
export 'src/step_sensor.dart';
export 'src/steps_repository.dart';
export 'src/steps_sample.dart';
