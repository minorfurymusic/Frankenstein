import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_share/share.dart';

import '../../app_dependencies.dart';
import '../share_preview_screen.dart';

/// Abre a pré-visualização obrigatória do cartão (`.claude/rules/share.md`)
/// para um treino; só compartilha no toque.
void openWorkoutShare(BuildContext context, AppDependencies deps, HealthEvent session) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => SharePreviewScreen(
      title: 'Compartilhar treino',
      cardContent: WorkoutCardVisual(data: buildWorkoutShareCard(session)),
      suggestedFileName: 'treino.png',
      shareText: 'Meu treino — RLT',
      shareSheet: deps.shareSheet,
      imageCapturer: deps.imageCapturer,
    ),
  ));
}

/// Idem para corrida/caminhada: a rota sai com começo e fim escondidos.
void openRunShare(BuildContext context, AppDependencies deps, HealthEvent run) {
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => SharePreviewScreen(
      title: 'Compartilhar corrida',
      cardContent: RunCardVisual(data: buildRunShareCard(run, deps.core.gpsTrackPoints(run.id))),
      suggestedFileName: 'corrida.png',
      shareText: 'Minha corrida — RLT',
      shareSheet: deps.shareSheet,
      imageCapturer: deps.imageCapturer,
    ),
  ));
}
