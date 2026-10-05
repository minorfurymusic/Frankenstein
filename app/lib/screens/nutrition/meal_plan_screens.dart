// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:frankstein_ai/ai.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../ai/ai_consent.dart';
import '../../ai/ai_settings.dart';
import '../../app_dependencies.dart';
import '../../data/meal_plan.dart';
import '../../data/nutrition_store.dart';
import '../../documents/document_files.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/badges.dart';
import '../../widgets/common.dart';
import '../account/brain_settings_screen.dart';
import 'meal_labels.dart';

/// Ordem das refeições no plano.
const planMealOrder = [MealType.breakfast, MealType.snack, MealType.lunch, MealType.dinner];

/// Plano de refeições (pedido do usuário, 2026-10-05): montar o próprio,
/// importar o do profissional (a IA lê foto/PDF) ou pedir sugestão à IA.
/// Tudo vira um rascunho que a pessoa revisa antes de salvar.
class MealPlanScreen extends StatefulWidget {
  final AppDependencies deps;
  const MealPlanScreen({super.key, required this.deps});

  @override
  State<MealPlanScreen> createState() => _MealPlanScreenState();
}

class _MealPlanScreenState extends State<MealPlanScreen> {
  String? _busy;

  AppDependencies get deps => widget.deps;

  Future<void> _edit(MealPlan? initial, {PickedDocument? attachment, MealPlanSource source = MealPlanSource.manual}) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => MealPlanEditScreen(deps: deps, initial: initial, newAttachment: attachment, source: source),
    ));
  }

  Future<bool> _ensureAi() async {
    if (deps.ai.hasKey.value) return true;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => BrainSettingsScreen(deps: deps)));
    return deps.ai.hasKey.value;
  }

  Future<void> _import() async {
    final picker = deps.documentPicker;
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            key: const Key('plan_import_camera'),
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Fotografar o plano'),
            onTap: () => Navigator.pop(context, 'camera'),
          ),
          ListTile(
            key: const Key('plan_import_gallery'),
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Foto da galeria'),
            onTap: () => Navigator.pop(context, 'gallery'),
          ),
          ListTile(
            key: const Key('plan_import_pdf'),
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('PDF'),
            onTap: () => Navigator.pop(context, 'pdf'),
          ),
        ]),
      ),
    );
    if (source == null || !mounted) return;
    PickedDocument? file;
    try {
      file = switch (source) {
        'camera' => await picker.takePhoto(),
        'gallery' => await picker.pickImage(),
        _ => await picker.pickPdf(),
      };
    } catch (e) {
      if (mounted) showRltError(context, 'Não foi possível abrir: $e');
      return;
    }
    if (file == null || !mounted) return;
    if (!deps.ai.hasKey.value) {
      // Sem IA: guarda o documento e a pessoa digita os itens.
      showRltSaved(context, 'Sem a IA ativa, o documento fica guardado e você digita os itens.');
      await _edit(null, attachment: file, source: MealPlanSource.imported);
      return;
    }
    if (!await ensureAiConsent(context, deps, sending: 'A foto ou o PDF do plano alimentar, para ler as refeições')) return;
    setState(() => _busy = 'Lendo o plano com o Gemini…');
    try {
      final draft = await readMealPlan(await deps.ai.client(), [AiPart.file(file.bytes, file.mimeType)]);
      if (!mounted) return;
      setState(() => _busy = null);
      await _edit(
        MealPlan.fromDraft(draft, source: MealPlanSource.imported, fallbackName: 'Plano do profissional'),
        attachment: file,
        source: MealPlanSource.imported,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      showRltError(context, aiFailureMessage(e));
    }
  }

  Future<void> _suggest() async {
    final goals = deps.goals.goalsFor(DateTime.now());
    if (goals == null) {
      showRltError(context, 'Preencha o perfil (Conta › Perfil) para a IA saber suas metas.');
      return;
    }
    if (!await _ensureAi() || !mounted) return;
    if (!await ensureAiConsent(context, deps,
        sending: 'Suas metas do dia (calorias e macros) e suas preferências e alergias alimentares — sem nome nem histórico')) {
      return;
    }
    final prefs = deps.nutrition.dietPreferences();
    setState(() => _busy = 'Montando a sugestão com o Gemini…');
    try {
      final draft = await suggestMealPlan(
        await deps.ai.client(),
        caloriesKcal: goals.caloriesKcal,
        proteinGrams: goals.proteinGrams,
        carbsGrams: goals.carbsGrams,
        fatGrams: goals.fatGrams,
        fiberGrams: goals.fiberGrams,
        preferences: {for (final t in prefs.tags) DietPreferences.labels[t] ?? t},
        allergies: prefs.allergies,
        dislikes: prefs.dislikes,
      );
      if (!mounted) return;
      setState(() => _busy = null);
      await _edit(MealPlan.fromDraft(draft, source: MealPlanSource.ai, fallbackName: 'Sugestão de cardápio'), source: MealPlanSource.ai);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = null);
      showRltError(context, aiFailureMessage(e));
    }
  }

  Future<void> _delete(MealPlan plan) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar o plano?'),
        content: const Text('O plano sai do RLT. O que você já registrou no diário continua.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(key: const Key('plan_delete_confirm'), onPressed: () => Navigator.pop(context, true), child: const Text('Apagar')),
        ],
      ),
    );
    if (ok != true) return;
    for (final a in plan.attachments) {
      await deps.documentFiles.delete(a);
    }
    deps.mealPlans.delete();
    deps.notifyDataChanged();
  }

  /// Registra um item do plano no diário de hoje, como adição rápida
  /// (uma porção = o item do plano).
  void _log(MealPlanMeal meal, MealPlanItem item) {
    final kcal = item.kcal;
    if (kcal == null || kcal <= 0) return;
    final store = deps.nutrition;
    final existing = store.myItems().where((f) => f.name == item.description && (f.energyKcalPer100g - kcal).abs() < 0.5);
    final food = existing.isNotEmpty
        ? existing.first
        : store.createQuickItem(
            name: item.description,
            kcal: kcal,
            protein: item.proteinGrams ?? 0,
            carbs: item.carbsGrams ?? 0,
            fat: item.fatGrams ?? 0,
          );
    final now = DateTime.now();
    deps.mealLogger.logMeal(
      items: [MealItemInput(foodId: food.id, grams: 100, inputMethod: MealItemInputMethod.quickAdd)],
      mealType: meal.mealType,
      occurredAt: now.toUtc(),
      occurredAtTzOffsetMinutes: now.timeZoneOffset.inMinutes,
    );
    deps.notifyDataChanged();
    showRltSaved(context, '${item.description} salvo em Nutrição › ${mealTypeLabel(meal.mealType)}.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plano de refeições')),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) {
          final plan = deps.mealPlans.load();
          return ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
            if (_busy != null) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: RltSpace.xs),
              Text(_busy!, key: const Key('plan_busy'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: RltSpace.m),
            ],
            if (plan == null) ..._empty(context) else ..._plan(context, plan),
          ]);
        },
      ),
    );
  }

  List<Widget> _empty(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget option(String key, IconData icon, String title, String subtitle, VoidCallback onTap) => Card(
          margin: const EdgeInsets.only(bottom: RltSpace.s),
          child: ListTile(
            key: Key(key),
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _busy == null ? onTap : null,
          ),
        );
    return [
      Text('Um dia-tipo com as refeições e o que comer em cada uma. Fica no celular; dá para registrar cada item no diário com um toque.',
          style: t.bodyMedium),
      const SizedBox(height: RltSpace.l),
      option('plan_import', Icons.upload_file_outlined, 'Importar do meu profissional',
          'Foto ou PDF do plano do nutricionista. A IA lê as refeições; você confere.', _import),
      option('plan_create', Icons.edit_note_outlined, 'Montar o meu', 'Você escreve as refeições e os itens.', () => _edit(null)),
      option('plan_ai', Icons.auto_awesome_outlined, 'Pedir sugestão à IA',
          'Um cardápio a partir das suas metas e preferências. É uma sugestão para você ajustar.', _suggest),
    ];
  }

  List<Widget> _plan(BuildContext context, MealPlan plan) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    return [
      Text(plan.name, key: const Key('plan_name'), style: t.titleLarge),
      const SizedBox(height: RltSpace.xs),
      Wrap(spacing: RltSpace.s, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Text(plan.source.label, style: t.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
        if (plan.kcal > 0) Text('~${formatNumber(plan.kcal)} kcal no dia', style: RltTheme.tabular(t.bodyMedium!)),
        if (plan.estimated) const RltBadge(RltBadgeKind.estimate),
      ]),
      if (plan.notes != null) ...[const SizedBox(height: RltSpace.s), Text(plan.notes!, style: t.bodyMedium)],
      if (plan.source == MealPlanSource.ai)
        Padding(
          padding: const EdgeInsets.only(top: RltSpace.s),
          child: Text(
            'Isto é uma sugestão, feita pela IA a partir das suas metas e preferências. Ajuste como quiser; um nutricionista pode orientar melhor.',
            key: const Key('plan_ai_disclaimer'),
            style: t.bodySmall,
          ),
        ),
      for (final type in planMealOrder)
        for (final meal in plan.mealsOf(type)) ...[
          RltSectionHeader('${mealTypeLabel(meal.mealType)}${meal.time == null ? '' : ' · ${meal.time}'}'),
          for (final item in meal.items)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(item.description),
              subtitle: item.kcal == null
                  ? null
                  : Text('${formatNumber(item.kcal!)} kcal'
                      '${item.proteinGrams == null ? '' : ' · P ${formatNumber(item.proteinGrams!)} g'}'
                      '${item.carbsGrams == null ? '' : ' · C ${formatNumber(item.carbsGrams!)} g'}'
                      '${item.fatGrams == null ? '' : ' · G ${formatNumber(item.fatGrams!)} g'}'),
              trailing: item.kcal == null || item.kcal! <= 0
                  ? null
                  : IconButton.filledTonal(
                      key: Key('plan_log_${meal.mealType.wireValue}_${meal.items.indexOf(item)}'),
                      tooltip: 'Registrar no diário',
                      onPressed: () => _log(meal, item),
                      icon: const Icon(Icons.add),
                    ),
            ),
        ],
      const SizedBox(height: RltSpace.l),
      Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
        OutlinedButton.icon(
          key: const Key('plan_edit'),
          onPressed: () => _edit(plan, source: plan.source),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Editar'),
        ),
        OutlinedButton.icon(
          key: const Key('plan_delete'),
          onPressed: () => _delete(plan),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Apagar'),
        ),
      ]),
      const SizedBox(height: RltSpace.l),
      const HealthDisclaimer(),
    ];
  }
}

/// Revisar/editar o plano antes de salvar (montado, importado ou sugerido).
class MealPlanEditScreen extends StatefulWidget {
  final AppDependencies deps;
  final MealPlan? initial;
  final MealPlanSource source;

  /// Foto/PDF do profissional ainda não guardado (só no "Salvar").
  final PickedDocument? newAttachment;
  const MealPlanEditScreen({super.key, required this.deps, this.initial, this.source = MealPlanSource.manual, this.newAttachment});

  @override
  State<MealPlanEditScreen> createState() => _MealPlanEditScreenState();
}

class _MealPlanEditScreenState extends State<MealPlanEditScreen> {
  late final _name = TextEditingController(
    text: widget.initial?.name ?? (widget.source == MealPlanSource.imported ? 'Plano do profissional' : 'Meu plano'),
  );
  late final _notes = TextEditingController(text: widget.initial?.notes ?? '');
  late final Map<MealType, List<MealPlanItem>> _items = {
    for (final t in planMealOrder) t: [for (final m in widget.initial?.mealsOf(t) ?? const <MealPlanMeal>[]) ...m.items],
  };
  late final Map<MealType, String?> _times = {
    for (final t in planMealOrder) t: widget.initial?.mealsOf(t).map((m) => m.time).whereType<String>().firstOrNull,
  };
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    final deps = widget.deps;
    String? stored;
    try {
      final previous = deps.mealPlans.load();
      final attachments = [...?widget.initial?.attachments];
      if (widget.newAttachment != null) {
        stored = (await deps.documentFiles.store(widget.newAttachment!)).storedName;
        attachments.add(stored);
      }
      final plan = MealPlan(
        name: _name.text,
        source: widget.source,
        createdAt: widget.initial?.createdAt ?? DateTime.now(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        estimated: widget.initial?.estimated ?? false,
        attachments: attachments,
        meals: [
          for (final t in planMealOrder)
            if (_items[t]!.isNotEmpty) MealPlanMeal(mealType: t, time: _times[t], items: _items[t]!),
        ],
      );
      deps.mealPlans.save(plan);
      // Plano trocado: o anexo do anterior sai (não fica arquivo sem dono).
      if (previous != null) {
        for (final a in previous.attachments) {
          if (!attachments.contains(a)) await deps.documentFiles.delete(a);
        }
      }
      deps.notifyDataChanged();
      if (!mounted) return;
      Navigator.of(context).pop();
      showRltSaved(context, 'Plano salvo em Nutrição › Dieta e metas › Plano de refeições.');
    } catch (e) {
      if (stored != null) await deps.documentFiles.delete(stored);
      if (mounted) {
        setState(() => _saving = false);
        showRltError(context, e);
      }
    }
  }

  Future<void> _editItem(MealType type, [int? index]) async {
    final item = await showDialog<MealPlanItem>(
      context: context,
      builder: (_) => _PlanItemDialog(initial: index == null ? null : _items[type]![index]),
    );
    if (item == null) return;
    setState(() => index == null ? _items[type]!.add(item) : _items[type]![index] = item);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fromAi = widget.initial?.estimated ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Novo plano' : 'Revisar plano'),
        actions: [TextButton(key: const Key('plan_save'), onPressed: _saving ? null : _save, child: const Text('Salvar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        if (fromAi)
          Padding(
            padding: const EdgeInsets.only(bottom: RltSpace.m),
            child: Row(children: [
              const RltBadge(RltBadgeKind.estimate),
              const SizedBox(width: RltSpace.s),
              Expanded(child: Text('Confira cada item antes de salvar. Calorias são estimativa.', style: t.bodySmall)),
            ]),
          ),
        if (widget.source == MealPlanSource.ai)
          Card(
            key: const Key('plan_edit_suggestion'),
            color: RltColors.of(context).tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(RltSpace.m),
              child: Text(
                'Sugestão da IA: um ponto de partida a partir das suas metas e preferências. Confira e ajuste antes de salvar.',
                style: t.bodyMedium?.copyWith(color: RltColors.of(context).onTertiaryContainer),
              ),
            ),
          ),
        if (widget.newAttachment != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.attach_file),
            title: Text(widget.newAttachment!.name),
            subtitle: const Text('Documento do profissional — fica guardado só no celular.'),
          ),
        TextField(key: const Key('plan_name_field'), controller: _name, decoration: const InputDecoration(labelText: 'Nome do plano')),
        for (final type in planMealOrder) ...[
          RltSectionHeader(
            mealTypeLabel(type),
            action: TextButton.icon(
              key: Key('plan_add_${type.wireValue}'),
              onPressed: () => _editItem(type),
              icon: const Icon(Icons.add),
              label: const Text('Item'),
            ),
          ),
          if (_items[type]!.isEmpty) Text('Nada nesta refeição.', style: t.bodySmall),
          for (var i = 0; i < _items[type]!.length; i++)
            ListTile(
              key: Key('plan_item_${type.wireValue}_$i'),
              contentPadding: EdgeInsets.zero,
              title: Text(_items[type]![i].description),
              subtitle: _items[type]![i].kcal == null ? null : Text('${formatNumber(_items[type]![i].kcal!)} kcal'),
              onTap: () => _editItem(type, i),
              trailing: IconButton(
                tooltip: 'Tirar item',
                onPressed: () => setState(() => _items[type]!.removeAt(i)),
                icon: const Icon(Icons.close),
              ),
            ),
        ],
        const SizedBox(height: RltSpace.l),
        TextField(controller: _notes, minLines: 2, maxLines: 5, decoration: const InputDecoration(labelText: 'Observações')),
      ]),
    );
  }
}

class _PlanItemDialog extends StatefulWidget {
  final MealPlanItem? initial;
  const _PlanItemDialog({this.initial});

  @override
  State<_PlanItemDialog> createState() => _PlanItemDialogState();
}

class _PlanItemDialogState extends State<_PlanItemDialog> {
  late final _desc = TextEditingController(text: widget.initial?.description ?? '');
  late final _kcal = TextEditingController(text: _fmt(widget.initial?.kcal));
  late final _p = TextEditingController(text: _fmt(widget.initial?.proteinGrams));
  late final _c = TextEditingController(text: _fmt(widget.initial?.carbsGrams));
  late final _f = TextEditingController(text: _fmt(widget.initial?.fatGrams));

  static String _fmt(double? v) => v == null ? '' : formatNumber(v);

  @override
  void dispose() {
    for (final c in [_desc, _kcal, _p, _c, _f]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => c.text.trim().isEmpty ? null : parseNumber(c.text);

  @override
  Widget build(BuildContext context) {
    const number = TextInputType.numberWithOptions(decimal: true);
    Widget field(Key key, TextEditingController c, String label) => Expanded(
          child: TextField(key: key, controller: c, keyboardType: number, decoration: InputDecoration(labelText: label)),
        );
    return AlertDialog(
      title: Text(widget.initial == null ? 'Novo item' : 'Editar item'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            key: const Key('plan_item_desc'),
            controller: _desc,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'O que comer (ex.: 2 ovos mexidos)'),
          ),
          Row(children: [field(const Key('plan_item_kcal'), _kcal, 'kcal (opcional)')]),
          Row(children: [
            field(const Key('plan_item_p'), _p, 'Proteína g'),
            const SizedBox(width: RltSpace.s),
            field(const Key('plan_item_c'), _c, 'Carbo g'),
            const SizedBox(width: RltSpace.s),
            field(const Key('plan_item_f'), _f, 'Gordura g'),
          ]),
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('plan_item_ok'),
          onPressed: () {
            if (_desc.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              MealPlanItem(description: _desc.text, kcal: _num(_kcal), proteinGrams: _num(_p), carbsGrams: _num(_c), fatGrams: _num(_f)),
            );
          },
          child: const Text('OK'),
        ),
      ],
    );
  }
}
