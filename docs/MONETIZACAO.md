# MONETIZAÇÃO — Frankstein

**Sem anúncios.** O sistema de anúncios foi cancelado: SDKs de anúncio são
binários proprietários e linká-los a módulos GPL/AGPL viola a licença.

## Degraus

### GRÁTIS — para sempre, sem conta, sem nuvem
Tudo que roda no aparelho, sem limite, sem expiração, **sem cadastro**.
Sem login significa sem servidor e sem você virar controlador de dados na LGPD.
É o argumento de marketing mais forte do produto: os dados nunca saem do celular.

### PREMIUM — R$ 20 / US$ 10 por mês
Só o que custa servidor de verdade:
1. Backup criptografado e sincronização entre aparelhos
2. Acesso web ao painel pessoal
3. Conector de prontuário (Fasten/FHIR) para hospitais e planos
4. wger hospedado
5. Cérebro reforçado em nuvem, com teto explícito de consultas/mês
6. Histórico consolidado em nuvem
7. Conta familiar (até 4 pessoas)
8. Suporte prioritário

### PRO / B2B — onde está o dinheiro
Painel profissional, seats, vínculo com pacientes, marca branca, relatórios.
20 nutricionistas a R$ 80/mês valem mais que 500 usuários a R$ 20 — e dão menos suporte.

### NUNCA pagar, nunca limitar
Exportação de dados (LGPD art. 18), histórico local, avisos de saúde, passos,
refeições, treino, corrida.

## Entitlements
```
Subscription: user_id, plan, channel (play|apple|stripe|pix|b2b_seat),
  status (trialing|active|past_due|grace|canceled|expired),
  current_period_end, cancel_at_period_end, external_id

Entitlement (o que o cliente recebe):
  { "sub": "...", "plan": "premium", "features": ["no_ads","cloud_sync"],
    "exp": "...", "sig": "<Ed25519>" }
```
- Webhooks idempotentes; fila de retry; reconciliação diária.
- Graça offline: vale até exp + 7 dias sem rede.
- Dunning sem apagar dado. Downgrade some com o recurso, não com o dado.
- Pix é assíncrono: `pending_payment` + confirmação por webhook.

## Canais (decidir em ADR-7)
| Canal | Pagamento | Nota |
|---|---|---|
| Google Play | Play Billing | comissão relevante |
| App Store | StoreKit | idem |
| F-Droid / APK direto | Pix, cartão, boleto | sem comissão de loja |
| Web (preferível) | checkout fora do app | melhor margem |

Preço por região no servidor (`price_book`), nunca fixo no app.
Confirme as regras vigentes da loja antes de implementar e cite a fonte no ADR-7.
