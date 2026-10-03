import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_health_records/health_records.dart';

import '../../app_dependencies.dart';
import '../../documents/document_files.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/line_chart.dart';
import '../../widgets/state_views.dart';
import '../account/account_more_screens.dart';

String _fmtDate(LocalDate d) => ddmmyyyy(DateTime(d.year, d.month, d.day));

String _size(int bytes) =>
    bytes >= 1024 * 1024 ? '${formatNumber(bytes / (1024 * 1024), decimals: 1)} MB' : '${(bytes / 1024).ceil()} KB';

LocalDate _today() => LocalDate.fromDateTime(DateTime.now());

/// Receitas médicas (pranchetas Receitas e ReceitasEstados): foto ou PDF
/// guardados no celular, com quem receitou, validade e remédios vinculados.
class PrescriptionsScreen extends StatelessWidget {
  final AppDependencies deps;
  const PrescriptionsScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) => _DocumentListScreen(deps: deps, kind: HealthDocumentKind.prescription);
}

/// Exames e documentos (pranchetas Exames e ExamesEstados): foto ou PDF,
/// categoria e data. Os valores lidos do exame e o gráfico por marcador
/// dependem de decisão (unidades) e da IA (ADR-11).
class ExamsScreen extends StatelessWidget {
  final AppDependencies deps;
  const ExamsScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) => _DocumentListScreen(deps: deps, kind: HealthDocumentKind.exam);
}

class _DocumentListScreen extends StatefulWidget {
  final AppDependencies deps;
  final HealthDocumentKind kind;
  const _DocumentListScreen({required this.deps, required this.kind});

  @override
  State<_DocumentListScreen> createState() => _DocumentListScreenState();
}

class _DocumentListScreenState extends State<_DocumentListScreen> {
  ExamCategory? _category;

  bool get _isPrescription => widget.kind == HealthDocumentKind.prescription;

  Future<void> _add(Future<PickedDocument?> Function() pick) async {
    PickedDocument? picked;
    try {
      picked = await pick();
    } catch (e) {
      if (mounted) showRltError(context, 'Não foi possível abrir: $e');
      return;
    }
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => DocumentFormScreen(deps: widget.deps, kind: widget.kind, initialFile: picked),
    ));
  }

  void _openForm() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DocumentFormScreen(deps: widget.deps, kind: widget.kind),
      ));

  @override
  Widget build(BuildContext context) {
    final picker = widget.deps.documentPicker;
    final title = _isPrescription ? 'Receitas médicas' : 'Exames e documentos';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('document_add'),
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: Text(_isPrescription ? 'Adicionar receita' : 'Enviar exame'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: widget.deps.dataVersion,
        builder: (context, _, _) {
          final docs = widget.deps.documents.list(widget.kind, category: _isPrescription ? null : _category);
          final meds = {for (final m in widget.deps.medicationRepository.listAll()) m.id: m.name};
          final anyAtAll = _category == null ? docs.isNotEmpty : widget.deps.documents.list(widget.kind).isNotEmpty;
          return ListView(
            padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, 96),
            children: [
              if (!_isPrescription && anyAtAll)
                Wrap(spacing: RltSpace.s, children: [
                  ChoiceChip(label: const Text('Todos'), selected: _category == null, onSelected: (_) => setState(() => _category = null)),
                  for (final c in ExamCategory.values)
                    ChoiceChip(
                      key: Key('exam_filter_${c.wireValue}'),
                      label: Text(c.label),
                      selected: _category == c,
                      onSelected: (_) => setState(() => _category = c),
                    ),
                ]),
              if (!anyAtAll)
                StateCard(
                  icon: _isPrescription ? Icons.description_outlined : Icons.science_outlined,
                  title: _isPrescription ? 'Nenhuma receita guardada' : 'Nenhum exame ainda',
                  message: _isPrescription
                      ? 'Fotografe a receita ou envie o PDF. Você pode vincular os remédios depois.'
                      : 'Envie uma foto ou PDF do exame. Fica guardado só no seu celular.',
                  actionLabel: _isPrescription ? 'Fotografar receita' : 'Fotografar exame',
                  actionIcon: Icons.photo_camera_outlined,
                  onAction: () => _add(picker.takePhoto),
                )
              else if (docs.isEmpty)
                const Padding(padding: EdgeInsets.all(RltSpace.l), child: Text('Nada nesta categoria.'))
              else ...[
                if (!_isPrescription && _category == null) ..._trackedMarkers(context),
                if (!_isPrescription) const RltSectionHeader('Exames'),
                for (final d in docs) _DocumentTile(deps: widget.deps, doc: d, medNames: meds),
              ],
              if (!anyAtAll)
                Padding(
                  padding: const EdgeInsets.only(top: RltSpace.s),
                  child: OutlinedButton.icon(
                    key: const Key('document_empty_pdf'),
                    onPressed: () => _add(picker.pickPdf),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Enviar PDF'),
                  ),
                ),
              if (!_isPrescription) ...[
                const SizedBox(height: RltSpace.l),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.local_hospital_outlined),
                    title: const Text('Conectar prontuário de hospital'),
                    subtitle: const Text('Importe exames direto do hospital.'),
                    trailing: const RltBadge(RltBadgeKind.premium),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SubscriptionScreen())),
                  ),
                ),
              ],
              const SizedBox(height: RltSpace.l),
              const HealthDisclaimer(),
            ],
          );
        },
      ),
    );
  }
}

extension on _DocumentListScreenState {
  List<Widget> _trackedMarkers(BuildContext context) {
    final history = widget.deps.documents.markerHistory();
    if (history.isEmpty) return const [];
    final t = Theme.of(context).textTheme;
    final c = RltColors.of(context);
    final keys = history.keys.toList()
      ..sort((a, b) => history[a]!.first.marker.name.compareTo(history[b]!.first.marker.name));
    return [
      const RltSectionHeader('Marcadores acompanhados'),
      for (final k in keys)
        Builder(builder: (context) {
          final readings = history[k]!;
          final last = readings.first.marker;
          final prev = readings.skip(1).where((r) => r.marker.unit == last.unit).firstOrNull?.marker;
          return ListTile(
            key: Key('marker_${k.replaceAll(' ', '_')}'),
            contentPadding: EdgeInsets.zero,
            title: Text(last.name, style: t.bodyLarge),
            subtitle: prev == null ? Text('1 medição', style: t.bodySmall) : Text(trendLabel(prev.value, last.value), style: t.bodySmall),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('${formatMarkerValue(last.value)} ${last.unit}', style: RltTheme.tabular(t.titleSmall!)),
              Icon(Icons.chevron_right, color: c.onSurfaceVariant),
            ]),
            onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => MarkerScreen(deps: widget.deps, markerKey: k),
            )),
          );
        }),
    ];
  }
}

/// "↑ desde o último" (prancheta Exames). Só direção, sem julgamento.
String trendLabel(double previous, double last) {
  final tolerance = previous.abs() * 0.005;
  if ((last - previous).abs() <= tolerance) return '→ igual ao anterior';
  return last > previous ? '↑ desde o último' : '↓ desde o último';
}

/// Evolução de um marcador (prancheta ExameMarcador): última e anterior,
/// gráfico por período, faixa de referência do laboratório e as medições.
/// Mostra; não diz se está alto ou baixo (ADR-16).
class MarkerScreen extends StatefulWidget {
  final AppDependencies deps;
  final String markerKey;
  const MarkerScreen({super.key, required this.deps, required this.markerKey});

  @override
  State<MarkerScreen> createState() => _MarkerScreenState();
}

class _MarkerScreenState extends State<MarkerScreen> {
  int? _months = 6; // null = tudo

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final readings = widget.deps.documents.markerHistory()[widget.markerKey] ?? const <MarkerReading>[];
    if (readings.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Marcador')), body: const SizedBox.shrink());
    }
    final last = readings.first.marker;
    final sameUnit = [for (final r in readings) if (r.marker.unit == last.unit) r];
    final otherUnits = readings.length - sameUnit.length;
    final prev = sameUnit.length > 1 ? sameUnit[1].marker : null;
    final now = DateTime.now();
    final since = _months == null ? null : DateTime(now.year, now.month - _months!, now.day);
    final points = [
      for (final r in sameUnit.reversed)
        if (r.date != null && (since == null || !DateTime(r.date!.year, r.date!.month, r.date!.day).isBefore(since)))
          ChartPoint(DateTime(r.date!.year, r.date!.month, r.date!.day), r.marker.value),
    ];
    final ref = readings.map((r) => r.marker).firstWhere(
          (m) => m.unit == last.unit && (m.referenceLow != null || m.referenceHigh != null),
          orElse: () => last,
        );
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(last.name),
          Text('${last.unit.isEmpty ? 'sem unidade' : last.unit} · ${readings.length} ${readings.length == 1 ? 'medição' : 'medições'}',
              style: t.bodySmall),
        ]),
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        SegmentedButton<int?>(
          segments: const [
            ButtonSegment(value: 6, label: Text('6 meses')),
            ButtonSegment(value: 12, label: Text('1 ano')),
            ButtonSegment(value: null, label: Text('Tudo')),
          ],
          selected: {_months},
          onSelectionChanged: (v) => setState(() => _months = v.first),
        ),
        const SizedBox(height: RltSpace.l),
        Row(children: [
          Expanded(child: _MarkerFact(label: 'Última', value: formatMarkerValue(last.value), unit: last.unit)),
          if (prev != null) Expanded(child: _MarkerFact(label: 'Anterior', value: formatMarkerValue(prev.value), unit: prev.unit)),
        ]),
        const SizedBox(height: RltSpace.l),
        if (points.length >= 2)
          RltLineChart(
            series: [ChartSeries(label: last.name, color: c.primary, points: points)],
            semanticsLabel: 'Evolução de ${last.name}',
          )
        else
          Text('O gráfico aparece com duas medições datadas no período.', style: t.bodySmall),
        if (ref.referenceLow != null || ref.referenceHigh != null) ...[
          const SizedBox(height: RltSpace.m),
          Text('Faixa de referência do laboratório: ${referenceLabel(ref)}', key: const Key('marker_reference'), style: t.bodyMedium),
        ],
        if (otherUnits > 0)
          Padding(
            padding: const EdgeInsets.only(top: RltSpace.s),
            child: Text(
              '$otherUnits ${otherUnits == 1 ? 'medição está' : 'medições estão'} em outra unidade e ficam fora do gráfico.',
              style: t.bodySmall,
            ),
          ),
        const RltSectionHeader('Medições'),
        for (final r in readings)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${formatMarkerValue(r.marker.value)} ${r.marker.unit}', style: RltTheme.tabular(t.titleSmall!)),
            subtitle: Text([if (r.date != null) _fmtDate(r.date!), r.documentTitle].join(' · ')),
            onTap: () {
              final doc = widget.deps.documents.byId(r.documentId);
              if (doc == null) return;
              Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => doc.files.isEmpty
                    ? DocumentFormScreen(deps: widget.deps, kind: doc.kind, existing: doc)
                    : DocumentViewerScreen(deps: widget.deps, doc: doc),
              ));
            },
          ),
        const SizedBox(height: RltSpace.l),
        Text('Valores fora da faixa de referência não são diagnóstico. Leve o resultado ao seu médico.', style: t.bodySmall),
        const SizedBox(height: RltSpace.m),
        const HealthDisclaimer(),
      ]),
    );
  }
}

class _MarkerFact extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _MarkerFact({required this.label, required this.value, required this.unit});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelMedium?.copyWith(color: RltColors.of(context).onSurfaceVariant)),
      Text.rich(TextSpan(children: [
        TextSpan(text: value, style: RltTheme.tabular(t.headlineSmall!)),
        TextSpan(text: ' $unit', style: t.bodyMedium),
      ])),
    ]);
  }
}

class _DocumentTile extends StatelessWidget {
  final AppDependencies deps;
  final HealthDocument doc;
  final Map<String, String> medNames;
  const _DocumentTile({required this.deps, required this.doc, required this.medNames});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final isPdf = doc.files.isNotEmpty && doc.files.first.isPdf;
    final linked = [for (final id in doc.linkedMedicationIds) ?medNames[id]];
    final String line2;
    if (doc.kind == HealthDocumentKind.prescription) {
      line2 = [if (doc.specialty != null) doc.specialty!, if (doc.date != null) _fmtDate(doc.date!)].join(' · ');
    } else {
      line2 = [if (doc.category != null) doc.category!.label, if (doc.date != null) _fmtDate(doc.date!)].join(' · ');
    }
    final expired = doc.isExpiredOn(_today());
    return Card(
      key: Key('document_${doc.id}'),
      margin: const EdgeInsets.only(bottom: RltSpace.s),
      child: InkWell(
        borderRadius: BorderRadius.circular(RltRadius.card),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => doc.files.isEmpty
              ? DocumentFormScreen(deps: deps, kind: doc.kind, existing: doc)
              : DocumentViewerScreen(deps: deps, doc: doc),
        )),
        child: Padding(
          padding: const EdgeInsets.all(RltSpace.m),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 48,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: c.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)),
              child: Text(doc.files.isEmpty ? '—' : (isPdf ? 'PDF' : 'FOTO'), style: t.labelSmall),
            ),
            const SizedBox(width: RltSpace.m),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(doc.title, style: t.titleMedium),
                if (line2.isNotEmpty) Text(line2, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
                if (doc.validUntil != null)
                  Text(
                    expired ? 'Vencida em ${_fmtDate(doc.validUntil!)}' : 'Válida até ${_fmtDate(doc.validUntil!)}',
                    style: t.bodyMedium?.copyWith(color: expired ? c.error : c.success),
                  ),
                if (linked.isNotEmpty) ...[
                  const SizedBox(height: RltSpace.xs),
                  Wrap(spacing: RltSpace.xs, runSpacing: RltSpace.xs, children: [
                    for (final n in linked)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: c.secondaryContainer, borderRadius: BorderRadius.circular(999)),
                        child: Text(n, style: t.labelMedium?.copyWith(color: c.onSecondaryContainer)),
                      ),
                  ]),
                ],
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Cadastro/edição de receita ou exame. Os arquivos só são gravados no
/// "Salvar".
class DocumentFormScreen extends StatefulWidget {
  final AppDependencies deps;
  final HealthDocumentKind kind;
  final HealthDocument? existing;
  final PickedDocument? initialFile;
  const DocumentFormScreen({super.key, required this.deps, required this.kind, this.existing, this.initialFile});

  @override
  State<DocumentFormScreen> createState() => _DocumentFormScreenState();
}

class _DocumentFormScreenState extends State<DocumentFormScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _specialty = TextEditingController(text: widget.existing?.specialty ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late LocalDate? _date = widget.existing?.date ?? _today();
  late LocalDate? _validUntil = widget.existing?.validUntil;
  late ExamCategory _category = widget.existing?.category ?? ExamCategory.blood;
  late final Set<String> _linked = {...?widget.existing?.linkedMedicationIds};
  late final List<HealthDocumentFile> _kept = [...?widget.existing?.files];
  late final List<PickedDocument> _added = [?widget.initialFile];
  late final List<ExamMarker> _markers = [...?widget.existing?.markers];
  bool _saving = false;

  bool get _isPrescription => widget.kind == HealthDocumentKind.prescription;

  @override
  void dispose() {
    _title.dispose();
    _specialty.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<PickedDocument?> Function() pick) async {
    try {
      final p = await pick();
      if (p != null && mounted) setState(() => _added.add(p));
    } catch (e) {
      if (mounted) showRltError(context, 'Não foi possível abrir: $e');
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final deps = widget.deps;
    final stored = <HealthDocumentFile>[];
    try {
      for (final p in _added) {
        stored.add(await deps.documentFiles.store(p));
      }
      final doc = HealthDocument(
        id: widget.existing?.id ?? HealthDataCore.newId(),
        kind: widget.kind,
        title: _title.text,
        date: _date,
        specialty: _isPrescription ? _specialty.text : null,
        validUntil: _isPrescription ? _validUntil : null,
        category: _isPrescription ? null : _category,
        linkedMedicationIds: _isPrescription ? _linked.toList() : const [],
        files: [..._kept, ...stored],
        notes: _notes.text,
        markers: _isPrescription ? const [] : _markers,
      );
      deps.documents.save(doc);
      final keptNames = {for (final f in _kept) f.storedName};
      for (final f in widget.existing?.files ?? const <HealthDocumentFile>[]) {
        if (!keptNames.contains(f.storedName)) await deps.documentFiles.delete(f.storedName);
      }
      deps.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      showRltSaved(context, _isPrescription ? 'Receita salva em Saúde › Receitas médicas.' : 'Exame salvo em Saúde › Exames.');
    } catch (e) {
      for (final f in stored) {
        await deps.documentFiles.delete(f.storedName);
      }
      if (mounted) {
        setState(() => _saving = false);
        showRltError(context, e);
      }
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_isPrescription ? 'Apagar receita?' : 'Apagar exame?'),
        content: const Text('O registro e os arquivos saem do celular. Não dá para desfazer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(key: const Key('document_delete_confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final existing = widget.existing!;
    widget.deps.documents.delete(existing.id);
    for (final f in existing.files) {
      await widget.deps.documentFiles.delete(f.storedName);
    }
    widget.deps.notifyDataChanged();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Widget _dateField(String label, LocalDate? value, ValueChanged<LocalDate?> onChanged, {Key? key, bool clearable = false}) {
    return InkWell(
      key: key,
      onTap: () async {
        final v = value;
        final picked = await showDatePicker(
          context: context,
          initialDate: v == null ? DateTime.now() : DateTime(v.year, v.month, v.day),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) setState(() => onChanged(LocalDate.fromDateTime(picked)));
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: clearable && value != null
              ? IconButton(tooltip: 'Limpar', onPressed: () => setState(() => onChanged(null)), icon: const Icon(Icons.close))
              : const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(value == null ? 'Sem data' : _fmtDate(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final picker = widget.deps.documentPicker;
    final meds = widget.deps.medicationRepository.listAll();
    final title = widget.existing != null
        ? (_isPrescription ? 'Editar receita' : 'Editar exame')
        : (_isPrescription ? 'Nova receita' : 'Novo exame');
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          TextButton(key: const Key('document_save'), onPressed: _saving ? null : _save, child: const Text('Salvar')),
        ],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        RltSectionHeader(_isPrescription ? 'Foto ou PDF da receita' : 'Foto ou PDF do exame'),
        for (final f in _kept)
          _FileRow(
            name: f.originalName,
            detail: '${f.isPdf ? 'PDF' : 'Foto'} · ${_size(f.sizeBytes)}',
            onRemove: () => setState(() => _kept.remove(f)),
          ),
        for (final p in _added)
          _FileRow(
            name: p.name,
            detail: '${p.mimeType == 'application/pdf' ? 'PDF' : 'Foto'} · ${_size(p.bytes.length)}',
            onRemove: () => setState(() => _added.remove(p)),
          ),
        Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
          OutlinedButton.icon(
            key: const Key('document_take_photo'),
            onPressed: () => _pick(picker.takePhoto),
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Fotografar'),
          ),
          OutlinedButton.icon(
            key: const Key('document_gallery'),
            onPressed: () => _pick(picker.pickImage),
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Galeria'),
          ),
          OutlinedButton.icon(
            key: const Key('document_pdf'),
            onPressed: () => _pick(picker.pickPdf),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF'),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: RltSpace.xs),
          child: Text('Os arquivos ficam só no seu celular.', style: t.bodySmall),
        ),
        const SizedBox(height: RltSpace.l),
        TextField(
          key: const Key('document_title'),
          controller: _title,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: _isPrescription ? 'Quem receitou' : 'Nome do exame'),
        ),
        const SizedBox(height: RltSpace.m),
        if (_isPrescription) ...[
          TextField(
            controller: _specialty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Especialidade (opcional)'),
          ),
          const SizedBox(height: RltSpace.m),
          _dateField('Data da receita', _date, (v) => _date = v),
          const SizedBox(height: RltSpace.m),
          _dateField('Válida até (opcional)', _validUntil, (v) => _validUntil = v, key: const Key('document_valid_until'), clearable: true),
          const RltSectionHeader('Remédios desta receita'),
          if (meds.isEmpty)
            Text('Nenhum remédio cadastrado. Cadastre em Saúde › Remédios e vincule depois.', style: t.bodyMedium)
          else
            Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
              for (final m in meds)
                FilterChip(
                  key: Key('document_link_${m.id}'),
                  label: Text(m.name),
                  selected: _linked.contains(m.id),
                  onSelected: (v) => setState(() => v ? _linked.add(m.id) : _linked.remove(m.id)),
                ),
            ]),
        ] else ...[
          Text('Categoria', style: t.labelLarge),
          const SizedBox(height: RltSpace.xs),
          Wrap(spacing: RltSpace.s, children: [
            for (final c in ExamCategory.values)
              ChoiceChip(
                key: Key('document_category_${c.wireValue}'),
                label: Text(c.label),
                selected: _category == c,
                onSelected: (_) => setState(() => _category = c),
              ),
          ]),
          const SizedBox(height: RltSpace.m),
          _dateField('Data do exame', _date, (v) => _date = v),
          RltSectionHeader(
            'Valores do exame',
            action: TextButton.icon(
              key: const Key('marker_add'),
              onPressed: () async {
                final m = await showDialog<ExamMarker>(context: context, builder: (_) => const MarkerDialog());
                if (m != null) setState(() => _markers.add(m));
              },
              icon: const Icon(Icons.add),
              label: const Text('Adicionar valor'),
            ),
          ),
          if (_markers.isEmpty)
            Text('Opcional. Digite os valores como estão no laudo, com a unidade dele, para acompanhar cada um ao longo do tempo.',
                style: t.bodySmall)
          else ...[
            Text('Confira cada valor com o papel antes de salvar.', style: t.bodySmall),
            for (var i = 0; i < _markers.length; i++)
              ListTile(
                key: Key('marker_row_$i'),
                contentPadding: EdgeInsets.zero,
                title: Text(_markers[i].name),
                subtitle: _markers[i].referenceLow == null && _markers[i].referenceHigh == null
                    ? null
                    : Text('Referência do laboratório: ${referenceLabel(_markers[i])}'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('${formatMarkerValue(_markers[i].value)} ${_markers[i].unit}', style: RltTheme.tabular(t.titleSmall!)),
                  IconButton(
                    tooltip: 'Tirar valor',
                    onPressed: () => setState(() => _markers.removeAt(i)),
                    icon: const Icon(Icons.close),
                  ),
                ]),
                onTap: () async {
                  final m = await showDialog<ExamMarker>(context: context, builder: (_) => MarkerDialog(initial: _markers[i]));
                  if (m != null) setState(() => _markers[i] = m);
                },
              ),
          ],
        ],
        const SizedBox(height: RltSpace.m),
        TextField(controller: _notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Anotações')),
        if (widget.existing != null) ...[
          const SizedBox(height: RltSpace.l),
          OutlinedButton.icon(
            key: const Key('document_delete'),
            onPressed: _delete,
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

class _FileRow extends StatelessWidget {
  final String name;
  final String detail;
  final VoidCallback onRemove;
  const _FileRow({required this.name, required this.detail, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(detail.startsWith('PDF') ? Icons.picture_as_pdf_outlined : Icons.image_outlined),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(detail),
      trailing: IconButton(tooltip: 'Tirar arquivo', onPressed: onRemove, icon: const Icon(Icons.close)),
    );
  }
}

/// Uma página para mostrar: foto inteira, ou página [pdfPage] de um PDF.
class _PageRef {
  final HealthDocumentFile file;
  final int? pdfPage;
  final int? pdfPages;
  const _PageRef(this.file, {this.pdfPage, this.pdfPages});
}

/// Tela cheia (prancheta Receitas, "Tela cheia"): fotos e páginas de PDF
/// com pinça para ampliar. PDF é desenhado pelo próprio Android.
class DocumentViewerScreen extends StatefulWidget {
  final AppDependencies deps;
  final HealthDocument doc;
  const DocumentViewerScreen({super.key, required this.deps, required this.doc});

  @override
  State<DocumentViewerScreen> createState() => _DocumentViewerScreenState();
}

class _DocumentViewerScreenState extends State<DocumentViewerScreen> {
  List<_PageRef>? _pages;
  int _index = 0;
  final Map<int, Future<Uint8List?>> _cache = {};

  @override
  void initState() {
    super.initState();
    _loadPages();
  }

  Future<void> _loadPages() async {
    final pages = <_PageRef>[];
    for (final f in widget.doc.files) {
      if (!f.isPdf) {
        pages.add(_PageRef(f));
        continue;
      }
      final path = widget.deps.documentFiles.pathOf(f.storedName);
      final count = path == null ? null : await widget.deps.pdfRenderer.pageCount(path);
      if (count == null || count == 0) {
        pages.add(_PageRef(f, pdfPage: -1));
      } else {
        for (var i = 0; i < count; i++) {
          pages.add(_PageRef(f, pdfPage: i, pdfPages: count));
        }
      }
    }
    if (mounted) setState(() => _pages = pages);
  }

  Future<Uint8List?> _bytes(int i) => _cache.putIfAbsent(i, () {
        final p = _pages![i];
        if (p.pdfPage == null) return widget.deps.documentFiles.readBytes(p.file.storedName);
        if (p.pdfPage! < 0) return Future.value(null);
        final path = widget.deps.documentFiles.pathOf(p.file.storedName)!;
        return widget.deps.pdfRenderer.renderPage(path, p.pdfPage!);
      });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final doc = widget.doc;
    final pages = _pages;
    final current = pages == null || pages.isEmpty ? null : pages[_index];
    final sub = [
      if (doc.date != null) _fmtDate(doc.date!),
      if (pages != null && pages.length > 1) 'página ${_index + 1} de ${pages.length}',
    ].join(' · ');
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doc.title),
          if (sub.isNotEmpty) Text(sub, style: t.bodySmall),
        ]),
        actions: [
          IconButton(
            key: const Key('document_edit'),
            tooltip: 'Editar',
            onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
              builder: (_) => DocumentFormScreen(deps: widget.deps, kind: doc.kind, existing: doc),
            )),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: pages == null
              ? const Center(child: CircularProgressIndicator())
              : PageView.builder(
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) => FutureBuilder<Uint8List?>(
                    future: _bytes(i),
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
                      final bytes = snap.data;
                      if (bytes == null) {
                        return Padding(
                          padding: const EdgeInsets.all(RltSpace.l),
                          child: Center(
                            child: StateCard(
                              icon: Icons.error_outline,
                              title: 'Não foi possível abrir o arquivo',
                              message: pages[i].file.isPdf
                                  ? 'O PDF pode estar protegido por senha ou danificado. O arquivo continua guardado.'
                                  : 'O arquivo não foi encontrado no celular.',
                            ),
                          ),
                        );
                      }
                      return InteractiveViewer(
                        maxScale: 6,
                        child: Center(child: Image.memory(bytes, fit: BoxFit.contain, gaplessPlayback: true)),
                      );
                    },
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(RltSpace.m),
          child: Column(children: [
            Text('Faça pinça para ampliar', style: t.bodySmall),
            if (doc.kind == HealthDocumentKind.prescription) ...[
              const SizedBox(height: RltSpace.s),
              OutlinedButton.icon(
                key: const Key('document_link_meds'),
                onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
                  builder: (_) => DocumentFormScreen(deps: widget.deps, kind: doc.kind, existing: doc),
                )),
                icon: const Icon(Icons.link),
                label: Text(doc.linkedMedicationIds.isEmpty ? 'Vincular remédio' : 'Remédios vinculados'),
              ),
            ],
            if (current != null && current.file.isPdf && current.pdfPages != null)
              Text(current.file.originalName, style: t.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

/// Valor do exame com até 2 casas, como costuma vir no laudo.
String formatMarkerValue(double v) {
  final rounded = (v * 100).round() / 100;
  final decimals = rounded == rounded.roundToDouble() ? 0 : ((rounded * 10).round() / 10 == rounded ? 1 : 2);
  return formatNumber(rounded, decimals: decimals);
}

String referenceLabel(ExamMarker m) {
  final lo = m.referenceLow;
  final hi = m.referenceHigh;
  final u = m.unit.isEmpty ? '' : ' ${m.unit}';
  if (lo != null && hi != null) return '${formatMarkerValue(lo)} a ${formatMarkerValue(hi)}$u';
  if (lo != null) return 'a partir de ${formatMarkerValue(lo)}$u';
  if (hi != null) return 'até ${formatMarkerValue(hi)}$u';
  return '';
}

/// Digitar/corrigir um valor do exame (nome, valor, unidade do laudo e,
/// se houver, a faixa de referência do laboratório).
class MarkerDialog extends StatefulWidget {
  final ExamMarker? initial;
  const MarkerDialog({super.key, this.initial});

  @override
  State<MarkerDialog> createState() => _MarkerDialogState();
}

class _MarkerDialogState extends State<MarkerDialog> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _value = TextEditingController(text: widget.initial == null ? '' : formatMarkerValue(widget.initial!.value));
  late final _unit = TextEditingController(text: widget.initial?.unit ?? '');
  late final _low = TextEditingController(
      text: widget.initial?.referenceLow == null ? '' : formatMarkerValue(widget.initial!.referenceLow!));
  late final _high = TextEditingController(
      text: widget.initial?.referenceHigh == null ? '' : formatMarkerValue(widget.initial!.referenceHigh!));
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _value, _unit, _low, _high]) {
      c.dispose();
    }
    super.dispose();
  }

  void _ok() {
    final v = parseNumber(_value.text);
    if (v == null) {
      setState(() => _error = 'Digite o valor (ex.: 102 ou 5,9).');
      return;
    }
    try {
      Navigator.pop(
        context,
        ExamMarker(
          name: _name.text,
          value: v,
          unit: _unit.text,
          referenceLow: _low.text.trim().isEmpty ? null : parseNumber(_low.text),
          referenceHigh: _high.text.trim().isEmpty ? null : parseNumber(_high.text),
        ),
      );
    } on ArgumentError catch (e) {
      setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    const number = TextInputType.numberWithOptions(decimal: true);
    return AlertDialog(
      title: Text(widget.initial == null ? 'Adicionar valor' : 'Corrigir valor'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('marker_name'),
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome (ex.: Glicemia de jejum)'),
          ),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('marker_value'),
                controller: _value,
                keyboardType: number,
                decoration: const InputDecoration(labelText: 'Valor'),
              ),
            ),
            const SizedBox(width: RltSpace.s),
            Expanded(
              child: TextField(
                key: const Key('marker_unit'),
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unidade do laudo'),
              ),
            ),
          ]),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('marker_low'),
                controller: _low,
                keyboardType: number,
                decoration: const InputDecoration(labelText: 'Referência de'),
              ),
            ),
            const SizedBox(width: RltSpace.s),
            Expanded(
              child: TextField(
                key: const Key('marker_high'),
                controller: _high,
                keyboardType: number,
                decoration: const InputDecoration(labelText: 'até'),
              ),
            ),
          ]),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: RltSpace.s),
              child: Text(_error!, style: TextStyle(color: RltColors.of(context).error)),
            ),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(key: const Key('marker_ok'), onPressed: _ok, child: const Text('OK')),
      ],
    );
  }
}
