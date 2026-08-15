/// Uma sessão de sono vinda do Health Connect — mesmo raciocínio de
/// [HeartRateSample]: `externalId` obrigatório (dedup por
/// `(source, external_id)`, `.claude/rules/datacore.md`).
class SleepSessionSample {
  final String externalId;
  final DateTime startedAt;
  final DateTime endedAt;
  final int tzOffsetMinutes;

  SleepSessionSample({
    required this.externalId,
    required this.startedAt,
    required this.endedAt,
    required this.tzOffsetMinutes,
  }) {
    if (!startedAt.isUtc || !endedAt.isUtc) {
      throw ArgumentError('startedAt/endedAt precisam estar em UTC');
    }
    if (!endedAt.isAfter(startedAt)) {
      throw ArgumentError('endedAt precisa ser depois de startedAt');
    }
  }

  Duration get duration => endedAt.difference(startedAt);
}
