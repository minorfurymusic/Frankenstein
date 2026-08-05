# ADR-4a — Gadgetbridge: FEDERATE via Health Connect ou fork sob AGPL?

**Status:** proposto
**Data:** 2026-08-05

## Contexto

`docs/recon/gadgetbridge.md` (ficha produzida sem clone, por leitura de
navegador — `codeberg.org` bloqueado pelo proxy deste ambiente) já
recomendou FEDERATE via Android Health Connect em vez de WRAP, com a
pergunta em aberto: o Gadgetbridge **escreve** passos/FC/sono no Health
Connect, ou só **lê** de lá? A dependência `androidx.health.connect.client`
prova integração, não a direção (`docs/recon/gadgetbridge.md`, seção
"PERGUNTA QUE DECIDE O RUMO"). `docs/adr/000-pendentes.md` registrou esta
ADR no Ciclo 7. O achado que resolve a pergunta já está na mesma ficha,
seção "Achado (Ciclo 7)" — com uma ressalva de fonte que pesa na decisão
desta ADR.

## Opções consideradas

1. **FEDERATE via Android Health Connect** — o Frankstein lê o Health
   Connect, nunca toca no código do Gadgetbridge nem chama API dele. Só
   funciona se o Gadgetbridge **escreve** no Health Connect.
2. **Fork sob AGPL-3.0** — embutir/manter um fork do Gadgetbridge força
   AGPL-3.0 sobre o Frankstein inteiro (`docs/LICENSE-AUDIT.md`, Cenário A)
   e herda a carga de manter sincronizado com um projeto de 16.839 commits
   em atividade diária (`docs/recon/gadgetbridge.md`).
3. **Exportação de arquivo** (o usuário exporta do Gadgetbridge e importa
   no Frankstein manualmente) — só necessária se a opção 1 não for viável
   (Gadgetbridge só lê do Health Connect, não escreve).

## Decisão

**Opção 1: FEDERATE via Android Health Connect.**

O achado do Ciclo 7 (`docs/recon/gadgetbridge.md`, seção "Achado (Ciclo 7)")
aponta que o Gadgetbridge **escreve** no Health Connect — duas fontes via
`WebSearch` convergem: a página oficial de integração (permissões
`WRITE_STEPS`, `WRITE_HEART_RATE`, `WRITE_SLEEP` citadas) e a listagem de
permissões do F-Droid (derivada do manifesto do APK, fonte mais primária).
Isso é o bastante para **propor** a opção 1, mas não para aceitá-la sem
ressalva.

**Isto está proposto, não aceito — com uma condição explícita para
aceitar:** a fonte do achado é busca indexada, não leitura direta do
manifesto/código (o proxy deste ambiente bloqueou tanto `codeberg.org`
quanto `gadgetbridge.org` — ver `docs/recon/gadgetbridge.md`). Antes de F9
(`docs/PRODUTO.md:51`, "Wearable BLE") depender disso de verdade,
confirme lendo o `AndroidManifest.xml`/código de sync do Gadgetbridge
diretamente, fora deste ambiente, do mesmo jeito que a ficha inteira foi
produzida.

## Consequências

- **Fica mais fácil:** nenhuma carga de licença (AGPL-3.0) nem de
  manutenção de fork recai sobre o Frankstein — o usuário mantém o
  Gadgetbridge por conta própria, o Frankstein só lê um provedor de dados
  do sistema Android.
- **Fica mais difícil:** o item 3 da Definição de Pronto do MVP
  (`docs/PRODUTO.md:62`, "Pulseira BLE sincroniza FC e sono") passa a
  depender de um app de terceiro instalado — já registrado como risco de
  produto em `docs/VIABILITY.md` ("Risco de MVP — item 3"). iOS não tem
  Health Connect — gap já registrado em ADR-1, precisa de HealthKit como
  equivalente, não investigado.
- **Passa a ser proibido:** copiar qualquer trecho de código do
  Gadgetbridge "só para consultar como faz" — risco de contaminação de
  licença que a própria ficha já sinaliza como alto e permanente.

## Não verificado

Tudo que depende do achado do Ciclo 7: a direção real de escrita do
Gadgetbridge no Health Connect só foi confirmada por busca indexada, não
por leitura do manifesto/código. Esta ADR fica **proposta** e não deve
virar **aceita** sem essa confirmação de primeira mão.
