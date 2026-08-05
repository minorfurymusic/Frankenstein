# Ficha de reconhecimento — <Nome do repositório>

> Se a leitura não foi por clone (ex.: repositório bloqueado pelo proxy
> deste ambiente), diga isso na primeira linha e não afirme nada sobre
> build.

**Repositório:** <URL do clone>
**Commit avaliado:** `<hash>` (<data>)

## Licença

Lida literalmente de `<arquivo LICENSE/LICENSE.txt/LICENSE.md>` na raiz do
clone: **<licença>**. Cite o cabeçalho literal, não deduza pelo nome do
arquivo ou por um badge.

Verifique se há mais de um arquivo de licença no repositório
(`find . -iregex '.*/\(LICENSE\|COPYING\|NOTICE\)[^/]*'`) e se há
sublicenças por subdiretório (bibliotecas vendorizadas, fontes, dados de
conteúdo) — registre cada uma encontrada, mesmo que pareça irrelevante.

**Relevante para ADR-5:** como esta licença se compara às outras fichas já
prontas — é a mais restritiva, é permissiva pura, é o mesmo regime de
outra ficha?

## Stack observada

Confirmado abrindo o repositório (não deduzido da hipótese em
`docs/PRODUTO.md`): linguagem, framework, build system.

## Build

**Tentei compilar** ou **Não tentei compilar** — nunca deixe implícito.
Se tentou: comando exato, resultado literal, causa raiz do que falhou (e
se a causa é do projeto ou do ambiente, ex.: proxy bloqueando um
repositório Maven/registry). Se não tentou: motivo específico (toolchain
ausente, dependência vazia por clone raso, fora de escopo do ciclo).

## Observações

Qualquer achado que muda uma hipótese de `docs/PRODUTO.md`, aponta para um
padrão de absorção (PORT/WRAP/FEDERATE/VENDOR/HARVEST), ou é relevante para
outro documento (`docs/ARQUITETURA.md`, `docs/B2B.md`, `docs/MONETIZACAO.md`).
