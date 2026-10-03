import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../health/medications_screen.dart';

/// Lembretes (pranchetas Lembretes e ContaLembretes): remédios, água e
/// treino — horários e liga/desliga. Guarda as escolhas no aparelho.
class RemindersScreen extends StatefulWidget {
  final AppDependencies deps;
  const RemindersScreen({super.key, required this.deps});

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  late Map<String, dynamic> _prefs;

  @override
  void initState() {
    super.initState();
    final raw = widget.deps.profileRepository.getSetting('reminders');
    _prefs = raw == null
        ? {'water_on': false, 'water_every_hours': 2, 'workout_on': false, 'workout_time': 18 * 60}
        : jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<void> _save() async {
    widget.deps.profileRepository.setSetting('reminders', jsonEncode(_prefs));
    await _ensurePermission();
    widget.deps.reminders.schedule();
  }

  /// Android 13+ pede permissão para notificar; só pergunta quando a pessoa
  /// liga um lembrete.
  Future<void> _ensurePermission() async {
    final s = widget.deps.reminders.scheduler;
    if (!await s.hasPermission()) await s.requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final meds = widget.deps.healthRead.activeMedications();
    return Scaffold(
      appBar: AppBar(title: const Text('Lembretes')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text('Os avisos usam as notificações do próprio Android — nada passa pela internet.', style: t.bodySmall),
        const RltSectionHeader('Remédios'),
        if (meds.isEmpty) Text('Nenhum remédio ativo.', style: t.bodyMedium),
        for (final m in meds)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${m.name} ${doseLabel(m)}'),
            subtitle: Text(m.timesOfDay.map(formatTimeOfDay).join(' · ')),
            value: m.remindersEnabled,
            onChanged: (v) {
              widget.deps.medicationRepository.save(Medication(
                id: m.id,
                name: m.name,
                doseAmount: m.doseAmount,
                doseUnit: m.doseUnit,
                form: m.form,
                timesOfDay: m.timesOfDay,
                startDate: m.startDate,
                endDate: m.endDate,
                notes: m.notes,
                remindersEnabled: v,
              ));
              widget.deps.notifyDataChanged();
              if (v) _ensurePermission();
              setState(() {});
            },
          ),
        const RltSectionHeader('Água'),
        SwitchListTile(
          key: const Key('reminder_water'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Lembrar de beber água'),
          subtitle: Text('A cada ${_prefs['water_every_hours']} horas, das 8h às 22h'),
          value: _prefs['water_on'] as bool,
          onChanged: (v) => setState(() {
            _prefs['water_on'] = v;
            _save();
          }),
        ),
        Wrap(spacing: RltSpace.s, children: [
          for (final h in const [1, 2, 3])
            ChoiceChip(
              label: Text('$h h'),
              selected: _prefs['water_every_hours'] == h,
              onSelected: (_) => setState(() {
                _prefs['water_every_hours'] = h;
                _save();
              }),
            ),
        ]),
        const RltSectionHeader('Treino'),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Lembrar do treino'),
          subtitle: Text('Todo dia às ${formatTimeOfDay(_prefs['workout_time'] as int)}'),
          value: _prefs['workout_on'] as bool,
          onChanged: (v) => setState(() {
            _prefs['workout_on'] = v;
            _save();
          }),
        ),
        TextButton.icon(
          onPressed: () async {
            final m = _prefs['workout_time'] as int;
            final picked = await showTimePicker(context: context, initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60));
            if (picked == null) return;
            setState(() {
              _prefs['workout_time'] = picked.hour * 60 + picked.minute;
              _save();
            });
          },
          icon: const Icon(Icons.schedule),
          label: Text('Horário: ${two((_prefs['workout_time'] as int) ~/ 60)}:${two((_prefs['workout_time'] as int) % 60)}'),
        ),
      ]),
    );
  }
}
