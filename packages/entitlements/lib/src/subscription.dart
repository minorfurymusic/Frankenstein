/// Canal de pagamento (`docs/MONETIZACAO.md:34`, `docs/adr/007-canais-distribuicao-pagamento.md`).
enum SubscriptionChannel {
  play,
  apple,
  stripe,
  pix,
  b2bSeat;

  String get wireValue => switch (this) {
        SubscriptionChannel.play => 'play',
        SubscriptionChannel.apple => 'apple',
        SubscriptionChannel.stripe => 'stripe',
        SubscriptionChannel.pix => 'pix',
        SubscriptionChannel.b2bSeat => 'b2b_seat',
      };
}

/// Estado da assinatura no servidor (`docs/MONETIZACAO.md:34`).
enum SubscriptionStatus {
  trialing,
  active,
  pastDue,
  grace,
  canceled,
  expired;

  String get wireValue => switch (this) {
        SubscriptionStatus.trialing => 'trialing',
        SubscriptionStatus.active => 'active',
        SubscriptionStatus.pastDue => 'past_due',
        SubscriptionStatus.grace => 'grace',
        SubscriptionStatus.canceled => 'canceled',
        SubscriptionStatus.expired => 'expired',
      };
}

/// Registro de assinatura do lado do servidor (`docs/MONETIZACAO.md:33-34`).
/// **Não é o que o cliente recebe** — isso é [Entitlement] (assinado,
/// derivado deste registro). `Subscription` é o dado de origem, de onde o
/// servidor deriva o entitlement antes de assinar; o cliente nunca vê
/// esta classe diretamente.
class Subscription {
  final String userId;
  final String plan;
  final SubscriptionChannel channel;
  final SubscriptionStatus status;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final String externalId;

  Subscription({
    required this.userId,
    required this.plan,
    required this.channel,
    required this.status,
    required this.currentPeriodEnd,
    required this.externalId,
    this.cancelAtPeriodEnd = false,
  }) {
    if (!currentPeriodEnd.isUtc) {
      throw ArgumentError('currentPeriodEnd precisa estar em UTC');
    }
  }
}
