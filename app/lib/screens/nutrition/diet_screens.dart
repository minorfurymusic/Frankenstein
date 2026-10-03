// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'package:flutter/material.dart';
import 'package:frankstein_nutrition/nutrition.dart';

import '../../app_dependencies.dart';
import '../../data/nutrition_store.dart';
import '../../format.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/state_views.dart';
import '../account/goals_screen.dart';
import 'food_detail_screen.dart';

/// Dieta e metas (prancheta DietaMetas): atalho para as metas calculadas e
/// as preferências/restrições de dieta.
class DietAndGoalsScreen extends StatefulWidget {
  final AppDependencies deps;
  const DietAndGoalsScreen({super.key, required this.deps});

  @override
  State<DietAndGoalsScreen> createState() => _DietAndGoalsScreenState();
}

class _DietAndGoalsScreenState extends State<DietAndGoalsScreen> {
  late Set<String> _tags;
  late final TextEditingController _allergies;
  late final TextEditingController _dislikes;

  @override
  void initState() {
    super.initState();
    final p = widget.deps.nutrition.dietPreferences();
    _tags = {...p.tags};
    _allergies = TextEditingController(text: p.allergies);
    _dislikes = TextEditingController(text: p.dislikes);
  }

  @override
  void dispose() {
    _allergies.dispose();
    _dislikes.dispose();
    super.dispose();
  }

  void _save() {
    widget.deps.nutrition.saveDietPreferences(
      DietPreferences(tags: _tags, allergies: _allergies.text.trim(), dislikes: _dislikes.text.trim()),
    );
    Navigator.of(context).pop();
    showRltSaved(context, 'Preferências de dieta salvas.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final goals = widget.deps.goals.goalsFor(DateTime.now());
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dieta e metas'),
        actions: [TextButton(key: const Key('diet_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Meta de hoje', style: t.titleSmall),
          subtitle: Text(goals == null
              ? 'Preencha o perfil para calcular'
              : '${formatNumber(goals.caloriesKcal)} kcal · P ${formatNumber(goals.proteinGrams)} g · '
                  'C ${formatNumber(goals.carbsGrams)} g · G ${formatNumber(goals.fatGrams)} g · fibra ${formatNumber(goals.fiberGrams)} g'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GoalsScreen(deps: widget.deps))),
        ),
        // TODO(frankstein): plano de refeições (opcional no prompt do design) — sem especificação ainda.
        const RltSectionHeader('Preferências e restrições'),
        Wrap(spacing: RltSpace.s, runSpacing: RltSpace.s, children: [
          for (final e in DietPreferences.labels.entries)
            FilterChip(
              key: Key('diet_${e.key}'),
              label: Text(e.value),
              selected: _tags.contains(e.key),
              onSelected: (v) => setState(() => v ? _tags.add(e.key) : _tags.remove(e.key)),
            ),
        ]),
        const SizedBox(height: RltSpace.l),
        TextField(controller: _allergies, decoration: const InputDecoration(labelText: 'Alergias alimentares')),
        const SizedBox(height: RltSpace.m),
        TextField(controller: _dislikes, decoration: const InputDecoration(labelText: 'Alimentos que não gosta')),
        const SizedBox(height: RltSpace.s),
        Text('Ficam só no seu celular. Servem de contexto para o Cérebro; nada é escondido por causa delas.', style: t.bodySmall),
      ]),
    );
  }
}

/// Receitas e refeições próprias (prancheta ReceitasProprias;
/// `docs/specs/nutricao.md`, "Refeição/receita personalizada").
class RecipesScreen extends StatelessWidget {
  final AppDependencies deps;
  const RecipesScreen({super.key, required this.deps});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Receitas próprias')),
      floatingActionButton: FloatingActionButton.extended(
        key: const Key('recipe_new'),
        onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RecipeFormScreen(deps: deps))),
        icon: const Icon(Icons.add),
        label: const Text('Nova receita'),
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: deps.dataVersion,
        builder: (context, _, _) {
          final recipes = deps.nutrition.recipes();
          if (recipes.isEmpty) {
            return ListView(padding: const EdgeInsets.all(RltSpace.l), children: const [
              StateCard(
                icon: Icons.menu_book_outlined,
                title: 'Nenhuma receita ainda',
                message: 'Monte com os ingredientes uma vez e registre com um toque depois.',
              ),
            ]);
          }
          return ListView(padding: const EdgeInsets.fromLTRB(RltSpace.l, RltSpace.s, RltSpace.l, 96), children: [
            for (final r in recipes)
              Builder(builder: (context) {
                final food = deps.foodRepository.findById(r.foodId);
                final perServing = food == null ? 0 : food.energyKcalPer100g * r.servingGrams / 100;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r.name, style: t.bodyLarge),
                  subtitle: Text('${r.ingredients.length} ingredientes · ${r.servings} '
                      '${r.servings == 1 ? 'porção' : 'porções'} de ${formatNumber(r.servingGrams)} g · '
                      '${formatNumber(perServing)} kcal por porção'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: food == null
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => FoodDetailScreen(deps: deps, food: food))),
                );
              }),
          ]);
        },
      ),
    );
  }
}

class RecipeFormScreen extends StatefulWidget {
  final AppDependencies deps;
  const RecipeFormScreen({super.key, required this.deps});

  @override
  State<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _RecipeFormScreenState extends State<RecipeFormScreen> {
  final _name = TextEditingController();
  final _servings = TextEditingController(text: '1');
  final _search = TextEditingController();
  final _ingredients = <(Food, double)>[];
  List<Food> _results = const [];

  @override
  void dispose() {
    _name.dispose();
    _servings.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _addIngredient(Food f) async {
    final grams = await showDialog<double>(context: context, builder: (_) => _GramsDialog(food: f));
    if (grams == null) return;
    setState(() {
      _ingredients.add((f, grams));
      _results = const [];
      _search.clear();
    });
  }

  void _save() {
    try {
      widget.deps.nutrition.createRecipe(
        name: _name.text,
        servings: (parseNumber(_servings.text) ?? 1).round(),
        ingredients: [for (final (f, g) in _ingredients) RecipeIngredient(f.id, g)],
      );
      widget.deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, 'Receita salva em Nutrição › Receitas próprias.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final totalKcal = _ingredients.fold<double>(0, (s, i) => s + i.$1.energyKcalPer100g * i.$2 / 100);
    final totalGrams = _ingredients.fold<double>(0, (s, i) => s + i.$2);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova receita'),
        actions: [TextButton(key: const Key('recipe_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(padding: const EdgeInsets.all(RltSpace.l), children: [
        TextField(key: const Key('recipe_name'), controller: _name, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Nome da receita')),
        const SizedBox(height: RltSpace.m),
        TextField(controller: _servings, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Rende quantas porções')),
        const RltSectionHeader('Ingredientes'),
        for (var i = 0; i < _ingredients.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(_ingredients[i].$1.name),
            subtitle: Text('${formatNumber(_ingredients[i].$2)} g · '
                '${formatNumber(_ingredients[i].$1.energyKcalPer100g * _ingredients[i].$2 / 100)} kcal'),
            trailing: IconButton(
              tooltip: 'Remover',
              onPressed: () => setState(() => _ingredients.removeAt(i)),
              icon: const Icon(Icons.close),
            ),
          ),
        if (_ingredients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: RltSpace.s),
            child: Text('Total: ${formatNumber(totalGrams)} g · ${formatNumber(totalKcal)} kcal', style: RltTheme.tabular(t.titleSmall!)),
          ),
        TextField(
          key: const Key('recipe_search'),
          controller: _search,
          decoration: const InputDecoration(labelText: 'Buscar ingrediente', prefixIcon: Icon(Icons.search)),
          onChanged: (q) => setState(() => _results = q.trim().length < 2 ? const [] : widget.deps.foodRepository.searchByName(q.trim(), limit: 10)),
        ),
        for (var i = 0; i < _results.length; i++)
          ListTile(
            key: Key('recipe_result_$i'),
            contentPadding: EdgeInsets.zero,
            title: Text(_results[i].name),
            subtitle: Text('${formatNumber(_results[i].energyKcalPer100g)} kcal por 100 g'),
            trailing: const Icon(Icons.add),
            onTap: () => _addIngredient(_results[i]),
          ),
        // TODO(frankstein): foto da receita (câmera, etapa de integrações).
      ]),
    );
  }
}

class _GramsDialog extends StatefulWidget {
  final Food food;
  const _GramsDialog({required this.food});
  @override
  State<_GramsDialog> createState() => _GramsDialogState();
}

class _GramsDialogState extends State<_GramsDialog> {
  final _g = TextEditingController(text: '100');
  @override
  void dispose() {
    _g.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.food.name),
      content: TextField(
        key: const Key('grams_input'),
        controller: _g,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Quantidade', suffixText: 'g'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(
          key: const Key('grams_ok'),
          onPressed: () {
            final v = parseNumber(_g.text);
            if (v != null && v > 0) Navigator.pop(context, v);
          },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}
