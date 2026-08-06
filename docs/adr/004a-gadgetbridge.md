# ADR-4a — Gadgetbridge: FEDERATE via Health Connect ou fork sob AGPL?

**Status:** proposto
**Data:** 2026-08-05
**Revisão:** 1 (2026-08-06) — tentativa de confirmação de primeira mão,
ver "Achado (Ciclo 29)" abaixo. Continua proposta: a condição que a
própria ADR exige não foi cumprida por completo.

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

## Achado (Ciclo 29) — tentativa de leitura de primeira mão

Tentei cumprir a condição da revisão original. Resultado misto, registrado
por completo porque contradiz o achado do Ciclo 7 antes de ser explicado.

**1. Rede bloqueada, de novo, confirmado de novo:** `codeberg.org`,
`gadgetbridge.org` e `f-droid.org` — os três `HTTP 403`
(`CONNECT tunnel failed`) neste ambiente. Mesma causa da ficha original,
não é falha pontual.

**2. Mas existe um mirror no GitHub, e esse eu consegui ler de verdade —
`raw.githubusercontent.com` não está bloqueado.** Li os arquivos reais,
não resumo de busca:
```
$ curl raw.githubusercontent.com/Freeyourgadget/Gadgetbridge/master/app/src/main/AndroidManifest.xml
$ grep -in "health" AndroidManifest.xml
(nenhum resultado)

$ curl raw.githubusercontent.com/Freeyourgadget/Gadgetbridge/master/app/build.gradle
$ grep -in "health" build.gradle
(nenhum resultado)

$ curl raw.githubusercontent.com/Freeyourgadget/Gadgetbridge/master/CHANGELOG.md
$ grep -in "health connect" CHANGELOG.md
(nenhum resultado, 2480 linhas)
```
Zero referência a Health Connect em nenhum dos três — o oposto do achado
do Ciclo 7. **Mas** o próprio README desse mirror diz: *"Gadgetbridge is
now hosted on codeberg.org"*, e a busca de arquivo do GitHub confirma o
repositório **arquivado em 2026-02-24, somente leitura**. Ou seja: essa
leitura de primeira mão é real, mas é de um snapshot congelado de
fevereiro — não do `master` atual do codeberg (hoje é agosto). Não prova
que o Gadgetbridge não tem Health Connect; prova que não tinha até a data
do arquivamento.

**3. `WebSearch` de novo, mais específico que o do Ciclo 7:** achou a PR
`#4481` ("Health Connect Integration") e a issue `#3121` ("Health Connect
API support") no codeberg, a página oficial
`gadgetbridge.org/basics/integrations/health-connect/`, e o post de
release "Gadgetbridge 0.89.0: Two big new features". O resumo do modelo
de busca (não é leitura direta, é resumo de terceiro) descreve um caminho
de UI específico — "Settings → External Integrations → Health Connect" —
e reafirma escrita de `WRITE_STEPS`/`WRITE_HEART_RATE`. Bate com o achado
do Ciclo 7, e a existência de uma PR nomeada + release note batendo com
"duas grandes novidades" é consistente com isso ser uma feature
relativamente recente — o que também explicaria por que o mirror
arquivado (item 2) não tem nada disso.

**Conclusão honesta:** as duas fontes não se contradizem de verdade —
prova mais provável é que a feature foi mergeada **depois** do
arquivamento do mirror do GitHub, então o item 2 (primeira mão) é real
mas desatualizado, e o item 3 (busca) é mais recente mas continua sendo
busca indexada, não leitura direta do `master` de hoje. **A condição que
esta ADR exige — ler o manifesto/código atual diretamente — continua não
cumprida**, apesar do esforço adicional. Não vou marcar como aceita só
com isso.

## Não verificado

- A direção de escrita do Gadgetbridge no Health Connect no `master`
  atual do codeberg — não lido de primeira mão (rede bloqueada), só
  inferido por busca indexada (item 3 acima) e por um mirror desatualizado
  que mostra ausência da feature antes de 2026-02-24 (item 2 acima).
- Se a PR `#4481` foi de fato mergeada, e em que data — não confirmado,
  só a existência da PR/issue via busca.
- Esta ADR fica **proposta** e não deve virar **aceita** sem confirmação
  de primeira mão do `master` atual — a mesma condição da revisão
  original, ainda não satisfeita.
