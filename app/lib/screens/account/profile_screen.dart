import 'package:flutter/material.dart';
import 'package:frankstein_profile/profile.dart';

import '../../app_dependencies.dart';
import '../../format.dart';
import '../../theme/rlt_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/progress.dart';

/// Conta › Perfil (prancheta ContaPerfil): os dados que entram nas fórmulas
/// (ADR-15). Peso e % de gordura viram registros em Saúde › Corpo — a
/// medida mais recente é a que o cálculo usa.
class ProfileScreen extends StatefulWidget {
  final AppDependencies deps;
  const ProfileScreen({super.key, required this.deps});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  BiologicalSex? _sex;
  DateTime? _birth;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _fat = TextEditingController();
  final _rate = TextEditingController();
  final _steps = TextEditingController();
  Objective _objective = Objective.maintain;
  double? _savedWeight;
  double? _savedFat;

  @override
  void initState() {
    super.initState();
    final p = widget.deps.profileRepository.load();
    final w = widget.deps.healthRead.weights();
    final f = widget.deps.healthRead.measurements('body_fat');
    _savedWeight = w.isEmpty ? null : w.first.value;
    _savedFat = f.isEmpty ? null : f.first.value;
    _sex = p?.sex;
    _birth = p?.birthDate;
    _height.text = p == null ? '' : (p.heightMeters * 100).round().toString();
    _weight.text = _savedWeight == null ? '' : formatNumber(_savedWeight!, decimals: 1);
    _fat.text = _savedFat == null ? '' : formatNumber(_savedFat!, decimals: 0);
    _objective = p?.objective ?? Objective.maintain;
    _rate.text = p == null || p.rateGramsPerDay == 0 ? '50' : p.rateGramsPerDay.round().toString();
    _steps.text = (p?.stepsGoal ?? 8000).toString();
  }

  @override
  void dispose() {
    for (final c in [_height, _weight, _fat, _rate, _steps]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) => parseNumber(c.text);

  void _save() {
    final height = _num(_height);
    final weight = _num(_weight);
    final fat = _fat.text.trim().isEmpty ? null : _num(_fat);
    final rate = _objective == Objective.maintain ? 0.0 : _num(_rate);
    final steps = _num(_steps)?.round();
    final missing = [
      if (_sex == null) 'sexo biológico',
      if (_birth == null) 'data de nascimento',
      if (height == null) 'altura',
      if (weight == null) 'peso',
      if (rate == null) 'ritmo',
      if (steps == null) 'meta de passos',
    ];
    if (missing.isNotEmpty) {
      showRltError(context, ArgumentError('falta ${missing.join(', ')}'));
      return;
    }
    final deps = widget.deps;
    try {
      final profile = Profile(
        sex: _sex!,
        birthDate: _birth!,
        heightMeters: height! / 100,
        objective: _objective,
        rateGramsPerDay: rate!,
        stepsGoal: steps!,
      );
      final at = DateTime.now().toUtc();
      final tz = deps.tzOffsetMinutesNow();
      // Peso e gordura só viram registro novo quando mudam.
      if (_savedWeight == null || (weight! - _savedWeight!).abs() > 0.05) {
        deps.bodyLogger.weight(kg: weight!, occurredAt: at, occurredAtTzOffsetMinutes: tz);
      }
      if (fat != null && (_savedFat == null || (fat - _savedFat!).abs() > 0.05)) {
        deps.bodyLogger.bodyFat(percent: fat, occurredAt: at, occurredAtTzOffsetMinutes: tz);
      }
      deps.profileRepository.save(profile);
      deps.notifyDataChanged();
      Navigator.of(context).pop();
      showRltSaved(context, 'Perfil salvo. As metas foram recalculadas.');
    } catch (e) {
      showRltError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const numeric = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [TextButton(key: const Key('profile_save'), onPressed: _save, child: const Text('Salvar'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(RltSpace.l),
        children: [
          Text('Esses dados entram nas fórmulas das suas metas e ficam só no seu celular.', style: t.bodyMedium),
          const RltSectionHeader('Sexo biológico'),
          Text('Usado nas fórmulas de gasto calórico e de água — não é identidade de gênero.', style: t.bodySmall),
          const SizedBox(height: RltSpace.s),
          SegmentedButton<BiologicalSex>(
            key: const Key('profile_sex'),
            emptySelectionAllowed: true,
            segments: const [
              ButtonSegment(value: BiologicalSex.female, label: Text('Feminino')),
              ButtonSegment(value: BiologicalSex.male, label: Text('Masculino')),
            ],
            selected: {?_sex},
            onSelectionChanged: (s) => setState(() => _sex = s.isEmpty ? null : s.first),
          ),
          const SizedBox(height: RltSpace.l),
          InkWell(
            key: const Key('profile_birth'),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _birth ?? DateTime(1990),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => _birth = d);
            },
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'Data de nascimento', suffixIcon: Icon(Icons.calendar_today_outlined)),
              child: Text(_birth == null ? 'Escolher' : ddmmyyyy(_birth!)),
            ),
          ),
          const SizedBox(height: RltSpace.m),
          Row(children: [
            Expanded(
              child: TextField(
                key: const Key('profile_height'),
                controller: _height,
                keyboardType: numeric,
                decoration: const InputDecoration(labelText: 'Altura', suffixText: 'cm'),
              ),
            ),
            const SizedBox(width: RltSpace.m),
            Expanded(
              child: TextField(
                key: const Key('profile_weight'),
                controller: _weight,
                keyboardType: numeric,
                decoration: const InputDecoration(labelText: 'Peso', suffixText: 'kg'),
              ),
            ),
          ]),
          const SizedBox(height: RltSpace.m),
          TextField(
            controller: _fat,
            keyboardType: numeric,
            decoration: const InputDecoration(
              labelText: '% de gordura (opcional)',
              suffixText: '%',
              helperText: 'Com ele, o gasto em repouso usa Katch-McArdle; sem ele, Mifflin-St Jeor.',
            ),
          ),
          const RltSectionHeader('Objetivo'),
          SegmentedButton<Objective>(
            key: const Key('profile_objective'),
            segments: const [
              ButtonSegment(value: Objective.lose, label: Text('Perder')),
              ButtonSegment(value: Objective.maintain, label: Text('Manter')),
              ButtonSegment(value: Objective.gain, label: Text('Ganhar')),
            ],
            selected: {_objective},
            onSelectionChanged: (s) => setState(() => _objective = s.first),
          ),
          if (_objective != Objective.maintain) ...[
            const SizedBox(height: RltSpace.m),
            TextField(
              key: const Key('profile_rate'),
              controller: _rate,
              keyboardType: numeric,
              decoration: InputDecoration(
                labelText: _objective == Objective.lose ? 'Quanto perder por dia' : 'Quanto ganhar por dia',
                suffixText: 'g/dia',
                helperText: 'Cada 50 g por dia ≈ 385 kcal (7.700 kcal por kg).',
              ),
            ),
          ],
          const SizedBox(height: RltSpace.m),
          TextField(
            controller: _steps,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Meta de passos por dia', suffixText: 'passos'),
          ),
          const SizedBox(height: RltSpace.xl),
        ],
      ),
    );
  }
}
