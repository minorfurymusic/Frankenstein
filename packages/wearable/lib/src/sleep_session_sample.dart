/// Uma sessão de sono vinda do Health Connect — mesmo raciocínio de
/// [HeartRateSample]: `externalId` obrigatório (dedup por
/// `(source, external_id)`, `.claude/rules/datacore.md`).
class SleepSessionSample {
  final String externalId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int tzOffsetMinutes;

  /// Fases, quando a pulseira informa (nem toda informa).
  final List<SleepStageSample> stages;

  SleepSessionSample({
    required this.externalId,
    required this.startedAt,
    required this.endedAt,
    required this.tzOffsetMinutes,
    this.stages = const [],
  }) {
    if (!startedAt.isUtc || !endedAt.isUtc) {
      throw ArgumentError('startedAt/endedAt precisam estar em UTC');
    }
    if (!endedAt.isAfter(startedAt)) {
      throw ArgumentError('endedAt precisa ser depois de startedAt');
    }
  }

  Duration get duration => endedAt.difference(startedAt);

  /// Minutos por fase (só as fases presentes).
  Map<SleepStage, int> get stageMinutes {
    final out = <SleepStage, int>{};
    for (final s in stages) {
      out[s.stage] = (out[s.stage] ?? 0) + s.endedAt.difference(s.startedAt).inMinutes;
    }
    return out;
  }
}

/// Fases do sono como o Health Connect classifica (`SleepSessionRecord`).
/// "Fora da cama" e "acordado na cama" contam como acordado.
enum SleepStage {
  awake('awake'),
  light('light'),
  deep('deep'),
  rem('rem'),
  sleeping('sleeping'),
  unknown('unknown');

  final String wireValue;
  const SleepStage(this.wireValue);

  static SleepStage fromWireValue(String v) =>
      SleepStage.values.firstWhere((s) => s.wireValue == v, orElse: () => SleepStage.unknown);
}

class SleepStageSample {
  final SleepStage stage;
  final DateTime startedAt;
  final DateTime endedAt;

  SleepStageSample({required this.stage, required this.startedAt, required this.endedAt}) {
    if (!startedAt.isUtc || !endedAt.isUtc) {
      throw ArgumentError('fase: startedAt/endedAt precisam estar em UTC');
    }
    if (endedAt.isBefore(startedAt)) {
      throw ArgumentError('fase: endedAt antes de startedAt');
    }
  }
}
