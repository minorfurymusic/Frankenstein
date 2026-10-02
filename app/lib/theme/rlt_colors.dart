import 'package:flutter/material.dart';

/// Design tokens de cor do RLT, um para um com as variáveis CSS do layout
/// (`docs/design/rlt-layout/Tokens.dc.html`, classes `.t-light`/`.t-dark`).
/// O nome de cada campo comenta a variável de origem, para conferir contra o
/// design sem adivinhar.
@immutable
class RltColors extends ThemeExtension<RltColors> {
  final Color surface; // --surface
  final Color surfaceContainerLow; // --scl
  final Color surfaceContainer; // --sc
  final Color surfaceContainerHigh; // --sch
  final Color surfaceContainerHighest; // --schh
  final Color onSurface; // --on
  final Color onSurfaceVariant; // --onv
  final Color outline; // --outline
  final Color outlineVariant; // --outv
  final Color primary; // --pri
  final Color onPrimary; // --onpri
  final Color primaryContainer; // --pc
  final Color onPrimaryContainer; // --onpc
  final Color secondary; // --sec
  final Color secondaryContainer; // --sc2
  final Color onSecondaryContainer; // --onsc2
  final Color tertiary; // --ter
  final Color tertiaryContainer; // --tc
  final Color onTertiaryContainer; // --ontc
  final Color error; // --err
  final Color onError; // --onerr
  final Color errorContainer; // --ec
  final Color onErrorContainer; // --onec
  final Color protein; // --prot
  final Color carbs; // --carb
  final Color fat; // --fat
  final Color water; // --water
  final Color sleep; // --sleep
  final Color inverseSurface; // --inv
  final Color onInverseSurface; // --oninv
  final Color success; // --ok
  final Color successContainer; // --okc
  final Color onSuccessContainer; // --onokc
  final Color scrim; // --scrim
  final Color shadow; // --shadow

  const RltColors({
    required this.surface,
    required this.surfaceContainerLow,
    required this.surfaceContainer,
    required this.surfaceContainerHigh,
    required this.surfaceContainerHighest,
    required this.onSurface,
    required this.onSurfaceVariant,
    required this.outline,
    required this.outlineVariant,
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.secondary,
    required this.secondaryContainer,
    required this.onSecondaryContainer,
    required this.tertiary,
    required this.tertiaryContainer,
    required this.onTertiaryContainer,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.water,
    required this.sleep,
    required this.inverseSurface,
    required this.onInverseSurface,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.scrim,
    required this.shadow,
  });

  static const light = RltColors(
    surface: Color(0xFFF5FAF7),
    surfaceContainerLow: Color(0xFFEFF5F2),
    surfaceContainer: Color(0xFFE9EFEC),
    surfaceContainerHigh: Color(0xFFE3EAE6),
    surfaceContainerHighest: Color(0xFFDDE4E0),
    onSurface: Color(0xFF161D1B),
    onSurfaceVariant: Color(0xFF3E4946),
    outline: Color(0xFF6E7976),
    outlineVariant: Color(0xFFBDC9C4),
    primary: Color(0xFF006A5E),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFF9DF2E1),
    onPrimaryContainer: Color(0xFF00201B),
    secondary: Color(0xFF4A635E),
    secondaryContainer: Color(0xFFCDE8E1),
    onSecondaryContainer: Color(0xFF06201B),
    tertiary: Color(0xFF8F4C2A),
    tertiaryContainer: Color(0xFFFFDBCB),
    onTertiaryContainer: Color(0xFF351000),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),
    protein: Color(0xFF2B5EA7),
    carbs: Color(0xFFB35F00),
    fat: Color(0xFF7A4FB0),
    water: Color(0xFF1C6FA8),
    sleep: Color(0xFF4F5BA6),
    inverseSurface: Color(0xFF2B3230),
    onInverseSurface: Color(0xFFECF2EF),
    success: Color(0xFF1E6B2F),
    successContainer: Color(0xFFC8EFCB),
    onSuccessContainer: Color(0xFF00210A),
    scrim: Color(0x5C000000), // rgba(0,0,0,.36)
    shadow: Color(0x24000000), // rgba(0,0,0,.14)
  );

  static const dark = RltColors(
    surface: Color(0xFF0E1513),
    surfaceContainerLow: Color(0xFF161D1B),
    surfaceContainer: Color(0xFF1A211F),
    surfaceContainerHigh: Color(0xFF252B29),
    surfaceContainerHighest: Color(0xFF2F3634),
    onSurface: Color(0xFFDDE4E0),
    onSurfaceVariant: Color(0xFFBDC9C4),
    outline: Color(0xFF879390),
    outlineVariant: Color(0xFF3E4946),
    primary: Color(0xFF81D5C5),
    onPrimary: Color(0xFF003730),
    primaryContainer: Color(0xFF005047),
    onPrimaryContainer: Color(0xFF9DF2E1),
    secondary: Color(0xFFB1CCC5),
    secondaryContainer: Color(0xFF334B46),
    onSecondaryContainer: Color(0xFFCDE8E1),
    tertiary: Color(0xFFFFB692),
    tertiaryContainer: Color(0xFF713518),
    onTertiaryContainer: Color(0xFFFFDBCB),
    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),
    protein: Color(0xFFA8C8FF),
    carbs: Color(0xFFFFB86E),
    fat: Color(0xFFD3BBFF),
    water: Color(0xFF8FCDFF),
    sleep: Color(0xFFBAC3FF),
    inverseSurface: Color(0xFFDDE4E0),
    onInverseSurface: Color(0xFF2B3230),
    success: Color(0xFFA6D8A9),
    successContainer: Color(0xFF1F4F27),
    onSuccessContainer: Color(0xFFC8EFCB),
    scrim: Color(0x99000000), // rgba(0,0,0,.6)
    shadow: Color(0x80000000), // rgba(0,0,0,.5)
  );

  /// Atalho para os widgets: `RltColors.of(context).water`.
  static RltColors of(BuildContext context) =>
      Theme.of(context).extension<RltColors>() ?? light;

  @override
  RltColors copyWith() => this;

  /// Troca de tema é instantânea (claro/escuro/sistema em Conta >
  /// Preferências); não há animação entre paletas, então interpolar não
  /// acrescenta nada.
  @override
  RltColors lerp(ThemeExtension<RltColors>? other, double t) =>
      t < 0.5 ? this : (other as RltColors? ?? this);
}
