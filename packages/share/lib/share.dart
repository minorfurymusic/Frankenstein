/// Compartilhamento social — cards renderizados no aparelho, sem SDK
/// proprietário (`.claude/rules/share.md`).
///
/// Fase 12 (parcial): `WorkoutShareCardData`/`RunShareCardData` (dado já
/// seguro, sem campos sensíveis, rota já ofuscada) + `buildWorkoutShareCard`/
/// `buildRunShareCard` (nunca aceitam `HealthEvent` de tipo clínico —
/// checagem estrutural, não convenção). Renderização em imagem e share
/// sheet nativo ficam em `app/` (dependem de Flutter/platform channel,
/// fora deste pacote plain-Dart).
library;

export 'src/share_card_builder.dart';
export 'src/share_card_data.dart';
