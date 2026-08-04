# OFFLINE-IA — o cérebro no aparelho

O celular do usuário é o servidor. Isso é o que torna o custo por usuário igual a zero.

## Perfis por capacidade do aparelho

| Perfil | RAM | Modelo | Download | O que faz |
|---|---|---|---|---|
| A — completo | >= 8 GB | 3B q4f16_1 | ~1,7–2,2 GB | conversa livre, resumos, tendências |
| B — assistente | 6 GB | 1,5B q4f16_1 | ~0,9–1,1 GB | comandos, extração, respostas curtas |
| C — leve | <= 4 GB | nenhum | 0 | roteador determinístico + templates |

O perfil C precisa funcionar **bem**, não ser um degradado triste: é a maior parte
do mercado brasileiro de Android. O roteador determinístico é o caminho principal,
não o plano B.

## Regras de implementação
1. O modelo nunca vai dentro do APK/AAB.
2. Download sob demanda, só no Wi-Fi por padrão, retomável, com hash verificado e
   tela avisando o tamanho antes.
3. O app é 100% funcional sem o modelo. Desinstalar o cérebro é um botão.
4. Descarregue o modelo da RAM ao ir para segundo plano ou ao iniciar GPS.
5. Teto térmico: se o aparelho esquentar, degrade para o roteador e avise.
6. Meça e publique em docs/PERF.md: tokens/s, RAM de pico, consumo por consulta.

## Distribuição dos pesos
Hospede em Cloudflare R2 (egress zero) ou na franquia de tráfego do VPS.
**Nunca em S3**: 1.000 usuários x 1,8 GB dariam cerca de US$ 160 no primeiro mês,
contra US$ 0 no R2.

## Base de alimentos offline
Subconjunto brasileiro do Open Food Facts embarcado (dezenas de MB), com
atualizações delta mensais. Sem isso, o código de barras vira dependente de rede
e a promessa offline quebra. Consulta ao catálogo completo é complemento, nunca
requisito.

## Licenças a respeitar aqui
ML Kit e Google Play Services são proprietários e recriariam o conflito com
GPL/AGPL. Use ZXing (código de barras), Tesseract (OCR), MapLibre/osmdroid (mapas).
