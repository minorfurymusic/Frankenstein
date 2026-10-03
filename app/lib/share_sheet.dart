import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

/// Compartilhamento nativo — `.claude/rules/share.md`: "Share sheet
/// nativo + intents. Sem SDK proprietário de rede social." `share_plus`
/// (BSD-3-Clause, mantido pela comunidade Flutter) só invoca o
/// `ACTION_SEND`/`UIActivityViewController` do sistema — não é um SDK de
/// rede social (Facebook/TikTok/etc., proibidos por
/// `.claude/rules/licenca.md`), é o mecanismo padrão do próprio SO;
/// nenhum dado sai pra servidor nenhum além do que o usuário escolher no
/// menu do sistema.
abstract class ShareSheet {
  Future<void> shareImage(Uint8List pngBytes, {required String suggestedFileName, String? text});

  /// Arquivo qualquer (ex.: GPX da corrida) pelo compartilhamento do
  /// Android — a pessoa escolhe para onde vai; nada sai sozinho.
  Future<void> shareFile(Uint8List bytes, {required String fileName, required String mimeType});
}

/// Implementação real — platform channel, **não verificável em
/// `flutter test`/sem device real** (mesma categoria de `path_provider`).
class NativeShareSheet implements ShareSheet {
  @override
  Future<void> shareImage(Uint8List pngBytes, {required String suggestedFileName, String? text}) async {
    await Share.shareXFiles(
      [XFile.fromData(pngBytes, name: suggestedFileName, mimeType: 'image/png')],
      text: text,
    );
  }

  @override
  Future<void> shareFile(Uint8List bytes, {required String fileName, required String mimeType}) async {
    await Share.shareXFiles([XFile.fromData(bytes, name: fileName, mimeType: mimeType)]);
  }
}

/// Fake pra teste — registra a chamada sem tocar em nenhum platform
/// channel, mesmo padrão de `FixtureWearableDataSource`/`FixtureBarcodeDecoder`.
class FakeShareSheet implements ShareSheet {
  bool called = false;
  Uint8List? lastBytes;
  String? lastFileName;
  String? lastText;

  @override
  Future<void> shareImage(Uint8List pngBytes, {required String suggestedFileName, String? text}) async {
    called = true;
    lastBytes = pngBytes;
    lastFileName = suggestedFileName;
    lastText = text;
  }

  String? lastFileMimeType;

  @override
  Future<void> shareFile(Uint8List bytes, {required String fileName, required String mimeType}) async {
    called = true;
    lastBytes = bytes;
    lastFileName = fileName;
    lastFileMimeType = mimeType;
  }
}
