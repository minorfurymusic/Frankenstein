import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import 'medications_screen.dart';

/// Frequências do layout (prancheta RemedioForm, "Frequência"). Cada uma
/// gera os horários a partir do primeiro; "personalizado" deixa a pessoa
/// montar a lista.
enum DoseFrequency {
  once('1 vez ao dia', 24),
  every12h('A cada 12 horas', 12),
  every8h('A cada 8 horas', 8),
  every6h('A cada 6 horas', 6),
  custom('Horários personalizados', 0);

  final String label;
  final int intervalHours;
  const DoseFrequency(this.label, this.intervalHours);

  List<int> timesFrom(int firstMinutes) {
    if (this == custom) return [firstMinutes];
    final count = 24 ~/ intervalHours;
    return [for (var i = 0; i < count; i++) (firstMinutes + i * intervalHours * 60) % (24 * 60)];
  }
}

const doseUnits = ['mg', 'g', 'mcg', 'ml', 'gotas', 'UI', 'unidade'];

/// Cadastrar/editar remédio (prancheta RemedioForm). Nada é sugerido: dose,
/// horários e duração são os que a pessoa digita (o RLT não prescreve).
class MedicationFormScreen extends StatefulWidget {
  final AppDependencies deps;
  final Medication? existing;
  const MedicationFormScreen({super.key, required this.deps, this.existing});

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _dose;
  late final TextEditingController _notes;
  late String _unit;
  late MedicationForm _form;
  late DoseFrequency _frequency;
  late List<int> _times;
  late DateTime _start;
  DateTime? _end;
  late bool _reminders;

  @override
  void initState() {
    super.initState();
    final m = widget.existing;
    _name = TextEditingController(text: m?.name ?? '');
    _dose = TextEditingController(
      text: m == null
          ? ''
          : (m.doseAmount == m.doseAmount.roundToDouble() ? m.doseAmount.toInt().toString() : '${m.doseAmount}'),
    );
    _notes = TextEditingController(text: m?.notes ?? '');
    _unit = m != null && doseUnits.contains(m.doseUnit) ? m.doseUnit : 'mg';
    _form = m?.form ?? MedicationForm.tablet;
    _times = m?.timesOfDay.toList() ?? [8 * 60];
    _frequency = m == null ? DoseFrequency.once : DoseFrequency.custom;
    final now = DateTime.now();
    _start = m == null ? DateTime(now.year, now.month, now.day) : DateTime(m.startDate.year, m.startDate.month, m.startDate.day);
    _end = m?.endDate == null ? null : DateTime(m!.endDate!.year, m.endDate!.month, m.endDate!.day);
    _reminders = m?.remindersEnabled ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickTime({int? replaceIndex}) async {
    final initial = replaceIndex == null ? const TimeOfDay(hour: 8, minute: 0) : _toTod(_times[replaceIndex]);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final minutes = picked.hour * 60 + picked.minute;
    setState(() {
      if (replaceIndex == null) {
        _times = {..._times, minutes}.toList()..sort();
        _frequency = DoseFrequency.custom;
      } else if (replaceIndex == 0 && _frequency != DoseFrequency.custom) {
        _times = _frequency.timesFrom(minutes)..sort();
      } else {
        _times[replaceIndex] = minutes;
        _times = _times.toSet().toList()..sort();
      }
    });
  }

  TimeOfDay _toTod(int minutes) => TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);

  Future<DateTime?> _pickDate(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
      );

  void _save() {
    final dose = double.tryParse(_dose.text.replaceAll(',', '.'));
    if (dose == null) {
      showRltError(context, ArgumentError('informe a dose em número'));
      return;
    }
    try {
      final medication = Medication(
        id: widget.existing?.id ?? HealthDataCore.newId(),
        name: _name.text,
        doseAmount: dose,
        doseUnit: _unit,
        form: _form,
        timesOfDay: _times,
        startDate: LocalDate.fromDateTime(_start),
        endDate: _end == null ? null : LocalDate.fromDateTime(_end!),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        remindersEnabled: _reminders,
      );
      widget.deps.medicationRepository.save(medication);
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, '${medication.name} salvo em Saúde › Remédios.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  void _endTreatment() {
    final m = widget.existing!;
    final now = DateTime.now();
    try {
      widget.deps.medicationRepository.endOn(m.id, LocalDate(now.year, now.month, now.day));
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, '${m.name}: tratamento encerrado hoje.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Editar remédio' : 'Novo remédio'),
        actions: [TextButton(key: const Key('medication_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RltSpace.l),
        children: [
          TextField(
            key: const Key('medication_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome do remédio', prefixIcon: Icon(Icons.search)),
          ),
          const SizedBox(height: RltSpace.m),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('medication_dose'),
                controller: _dose,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Dose'),
              ),
            ),
            const SizedBox(width: RltSpace.m),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _unit,
                decoration: const InputDecoration(labelText: 'Unidade'),
                items: [for (final u in doseUnits) DropdownMenuItem(value: u, child: Text(u))],
                onChanged: (v) => setState(() => _unit = v ?? _unit),
              ),
            ),
          ]),
          const RltSectionHeader('Forma'),
          Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
            for (final f in MedicationForm.values)
              ChoiceChip(
                label: Text(_capitalize(medicationFormLabel(f))),
                selected: _form == f,
                onSelected: (_) => setState(() => _form = f),
              ),
          ]),
          const SizedBox(height: RltSpace.l),
          DropdownButtonFormField<DoseFrequency>(
            key: const Key('medication_frequency'),
            initialValue: _frequency,
            decoration: const InputDecoration(labelText: 'Frequência'),
            items: [for (final f in DoseFrequency.values) DropdownMenuItem(value: f, child: Text(f.label))],
            onChanged: (f) {
              if (f == null) return;
              setState(() {
                _frequency = f;
                if (f != DoseFrequency.custom) _times = f.timesFrom(_times.first)..sort();
              });
            },
          ),
          const RltSectionHeader('Horários'),
          Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
            for (var i = 0; i < _times.length; i++)
              InputChip(
                avatar: const Icon(Icons.schedule, size: 18),
                label: Text(formatTimeOfDay(_times[i]), style: RltTheme.tabular(t.labelLarge!.copyWith(fontSize: 14))),
                onPressed: () => _pickTime(replaceIndex: i),
                onDeleted: _times.length > 1 ? () => setState(() => _times.removeAt(i)) : null,
              ),
            ActionChip(
              key: const Key('medication_add_time'),
              avatar: const Icon(Icons.add, size: 18),
              label: const Text('Adicionar'),
              onPressed: () => _pickTime(),
            ),
          ]),
          const SizedBox(height: RltSpace.l),
          _DateField(
            label: 'Início',
            value: _start,
            onTap: () async {
              final d = await _pickDate(_start);
              if (d != null) setState(() => _start = d);
            },
          ),
          const RltSectionHeader('Duração'),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Uso contínuo')),
              ButtonSegment(value: false, label: Text('Até uma data')),
            ],
            selected: {_end == null},
            onSelectionChanged: (s) => setState(() {
              _end = s.first ? null : _start.add(const Duration(days: 6));
            }),
          ),
          if (_end != null) ...[
            const SizedBox(height: RltSpace.m),
            _DateField(
              label: 'Termina em',
              value: _end!,
              onTap: () async {
                final d = await _pickDate(_end!);
                if (d != null) setState(() => _end = d);
              },
            ),
          ] else ...[
            const SizedBox(height: RltSpace.s),
            const Align(alignment: Alignment.centerLeft, child: RltBadge(RltBadgeKind.continuousUse)),
          ],
          const SizedBox(height: RltSpace.l),
          TextField(
            controller: _notes,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Observações'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Lembrete'),
            // TODO(frankstein): notificação local de verdade (etapa de integrações) — hoje só guarda a escolha.
            subtitle: const Text('Avisar no horário de cada dose'),
            value: _reminders,
            onChanged: (v) => setState(() => _reminders = v),
          ),
          if (editing) ...[
            const SizedBox(height: RltSpace.s),
            OutlinedButton.icon(
              key: const Key('medication_end'),
              onPressed: _endTreatment,
              icon: const Icon(Icons.event_busy_outlined),
              label: const Text('Encerrar tratamento hoje'),
            ),
          ],
          const SizedBox(height: RltSpace.xl),
        ],
      ),
    );
  }

  String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  const _DateField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.calendar_today_outlined)),
        child: Text(ddmmyyyy(value)),
      ),
    );
  }
}
