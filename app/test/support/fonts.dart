import 'dart:io';

import 'package:flutter/services.dart';
import 'package:frankstein/theme/rlt_theme.dart';

/// Carrega a Figtree embutida: sem isso o `flutter test` mede texto com a
/// fonte de teste (glifos quadrados, bem mais largos que a Figtree) e acusa
/// estouro que não existe no aparelho — ou esconde o que existe.
Future<void> loadFigtree() async {
  final loader = FontLoader(kRltFontFamily);
  for (final w in [400, 500, 600, 700, 800]) {
    final bytes = File('assets/fonts/figtree/Figtree-w$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}
