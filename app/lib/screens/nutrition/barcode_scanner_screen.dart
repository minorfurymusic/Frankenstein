// Implementação original do Frankstein. Não deriva do código-fonte do
// OpenNutriTracker (GPL-3.0) — ver docs/specs/nutricao.md e ADR-5.

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';

import '../../theme/rlt_theme.dart';

/// Formatos de rótulo de alimento (EAN/UPC). QR e afins ficam de fora para
/// não ler o código errado da embalagem.
const int kFoodBarcodeFormats = Format.ean13 | Format.ean8 | Format.upca | Format.upce;

/// Câmera só no Android (ADR-12). Em teste/desktop vai direto para a
/// digitação.
bool get barcodeCameraAvailable => !kIsWeb && Platform.isAndroid;

/// Normaliza o que veio da câmera ou do teclado: só dígitos, 8 a 14.
String? normalizeBarcode(String? raw) {
  final v = (raw ?? '').replaceAll(RegExp(r'\D'), '');
  return v.length >= 8 && v.length <= 14 ? v : null;
}

/// Leitor de código de barras pela câmera (ZXing, ADR-10 — sem serviço do
/// Google). Tudo no aparelho: a imagem não é gravada nem enviada. Devolve o
/// código lido, ou o digitado em "Digitar o código".
class BarcodeScannerScreen extends StatefulWidget {
  final Future<String?> Function(BuildContext context) typeManually;
  const BarcodeScannerScreen({super.key, required this.typeManually});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  bool _done = false;
  bool _cameraError = false;

  void _finish(String? code) {
    if (_done || code == null) return;
    _done = true;
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ler código de barras')),
      body: Column(children: [
        Expanded(
          child: _cameraError
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(RltSpace.xl),
                    child: Text(
                      'Não deu para usar a câmera. Libere a câmera para o RLT nas configurações do Android ou digite o código.',
                      style: t.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ReaderWidget(
                  codeFormat: kFoodBarcodeFormats,
                  tryHarder: true,
                  showGallery: false,
                  showToggleCamera: false,
                  resolution: ResolutionPreset.medium,
                  onControllerCreated: (_, error) {
                    if (error != null && mounted) setState(() => _cameraError = true);
                  },
                  onScan: (code) {
                    if (code.isValid) _finish(normalizeBarcode(code.text));
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(RltSpace.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Aponte para o código do rótulo. A imagem não é gravada nem enviada.', style: t.bodySmall, textAlign: TextAlign.center),
            const SizedBox(height: RltSpace.s),
            OutlinedButton.icon(
              key: const Key('barcode_type_manually'),
              onPressed: () async {
                final code = await widget.typeManually(context);
                if (mounted) _finish(code);
              },
              icon: const Icon(Icons.keyboard),
              label: const Text('Digitar o código'),
            ),
          ]),
        ),
      ]),
    );
  }
}
