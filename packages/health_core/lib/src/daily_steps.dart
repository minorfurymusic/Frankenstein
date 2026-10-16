import 'dart:math' as math;

import 'health_event.dart';

/// Passos de um dia a partir dos eventos `steps` daquele dia (ADR-20).
///
/// Duas fontes, uma por dia, para não contar em dobro:
/// - Health Connect (`source: wearable`, `payload.daily_total == true`): o
///   total do dia lido do Android; vale a leitura mais recente.
/// - Contador do próprio app (`source: pedometer`): janelas que se somam.
///
/// As duas contam os mesmos passos do celular; fica o maior total — se uma
/// fonte falhou parte do dia, a outra cobre.
///
/// Registrados à mão (`source: manual`, ex.: caminhada sem o celular)
/// somam por cima — são passos que nenhuma das duas viu.
int dailyStepCount(Iterable<HealthEvent> stepEvents) {
  var counter = 0;
  var manual = 0;
  HealthEvent? latestDaily;
  for (final e in stepEvents) {
    if (e.type != HealthEventType.steps) continue;
    if (e.source == HealthEventSource.manual) {
      manual += (e.payload['count'] as num).toInt();
    } else if (isDailyStepTotal(e)) {
      if (latestDaily == null || e.recordedAt.isAfter(latestDaily.recordedAt)) latestDaily = e;
    } else {
      counter += (e.payload['count'] as num).toInt();
    }
  }
  final daily = latestDaily == null ? 0 : (latestDaily.payload['count'] as num).toInt();
  return math.max(daily, counter) + manual;
}

/// Total diário lido do Health Connect (não é uma janela que se soma).
bool isDailyStepTotal(HealthEvent e) => e.payload['daily_total'] == true;
