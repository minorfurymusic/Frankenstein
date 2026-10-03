import 'package:flutter/material.dart';

import '../../app_dependencies.dart';
import '../../data/health_read_model.dart';
import '../../format.dart';
import '../../theme/rlt_colors.dart';
import '../../theme/rlt_theme.dart';
import '../../wearables/health_connect.dart';
import '../../widgets/badges.dart';
import '../../widgets/state_views.dart';
import '../account/devices_screen.dart';

/// Meta de sono da prancheta Sono ("Meta 8 h").
// TODO(frankstein): meta de sono editável em Conta › Metas (hoje fixa no valor da prancheta).
const int kSleepGoalMinutes = 8 * 60;

String _hm(int minutes) => minutes >= 60 ? '${minutes ~/ 60} h ${two(minutes % 60)}' : '$minutes min';

/// Ordem e nome das fases (prancheta Sono).
const _stageOrder = ['deep', 'light', 'rem', 'awake'];
const _stageLabel = {'deep': 'Profundo', 'light': 'Leve', 'rem': 'REM', 'awake': 'Acordado', 'sleeping': 'Dormindo'};

Color _stageColor(RltColors c, String stage) => switch (stage) {
      'deep' => c.sleep,
      'light' => c.primaryContainer,
      'rem' => c.protein,
      'awake' => c.outline,
      _ => c.secondaryContainer,
    };

/// Sono (pranchetas Sono e SonoEstados): última noite com fases, últimos 7
/// dias contra a meta. Vem da pulseira, via Health Connect; ao abrir, lê o
/// que houver de novo (local, sem internet).
class SleepScreen extends StatefulWidget {
  final AppDependencies deps;
  const SleepScreen({super.key, required this.deps});

  @override
  State<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends State<SleepScreen> {
  WearableSyncOutcome? _outcome;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    if (widget.deps.wearables.enabled) _syncNow();
  }

  Future<void> _syncNow({bool connect = false}) async {
    setState(() => _syncing = true);
    final w = widget.deps.wearables;
    final outcome = connect ? await w.connect() : await w.syncNow();
    if (mounted) {
      setState(() {
        _syncing = false;
        _outcome = outcome;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sono')),
      body: ValueListenableBuilder<int>(
        valueListenable: widget.deps.dataVersion,
        builder: (context, _, _) {
          final nights = widget.deps.healthRead.sleeps(days: 14);
          return ListView(
            padding: const EdgeInsets.all(RltSpace.l),
            children: [
              ..._state(context, nights),
              if (nights.isNotEmpty) ...[
                _LastNight(night: nights.first),
                const SizedBox(height: RltSpace.l),
                _Week(nights: nights),
                const SizedBox(height: RltSpace.m),
                Text('Dados da pulseira, via Health Connect.', style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: RltSpace.l),
              const HealthDisclaimer(),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _state(BuildContext context, List<SleepView> nights) {
    final w = widget.deps.wearables;
    if (_syncing && nights.isEmpty) return const [LoadingCard()];
    switch (_outcome?.state) {
      case WearableSyncState.noPermission:
        return [
          StateCard(
            key: const Key('sleep_no_permission'),
            icon: Icons.lock_outline,
            title: 'Sem permissão para ler o sono',
            message: 'A pulseira está conectada, mas o RLT ainda não pode ler os dados de sono no Health Connect.',
            tone: StateTone.permission,
            actionLabel: 'Permitir leitura do sono',
            onAction: () => _syncNow(connect: true),
          ),
          const SizedBox(height: RltSpace.l),
        ];
      case WearableSyncState.error:
        return [
          StateCard(
            key: const Key('sleep_error'),
            icon: Icons.sync_problem,
            title: 'Não foi possível sincronizar o sono',
            message: 'O Health Connect não respondeu. Tente de novo em instantes.',
            actionLabel: 'Tentar de novo',
            onAction: _syncNow,
          ),
          const SizedBox(height: RltSpace.l),
        ];
      default:
        break;
    }
    if (nights.isNotEmpty) return const [];
    if (!w.enabled) {
      return [
        StateCard(
          key: const Key('sleep_connect'),
          icon: Icons.bedtime_outlined,
          title: 'Conecte uma pulseira para ver o sono',
          message: 'O sono vem de pulseiras e relógios pelo Health Connect do Android. Sem eles, esta tela fica vazia.',
          tone: StateTone.permission,
          actionLabel: 'Conectar dispositivo',
          onAction: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DevicesScreen(deps: widget.deps))),
        ),
      ];
    }
    return const [
      StateCard(
        key: Key('sleep_empty'),
        icon: Icons.bedtime_outlined,
        title: 'Nenhuma noite registrada ainda',
        message: 'Durma com a pulseira. A primeira noite aparece aqui depois da sincronização.',
      ),
    ];
  }
}

class _LastNight extends StatelessWidget {
  final SleepView night;
  const _LastNight({required this.night});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final s = night.startLocal;
    final e = night.endLocal;
    final title = DateTime(s.year, s.month, s.day) == DateTime(e.year, e.month, e.day)
        ? 'Noite de ${s.day} de ${monthShort(s.month)}'
        : 'Noite de ${s.day} para ${e.day} de ${monthShort(e.month)}';
    final hasStages = night.stageMinutes.keys.any(_stageOrder.contains);
    final total = night.minutes == 0 ? 1 : night.minutes;
    return Card(
      key: const Key('sleep_last_night'),
      child: Padding(
        padding: const EdgeInsets.all(RltSpace.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: t.titleMedium),
          const SizedBox(height: RltSpace.m),
          Text('Dormiu', style: t.labelMedium?.copyWith(color: c.onSurfaceVariant)),
          Text(
            '${night.asleepMinutes ~/ 60} h ${two(night.asleepMinutes % 60)} min',
            key: const Key('sleep_asleep'),
            style: RltTheme.tabular(t.headlineMedium!),
          ),
          const SizedBox(height: RltSpace.s),
          Row(children: [
            Expanded(child: _Fact(label: 'Deitou', value: hhmm(s))),
            Expanded(child: _Fact(label: 'Acordou', value: hhmm(e))),
            Expanded(child: _Fact(label: 'Na cama', value: _hm(night.minutes))),
          ]),
          if (hasStages) ...[
            const SizedBox(height: RltSpace.l),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 28,
                child: night.stages.isEmpty
                    ? const SizedBox.shrink()
                    : Row(children: [
                        for (final st in night.stages)
                          if (st.endLocal.difference(st.startLocal).inMinutes > 0)
                            Expanded(
                              flex: st.endLocal.difference(st.startLocal).inMinutes,
                              child: Container(color: _stageColor(c, st.stage)),
                            ),
                      ]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(children: [
                Text(hhmm(s), style: t.labelSmall),
                const Spacer(),
                Text(hhmm(e), style: t.labelSmall),
              ]),
            ),
            const SizedBox(height: RltSpace.s),
            for (final key in _stageOrder)
              if (night.stageMinutes[key] != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(color: _stageColor(c, key), borderRadius: BorderRadius.circular(3)),
                    ),
                    const SizedBox(width: RltSpace.s),
                    Expanded(child: Text(_stageLabel[key]!, style: t.bodyMedium)),
                    Text(_hm(night.stageMinutes[key]!), style: RltTheme.tabular(t.bodyMedium!)),
                    SizedBox(
                      width: 48,
                      child: Text(
                        '${(night.stageMinutes[key]! * 100 / total).round()}%',
                        textAlign: TextAlign.end,
                        style: t.bodySmall?.copyWith(color: c.onSurfaceVariant),
                      ),
                    ),
                  ]),
                ),
          ] else ...[
            const SizedBox(height: RltSpace.m),
            Text('A pulseira não informou as fases desta noite.', style: t.bodySmall),
          ],
        ]),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;
  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: t.labelMedium?.copyWith(color: RltColors.of(context).onSurfaceVariant)),
      Text(value, style: RltTheme.tabular(t.titleMedium!)),
    ]);
  }
}

class _Week extends StatelessWidget {
  final List<SleepView> nights;
  const _Week({required this.nights});

  @override
  Widget build(BuildContext context) {
    final c = RltColors.of(context);
    final t = Theme.of(context).textTheme;
    final today = DateTime.now();
    // Cada noite conta no dia em que a pessoa acordou.
    final byDay = <DateTime, int>{};
    for (final n in nights) {
      final d = DateTime(n.endLocal.year, n.endLocal.month, n.endLocal.day);
      byDay[d] = (byDay[d] ?? 0) + n.asleepMinutes;
    }
    final days = [for (var i = 6; i >= 0; i--) DateTime(today.year, today.month, today.day).subtract(Duration(days: i))];
    final maxMinutes = [kSleepGoalMinutes, ...byDay.values].reduce((a, b) => a > b ? a : b);
    const chartHeight = 120.0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(RltSpace.l),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Últimos 7 dias', style: t.titleMedium)),
            Text('Meta ${kSleepGoalMinutes ~/ 60} h', style: t.bodySmall?.copyWith(color: c.onSurfaceVariant)),
          ]),
          const SizedBox(height: RltSpace.m),
          SizedBox(
            height: chartHeight + 20,
            child: Stack(children: [
              Positioned(
                left: 0,
                right: 0,
                top: chartHeight * (1 - kSleepGoalMinutes / maxMinutes),
                child: Container(height: 1, color: c.outline),
              ),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                for (final d in days)
                  Expanded(
                    child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        height: chartHeight * (byDay[d] ?? 0) / maxMinutes,
                        decoration: BoxDecoration(color: c.sleep, borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(height: 4),
                      Text(weekdayInitial(d), style: t.labelSmall),
                    ]),
                  ),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}
