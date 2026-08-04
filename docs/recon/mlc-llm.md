# Ficha de reconhecimento — MLC LLM

> Nota sobre o modelo: `docs/recon/_MODELO.md` contém o template de ADR
> ("ADR-<N> — <título>, Contexto, Opções, Decisão, Consequências"), não um
> template de ficha de repositório. É inconsistência do kit, registrada em
> "Débito técnico" no relatório do ciclo. Esta ficha usa a estrutura de campos
> que você pediu na mensagem do Ciclo 1-6 (commit, licença literal, build).

**Repositório:** https://github.com/mlc-ai/mlc-llm.git
**Commit avaliado:** `2f78caa4db0f90730a11ee3bb5cbd5f23bf67f9f` (2026-07-30, clone raso `--depth 1`)

## Licença

Lida literalmente de `LICENSE` na raiz do clone: **Apache License, Version 2.0**
(cabeçalho: "Apache License / Version 2.0, January 2004").
`NOTICE`: "MLC LLM — Copyright (c) 2023-2025 by MLC LLM Contributors".

Nenhum outro arquivo `LICENSE`/`COPYING` no repositório principal
(`find . -iregex '.*/\(LICENSE\|COPYING\|NOTICE\)[^/]*'` → só `./LICENSE` e
`./NOTICE`). Cabeçalho de `pyproject.toml` também cita Apache-2.0
explicitamente, consistente com o `LICENSE`.

**Divergência relevante:** o projeto depende de 6 submódulos git em
`3rdparty/` (`argparse`, `tokenizers-cpp`, `googletest`, `tvm`, `stb`,
`xgrammar`), cada um com sua própria licença — **não avaliada aqui**, porque
o clone raso (`scripts/clone-refs.sh` usa `git clone --depth 1`, sem
`--recurse-submodules`) deixou esses diretórios vazios. `tvm` aponta para
`https://github.com/mlc-ai/relax.git` (fork do TVM usado pelo MLC), não o
TVM oficial. Antes de qualquer ADR de licenciamento (ADR-5), essas 6
licenças de submódulo precisam ser lidas — Apache-2.0 no projeto principal
não garante que os submódulos sejam.

## Stack observada

Confirmado abrindo o repositório (não deduzido): C++ (`cpp/`, `CMakeLists.txt`),
Python (`python/`, `pyproject.toml`), bindings móveis nativos em
`android/mlc4j` (Java/Kotlin) e `ios/MLCSwift` (Swift) — relevantes para
`.claude/rules/brain.md`, que já assume módulo `mlc_*` / `*brain*` no shell
do app. Build system: CMake + Ninja no nível C++; wheel Python via
`pyproject.toml`.

## Build

**Não tentei compilar.** Motivo: os 6 submódulos em `3rdparty/` (inclusive o
TVM/`relax`, que é o compilador ML usado pelo projeto) estão vazios porque o
clone foi raso e sem `--recurse-submodules`; um build real exigiria clonar
todos eles (GBs de código, incluindo o próprio TVM) mais um toolchain LLVM e
um backend de GPU (Vulkan/CUDA/ROCm/Metal conforme a plataforma-alvo) —
fora do escopo e do tempo de um ciclo de reconhecimento. `python3`, `cmake`
e `ninja` estão disponíveis no ambiente, mas isso não foi suficiente nem
testado como pré-requisito.

## Observações para Fase 0 / OFFLINE-IA.md

- Confirma o que `docs/OFFLINE-IA.md` já assume: existe binding Android
  (`mlc4j`) e iOS (`MLCSwift`) prontos, não é preciso escrever a ponte do
  zero — mas ainda não sei o tamanho/RAM real de cada perfil A/B/C sem rodar
  o modelo, que não foi tentado aqui.
- Apache-2.0 no core é compatível com o restante do conjunto (copyleft
  aceito no projeto, ver `STATUS.md`), mas as licenças dos 6 submódulos
  ficam pendentes — não posso assinar o ADR-5 com esse buraco.
