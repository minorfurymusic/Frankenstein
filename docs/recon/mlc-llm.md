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

**Atualização (Ciclo B, 2026-08-05) — submódulos lidos.** Rodei
`git -C refs/mlc-llm submodule update --init --depth 1`. Na primeira
tentativa o `tvm` ficou num estado quebrado (HEAD apontando pra um commit
real, mas working tree vazio e index cheio de entradas "deleted" —
provavelmente interrompido no meio do checkout, é o maior dos 6). Repeti
isolado com `--force` para esse submódulo e completou limpo na 2ª
tentativa; os outros 5 vieram completos já na primeira. Todos os 6 estão
com conteúdo e `git status` limpo agora. Licença de cada um, lida
literalmente do arquivo `LICENSE` em `3rdparty/<nome>/`:

| Submódulo | Commit avaliado | Licença (literal) |
|---|---|---|
| `argparse` | `557948f1236db9e27089959de837cc23de6c6bbd` | MIT |
| `googletest` | `45804691223635953f311cf31a10c632553bbfc3` | BSD-3-Clause |
| `stb` | `ae721c50eaf761660b4f90cc590453cdb0c2acd0` | Dupla licença: MIT **ou** Unlicense (domínio público), à escolha de quem usa |
| `tokenizers-cpp` | `34885cfd7b9ef27b859c28a41e71413dd31926f5` | Apache-2.0 |
| `tvm` (fork `mlc-ai/relax.git`, não o TVM oficial) | `837cb9de1127b48ce48e4cefe09e83215b9d4ba7` | Apache-2.0 |
| `xgrammar` | `d4f57c440f3da8e7330a1e5d50bba9c31f9433ea` | Apache-2.0 |

**Todas permissivas — nenhuma copyleft.** Isso **não muda a conclusão**
de `docs/LICENSE-AUDIT.md`: o MLC LLM continua permissivo de ponta a
ponta até onde foi possível verificar, sem contaminação de GPL/AGPL vinda
dos submódulos. Aviso explícito pedido: não houve mudança de conclusão.

**Achado novo, uma camada mais funda:** `tvm/licenses/` tem mais 6
licenças de bibliotecas que o próprio TVM vendoriza —
`builtin_fp16` (LLVM, Apache-2.0 with LLVM Exceptions), `cutlass` (NVIDIA,
BSD-3-Clause), `cutlass_fpA_intB_gemm` (Apache-2.0), `libflash_attn`
(BSD-3-Clause), `tensorrt_llm` (Apache-2.0), `vllm` (Apache-2.0) — lidas
literalmente do cabeçalho de cada arquivo em `3rdparty/tvm/licenses/`.
Também todas permissivas. Não fui mais fundo que isso (ex.: se alguma
dessas por sua vez vendoriza outra coisa) — três camadas de submódulo
aninhado é razoável parar por ciclo.

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
  aceito no projeto, ver `STATUS.md`). **Atualização Ciclo B:** as 6
  licenças de submódulo foram lidas e são todas permissivas (MIT, BSD-3,
  Apache-2.0, MIT/Unlicense) — o buraco que bloqueava o fechamento deste
  ponto do ADR-5 está fechado. `docs/LICENSE-AUDIT.md` pode ser atualizado
  para remover essa ressalva específica.
