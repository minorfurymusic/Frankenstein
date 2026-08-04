# Ficha de reconhecimento — Fasten Health

> `docs/recon/_MODELO.md` é o template de ADR, não de ficha de repositório
> (débito técnico registrado em `STATUS.md` no Ciclo 1).

**Repositório:** https://github.com/fastenhealth/fasten-onprem.git
**Commit avaliado:** `36d92446884e9e20eda8d2b2a0a1115c9c57f7ef` (2026-02-12)

## Licença

Lida literalmente de `LICENSE.md` na raiz do clone (não há `LICENSE` sem
extensão): **GNU General Public License, Version 3** (cabeçalho: "GNU
GENERAL PUBLIC LICENSE / Version 3, 29 June 2007", Copyright FSF). Único
arquivo de licença no repositório
(`find . -iregex '.*/\(LICENSE\|COPYING\|NOTICE\)[^/]*'` → só
`./LICENSE.md`). Nada divergente por subdiretório encontrado.

**Nuance de negócio, não de licença de código** (vale registrar): o
`README.md` deixa explícito que este repositório (`fasten-onprem`) é só o
PHR self-hosted de código aberto, e que existe um produto separado e
proprietário, "Fasten Connect", que **não está neste repositório** e não é
GPL. Não avaliei o Fasten Connect — não faz parte dos 7.

**Relevante para ADR-5:** GPL-3.0 puro, mesmo regime do FoodYou e do
OpenNutriTracker.

## Stack observada

Confirmado abrindo o repositório: **backend Go** (`go.mod`: `module
github.com/fastenhealth/fasten-onprem`, `go 1.21.1`, `toolchain go1.24.2`)
+ **frontend Angular** (`frontend/package.json`: `@angular/*` ^14.1.3,
`yarn.lock`) — bate com a hipótese "Go, self-hosted" em `docs/PRODUTO.md`,
com o detalhe adicional de que o frontend é Angular, não algo embutido no
binário Go.

## Build

**Tentei compilar.** `go build ./...` (timeout 180s, `go1.24.7` disponível
no ambiente, satisfaz o `toolchain go1.24.2` do `go.mod`):
- A maior parte das dependências (dezenas de módulos) baixou com sucesso
  via `proxy.golang.org` (liberado neste ambiente).
- Falhou em `github.com/fastenhealth/fasten-sources@v0.6.25`: esse módulo
  não está publicado num proxy de módulos, então o Go tentou `git
  ls-remote` diretamente no GitHub e falhou —
  `fatal: could not read Password for 'http://local_proxy@127.0.0.1:41729':
  terminal prompts disabled`. É bloqueio de rede/autenticação do ambiente
  para acesso direto a repositórios git (fora do proxy de módulos padrão),
  não um erro de código do Fasten.
- Efeito colateral do mesmo problema: `backend/resources/related_versions.go`
  também falhou (`pattern related_versions.json: no matching files found`),
  provavelmente um arquivo gerado que depende do módulo não resolvido.

Não tentei o frontend Angular (`yarn install`) neste ciclo — o bloqueio do
backend já é suficiente para não fechar "compila" sem ressalva, e o tempo
do ciclo foi para o achado do backend.

## Observações

- `fasten-sources` é outro repositório do mesmo projeto (`fastenhealth/`),
  não um dos 7 escolhidos — não abri esse repositório, então não posso
  citar sua licença ou conteúdo aqui.
