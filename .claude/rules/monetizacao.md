---
paths:
  - "packages/entitlements/**"
  - "server/**"
  - "**/*subscription*"
  - "**/*payment*"
---
# Regras de monetização

Princípio: grátis = roda no aparelho. Pago = consome servidor.

- PROIBIDO qualquer código de anúncio. O sistema de anúncios foi cancelado.
- PROIBIDO `if (isPremium)` decidido no cliente. O cliente apresenta um
  entitlement assinado (Ed25519/JWT); quem valida é o servidor.
- Nunca são pagos nem limitados: passos, refeição, treino, corrida, IA local,
  histórico local, exportação de dados, avisos de saúde.
- São pagos: backup/sync, acesso web, conector FHIR, wger hospedado, cérebro
  reforçado em nuvem (com teto explícito), histórico em nuvem, conta familiar.
- Período de graça offline: entitlement vale até exp + 7 dias sem rede.
- Downgrade nunca apaga dado. O recurso some, o dado permanece e continua exportável.
- Webhooks idempotentes (chave: external_id + event_id).
- Pix é assíncrono: modele pending_payment. Nunca libere no clique.
