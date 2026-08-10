// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'dart:typed_data';

/// Decodifica o valor de um código de barras a partir de bytes de imagem
/// (um frame de câmera já capturado, ou uma foto da galeria) —
/// `docs/specs/nutricao.md`, fluxo "Registrar por código de barras":
/// "abrir a câmera → ler o código → cair na mesma tela de detalhe
/// nutricional do fluxo de busca".
///
/// **Câmera/hardware fica atrás desta interface de propósito** — mesmo
/// padrão de `packages/activity/lib/src/step_sensor.dart` para
/// `StepSensor`: este ambiente de desenvolvimento não tem SDK Android,
/// `/dev/kvm` nem câmera para validar uma implementação real. O que
/// existe aqui é o contrato + uma implementação de fixture para teste
/// ([FixtureBarcodeDecoder]); a implementação concreta entra depois como
/// uma classe nova, sem mudar quem consome [BarcodeDecoder].
///
/// **Pacote escolhido para a implementação concreta (não incluído neste
/// ciclo): `flutter_zxing` (pub.dev, versão 2.3.0 no momento da pesquisa,
/// licença MIT, ZXing-cpp via Dart FFI — sem ML Kit nem Google Play
/// Services, `.claude/rules/licenca.md`).** Ele depende do SDK Flutter e
/// do pacote `camera`, então não pode entrar como dependência deste
/// pacote (`frankstein_nutrition` é Dart puro, testável com `dart test`,
/// mesmo padrão de `frankstein_health_core`/`frankstein_activity`) — a
/// classe concreta que implementa [BarcodeDecoder] com `flutter_zxing`
/// deve morar em `app/` (o shell Flutter), num ciclo futuro com
/// dispositivo/emulador para validar.
///
/// TODO(frankstein): implementar `ZxingBarcodeDecoder` em `app/` usando
/// `flutter_zxing` ^2.3.0 (MIT) quando houver dispositivo/emulador para
/// testar a leitura de câmera de verdade.
abstract class BarcodeDecoder {
  /// Retorna o valor decodificado do código de barras, ou `null` se
  /// nenhum código pôde ser reconhecido na imagem.
  Future<String?> decodeImage(Uint8List imageBytes);
}

/// Implementação de teste: decodifica só o que foi registrado
/// explicitamente via [registerImage] — sem nenhuma leitura real de
/// imagem. Existe para permitir testar o fluxo "escanear → achar no
/// catálogo → registrar" sem câmera nem um decodificador de imagem de
/// verdade.
class FixtureBarcodeDecoder implements BarcodeDecoder {
  final Map<String, String> _knownImages = {};

  /// Associa [imageBytes] ao valor de código de barras que um decodificador
  /// real teria lido dali. A chave de comparação é o conteúdo dos bytes
  /// (lista de valores, não a identidade do objeto `Uint8List`).
  void registerImage(Uint8List imageBytes, String barcodeValue) {
    _knownImages[_key(imageBytes)] = barcodeValue;
  }

  @override
  Future<String?> decodeImage(Uint8List imageBytes) async {
    return _knownImages[_key(imageBytes)];
  }

  String _key(Uint8List bytes) => bytes.join(',');
}
