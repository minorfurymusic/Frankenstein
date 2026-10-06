import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/health_area.dart';
import '../../widgets/state_views.dart';
import '../../widgets/timeline_item.dart';

/// Histórico médico (prancheta Historico): diário de sintomas e o que a
/// pessoa informa — condições, alergias, cirurgias, vacinas e consultas.
class SymptomsScreen extends StatelessWidget {
  final AppDependencies deps;
  const SymptomsScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico médico')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('symptom_new'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SymptomFormScreen(deps: deps))),
        icon: const Icon(Icons.add),
        label: const Text('Registrar sintoma'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) => GuardedView(
          errorTitle: 'Não foi possível carregar o histórico',
          errorMessage: 'Nada foi perdido. Tente de novo.',
          builder: (context) {
          final symptoms = deps.healthRead.symptoms();
          return ListView(
            padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, 96),
            children: [
              const RltSectionHeader('Diário de sintomas'),
              if (symptoms.isEmpty)
                StateCard(
                  key: const Key('symptoms_empty'),
                  icon: Icons.sentiment_satisfied_outlined,
                  title: 'Nenhum sintoma registrado',
                  message: 'Anote o que sentir, a intensidade e quando começou. Ajuda muito na hora da consulta.',
                  actionLabel: 'Registrar sintoma',
                  actionIcon: Icons.add,
                  onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => SymptomFormScreen(deps: deps))),
                ),
              for (var i = 0; i < symptoms.length; i++)
                TimelineItem(
                  time: ddmm(symptoms[i].startedLocal),
                  area: HealthArea.symptom,
                  title: symptoms[i].name,
                  detail: [
                    if (symptoms[i].intensity != null) 'Intensidade ${symptoms[i].intensity} de 10',
                    relativeDayTime(symptoms[i].startedLocal),
                    if (symptoms[i].endedLocal != null) 'até ${hhmm(symptoms[i].endedLocal!)}',
                    if (symptoms[i].notes != null) symptoms[i].notes!,
                  ].join(' · '),
                  isLast: i == symptoms.length - 1,
                ),
              for (final kind in MedicalHistoryKind.values) ...[
                RltSectionHeader(
                  _plural(kind),
                  action: TextButton.icon(
                    key: Key('history_add_${kind.name}'),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => MedicalHistoryFormScreen(deps: deps, kind: kind)),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Adicionar'),
                  ),
                ),
                for (final item in deps.medicalHistory.list(kind: kind))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.title),
                    subtitle: Text([
                      if (item.date != null) ddmmyyyy(DateTime(item.date!.year, item.date!.month, item.date!.day)),
                      ?item.professional,
                      ?item.notes,
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => MedicalHistoryFormScreen(deps: deps, kind: kind, existing: item)),
                    ),
                  ),
                if (deps.medicalHistory.list(kind: kind).isEmpty)
                  Text('Nenhum item.', style: t.bodySmall?.copyWith(color: RltColors.of(context).onSurfaceVariant)),
              ],
              const SizedBox(height: RltSpace.l),
              const HealthDisclaimer(),
            ],
          );
        }),
      ),
    );
  }
}

/// Registrar sintoma (prancheta SintomaForm): nome, atalhos comuns,
/// intensidade 0–10, começo, "ainda sentindo" ou fim, observação.
class SymptomFormScreen extends StatefulWidget {
  final AppDependencies deps;
  const SymptomFormScreen({super.key, required this.deps});

  @override
  State<SymptomFormScreen> createState() => _SymptomFormScreenState();
}

class _SymptomFormScreenState extends State<SymptomFormScreen> {
  static const _common = ['Dor de cabeça', 'Náusea', 'Febre', 'Tontura', 'Cansaço'];
  final _name = TextEditingController();
  final _notes = TextEditingController();
  double _intensity = 4;
  DateTime _start = DateTime.now();
  bool _ongoing = true;
  DateTime _end = DateTime.now();

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _save() {
    try {
      widget.deps.symptomLogger.log(
        name: _name.text,
        intensity: _intensity.round(),
        occurredAt: _start.toUtc(),
        occurredAtTzOffsetMinutes: _start.timeZoneOffset.inMinutes,
        endedAt: _ongoing ? null : _end.toUtc(),
        notes: _notes.text,
      );
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, 'Sintoma salvo em Saúde › Histórico médico.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar sintoma'),
        actions: [TextButton(key: const Key('symptom_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RltSpace.l),
        children: [
          TextField(
            key: const Key('symptom_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Sintoma', prefixIcon: Icon(Icons.sentiment_dissatisfied_outlined)),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: RltSpace.m),
          Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
            for (final s in _common)
              ChoiceChip(
                label: Text(s),
                selected: _name.text == s,
                onSelected: (_) => setState(() => _name.text = s),
              ),
          ]),
          const SizedBox(height: RltSpace.xl),
          Row(children: [
            Expanded(child: Text('Intensidade', style: t.titleSmall)),
            Text('${_intensity.round()} de 10', style: RltTheme.tabular(t.titleMedium!.copyWith(color: c.tertiary))),
          ]),
          Slider(
            key: const Key('symptom_intensity'),
            value: _intensity,
            min: 0,
            max: 10,
            divisions: 10,
            activeColor: c.tertiary,
            label: '${_intensity.round()}',
            onChanged: (v) => setState(() => _intensity = v),
          ),
          const SizedBox(height: RltSpace.m),
          _DateTimeField(
            label: 'Começou',
            value: _start,
            onTap: () async {
              final d = await _pickDateTime(_start);
              if (d != null) setState(() => _start = d);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Ainda sentindo', style: t.titleSmall),
            subtitle: const Text('Desligue para informar quando terminou'),
            value: _ongoing,
            onChanged: (v) => setState(() {
              _ongoing = v;
              if (!v) _end = DateTime.now();
            }),
          ),
          if (!_ongoing)
            _DateTimeField(
              label: 'Terminou',
              value: _end,
              onTap: () async {
                final d = await _pickDateTime(_end);
                if (d != null) setState(() => _end = d);
              },
            ),
          const SizedBox(height: RltSpace.m),
          TextField(controller: _notes, minLines: 3, maxLines: 5, decoration: const InputDecoration(labelText: 'Observação')),
          const SizedBox(height: RltSpace.xl),
          const HealthDisclaimer(),
        ],
      ),
    );
  }
}

class _DateTimeField extends StatelessWidget {
  final String label;
  final DateTime value;
  final VoidCallback onTap;
  const _DateTimeField({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: const Icon(Icons.schedule)),
        child: Text(relativeDayTime(value)),
      ),
    );
  }
}

String _plural(MedicalHistoryKind k) => switch (k) {
      MedicalHistoryKind.condition => 'Condições e diagnósticos informados',
      MedicalHistoryKind.allergy => 'Alergias',
      MedicalHistoryKind.surgery => 'Cirurgias',
      MedicalHistoryKind.vaccine => 'Vacinas',
      MedicalHistoryKind.appointment => 'Consultas',
    };

/// Cadastrar/editar item do histórico médico.
class MedicalHistoryFormScreen extends StatefulWidget {
  final AppDependencies deps;
  final MedicalHistoryKind kind;
  final MedicalHistoryItem? existing;
  const MedicalHistoryFormScreen({super.key, required this.deps, required this.kind, this.existing});

  @override
  State<MedicalHistoryFormScreen> createState() => _MedicalHistoryFormScreenState();
}

class _MedicalHistoryFormScreenState extends State<MedicalHistoryFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _professional = TextEditingController(text: widget.existing?.professional ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late LocalDate? _date = widget.existing?.date;

  @override
  void dispose() {
    _title.dispose();
    _professional.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save() {
    try {
      widget.deps.medicalHistory.save(MedicalHistoryItem(
        id: widget.existing?.id ?? HealthDataCore.newId(),
        kind: widget.kind,
        title: _title.text,
        date: _date,
        professional: _professional.text.trim().isEmpty ? null : _professional.text,
        notes: _notes.text.trim().isEmpty ? null : _notes.text,
      ));
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, '${widget.kind.label} salvo em Saúde › Histórico médico.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAppointment = widget.kind == MedicalHistoryKind.appointment;
    final d = _date;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kind.label),
        actions: [TextButton(key: const Key('history_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        TextField(
          key: const Key('history_title'),
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: isAppointment ? 'Especialidade' : 'Nome'),
        ),
        const SizedBox(height: RltSpace.m),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: d == null ? DateTime.now() : DateTime(d.year, d.month, d.day),
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (picked != null) setState(() => _date = LocalDate.fromDateTime(picked));
          },
          child: InputDecorator(
            decoration: const InputDecoration(labelText: 'Data (opcional)', suffixIcon: Icon(Icons.calendar_today_outlined)),
            child: Text(d == null ? 'Sem data' : ddmmyyyy(DateTime(d.year, d.month, d.day))),
          ),
        ),
        if (isAppointment) ...[
          const SizedBox(height: RltSpace.m),
          TextField(controller: _professional, decoration: const InputDecoration(labelText: 'Profissional')),
        ],
        const SizedBox(height: RltSpace.m),
        TextField(controller: _notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Anotações')),
        if (widget.existing != null) ...[
          const SizedBox(height: RltSpace.l),
          OutlinedButton.icon(
            onPressed: () {
              widget.deps.medicalHistory.delete(widget.existing!.id);
              widget.deps.notifyDataChanged();
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.delete_outline),
            label: const Text('Apagar'),
          ),
        ],
        const SizedBox(height: RltSpace.l),
        const HealthDisclaimer(),
      ]),
    );
  }
}
