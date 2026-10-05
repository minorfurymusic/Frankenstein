// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import 'barcode_scanner_screen.dart';
import 'food_detail_screen.dart';
import 'meal_labels.dart';
import 'plate_photo_screen.dart';

/// Adicionar alimento (prancheta AdicionarAlimento; `docs/specs/nutricao.md`,
/// tela 2): busca por nome, código de barras, adição rápida, foto do prato,
/// e recentes/favoritos/meus itens para adicionar com um toque.
class AddFoodScreen extends StatefulWidget {
  final AppDependencies deps;
  final MealType? mealType;
  final DateTime? day;
  const AddFoodScreen({super.key, required this.deps, this.mealType, this.day});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _query = TextEditingController();
  List<Food> _results = const [];

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String q) {
    setState(() => _results = q.trim().length < 2 ? const [] : widget.deps.foodRepository.searchByName(q.trim(), limit: 30));
  }

  void _open(Food food, {MealItemInputMethod method = MealItemInputMethod.search}) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FoodDetailScreen(deps: widget.deps, food: food, mealType: widget.mealType, inputMethod: method, day: widget.day),
    ));
  }

  static Future<String?> _typeBarcode(BuildContext context) =>
      showDialog<String>(context: context, builder: (_) => const _BarcodeDialog());

  Future<void> _barcode() async {
    final Future<String?> reading = barcodeCameraAvailable
        ? Navigator.of(context).push<String>(MaterialPageRoute(
            builder: (_) => const BarcodeScannerScreen(typeManually: _typeBarcode),
          ))
        : _typeBarcode(context);
    final code = await reading;
    if (code == null || !mounted) return;
    final food = widget.deps.foodRepository.findByBarcode(code);
    if (food != null) {
      _open(food, method: MealItemInputMethod.barcode);
      return;
    }
    final created = await Navigator.of(context).push<Food>(MaterialPageRoute(
      builder: (_) => QuickAddScreen(deps: widget.deps, barcode: code, mealType: widget.mealType, day: widget.day),
    ));
    if (created != null && mounted) _open(created, method: MealItemInputMethod.barcode);
  }

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final store = widget.deps.nutrition;
    final title = widget.mealType == null ? 'Adicionar alimento' : 'Adicionar ao ${mealTypeLabel(widget.mealType!).toLowerCase()}';
    Widget action(String key, IconData icon, String label, VoidCallback onTap) => Expanded(
          child: Material(
            color: c.secondaryContainer,
            borderRadius: BorderRadius.circular(RltRadius.card),
            child: InkWell(
              key: Key(key),
              borderRadius: BorderRadius.circular(RltRadius.card),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: RltSpace.m, horizontal: RltSpace.s),
                child: Column(children: [
                  Icon(icon, color: c.onSecondaryContainer),
                  const SizedBox(height: 4),
                  Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: c.onSecondaryContainer)),
                ]),
              ),
            ),
          ),
        );

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, RltSpace.m),
            child: Column(children: [
              TextField(
                key: const Key('food_search'),
                controller: _query,
                onChanged: _search,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  labelText: 'Buscar alimento',
                  hintText: 'Ex.: arroz, banana, pão de queijo',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
              const SizedBox(height: RltSpace.m),
              Row(children: [
                action('add_barcode', Icons.qr_code_scanner, 'Código de barras', _barcode),
                const SizedBox(width: RltSpace.s),
                action('add_quick', Icons.bolt, 'Adição rápida', () async {
                  final created = await Navigator.of(context).push<Food>(MaterialPageRoute(
                    builder: (_) => QuickAddScreen(deps: widget.deps, mealType: widget.mealType, day: widget.day),
                  ));
                  if (created != null && mounted) _open(created, method: MealItemInputMethod.quickAdd);
                }),
                const SizedBox(width: RltSpace.s),
                action('add_photo', Icons.photo_camera_outlined, 'Foto do prato', () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PlatePhotoScreen(deps: widget.deps, mealType: widget.mealType, day: widget.day),
                  ));
                }),
              ]),
            ]),
          ),
          if (_results.isNotEmpty || _query.text.trim().length >= 2)
            Expanded(
              child: _results.isEmpty
                  ? const Center(child: Text('Nada encontrado. Tente outro nome ou use a adição rápida.'))
                  : _FoodList(foods: _results, deps: widget.deps, onOpen: _open, keyPrefix: 'result'),
            )
          else ...[
            const TabBar(tabs: [Tab(text: 'Recentes'), Tab(text: 'Favoritos'), Tab(text: 'Meus itens')]),
            Expanded(
              child: TabBarView(children: [
                _FoodList(foods: store.recentFoods(), deps: widget.deps, onOpen: _open, keyPrefix: 'recent', empty: 'O que você registrar aparece aqui.'),
                _FoodList(foods: store.favoriteFoods(), deps: widget.deps, onOpen: _open, keyPrefix: 'fav', empty: 'Toque na estrela para favoritar.'),
                _FoodList(foods: store.myItems(), deps: widget.deps, onOpen: _open, keyPrefix: 'mine', empty: 'Itens de adição rápida e receitas próprias.'),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _FoodList extends StatefulWidget {
  final List<Food> foods;
  final AppDependencies deps;
  final void Function(Food) onOpen;
  final String keyPrefix;
  final String? empty;
  const _FoodList({required this.foods, required this.deps, required this.onOpen, required this.keyPrefix, this.empty});

  @override
  State<_FoodList> createState() => _FoodListState();
}

class _FoodListState extends State<_FoodList> {
  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    if (widget.foods.isEmpty) {
      return Center(child: Padding(padding: const EdgeInsets.all(RltSpace.xl), child: Text(widget.empty ?? '', style: t.bodyMedium)));
    }
    final store = widget.deps.nutrition;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: RltSpace.l),
      itemCount: widget.foods.length,
      itemBuilder: (context, i) {
        final f = widget.foods[i];
        final fav = store.isFavorite(f.id);
        return ListTile(
          key: Key('${widget.keyPrefix}_$i'),
          contentPadding: EdgeInsets.zero,
          title: Text(f.name),
          subtitle: Text('100 g · ${formatNumber(f.energyKcalPer100g)} kcal', style: RltTheme.tabular(t.bodyMedium!)),
          onTap: () => widget.onOpen(f),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              tooltip: fav ? 'Tirar dos favoritos' : 'Favoritar',
              onPressed: () => setState(() => store.toggleFavorite(f.id)),
              icon: Icon(fav ? Icons.star : Icons.star_border, color: fav ? c.tertiary : c.onSurfaceVariant),
            ),
            IconButton.filledTonal(tooltip: 'Adicionar ${f.name}', onPressed: () => widget.onOpen(f), icon: const Icon(Icons.add)),
          ]),
        );
      },
    );
  }
}

class _BarcodeDialog extends StatefulWidget {
  const _BarcodeDialog();
  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _code = TextEditingController();
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Código de barras'),
      content: TextField(
        key: const Key('barcode_input'),
        controller: _code,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Digite os números do código', helperText: 'Os números embaixo das barras (8 a 14).'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('barcode_ok'),
          onPressed: () {
            final v = normalizeBarcode(_code.text);
            if (v != null) Navigator.pop(context, v);
          },
          child: const Text('Buscar'),
        ),
      ],
    );
  }
}

/// Adição rápida (`docs/specs/nutricao.md`, "Adição rápida"): nome + kcal,
/// macros opcionais. Com [barcode], vira o item daquele código (valores por
/// 100 g, como no rótulo). Devolve o alimento criado para a tela de detalhe.
class QuickAddScreen extends StatefulWidget {
  final AppDependencies deps;
  final String? barcode;
  final MealType? mealType;
  final DateTime? day;
  const QuickAddScreen({super.key, required this.deps, this.barcode, this.mealType, this.day});

  @override
  State<QuickAddScreen> createState() => _QuickAddScreenState();
}

class _QuickAddScreenState extends State<QuickAddScreen> {
  final _name = TextEditingController();
  final _kcal = TextEditingController();
  final _p = TextEditingController();
  final _c = TextEditingController();
  final _f = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _kcal, _p, _c, _f]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final kcal = parseNumber(_kcal.text);
    if (kcal == null) {
      showRltError(context, ArgumentError('informe as calorias em número'));
      return;
    }
    double opt(TextEditingController c) => parseNumber(c.text) ?? 0;
    try {
      final store = widget.deps.nutrition;
      final food = widget.barcode == null
          ? store.createQuickItem(name: _name.text, kcal: kcal, protein: opt(_p), carbs: opt(_c), fat: opt(_f))
          : store.createBarcodeItem(
              barcode: widget.barcode!,
              name: _name.text,
              kcalPer100g: kcal,
              proteinPer100g: opt(_p),
              carbsPer100g: opt(_c),
              fatPer100g: opt(_f),
            );
      Navigator.of(context).pop(food);
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const numeric = TextInputType.numberWithOptions(decimal: true);
    final perLabel = widget.barcode == null ? 'por porção' : 'por 100 g (rótulo)';
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.barcode == null ? 'Adição rápida' : 'Novo item'),
        actions: [TextButton(key: const Key('quick_save'), onPressed: _save, child: const Text('Continuar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        if (widget.barcode != null) ...[
          Text('O código ${widget.barcode} não está no catálogo. Copie os valores do rótulo — o item fica salvo para a próxima vez.',
              style: t.bodyMedium),
          const SizedBox(height: RltSpace.l),
        ],
        TextField(key: const Key('quick_name'), controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome')),
        const SizedBox(height: RltSpace.m),
        TextField(
          key: const Key('quick_kcal'),
          controller: _kcal,
          keyboardType: numeric,
          decoration: InputDecoration(labelText: 'Calorias $perLabel', suffixText: 'kcal'),
        ),
        const RltSectionHeader('Macros (opcional)'),
        Row(children: [
          Expanded(child: TextField(controller: _p, keyboardType: numeric, decoration: const InputDecoration(labelText: 'Proteína', suffixText: 'g'))),
          const SizedBox(width: RltSpace.s),
          Expanded(child: TextField(controller: _c, keyboardType: numeric, decoration: const InputDecoration(labelText: 'Carbo', suffixText: 'g'))),
          const SizedBox(width: RltSpace.s),
          Expanded(child: TextField(controller: _f, keyboardType: numeric, decoration: const InputDecoration(labelText: 'Gordura', suffixText: 'g'))),
        ]),
      ]),
    );
  }
}
