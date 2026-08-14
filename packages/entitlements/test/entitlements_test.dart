import 'package:frankstein_entitlements/entitlements.dart';
import 'package:test/test.dart';

Entitlement _entitlement({
  String subscriptionId = 'sub-1',
  String plan = 'premium',
  List<String> features = const ['no_ads', 'cloud_sync'],
  DateTime? expiresAt,
}) {
  return Entitlement(
    subscriptionId: subscriptionId,
    plan: plan,
    features: features,
    expiresAt: expiresAt ?? DateTime.utc(2026, 9, 1),
  );
}

void main() {
  group('Entitlement — validação e graça offline', () {
    test('rejeita expiresAt fora de UTC', () {
      expect(
        () => Entitlement(subscriptionId: 's', plan: 'premium', features: const [], expiresAt: DateTime(2026, 9, 1)),
        throwsArgumentError,
      );
    });

    test('hasFeature reflete a lista de features', () {
      final e = _entitlement(features: const ['cloud_sync']);
      expect(e.hasFeature('cloud_sync'), isTrue);
      expect(e.hasFeature('no_ads'), isFalse);
    });

    test('isValidAt: válido antes de expiresAt, inválido depois, sem graça', () {
      final e = _entitlement(expiresAt: DateTime.utc(2026, 9, 1));
      expect(e.isValidAt(DateTime.utc(2026, 8, 31)), isTrue);
      expect(e.isValidAt(DateTime.utc(2026, 9, 2)), isFalse);
    });

    test('isValidAt com offlineGrace: vale até exp + 7 dias sem rede', () {
      final e = _entitlement(expiresAt: DateTime.utc(2026, 9, 1));
      final doisDiasDepois = DateTime.utc(2026, 9, 3);
      expect(e.isValidAt(doisDiasDepois), isFalse); // sem graça, já expirou
      expect(e.isValidAt(doisDiasDepois, offlineGrace: true), isTrue); // dentro dos 7 dias

      final oitoDiasDepois = DateTime.utc(2026, 9, 9);
      expect(e.isValidAt(oitoDiasDepois, offlineGrace: true), isFalse); // além da graça
    });
  });

  group('EntitlementVerifier/EntitlementSigner — assinatura Ed25519', () {
    test('entitlement assinado pela chave certa verifica com sucesso', () async {
      final keyPair = await EntitlementSigner.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final signer = EntitlementSigner(keyPair: keyPair);
      final verifier = EntitlementVerifier(publicKey: publicKey);

      final entitlement = _entitlement();
      final signature = await signer.sign(entitlement);

      final verified = await verifier.verify(entitlement, signature);
      expect(verified.subscriptionId, entitlement.subscriptionId);
    });

    test('assinatura de outra chave é rejeitada', () async {
      final serverKeyPair = await EntitlementSigner.generateKeyPair();
      final attackerKeyPair = await EntitlementSigner.generateKeyPair();
      final serverPublicKey = await serverKeyPair.extractPublicKey();

      final attackerSigner = EntitlementSigner(keyPair: attackerKeyPair);
      final verifier = EntitlementVerifier(publicKey: serverPublicKey);

      final entitlement = _entitlement();
      final forgedSignature = await attackerSigner.sign(entitlement);

      expect(
        () => verifier.verify(entitlement, forgedSignature),
        throwsA(isA<InvalidEntitlementSignatureException>()),
      );
    });

    test('payload adulterado depois de assinado é rejeitado (plan trocado)', () async {
      final keyPair = await EntitlementSigner.generateKeyPair();
      final publicKey = await keyPair.extractPublicKey();
      final signer = EntitlementSigner(keyPair: keyPair);
      final verifier = EntitlementVerifier(publicKey: publicKey);

      final original = _entitlement(plan: 'free');
      final signature = await signer.sign(original);

      final tampered = _entitlement(plan: 'premium'); // mesmo sub, plan diferente
      expect(
        () => verifier.verify(tampered, signature),
        throwsA(isA<InvalidEntitlementSignatureException>()),
      );
    });
  });

  group('Subscription — validação', () {
    test('rejeita currentPeriodEnd fora de UTC', () {
      expect(
        () => Subscription(
          userId: 'u1',
          plan: 'premium',
          channel: SubscriptionChannel.pix,
          status: SubscriptionStatus.active,
          currentPeriodEnd: DateTime(2026, 9, 1),
          externalId: 'ext-1',
        ),
        throwsArgumentError,
      );
    });

    test('wireValue dos enums bate com docs/MONETIZACAO.md', () {
      expect(SubscriptionChannel.b2bSeat.wireValue, 'b2b_seat');
      expect(SubscriptionStatus.pastDue.wireValue, 'past_due');
    });
  });

  group('PendingPayment — Pix assíncrono, nunca libera no clique', () {
    test('começa pending; confirm() muda pra confirmed', () {
      final payment = PendingPayment(id: 'p1', subscriptionExternalId: 'ext-1', createdAt: DateTime.utc(2026, 8, 10));
      expect(payment.status, PendingPaymentStatus.pending);
      payment.confirm();
      expect(payment.status, PendingPaymentStatus.confirmed);
    });

    test('confirm() duas vezes lança PendingPaymentAlreadyResolvedException', () {
      final payment = PendingPayment(id: 'p1', subscriptionExternalId: 'ext-1', createdAt: DateTime.utc(2026, 8, 10));
      payment.confirm();
      expect(() => payment.confirm(), throwsA(isA<PendingPaymentAlreadyResolvedException>()));
    });

    test('expire() depois de confirm() lança PendingPaymentAlreadyResolvedException', () {
      final payment = PendingPayment(id: 'p1', subscriptionExternalId: 'ext-1', createdAt: DateTime.utc(2026, 8, 10));
      payment.confirm();
      expect(() => payment.expire(), throwsA(isA<PendingPaymentAlreadyResolvedException>()));
    });
  });

  group('WebhookIdempotencyGuard', () {
    test('primeira vez com uma chave devolve false (processar); repetição devolve true (ignorar)', () {
      final guard = WebhookIdempotencyGuard();
      expect(guard.alreadyProcessed('ext-1', 'evt-1'), isFalse);
      expect(guard.alreadyProcessed('ext-1', 'evt-1'), isTrue);
    });

    test('mesmo external_id com event_id diferente não é duplicata', () {
      final guard = WebhookIdempotencyGuard();
      expect(guard.alreadyProcessed('ext-1', 'evt-1'), isFalse);
      expect(guard.alreadyProcessed('ext-1', 'evt-2'), isFalse);
    });
  });
}
