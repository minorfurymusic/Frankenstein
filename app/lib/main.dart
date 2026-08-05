import 'package:flutter/material.dart';

void main() {
  runApp(const FrankstitApp());
}

/// Esqueleto do shell (ADR-1). Tela em branco de propósito — nenhum
/// módulo, nenhum cérebro, nenhum banco entra aqui neste ciclo.
class FrankstitApp extends StatelessWidget {
  const FrankstitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Frankstein',
      home: Scaffold(body: SizedBox.shrink()),
    );
  }
}
