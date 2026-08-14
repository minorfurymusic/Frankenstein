enum PendingPaymentStatus { pending, confirmed, expired }

/// Lançada ao tentar confirmar/expirar um [PendingPayment] que já saiu
/// do estado `pending` — uma confirmação/expiração só pode acontecer
/// uma vez.
class PendingPaymentAlreadyResolvedException implements Exception {
  final String message;
  PendingPaymentAlreadyResolvedException(this.message);

  @override
  String toString() => message;
}

/// Pix é assíncrono: a confirmação chega por webhook, não no clique do
/// usuário (`.claude/rules/monetizacao.md`: "Pix é assíncrono: modele
/// pending_payment. Nunca libere no clique."). Esta classe modela esse
/// estado intermediário — nada no cliente lê `status == confirmed` antes
/// do webhook real chamar [confirm].
class PendingPayment {
  final String id;
  final String subscriptionExternalId;
  final DateTime createdAt;

  PendingPaymentStatus _status = PendingPaymentStatus.pending;
  PendingPaymentStatus get status => _status;

  PendingPayment({
    required this.id,
    required this.subscriptionExternalId,
    required this.createdAt,
  }) {
    if (!createdAt.isUtc) {
      throw ArgumentError('createdAt precisa estar em UTC');
    }
  }

  /// Chamado só pelo handler de webhook do servidor, nunca pelo clique
  /// do usuário no app.
  void confirm() {
    if (_status != PendingPaymentStatus.pending) {
      throw PendingPaymentAlreadyResolvedException(
          'PendingPayment $id já está em ${_status.name}, não pode confirmar de novo');
    }
    _status = PendingPaymentStatus.confirmed;
  }

  void expire() {
    if (_status != PendingPaymentStatus.pending) {
      throw PendingPaymentAlreadyResolvedException(
          'PendingPayment $id já está em ${_status.name}, não pode expirar');
    }
    _status = PendingPaymentStatus.expired;
  }
}
