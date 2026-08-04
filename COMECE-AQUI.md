# COMECE AQUI

Este é o kit inicial do projeto Frankstein. Nenhum código de aplicativo ainda —
de propósito.

## O que fazer

```bash
# 1. Descompacte este kit numa pasta vazia e inicialize o git
cd frankstein
git init && git add . && git commit -m "chore: kit inicial do projeto"

# 2. Preencha as URLs em scripts/clone-refs.sh e rode
./scripts/clone-refs.sh

# 3. Abra o Claude Code nesta pasta
claude
```

## Primeira mensagem no Claude Code (copie exatamente)

> Leia `CLAUDE.md` e `STATUS.md`. Estamos na Fase 0, ciclo 1. Objetivo único:
> produzir `docs/recon/mlc-llm.md` a partir do modelo em `docs/recon/_MODELO.md`,
> lendo o repositório em `refs/mlc-llm`. A licença precisa ser lida literalmente
> do arquivo LICENSE, não deduzida. Não escreva nenhum código de aplicativo.
> Ao terminar, atualize `STATUS.md` e emita o relatório do ciclo.

Depois repita trocando o repositório. **Um repositório por ciclo, sete ciclos.**
Parece lento; é o que impede o relatório bonito sobre sete repositórios que ele
nunca abriu.

## Só depois das 7 fichas

- `docs/LICENSE-AUDIT.md` — matriz de compatibilidade
- `docs/VIABILITY.md` — o que entra no MVP, o que fica, o que sai
- ADR-1 a ADR-10 (lista em `docs/adr/000-pendentes.md`)

## Como o contexto é carregado

- `CLAUDE.md` — carrega toda sessão e sobrevive ao `/compact`. Por isso é curto.
- `.claude/rules/*.md` — as que têm `paths:` no topo aparecem sozinhas quando o
  Claude mexe nos arquivos correspondentes. `00-inviolaveis.md` não tem `paths`,
  então carrega sempre.
- `docs/*.md` — lidos sob demanda, quando o `CLAUDE.md` mandar.

Regra prática: quanto mais texto carregado, menor a aderência. Não engorde o
`CLAUDE.md`.

## Falta fazer (não incluído aqui)

`.claude/settings.json` com hooks de `PreToolUse` — a única coisa que **bloqueia**
de verdade, em vez de só pedir. Peça ao Claude Code para escrever, mandando ele
confirmar o schema atual em https://code.claude.com/docs/en/hooks antes.
Hooks desejados: barrar escrita em código de app enquanto as 7 fichas não
existirem; barrar dependência da lista proibida; barrar commit sem `make test`.
