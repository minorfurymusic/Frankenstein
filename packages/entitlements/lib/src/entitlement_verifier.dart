import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'entitlement.dart';

/// Lançada quando a assinatura Ed25519 de um [Entitlement] não confere
/// contra a chave pública esperada — dado adulterado, chave errada, ou
/// assinatura de outro payload.
class InvalidEntitlementSignatureException implements Exception {
  final String message;
  InvalidEntitlementSignatureException(this.message);

  @override
  String toString() => message;
}

/// Verifica a assinatura Ed25519 de um [Entitlement] contra a chave
/// pública do servidor (`docs/MONETIZACAO.md:38-41`,
/// `.claude/rules/00-inviolaveis.md`: "Nenhum degrau pago é decidido no
/// cliente. O cliente apresenta um entitlement assinado pelo servidor").
///
/// **O cliente só verifica, nunca assina** — só tem a chave pública. A
/// chave privada e o servidor de emissão são trabalho de outra fase
/// (nenhum provedor configurado ainda, por decisão explícita deste
/// ciclo). [EntitlementSigner], neste mesmo pacote, existe só pra
/// ferramenta/teste simular o lado do servidor — nunca roda no cliente.
class EntitlementVerifier {
  final SimplePublicKey publicKey;
  final Ed25519 _algorithm = Ed25519();

  EntitlementVerifier({required this.publicKey});

  /// Lança [InvalidEntitlementSignatureException] se a assinatura não
  /// bater. Devolve o mesmo [entitlement] recebido se válida — não
  /// reconstrói nada a partir da assinatura.
  Future<Entitlement> verify(Entitlement entitlement, String signatureBase64) async {
    final signature = Signature(base64Decode(signatureBase64), publicKey: publicKey);
    final valid = await _algorithm.verify(
      entitlement.canonicalPayloadBytes(),
      signature: signature,
    );
    if (!valid) {
      throw InvalidEntitlementSignatureException(
          'assinatura Ed25519 inválida para sub=${entitlement.subscriptionId}');
    }
    return entitlement;
  }
}

/// Assina um [Entitlement] com a chave privada Ed25519 — papel do
/// **servidor**, não do cliente. Existe neste pacote só pra testes e
/// ferramentas locais simularem um entitlement real; nenhum código do
/// app (`app/`) importa esta classe.
class EntitlementSigner {
  final SimpleKeyPair keyPair;
  final Ed25519 _algorithm = Ed25519();

  EntitlementSigner({required this.keyPair});

  Future<String> sign(Entitlement entitlement) async {
    final signature = await _algorithm.sign(
      entitlement.canonicalPayloadBytes(),
      keyPair: keyPair,
    );
    return base64Encode(signature.bytes);
  }

  static Future<SimpleKeyPair> generateKeyPair() => Ed25519().newKeyPair();
}
