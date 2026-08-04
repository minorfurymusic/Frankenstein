# Ficha de reconhecimento — OpenTracks

> `docs/recon/_MODELO.md` é o template de ADR, não de ficha de repositório
> (débito técnico registrado em `STATUS.md` no Ciclo 1). Estrutura de campos
> abaixo segue o que foi pedido na mensagem do Ciclo 1-6.

**Repositório:** https://github.com/OpenTracksApp/OpenTracks.git
**Commit avaliado:** `3c23a9f5400c7b5b914a221469d76cc019a18296` (2025-08-24)

## Licença

Lida literalmente de `LICENSE` na raiz do clone: **Apache License, Version 2.0**
(cabeçalho: "Apache License / Version 2.0, January 2004"). Único arquivo de
licença no repositório (`find . -iregex '.*/\(LICENSE\|COPYING\|NOTICE\)[^/]*'`
→ só `./LICENSE`), sem divergência por subdiretório encontrada.

**Relevante para ADR-5:** este é, dos 6 repositórios com ficha até agora, o
único com licença permissiva pura — não agrava o copyleft herdado dos
demais módulos GPL/AGPL. Isso muda a conversa do ADR-5: dá para tratar
OpenTracks como VENDOR/WRAP sem forçar o app inteiro a herdar GPL/AGPL por
causa dele especificamente (os outros módulos já forçam isso de qualquer
forma, mas vale registrar com destaque como você pediu).

## Stack observada

Confirmado abrindo o repositório: Android nativo, **100% Java** (276 arquivos
`.java` em `src/`, 0 `.kt`) — não Flutter, ao contrário do que
`docs/PRODUTO.md` assumia como hipótese antes desta ficha (coluna já estava
marcada "CONFIRMAR"). Gradle (`build.gradle`, wrapper Gradle 9.0.0),
`compileSdk = 36`, `minSdk = 26`, `targetSdk = 36`.

## Build

**Tentei compilar.** `./gradlew tasks` (timeout 90s):
1. Baixou e instalou Gradle 9.0.0 com sucesso (`services.gradle.org` não é
   bloqueado pelo proxy do ambiente).
2. Falhou na etapa de configuração: não conseguiu resolver
   `com.android.tools.build:gradle:8.11.1` — `Could not GET
   'https://dl.google.com/dl/android/maven2/...'. Received status code 403
   from server: Forbidden`.

Causa: o proxy de saída deste ambiente bloqueia `dl.google.com` (repositório
Maven do Google, necessário para o Android Gradle Plugin), mesmo padrão de
política que já bloqueou `codeberg.org` para o Gadgetbridge. Além disso não
há Android SDK instalado (`ANDROID_HOME` vazio), então mesmo resolvendo as
dependências o build pararia no passo seguinte. Build não avançou além da
configuração do Gradle.

## Observações para Fase 0 / PRODUTO.md

- `docs/PRODUTO.md` já foi atualizado (Ciclo 0.6) para "OpenTracks —
  Corrida, caminhada e GPS"; esta ficha confirma a stack como Android/Java
  puro, então a coluna "CONFIRMAR" pode ser fechada para "Android (Java),
  Gradle".
- Padrão de absorção mais provável, a decidir por ADR: **WRAP** (embutir
  como módulo/dependência Android nativo) é mais barato que **PORT**
  (reescrever GPS/rota/pace do zero), dado que `docs/ARQUITETURA.md` ainda
  não foi lido neste ciclo — decisão de shell fica para ADR-1, não aqui.
