# Ficha de reconhecimento — FoodYou

> `docs/recon/_MODELO.md` é o template de ADR, não de ficha de repositório
> (débito técnico registrado em `STATUS.md` no Ciclo 1).

**Repositório:** https://github.com/maksimowiczm/FoodYou.git
**Commit avaliado:** `00637df98ef36b6503e796f7d5152275b201022b` (2026-06-27)

## Licença

Lida literalmente de `LICENSE` na raiz do clone: **GNU General Public
License, Version 3** (cabeçalho: "GNU GENERAL PUBLIC LICENSE / Version 3,
29 June 2007", Copyright FSF). Único arquivo de licença no repositório
(`find . -iregex '.*/\(LICENSE\|COPYING\|NOTICE\)[^/]*'` → só `./LICENSE`).
Arquivos-fonte amostrados (`app/src/commonMain/kotlin/...`) não têm
cabeçalho de licença próprio — nada divergente do `LICENSE` raiz encontrado.

**Relevante para ADR-5:** GPL-3.0 puro, copyleft forte — consistente com a
decisão já tomada de aceitar copyleft no projeto (`STATUS.md`, "Decisões já
tomadas"). Não é o caso mais restritivo do conjunto por si só, mas confirma
que o app final não pode evitar GPL/AGPL de qualquer forma.

## Stack observada

Confirmado abrindo o repositório: **Kotlin Multiplatform / Compose**
(estrutura `app/src/commonMain/kotlin/...`, 600 arquivos `.kt`, 0 `.java`),
não Android/Compose puro como `docs/PRODUTO.md` descrevia como hipótese —
é Kotlin Multiplatform, o que é uma variação relevante (implica possível
alvo além de Android, a confirmar com `dev/`, `shared/` ainda não lidos a
fundo). Build: Gradle 8.13 (wrapper), plugin `com.android.application`
8.13.2, também há `flake.nix`/`flake.lock` (build alternativo via Nix, não
testado).

## Build

**Tentei compilar.** `./gradlew tasks` (timeout 90s):
1. Gradle 8.13 baixou e instalou com sucesso.
2. Falhou resolvendo o plugin `com.android.application` versão `8.13.2`:
   "Plugin ... was not found in any of the following sources" — procurou em
   Google, MavenRepo e Gradle Central Plugin Repository e não achou.

Mesma causa raiz da ficha do OpenTracks: o repositório Maven do Google
(`dl.google.com`) está bloqueado pela política de rede deste ambiente.
Build não avançou além da resolução de plugins.

## Observações para Fase 0 / PRODUTO.md

- `docs/PRODUTO.md` descreve a stack do FoodYou como "Android/Compose"; o
  clone mostra Kotlin Multiplatform. Não corrigi `docs/PRODUTO.md` neste
  ciclo — o objetivo declarado era só a ficha; fica marcado aqui para o
  próximo ciclo que tocar `docs/PRODUTO.md`.
- Presença de `flake.nix` sugere que o time do FoodYou já lida com
  reprodutibilidade de build fora do Gradle padrão; pode valer a pena para
  o monorepo do Frankstein mais adiante (Fase 2), mas isso é decisão de
  ADR, não deste ciclo.
