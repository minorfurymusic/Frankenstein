import 'package:frankstein_activity/activity.dart';
import 'package:frankstein_health_core/health_core.dart';
import 'package:frankstein_tool_registry/tool_registry.dart';

/// Atividade contada no Cérebro, sem gravar (decisão do usuário,
/// 2026-10-18): caminhada por distância vira passos pela passada da
/// pessoa (como "Registrar passos" em Exercícios); o resto vira "outra
/// atividade" com o MET da intensidade (como "Outras atividades"). O gasto
/// é calculado na leitura, pelo peso do dia — a IA não calcula.

/// Esforço de 1 a 10 dito pela pessoa → intensidade do registro manual.
ActivityIntensity intensityForEffort(int? effort) => switch (effort) {
      null => ActivityIntensity.moderate,
      <= 3 => ActivityIntensity.light,
      <= 6 => ActivityIntensity.moderate,
      _ => ActivityIntensity.vigorous,
    };

final Map<String, dynamic> logManualStepsSchema = {
  'type': 'object',
  'properties': {
    'distance_m': {'type': 'number', 'exclusiveMinimum': 0},
    'label': {'type': 'string'},
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['distance_m'],
};

ToolSpec logManualStepsSpec() => ToolSpec(
      name: 'log_manual_steps',
      description: 'Registra passos de uma caminhada contada, pela distância e a passada da pessoa',
      write: true,
      confirm: true,
      module: 'activity',
      parametersSchema: logManualStepsSchema,
    );

ToolHandler logManualStepsHandler(HealthDataCore core, {required double Function() stepMeters, required int Function() tzOffsetMinutesProvider}) {
  return (params) async {
    final meters = (params['distance_m'] as num).toDouble();
    final at = params['at'] == null ? DateTime.now().toUtc() : DateTime.parse(params['at'] as String).toUtc();
    final count = (meters / stepMeters()).round();
    final e = HealthEvent(
      id: HealthDataCore.newId(),
      type: HealthEventType.steps,
      source: HealthEventSource.manual,
      occurredAt: at,
      occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
      recordedAt: DateTime.now().toUtc(),
      payload: {'count': count, 'distance_m': meters, 'manual': true},
      confidence: 1,
    );
    core.insertEvent(e);
    return ToolResult.ok({'event_id': e.id, 'count': count});
  };
}

final Map<String, dynamic> logOtherActivitySchema = {
  'type': 'object',
  'properties': {
    'activity': {
      'enum': [for (final a in OtherActivity.values) a.code],
    },
    'minutes': {'type': 'number', 'exclusiveMinimum': 0},
    'intensity': {
      'enum': [for (final i in ActivityIntensity.values) i.name],
    },
    'label': {'type': 'string'},
    'at': {'type': 'string', 'format': 'date-time'},
  },
  'required': ['activity', 'minutes', 'intensity'],
};

ToolSpec logOtherActivitySpec() => ToolSpec(
      name: 'log_other_activity',
      description: 'Registra uma atividade contada (tempo e intensidade); o gasto sai do MET e do peso',
      write: true,
      confirm: true,
      module: 'activity',
      parametersSchema: logOtherActivitySchema,
    );

ToolHandler logOtherActivityHandler(ActivityLogger logger, {required int Function() tzOffsetMinutesProvider}) {
  return (params) async {
    try {
      final minutes = (params['minutes'] as num).toDouble();
      final duration = Duration(seconds: (minutes * 60).round());
      // Quem conta "brinquei 1 hora" já terminou: começou uma hora antes.
      final end = params['at'] == null ? DateTime.now().toUtc() : DateTime.parse(params['at'] as String).toUtc();
      final e = logger.log(
        activity: OtherActivity.fromCode(params['activity'] as String),
        intensity: ActivityIntensity.values.byName(params['intensity'] as String),
        duration: duration,
        occurredAt: params['at'] == null ? end.subtract(duration) : end,
        occurredAtTzOffsetMinutes: tzOffsetMinutesProvider(),
        notes: params['label'] as String?,
      );
      return ToolResult.ok({'event_id': e.id});
    } on ArgumentError catch (e) {
      return ToolResult.failure(e.message.toString());
    }
  };
}
