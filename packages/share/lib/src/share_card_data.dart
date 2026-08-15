/// Dado pronto pra virar card de compartilhamento — só o que já passou
/// pela checagem de tipo (`share_card_builder.dart`: nunca construído a
/// partir de um `HealthEvent` clínico) e, quando é rota, já ofuscado
/// (`.claude/rules/share.md`: "Rota de corrida sai ofuscada nos
/// primeiros e últimos 300 m").
///
/// **Sem peso, IMC, calorias ou medidas ainda.** `.claude/rules/share.md`
/// exige que esses campos comecem desligados, com opt-in campo a campo,
/// quando existirem num card — decisão deste ciclo: não incluí-los aqui
/// de jeito nenhum (nem desligados) até o card realmente precisar deles,
/// em vez de montar uma UI de opt-in pra campo que não existe. Registrado
/// como escopo adiado, não escondido.
class WorkoutShareCardData {
  final String title;
  final int setsCount;
  final List<String> exerciseNames;

  /// Frase pronta tipo "novo recorde: 70 kg" — opcional, só entra se
  /// quem chama [buildWorkoutShareCard] passar explicitamente
  /// (`personalRecordSummary`), nunca calculado escondido aqui dentro.
  final String? personalRecordSummary;

  WorkoutShareCardData({
    required this.title,
    required this.setsCount,
    required this.exerciseNames,
    this.personalRecordSummary,
  });
}

/// Um ponto de rota já seguro pra sair do aparelho — sem o rótulo
/// "GPS bruto", porque a esta altura já passou pela ofuscação de 300 m.
class RunShareRoutePoint {
  final double latitude;
  final double longitude;

  RunShareRoutePoint({required this.latitude, required this.longitude});
}

class RunShareCardData {
  final double distanceMeters;
  final Duration duration;
  final double? averagePaceSecondsPerKm;

  /// Rota já ofuscada (`obfuscateRouteEnds`, `packages/activity`) —
  /// **vazia** quando a rota é curta demais pra ofuscar com segurança
  /// (`.claude/rules/activity.md`: rota < 600 m devolve lista vazia),
  /// nunca a rota crua como alternativa.
  final List<RunShareRoutePoint> route;

  RunShareCardData({
    required this.distanceMeters,
    required this.duration,
    required this.averagePaceSecondsPerKm,
    required this.route,
  });
}
