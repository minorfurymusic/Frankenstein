/// Uma leitura de GPS capturada durante uma corrida/caminhada, antes de
/// virar `GpsTrackPoint` (que exige `eventId`/`seq` — atribuídos só na
/// hora de gravar, por [RunLogger]). `docs/PRODUTO.md:29`: "GPS, rota,
/// pace, splits por km, elevação".
class RunPointInput {
  final double latitude;
  final double longitude;
  final double? elevationMeters;

  /// Precisão relatada pelo GPS no momento da leitura, em metros.
  /// `null` quando a fonte não relata precisão. Usada pelo filtro de
  /// ruído (`.claude/rules/activity.md:16`) em `RunCalculator.filterByAccuracy`.
  final double? accuracyMeters;

  final DateTime recordedAt;

  RunPointInput({
    required this.latitude,
    required this.longitude,
    required this.recordedAt,
    this.elevationMeters,
    this.accuracyMeters,
  }) {
    if (!recordedAt.isUtc) {
      throw ArgumentError('recordedAt precisa estar em UTC');
    }
    if (latitude < -90 || latitude > 90) {
      throw ArgumentError('latitude fora do intervalo [-90, 90]: $latitude');
    }
    if (longitude < -180 || longitude > 180) {
      throw ArgumentError('longitude fora do intervalo [-180, 180]: $longitude');
    }
  }
}
