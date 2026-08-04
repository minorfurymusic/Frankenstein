# CUSTOS — Frankstein

Levantado em agosto de 2026. Ordem de grandeza; confirme antes de contratar.

## Princípio
**Grátis = tudo que roda no aparelho. Pago = tudo que consome o meu servidor.**
Honesto, impossível de burlar mesmo com o código aberto (o que é pago não existe
no cliente), e mantém o custo marginal por usuário gratuito em zero.

## Custo ZERO por usuário (roda no aparelho)
Passos, treino, GPS, refeições, código de barras, BLE, **inferência do LLM**, OCR,
relatório PDF, cards de compartilhamento, notificações locais, SQLite, exportação.

## Custo que ESCALA com usuário (nunca oferecer grátis)
Backup e sync em nuvem; instância hospedada de Fasten/wger; conector FHIR;
LLM em nuvem; OCR em nuvem; painel B2B; **seu tempo de suporte**.

## Custo FIXO
| Item | Aproximado |
|---|---|
| Google Play (conta de desenvolvedor) | US$ 25 uma vez |
| Apple Developer | US$ 99/ano |
| Domínio | ~US$ 15/ano |
| VPS mínimo (Hetzner CX/CAX) | ~EUR 5,50–6,00/mês, 20 TB inclusos |
| Cloudflare R2 (modelos) | US$ 0 (egress zero, franquia de 10 GB) |
| MEI (Brasil) | ~R$ 76/mês |
| F-Droid | US$ 0 |

## Cenário: 1.000 usuários, ZERO pagantes
Download do modelo: 1.000 x 1,8 GB = ~1,8 TB.
- Cloudflare R2: **US$ 0** | VPS Hetzner: **US$ 0** | AWS S3: **~US$ 160**

Total mensal: **~US$ 23–30 (R$ 130–170)**, dominado por Apple + MEI.
Com 10.000 usuários gratuitos o valor é praticamente o mesmo: **nada nessa conta
escala por pessoa.**

O que sangraria: dar backup em nuvem e Fasten hospedado no plano gratuito.
Aí 1.000 usuários viram US$ 400–900/mês.

## Margem por assinante (R$ 20)
```
Receita bruta          R$ 20,00
- Play Store (15%)     R$  3,00   <- via Pix seria ~R$ 0,20
- Impostos             R$  1,20
- Storage (2 GB)       R$  0,17
- LLM nuvem (teto)     R$  1,50
= Margem              ~R$ 14,00
```
Um assinante paga a infraestrutura de cerca de 100 usuários gratuitos.
Conversão de 1–2% já sustenta o projeto.
