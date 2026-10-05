// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../ai/ai_consent.dart';
import '../../ai/ai_settings.dart';
import '../../app_dependencies.dart';
import '../../data/nutrition_store.dart';
import '../../documents/document_files.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import '../account/brain_settings_screen.dart';
import 'meal_labels.dart';

/// Refeição pelo horário, quando a pessoa não escolheu.
MealType mealTypeForHour(int hour) => hour < 10
    ? MealType.breakfast
    : hour < 15
        ? MealType.lunch
        : hour < 18
            ? MealType.snack
            : MealType.dinner;

/// Foto do prato (prancheta CerebroFotoPrato): a IA identifica os alimentos
/// e estima porções e valores (com o peso da balança, se informado); a
/// pessoa ajusta e confirma. Sempre estimativa; nada é gravado antes do
/// "Confirmar". A foto vai para a Galeria de pratos.
class PlatePhotoScreen extends StatefulWidget {
  final AppDependencies deps;
  final MealType? mealType;
  final DateTime? day;
  const PlatePhotoScreen({super.key, required this.deps, this.mealType, this.day});

  @override
  State<PlatePhotoScreen> createState() => _PlatePhotoScreenState();
}

class _PlatePhotoScreenState extends State<PlatePhotoScreen> {
  PickedDocument? _photo;
  final _grams = TextEditingController();
  late MealType _meal = widget.mealType ?? mealTypeForHour(DateTime.now().hour);
  bool _mealChosen = false;
  List<PlateItem>? _items;
  bool _busy = false;
  bool _saving = false;
  String? _error;

  AppDependencies get deps => widget.deps;

  @override
  void initState() {
    super.initState();
    _mealChosen = widget.mealType != null;
  }

  @override
  void dispose() {
    _grams.dispose();
    super.dispose();
  }

  Future<void> _pick(Future<PickedDocument?> Function() pick) async {
    try {
      final p = await pick();
      if (p != null && mounted) {
        setState(() {
          _photo = p;
          _items = null;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) showRltError(context, 'Não foi possível abrir: $e');
    }
  }

  Future<void> _estimate() async {
    final photo = _photo;
    if (photo == null) return;
    if (!deps.ai.hasKey.value) {
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BrainSettingsScreen(deps: deps)));
      if (!deps.ai.hasKey.value || !mounted) return;
    }
    if (!await ensureAiConsent(context, deps, sending: 'A foto deste prato (e o peso da balança, se você informar)')) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final grams = _grams.text.trim().isEmpty ? null : parseNumber(_grams.text);
      final e = await estimatePlate(await deps.ai.client(), AiPart.file(photo.bytes, photo.mimeType), plateGrams: grams);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _items = [...e.items];
        final guess = MealType.values.where((m) => m.wireValue == e.mealType).firstOrNull;
        if (!_mealChosen && guess != null) _meal = guess;
        if (e.items.isEmpty) _error = 'A IA não achou comida nesta foto. Tente outra foto ou registre pela busca.';
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = aiFailureMessage(e);
        });
      }
    }
  }

  Future<void> _editGrams(int i) async {
    final item = _items![i];
    final v = await showDialog<double>(context: context, builder: (_) => _PortionDialog(item: item));
    if (v != null && mounted) setState(() => _items![i] = item.withGrams(v));
  }

  Future<void> _addItem() async {
    final item = await showDialog<PlateItem>(context: context, builder: (_) => const _AddPlateItemDialog());
    if (item != null && mounted) setState(() => _items!.add(item));
  }

  Future<void> _confirm() async {
    final items = _items;
    final photo = _photo;
    if (items == null || items.isEmpty || photo == null || _saving) return;
    setState(() => _saving = true);
    String? stored;
    try {
      final now = DateTime.now();
      final day = widget.day;
      final isToday = day == null || (day.year == now.year && day.month == now.month && day.day == now.day);
      final local = isToday ? now : DateTime(day.year, day.month, day.day, 12);
      final foods = [
        for (final i in items)
          (
            deps.nutrition.createEstimatedFood(
              name: i.name,
              grams: i.grams,
              kcal: i.kcal,
              protein: i.proteinGrams,
              carbs: i.carbsGrams,
              fat: i.fatGrams,
              fiber: i.fiberGrams,
            ),
            i.grams,
          ),
      ];
      final event = deps.mealLogger.logMeal(
        items: [for (final (f, g) in foods) MealItemInput(foodId: f.id, grams: g, inputMethod: MealItemInputMethod.photo)],
        mealType: _meal,
        occurredAt: local.toUtc(),
        occurredAtTzOffsetMinutes: local.timeZoneOffset.inMinutes,
      );
      stored = (await deps.documentFiles.store(photo)).storedName;
      deps.nutrition.addPlatePhoto(PlatePhoto(
        mealEventId: event.id,
        storedName: stored,
        mealType: _meal,
        atUtc: local.toUtc(),
        tzOffsetMinutes: local.timeZoneOffset.inMinutes,
      ));
      deps.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).popUntil((r) => r.isFirst);
      showRltSaved(context, 'Prato salvo em Nutrição › ${mealTypeLabel(_meal)} (estimativa).');
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showRltError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final picker = deps.documentPicker;
    final items = _items;
    double sum(double Function(PlateItem) f) => (items ?? const <PlateItem>[]).fold(0.0, (s, i) => s + f(i));
    return Scaffold(
      appBar: AppBar(title: const Text('Foto do prato')),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        Text('IA ativa só ao enviar: a foto vai para o ${AiSettings.providerName} quando você tocar em "Estimar".', style: t.bodySmall),
        const SizedBox(height: RltSpace.m),
        if (_photo == null)
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                key: const Key('plate_camera'),
                onPressed: () => _pick(picker.takePhoto),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Fotografar'),
              ),
            ),
            const SizedBox(width: RltSpace.s),
            Expanded(
              child: OutlinedButton.icon(
                key: const Key('plate_gallery'),
                onPressed: () => _pick(picker.pickImage),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galeria'),
              ),
            ),
          ])
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(RltRadius.card),
            child: SizedBox(height: 200, child: Image.memory(_photo!.bytes, fit: BoxFit.cover, width: double.infinity)),
          ),
          const SizedBox(height: RltSpace.m),
          TextField(
            key: const Key('plate_weight'),
            controller: _grams,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Peso da comida na balança (opcional)',
              suffixText: 'g',
              helperText: 'Ajuda a IA a acertar as porções.',
            ),
          ),
          const SizedBox(height: RltSpace.m),
          Text('Refeição', style: t.labelLarge),
          Wrap(spacing: RltSpace.s, children: [
            for (final m in MealType.values)
              ChoiceChip(
                key: Key('plate_meal_${m.wireValue}'),
                label: Text(mealTypeLabel(m)),
                selected: _meal == m,
                onSelected: (_) => setState(() {
                  _meal = m;
                  _mealChosen = true;
                }),
              ),
          ]),
          const SizedBox(height: RltSpace.m),
          if (_busy) ...[
            const LinearProgressIndicator(),
            const SizedBox(height: RltSpace.xs),
            Text('Estimando com o Gemini…', key: const Key('plate_busy'), style: t.bodySmall),
          ] else if (items == null)
            ValueListenableBuilder<bool>(
              valueListenable: deps.ai.hasKey,
              builder: (context, hasKey, _) => hasKey
                  ? FilledButton.icon(
                      key: const Key('plate_estimate'),
                      onPressed: _estimate,
                      icon: const Icon(Icons.auto_awesome_outlined),
                      label: const Text('Estimar com a IA'),
                    )
                  : StateCard(
                      key: const Key('plate_ai_hint'),
                      icon: Icons.auto_awesome_outlined,
                      title: 'Ative a IA para estimar o prato',
                      message: 'Com a sua chave, a IA identifica os alimentos e estima porções e calorias. Sem ela, registre pela busca ou pela adição rápida.',
                      tone: StateTone.permission,
                      actionLabel: 'Configurar IA',
                      onAction: _estimate,
                    ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: RltSpace.s),
              child: Text(_error!, key: const Key('plate_error'), style: t.bodyMedium?.copyWith(color: c.error)),
            ),
          if (items != null && items.isNotEmpty) ...[
            Card(
              key: const Key('plate_card'),
              child: Padding(
                padding: const EdgeInsets.all(RltSpace.l),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(child: Text('Encontrei ${items.length} ${items.length == 1 ? 'alimento' : 'alimentos'}:', style: t.titleSmall)),
                    const RltBadge(RltBadgeKind.estimate),
                  ]),
                  Text('REFEIÇÃO · ${mealTypeLabel(_meal)}', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
                  const SizedBox(height: RltSpace.s),
                  for (var i = 0; i < items.length; i++)
                    ListTile(
                      key: Key('plate_item_$i'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(items[i].name),
                      subtitle: Text('${formatNumber(items[i].grams)} g · toque para ajustar'),
                      onTap: () => _editGrams(i),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${formatNumber(items[i].kcal)} kcal', style: RltTheme.tabular(t.bodyMedium!)),
                        IconButton(
                          tooltip: 'Tirar',
                          onPressed: () => setState(() => items.removeAt(i)),
                          icon: const Icon(Icons.close),
                        ),
                      ]),
                    ),
                  TextButton.icon(
                    key: const Key('plate_add'),
                    onPressed: _addItem,
                    icon: const Icon(Icons.add),
                    label: const Text('Adicionar alimento'),
                  ),
                  const Divider(),
                  Row(children: [
                    Expanded(child: _Total('Total', formatNumber(sum((i) => i.kcal)), 'kcal', key: const Key('plate_total_kcal'))),
                    Expanded(child: _Total('Proteína', formatNumber(sum((i) => i.proteinGrams)), 'g')),
                    Expanded(child: _Total('Carbo', formatNumber(sum((i) => i.carbsGrams)), 'g')),
                    Expanded(child: _Total('Gordura', formatNumber(sum((i) => i.fatGrams)), 'g')),
                  ]),
                  const SizedBox(height: RltSpace.s),
                  Text('Porções estimadas pela foto${_grams.text.trim().isEmpty ? '' : ' e pelo peso informado'}. Ajuste se precisar.',
                      style: t.bodySmall),
                  const SizedBox(height: RltSpace.m),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('plate_discard'),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Descartar'),
                      ),
                    ),
                    const SizedBox(width: RltSpace.m),
                    Expanded(
                      child: FilledButton(
                        key: const Key('plate_confirm'),
                        onPressed: _saving ? null : _confirm,
                        child: const Text('Confirmar'),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ],
          const SizedBox(height: RltSpace.s),
          TextButton(onPressed: () => setState(() => _photo = null), child: const Text('Trocar foto')),
        ],
      ]),
    );
  }
}

/// Diálogos donos dos próprios campos: o controle só é liberado quando o
/// diálogo sai da tela de vez (liberar antes quebra a animação de saída).
class _PortionDialog extends StatefulWidget {
  final PlateItem item;
  const _PortionDialog({required this.item});

  @override
  State<_PortionDialog> createState() => _PortionDialogState();
}

class _PortionDialogState extends State<_PortionDialog> {
  late final _ctrl = TextEditingController(text: formatNumber(widget.item.grams));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.item.name),
      content: TextField(
        key: const Key('plate_grams_input'),
        controller: _ctrl,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Porção', suffixText: 'g'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('plate_grams_ok'),
          onPressed: () {
            final g = parseNumber(_ctrl.text);
            if (g != null && g > 0) Navigator.pop(context, g);
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}

class _AddPlateItemDialog extends StatefulWidget {
  const _AddPlateItemDialog();

  @override
  State<_AddPlateItemDialog> createState() => _AddPlateItemDialogState();
}

class _AddPlateItemDialogState extends State<_AddPlateItemDialog> {
  final _name = TextEditingController();
  final _grams = TextEditingController();
  final _kcal = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _grams, _kcal]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Adicionar alimento'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(key: const Key('plate_add_name'), controller: _name, decoration: const InputDecoration(labelText: 'Alimento')),
        TextField(
          key: const Key('plate_add_grams'),
          controller: _grams,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Porção', suffixText: 'g'),
        ),
        TextField(
          key: const Key('plate_add_kcal'),
          controller: _kcal,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Calorias da porção', suffixText: 'kcal'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('plate_add_ok'),
          onPressed: () {
            final g = parseNumber(_grams.text);
            final k = parseNumber(_kcal.text);
            if (_name.text.trim().isEmpty || g == null || g <= 0 || k == null || k < 0) return;
            Navigator.pop(context, PlateItem(name: _name.text.trim(), grams: g, kcal: k));
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _Total extends StatelessWidget {
  final String label;
  final String value;
  final String unit;
  const _Total(this.label, this.value, this.unit, {super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelSmall),
      Text.rich(TextSpan(children: [
        TextSpan(text: value, style: RltTheme.tabular(t.titleMedium!)),
        TextSpan(text: ' $unit', style: t.bodySmall),
      ])),
    ]);
  }
}

/// Galeria de pratos (prancheta GaleriaPratos): fotos por data, com a
/// refeição e a hora. Toque abre a foto grande.
class PlateGalleryView extends StatelessWidget {
  final AppDependencies deps;
  const PlateGalleryView({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final photos = deps.nutrition.platePhotos();
    if (photos.isEmpty) {
      return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        StateCard(
          key: const Key('gallery_empty'),
          icon: Icons.photo_library_outlined,
          title: 'Nenhuma foto de prato ainda',
          message: 'Fotografe a refeição e ela aparece aqui, organizada por data.',
          actionLabel: 'Fotografar prato',
          actionIcon: Icons.photo_camera_outlined,
          onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlatePhotoScreen(deps: deps))),
        ),
      ]);
    }
    final byDay = <DateTime, List<PlatePhoto>>{};
    for (final p in photos) {
      final l = p.local;
      byDay.putIfAbsent(DateTime(l.year, l.month, l.day), () => []).add(p);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String dayLabel(DateTime d) => d == today
        ? 'Hoje'
        : d == today.subtract(const Duration(days: 1))
            ? 'Ontem'
            : '${d.day} de ${monthShort(d.month)}';
    return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
      for (final e in byDay.entries) ...[
        RltSectionHeader(dayLabel(e.key)),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: RltSpace.s,
          crossAxisSpacing: RltSpace.s,
          childAspectRatio: 0.8,
          children: [
            for (final p in e.value)
              InkWell(
                key: Key('gallery_${p.mealEventId}'),
                onTap: () => _open(context, p),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: _Thumb(deps: deps, storedName: p.storedName)),
                  const SizedBox(height: 2),
                  Text('${mealTypeLabel(p.mealType)} ${hhmm(p.local)}', style: t.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ]),
              ),
          ],
        ),
      ],
    ]);
  }

  void _open(BuildContext context, PlatePhoto p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text('${mealTypeLabel(p.mealType)} · ${ddmm(p.local)} ${hhmm(p.local)}')),
        body: InteractiveViewer(maxScale: 5, child: Center(child: _Thumb(deps: deps, storedName: p.storedName, fit: BoxFit.contain))),
      ),
    ));
  }
}

class _Thumb extends StatelessWidget {
  final AppDependencies deps;
  final String storedName;
  final BoxFit fit;
  const _Thumb({required this.deps, required this.storedName, this.fit = BoxFit.cover});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: FutureBuilder<Uint8List?>(
        future: deps.documentFiles.readBytes(storedName),
        builder: (context, snap) => snap.data == null
            ? ColoredBox(color: RltColors.of(context).surfaceContainerHigh)
            : Image.memory(snap.data!, fit: fit, width: double.infinity, height: double.infinity),
      ),
    );
  }
}
