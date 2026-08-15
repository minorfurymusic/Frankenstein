import 'package:flutter/material.dart';
import 'package:frankstein_share/share.dart';

import '../card_image_capturer.dart';
import '../share_sheet.dart';

/// Preview obrigatório antes de qualquer compartilhamento
/// (`.claude/rules/share.md`: "Preview obrigatório: o usuário vê
/// exatamente o que vai sair" / "Publicação automática é proibida. Nada
/// sai sem toque explícito"). O card visível nesta tela é literalmente o
/// mesmo widget capturado como PNG — não há um "modo preview" diferente
/// do que realmente sai.
class SharePreviewScreen extends StatefulWidget {
  final String title;
  final Widget cardContent;
  final String suggestedFileName;
  final String shareText;
  final ShareSheet shareSheet;
  final CardImageCapturer imageCapturer;

  const SharePreviewScreen({
    super.key,
    required this.title,
    required this.cardContent,
    required this.suggestedFileName,
    required this.shareText,
    required this.shareSheet,
    required this.imageCapturer,
  });

  @override
  State<SharePreviewScreen> createState() => _SharePreviewScreenState();
}

class _SharePreviewScreenState extends State<SharePreviewScreen> {
  final _repaintKey = GlobalKey();
  bool _sharing = false;

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final pngBytes = await widget.imageCapturer.capture(_repaintKey);
      await widget.shareSheet.shareImage(
        pngBytes,
        suggestedFileName: widget.suggestedFileName,
        text: widget.shareText,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RepaintBoundary(
                key: _repaintKey,
                child: Material(child: widget.cardContent),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                key: const Key('share_button'),
                onPressed: _sharing ? null : _share,
                icon: const Icon(Icons.share),
                label: const Text('Compartilhar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visual do card de treino (`.claude/rules/share.md`: "Card renderizado
/// NO APARELHO"). Sem peso/IMC/calorias/medidas — esses campos nem
/// existem em `WorkoutShareCardData` ainda (decisão registrada no
/// próprio `packages/share`).
class WorkoutCardVisual extends StatelessWidget {
  final WorkoutShareCardData data;
  const WorkoutCardVisual({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('workout_card_visual'),
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(data.title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('${data.setsCount} séries'),
          Text(data.exerciseNames.join(', ')),
          if (data.personalRecordSummary != null) ...[
            const SizedBox(height: 12),
            Text(data.personalRecordSummary!, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ],
      ),
    );
  }
}

/// Visual do card de corrida — a rota (`data.route`) já chega aqui
/// ofuscada (`buildRunShareCard`, `packages/share`); esta tela não sabe
/// nem precisa saber que existiu uma rota crua antes.
class RunCardVisual extends StatelessWidget {
  final RunShareCardData data;
  const RunCardVisual({super.key, required this.data});

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final km = (data.distanceMeters / 1000).toStringAsFixed(2);
    final pace = data.averagePaceSecondsPerKm;
    return Container(
      key: const Key('run_card_visual'),
      width: 320,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Corrida', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text('$km km em ${_formatDuration(data.duration)}'),
          if (pace != null) Text('pace médio: ${(pace / 60).toStringAsFixed(1)} min/km'),
          Text('${data.route.length} pontos de rota (ofuscada)'),
        ],
      ),
    );
  }
}
