import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Captura um widget (por [RepaintBoundary]) como PNG — `.claude/rules/share.md`:
/// "Card renderizado NO APARELHO". Abstraído pelo mesmo motivo de
/// `WearableDataSource`/`StepSensor`: `RenderRepaintBoundary.toImage()`
/// depende do pipeline de rasterização real do engine Flutter, que **não
/// completa neste ambiente headless/sandbox** (mesma categoria de
/// `path_provider` — testado em dispositivo real, não em `flutter test`
/// aqui). A lógica em volta (botão dispara captura, preview obrigatório,
/// nada compartilha sozinho) fica testável através de [FakeCardImageCapturer].
abstract class CardImageCapturer {
  Future<Uint8List> capture(GlobalKey repaintBoundaryKey);
}

/// Implementação real — **não verificável em `flutter test`/sem device
/// real neste ambiente** (o `toByteData` nunca completou em teste aqui,
/// mesmo com `tester.runAsync`; não investigado a fundo por ser limite
/// de ambiente de renderização, não bug de lógica).
class RealCardImageCapturer implements CardImageCapturer {
  @override
  Future<Uint8List> capture(GlobalKey repaintBoundaryKey) async {
    final boundary = repaintBoundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}

/// Fake pra teste — devolve bytes fabricados sem tocar no pipeline de
/// rasterização real, mesmo padrão de `FakeShareSheet`/`FixtureWearableDataSource`.
class FakeCardImageCapturer implements CardImageCapturer {
  final Uint8List bytes;
  FakeCardImageCapturer({Uint8List? bytes}) : bytes = bytes ?? Uint8List.fromList([1, 2, 3]);

  @override
  Future<Uint8List> capture(GlobalKey repaintBoundaryKey) async => bytes;
}
