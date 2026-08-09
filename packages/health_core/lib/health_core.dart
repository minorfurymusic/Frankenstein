/// Health Data Core — SQLite local, fonte da verdade, offline-first
/// (`docs/ARQUITETURA.md`, `.claude/rules/datacore.md`).
///
/// Fase 3: schema `HealthEvent` append-only, tabela própria para pontos
/// de GPS, deduplicação por `(source, external_id)`, correção como
/// evento novo. Nenhum módulo (nutrição, passos, treino, wearable) entra
/// aqui — isso é o Core que todos eles vão escrever, fase a fase.
library;

export 'src/health_data_core.dart';
export 'src/health_event.dart';
