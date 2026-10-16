import 'dart:async';

import 'package:frankstein_health_core/health_core.dart';

import 'step_sensor.dart';
import 'steps_sample.dart';

/// Agrega leituras cumulativas de [StepSensor] em [HealthEvent]s do tipo
/// `steps`, gravados no Health Data Core (`.claude/rules/datacore.md`).
///
/// Lida com a semântica de contador cumulativo do sensor real: a
/// primeira leitura vira linha de base (nenhum evento ainda — não temos
/// como saber quantos desses passos aconteceram antes do app começar a
/// observar); leituras seguintes acumulam delta desde a linha de base;
/// se uma leitura vier **menor** que a anterior, o aparelho reiniciou —
/// o delta pendente até ali é gravado como evento antes de recomeçar a
/// linha de base do zero.
///
/// Não decide **quando** persistir (isso é política de app/foreground
/// service, fora daqui) — só oferece [recordSample] (chamado a cada
/// leitura) e [flush] (grava o delta acumulado como evento e reinicia a
/// janela). Nenhuma leitura crua é perdida por não ter sido "commitada"
/// ainda: [pendingDelta] deixa isso inspecionável.
/// Último ponto já gravado do contador cumulativo — guardado fora da
/// memória para que os passos dados com o app fechado (o sensor do
/// Android continua somando) entrem na volta, em vez de virarem a nova
/// linha de base.
class StepsCheckpoint {
  final int cumulative;
  final DateTime windowStartUtc;
  const StepsCheckpoint(this.cumulative, this.windowStartUtc);

  Map<String, dynamic> toJson() => {'cumulative': cumulative, 'window_start': windowStartUtc.toIso8601String()};

  static StepsCheckpoint? fromJson(Map<String, dynamic> j) {
    final c = j['cumulative'];
    final w = DateTime.tryParse(j['window_start']?.toString() ?? '');
    if (c is! int || w == null) return null;
    return StepsCheckpoint(c, w.toUtc());
  }
}

class StepsRepository {
  final HealthDataCore core;
  final String deviceId;

  /// Lê/grava o [StepsCheckpoint] (opcional; sem isso, a primeira
  /// leitura de cada sessão vira linha de base, como antes).
  final StepsCheckpoint? Function()? loadCheckpoint;
  final void Function(StepsCheckpoint)? saveCheckpoint;

  int? _baseline;
  int? _lastSeen;
  DateTime? _windowStart;

  StepsRepository({required this.core, required this.deviceId, this.loadCheckpoint, this.saveCheckpoint});

  /// Liga este repositório a uma fonte de leituras — cada [StepsSample]
  /// emitida vira uma chamada a [recordSample]. Não decide quando
  /// [flush]; quem chama continua responsável por isso (a política de
  /// "quando persistir" é do app/foreground service, documentado na
  /// classe). Cancele a subscription retornada para parar de ouvir.
  StreamSubscription<StepsSample> attachSensor(StepSensor sensor) {
    return sensor.readings.listen(recordSample);
  }

  /// Delta acumulado desde o último [flush], ainda não gravado.
  int get pendingDelta {
    if (_baseline == null || _lastSeen == null) return 0;
    return _lastSeen! - _baseline!;
  }

  void recordSample(StepsSample sample) {
    if (sample.deviceId != deviceId) {
      throw ArgumentError(
          'StepsSample de outro aparelho (${sample.deviceId}) — este repositório é do aparelho $deviceId');
    }
    if (_baseline == null) {
      final saved = loadCheckpoint?.call();
      if (saved != null && sample.cumulativeSteps >= saved.cumulative && !saved.windowStartUtc.isAfter(sample.timestampUtc)) {
        // Mesmo boot do aparelho: o que andou com o app fechado conta.
        _baseline = saved.cumulative;
        _windowStart = saved.windowStartUtc;
      } else {
        _baseline = sample.cumulativeSteps;
        _windowStart = sample.timestampUtc;
        saveCheckpoint?.call(StepsCheckpoint(_baseline!, _windowStart!));
      }
      _lastSeen = sample.cumulativeSteps;
      return;
    }
    if (sample.cumulativeSteps < _lastSeen!) {
      // Aparelho reiniciou — o contador voltou a zero. Grava o que já
      // tinha antes do reset, depois recomeça a janela nesta leitura.
      flush(at: sample.timestampUtc, tzOffsetMinutes: sample.tzOffsetMinutes);
      _baseline = sample.cumulativeSteps;
      _lastSeen = sample.cumulativeSteps;
      _windowStart = sample.timestampUtc;
      return;
    }
    _lastSeen = sample.cumulativeSteps;
  }

  /// Grava o delta pendente como um `HealthEvent` tipo `steps` e reinicia
  /// a janela de acumulação (nova linha de base = última leitura vista).
  /// Não grava nada (nem um evento de zero passos) se `pendingDelta == 0`.
  ///
  /// [at] é o instante do flush (UTC) — vira `recordedAt` do evento;
  /// `occurredAt` é o início da janela que está sendo fechada.
  /// [tzOffsetMinutes] é o fuso **local** de onde o evento aconteceu —
  /// não dá pra derivar de [at] porque `DateTime` em UTC sempre reporta
  /// offset zero; quem chama (a camada que sabe o fuso do aparelho)
  /// precisa passar explicitamente.
  void flush({required DateTime at, required int tzOffsetMinutes}) {
    if (!at.isUtc) throw ArgumentError('at precisa estar em UTC');
    final delta = pendingDelta;
    if (delta <= 0 || _windowStart == null) return;

    // Janela que passou da meia-noite local (app ficou fechado de um dia
    // para o outro): os passos vão para o dia do flush — sem saber a
    // hora de cada passo, é o dia em que a pessoa está olhando.
    // TODO(frankstein): dividir por hora exige o serviço nativo guardar
    // leituras com o app fechado; hoje só existe a leitura mais recente.
    var occurred = _windowStart!;
    final localStart = occurred.add(Duration(minutes: tzOffsetMinutes));
    final localEnd = at.add(Duration(minutes: tzOffsetMinutes));
    if (localStart.year != localEnd.year || localStart.month != localEnd.month || localStart.day != localEnd.day) {
      occurred = DateTime.utc(localEnd.year, localEnd.month, localEnd.day).subtract(Duration(minutes: tzOffsetMinutes));
    }

    core.insertEvent(HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.steps,
      source: HealthEventSource.pedometer,
      occurredAt: occurred,
      occurredAtTzOffsetMinutes: tzOffsetMinutes,
      recordedAt: at,
      payload: {
        'count': delta,
        'window_start': _windowStart!.toIso8601String(),
        'window_end': at.toIso8601String(),
      },
      confidence: 1.0,
      deviceId: deviceId,
    ));

    _baseline = _lastSeen;
    _windowStart = at;
    saveCheckpoint?.call(StepsCheckpoint(_baseline!, at));
  }
}
