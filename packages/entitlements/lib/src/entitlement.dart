import 'dart:convert';

/// O que o cliente recebe do servidor (`docs/MONETIZACAO.md:38-41`):
/// `{ "sub", "plan", "features", "exp", "sig" }`. Esta classe é só o
/// payload — a assinatura (`sig`) é verificada à parte por
/// `EntitlementVerifier`, nunca checada por esta classe (separação
/// deliberada entre "dado" e "prova de que o dado é legítimo").
class Entitlement {
  final String subscriptionId;
  final String plan;
  final List<String> features;
  final DateTime expiresAt;

  Entitlement({
    required this.subscriptionId,
    required this.plan,
    required this.features,
    required this.expiresAt,
  }) {
    if (!expiresAt.isUtc) {
      throw ArgumentError('expiresAt precisa estar em UTC');
    }
  }

  bool hasFeature(String feature) => features.contains(feature);

  /// Vale até [expiresAt]. Em graça offline (`.claude/rules/monetizacao.md`:
  /// "Período de graça offline: entitlement vale até exp + 7 dias sem
  /// rede") vale até `expiresAt + 7 dias` — quem decide se [offlineGrace]
  /// se aplica é o chamador (sabe se há rede), não esta classe.
  bool isValidAt(DateTime now, {bool offlineGrace = false}) {
    final limit = offlineGrace ? expiresAt.add(const Duration(days: 7)) : expiresAt;
    return !now.isAfter(limit);
  }

  /// Bytes exatos que o servidor assina e o cliente verifica — chaves em
  /// ordem fixa, pra quem assina e quem verifica sempre produzirem o
  /// mesmo payload canônico.
  List<int> canonicalPayloadBytes() {
    final map = <String, dynamic>{
      'sub': subscriptionId,
      'plan': plan,
      'features': features,
      'exp': expiresAt.toIso8601String(),
    };
    return utf8.encode(jsonEncode(map));
  }
}
