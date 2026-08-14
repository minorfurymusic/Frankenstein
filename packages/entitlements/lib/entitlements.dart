/// Entitlement assinado (Ed25519) e vínculo de assinatura no aparelho
/// (`.claude/rules/monetizacao.md`, `docs/adr/007-canais-distribuicao-pagamento.md`).
///
/// Fase 10/11 (parcial — esqueleto, sem provedor de pagamento
/// configurado, por decisão explícita deste ciclo): `Entitlement`
/// (payload que o cliente recebe), `EntitlementVerifier` (verifica a
/// assinatura Ed25519 — só o cliente verifica, nunca assina;
/// `EntitlementSigner` simula o lado do servidor só pra teste/ferramenta),
/// `Subscription`/`SubscriptionChannel`/`SubscriptionStatus` (registro do
/// lado do servidor), `PendingPayment` (Pix assíncrono — nunca libera no
/// clique), `WebhookIdempotencyGuard` (chave `external_id + event_id`).
///
/// **O que não está aqui:** nenhum SDK de pagamento (Play Billing,
/// StoreKit, Stripe), nenhuma chave privada real, nenhum servidor de
/// emissão — isso é configuração de provedor, fora do escopo deste
/// ciclo (`.claude/rules/00-inviolaveis.md`: "Nenhum degrau pago é
/// decidido no cliente").
library;

export 'src/entitlement.dart';
export 'src/entitlement_verifier.dart';
export 'src/pending_payment.dart';
export 'src/subscription.dart';
export 'src/webhook_idempotency.dart';
