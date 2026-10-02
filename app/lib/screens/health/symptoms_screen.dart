import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/health_area.dart';
import '../../widgets/state_views.dart';
import '../../widgets/timeline_item.dart';

/// Histórico médico — diário de sintomas (prancheta Historico). Condições,
/// alergias, cirurgias, vacinas e consultas ainda não têm onde ser gravadas.
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
        builder: (context, _, _) {
          final symptoms = deps.healthRead.symptoms();
          return ListView(
            padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, 96),
            children: [
              const RltSectionHeader('Diário de sintomas'),
              if (symptoms.isEmpty)
                const StateCard(
                  icon: Icons.sentiment_satisfied_outlined,
                  title: 'Nenhum sintoma registrado',
                  message: 'Registre aqui ou conte para o Cérebro: "acordei com dor de cabeça".',
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
              const RltSectionHeader('Condições, alergias, cirurgias, vacinas e consultas'),
              // TODO(frankstein): cadastro de condições, alergias, cirurgias, vacinas e consultas (dado novo, ainda sem tabela).
              Text('Em construção: entra no ciclo das telas com dado novo.', style: t.bodyMedium?.copyWith(color: RltColors.of(context).onSurfaceVariant)),
              const SizedBox(height: RltSpace.l),
              const HealthDisclaimer(),
            ],
          );
        },
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
