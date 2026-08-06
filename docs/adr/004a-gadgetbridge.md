# ADR-4a — Gadgetbridge: FEDERATE via Health Connect ou fork sob AGPL?

**Status:** aceito (confirmação explícita em 2026-08-06, depois da
revisão 2 — condição de primeira mão finalmente cumprida)
**Data:** 2026-08-05
**Revisão:** 2 (2026-08-06) — confirmação de primeira mão obtida por você,
fora deste ambiente (rede segue bloqueada aqui — ver "Achado (Ciclo 29)").
Ver "Achado (Ciclo 30)" abaixo.

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

**Opção 1: FEDERATE via Android Health Connect. Aceita.**

O achado do Ciclo 7 (`docs/recon/gadgetbridge.md`, seção "Achado (Ciclo 7)")
apontou que o Gadgetbridge **escreve** no Health Connect — duas fontes via
`WebSearch` convergiam, mas nenhuma era leitura de primeira mão. O Ciclo 29
tentou de novo e não conseguiu (rede deste ambiente bloqueia `codeberg.org`,
`gadgetbridge.org` e `f-droid.org` — ver "Achado (Ciclo 29)" abaixo). A
condição ficou pendente até você trazer, no Ciclo 30, a confirmação que
faltava — obtida por você, fora deste ambiente, do mesmo jeito que a ficha
original foi produzida.

**Condição cumprida — ver "Achado (Ciclo 30)" abaixo.** Permissão de
escrita declarada no manifesto do APK publicado (via listagem do F-Droid,
que extrai as permissões do binário distribuído — é o mesmo tipo de
evidência que a revisão anterior já chamava de "fonte mais primária", só
que agora com o texto literal das permissões, não um resumo de busca) é a
confirmação de primeira mão que esta ADR exigia. Documentação oficial do
projeto corrobora o alcance e a direção (provedor de dado, não consumidor).

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
- **Fica mais fácil (nova, Ciclo 30):** dado do Health Connect fica no
  aparelho, sem envio a servidor externo nem ao Google — coerente com
  offline-first sem desenho adicional, é a garantia que o próprio Health
  Connect já dá por definição de plataforma.
- **Fica mais difícil (nova, Ciclo 30):** Health Connect é nativo do AOSP
  só a partir do Android 14. Em Android 13 ou anterior, o usuário precisa
  instalar o app proprietário da Play Store para ter Health Connect — uma
  dependência proprietária **condicional à versão do Android do
  aparelho**, não ao Frankstein em si (o Frankstein não depende de nada
  proprietário; o *usuário* pode precisar instalar algo proprietário da
  Play Store dependendo do Android dele). Registrado em
  `docs/PLATFORM-PARITY.md`, Gap 2 — **não** entra nos perfis A/B/C da
  ADR-2, que são por RAM disponível para o LLM, um eixo diferente deste
  (versão do Android). Ver nota nessa ADR se isso causar confusão.

## Achado (Ciclo 30) — confirmação de primeira mão, trazida por você

Você trouxe a confirmação que faltava desde a revisão original, obtida
fora deste ambiente (mesma situação da ficha original de reconhecimento —
rede daqui não alcança nenhuma das três fontes primárias, confirmado de
novo no Ciclo 29).

**1. Permissões extraídas do APK publicado, via F-Droid.** A página do
pacote `nodomain.freeyourgadget.gadgetbridge` no F-Droid lista permissões
extraídas do APK em produção, incluindo `android.permission.health.WRITE_STEPS`,
`WRITE_SLEEP`, `WRITE_RESTING_HEART_RATE`, `WRITE_WEIGHT`, `WRITE_VO2_MAX`,
`WRITE_TOTAL_CALORIES_BURNED`. Permissão de **escrita** declarada no
manifesto do binário que usuários reais instalam — não é código-fonte que
eu li linha a linha, mas é a mesma classe de evidência (manifesto, não
busca), extraída de fora do projeto (F-Droid), de um artefato publicado.

**2. Documentação oficial confirma o alcance.**
`gadgetbridge.org/basics/integrations/health-connect/` lista os tipos
sincronizados: passos, distância, frequência cardíaca, SpO₂, glicose, VFC,
temperatura, frequência respiratória, FC de repouso, sessões de sono,
peso, VO₂ máx e sessões de exercício. Recurso lançado na versão 0.89.0 —
bate com o achado do Ciclo 29 (release note "Two big new features", PR
`#4481`), explicando por que o mirror arquivado do GitHub (item 2 do
Ciclo 29) não tinha nada disso: a feature é posterior ao arquivamento.

**3. Direção confirmada.** A documentação descreve o Gadgetbridge como
**provedor** de dado no Health Connect, outros apps como consumidores —
exatamente a direção que a Opção 1 (FEDERATE) precisa para funcionar.

**Ressalva de atribuição, por honestidade de processo:** eu não abri
`f-droid.org` nem `gadgetbridge.org` neste ciclo — tentei repetidamente
nos Ciclos 0 e 29 e os três domínios continuam bloqueados pela rede deste
ambiente. Esta confirmação vem de você, da mesma forma que
`docs/recon/gadgetbridge.md` já foi produzida (nota no topo do próprio
arquivo). Registro isso não para enfraquecer a decisão — o padrão de
evidência (permissão declarada no manifesto do binário publicado) é
sólido — mas porque a regra 2 do `CLAUDE.md` proíbe citar como "lido por
mim" o que não abri.

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

- **Resolvido no Ciclo 30** (histórico, não mais pendência): direção de
  escrita do Gadgetbridge no Health Connect — confirmada por permissão
  declarada no APK publicado (F-Droid) + documentação oficial.
- Equivalente ao Health Connect no iOS (HealthKit) — o Gadgetbridge é
  Android-only (`docs/recon/gadgetbridge.md`, seção Plataformas), então
  esta ADR não resolve o iOS. Já registrado como gap aberto em
  `docs/PLATFORM-PARITY.md`, Gap 2 — não investigado ainda, fora do
  escopo desta ADR.
- Se a PR `#4481` do codeberg foi de fato o commit que introduziu a
  feature, e a data exata — não é mais necessário para a decisão (a
  documentação oficial e a permissão do APK já bastam), mas fica como
  curiosidade não fechada.
