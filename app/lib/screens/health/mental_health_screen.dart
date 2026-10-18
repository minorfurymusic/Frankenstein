import 'package:flutter/material.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import 'symptoms_screen.dart';

/// Rótulo de cada nível de humor (1 a 5).
const moodLabels = ['Muito mal', 'Mal', 'Mais ou menos', 'Bem', 'Muito bem'];
const _moodIcons = [
  Icons.sentiment_very_dissatisfied_outlined,
  Icons.sentiment_dissatisfied_outlined,
  Icons.sentiment_neutral_outlined,
  Icons.sentiment_satisfied_outlined,
  Icons.sentiment_very_satisfied_outlined,
];

/// Sintomas mentais oferecidos como atalho no diário de sintomas.
const mentalSymptoms = ['Tristeza', 'Crise de ansiedade', 'Insônia', 'Irritação', 'Esquecimento', 'Euforia'];

/// Saúde › Saúde mental (ADR-23): humor do dia em um toque, histórico dos
/// últimos 30 dias e o aviso fixo de crise. Tudo fica no celular.
// TODO(frankstein): questionários PHQ-9 e GAD-7 — só com o texto oficial em
// português conferido na fonte (ADR-23).
class MentalHealthScreen extends StatelessWidget {
  final AppDependencies deps;
  const MentalHealthScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = RltColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Saúde mental')),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) {
          final moods = deps.healthRead.moods(days: 30);
          final today = DateTime.now();
          final todays = moods.where((m) => m.local.year == today.year && m.local.month == today.month && m.local.day == today.day);
          return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
            Text('Como você está hoje?', style: t.titleMedium),
            const SizedBox(height: RltSpace.s),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              for (var i = 1; i <= 5; i++)
                Expanded(
                  child: InkWell(
                    key: Key('mood_$i'),
                    borderRadius: BorderRadius.circular(RltRadius.card),
                    onTap: () => _checkIn(context, i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: RltSpace.s),
                      child: Column(children: [
                        Icon(_moodIcons[i - 1], size: 36, color: c.primary),
                        const SizedBox(height: 4),
                        Text(moodLabels[i - 1], style: t.labelSmall, textAlign: TextAlign.center),
                      ]),
                    ),
                  ),
                ),
            ]),
            if (todays.isNotEmpty) ...[
              const SizedBox(height: RltSpace.xs),
              Text('Hoje: ${moodLabels[todays.first.mood - 1]}. Pode registrar de novo se mudar.', style: t.bodySmall),
            ],
            const SizedBox(height: RltSpace.l),
            OutlinedButton.icon(
              key: const Key('mental_symptom'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SymptomFormScreen(deps: deps, suggestions: mentalSymptoms),
              )),
              icon: const Icon(Icons.add),
              label: const Text('Registrar sintoma (tristeza, ansiedade, insônia…)'),
            ),
            const RltSectionHeader('Últimos 30 dias'),
            if (moods.isEmpty)
              Text('Nenhum registro ainda. Um toque por dia já mostra como o humor muda com o tempo.', style: t.bodyMedium)
            else ...[
              _MoodStrip(moods: moods),
              const SizedBox(height: RltSpace.s),
              for (final m in moods.take(14)) _MoodTile(m),
            ],
            const SizedBox(height: RltSpace.l),
            const CrisisNotice(),
            const SizedBox(height: RltSpace.l),
            const HealthDisclaimer(),
          ]);
        },
      ),
    );
  }

  Future<void> _checkIn(BuildContext context, int mood) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CheckInSheet(deps: deps, mood: mood),
    );
    if (saved == true && context.mounted) showRltSaved(context, 'Humor salvo em Saúde › Saúde mental.');
  }
}

/// Aviso fixo do app para crise (ADR-23): o texto é do app, nunca da IA.
class CrisisNotice extends StatelessWidget {
  const CrisisNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Container(
      key: const Key('crisis_notice'),
      padding: const EdgeInsets.all(RltSpace.m),
      decoration: BoxDecoration(color: c.surfaceContainerHigh, borderRadius: BorderRadius.circular(RltRadius.card)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.support_agent_outlined, color: c.primary),
        const SizedBox(width: RltSpace.s),
        Expanded(
          child: Text(
            'Precisa conversar agora? Ligue 188 (CVV, 24 h, gratuito) ou acesse cvv.org.br. '
            'Em emergência, ligue 192 (SAMU).',
            style: t.bodyMedium,
          ),
        ),
      ]),
    );
  }
}

class _CheckInSheet extends StatefulWidget {
  final AppDependencies deps;
  final int mood;
  const _CheckInSheet({required this.deps, required this.mood});

  @override
  State<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends State<_CheckInSheet> {
  late int _mood = widget.mood;
  int? _energy;
  int? _anxiety;
  final _feelings = <String>{};
  final _notes = TextEditingController();

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    final now = DateTime.now();
    widget.deps.moodLogger.log(
      mood: _mood,
      energy: _energy,
      anxiety: _anxiety,
      feelings: _feelings.toList(),
      notes: _notes.text,
      occurredAt: now.toUtc(),
      occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    widget.deps.notifyDataChanged();
    Navigator.of(context).pop(true);
  }

  Widget _scale(String label, int? value, String low, String high, ValueChanged<int> onChanged, String key) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelLarge),
      Wrap(spacing: RltSpace.xs, children: [
        for (var i = 1; i <= 5; i++)
          ChoiceChip(key: Key('${key}_$i'), label: Text('$i'), selected: value == i, onSelected: (_) => setState(() => onChanged(i))),
      ]),
      Text('1 = $low · 5 = $high', style: t.bodySmall),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(RltSpace.l, 0, RltSpace.l, RltSpace.l + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Humor: ${moodLabels[_mood - 1]}', style: t.titleMedium),
          Wrap(spacing: RltSpace.xs, children: [
            for (var i = 1; i <= 5; i++)
              ChoiceChip(label: Text(moodLabels[i - 1]), selected: _mood == i, onSelected: (_) => setState(() => _mood = i)),
          ]),
          const SizedBox(height: RltSpace.m),
          Text('Se quiser, conte mais (tudo opcional):', style: t.bodyMedium),
          const SizedBox(height: RltSpace.s),
          _scale('Energia', _energy, 'sem energia', 'muita energia', (v) => _energy = v, 'mood_energy'),
          const SizedBox(height: RltSpace.s),
          _scale('Ansiedade', _anxiety, 'tranquilo', 'muito ansioso', (v) => _anxiety = v, 'mood_anxiety'),
          const SizedBox(height: RltSpace.s),
          Text('Como se sente', style: t.labelLarge),
          Wrap(spacing: RltSpace.xs, runSpacing: RltSpace.xs, children: [
            for (final f in MoodLogger.feelings)
              FilterChip(
                key: Key('mood_feeling_$f'),
                label: Text(f),
                selected: _feelings.contains(f),
                onSelected: (on) => setState(() => on ? _feelings.add(f) : _feelings.remove(f)),
              ),
          ]),
          const SizedBox(height: RltSpace.s),
          TextField(
            key: const Key('mood_notes'),
            controller: _notes,
            minLines: 1,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Anotação (o que aconteceu?)'),
          ),
          const SizedBox(height: RltSpace.m),
          SizedBox(
            width: double.infinity,
            child: FilledButton(key: const Key('mood_save'), onPressed: _save, child: const Text('Salvar')),
          ),
        ]),
      ),
    );
  }
}

/// Faixa dos últimos 30 dias: uma barra por dia com registro (último do
/// dia), mais alta quanto melhor o humor.
class _MoodStrip extends StatelessWidget {
  final List<MoodView> moods;
  const _MoodStrip({required this.moods});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final byDay = <String, MoodView>{};
    for (final m in moods) {
      byDay.putIfAbsent('${m.local.year}-${m.local.month}-${m.local.day}', () => m);
    }
    final today = DateTime.now();
    return SizedBox(
      key: const Key('mood_strip'),
      height: 56,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var d = 29; d >= 0; d--)
          () {
            final day = DateTime(today.year, today.month, today.day - d);
            final m = byDay['${day.year}-${day.month}-${day.day}'];
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                height: m == null ? 2 : 8.0 + m.mood * 9,
                decoration: BoxDecoration(
                  color: m == null ? c.outlineVariant : c.primary.withValues(alpha: 0.35 + m.mood * 0.13),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }(),
      ]),
    );
  }
}

class _MoodTile extends StatelessWidget {
  final MoodView m;
  const _MoodTile(this.m);

  @override
  Widget build(BuildContext context) {
    final extra = [
      if (m.energy != null) 'energia ${m.energy}/5',
      if (m.anxiety != null) 'ansiedade ${m.anxiety}/5',
      ...m.feelings,
    ].join(' · ');
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_moodIcons[m.mood - 1]),
      title: Text('${moodLabels[m.mood - 1]} — ${relativeDayTime(m.local)}'),
      subtitle: extra.isEmpty && m.notes == null ? null : Text([if (extra.isNotEmpty) extra, ?m.notes].join('\n')),
    );
  }
}
