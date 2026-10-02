# ADR-12 — Android apenas; nome do produto: RLT — Real Life Track

**Status:** aceito (decisão explícita do usuário, 2026-10-02) — altera ADR-1 e ADR-7
**Data:** 2026-10-02

## Contexto

ADR-1 escolheu Flutter como shell único pensando em Android e iOS, e
deixou dois buracos de iOS sem solução (GPS/OpenTracks e wearable/Health
Connect, consolidados em `docs/PLATFORM-PARITY.md`). Não há Mac/Xcode no
ambiente de desenvolvimento, e nenhuma linha de código iOS foi escrita.
O produto também não tinha nome comercial — "Frankstein" é o nome de
trabalho do repositório.

## Opções consideradas

1. Manter iOS no plano (ADR-1 como está).
2. Android apenas, iOS fora de escopo.

## Decisão

**Opção 2.** iOS abandonado. O produto se chama **RLT — Real Life Track**.

- Flutter continua como shell (ADR-1 vale para o resto: UI única,
  módulos nativos por platform channel).
- Os buracos de iOS de `docs/PLATFORM-PARITY.md` deixam de ser pendência —
  ficam como registro histórico.
- Canais de distribuição (ADR-7): App Store sai da lista. Ficam Google
  Play, F-Droid e APK direto. O resto da ADR-7 (sem venda dentro do app,
  fluxo "Já assinei" com e-mail + código) continua igual.
- Licença (ADR-5) **não muda**: o cliente segue Apache-2.0 com PORT em
  clean room do módulo de nutrição. O argumento de App Store da ADR-5
  perde força, mas o argumento principal (não depender da manutenção de
  código de terceiros) continua de pé. Mudar a licença seria outra
  decisão, não consequência desta.

## Consequências

- **Fica mais fácil:** uma plataforma só pra desenhar, testar e
  distribuir; nenhum caminho HealthKit/GPS iOS a construir.
- **Fica mais difícil:** fora do iPhone — mercado perdido, por escolha.
- **Passa a ser proibido:** gastar esforço em código específico de iOS sem
  nova decisão revertendo esta.
- **Pendente (não feito nesta ADR):** renomear o app de verdade — nome
  exibido (`android:label`), `applicationId` (`br.com.frankstein.frankstein`
  em `app/android/app/build.gradle.kts`), ícone. Trocar o `applicationId`
  antes do lançamento é barato; depois do lançamento quebra a atualização
  de quem já instalou. Fazer junto com o layout novo.
