# ADR-28 — Dados sobrevivem à reinstalação: chave fixa nos APKs de teste e "manter dados" ao desinstalar

**Status:** aceito (decisão explícita do usuário, 2026-10-20)
**Data:** 2026-10-20

## Contexto

O usuário pediu que, ao desinstalar o app, os dados cadastrados fiquem no
celular e voltem ao instalar de novo. Ele confirmou o motivo de desinstalar:
o APK novo do CI dá erro ao instalar por cima do antigo.

Os dados ficam na pasta interna do app (`app/lib/main.dart:21`), que o
Android apaga ao desinstalar. O backup automático do Android está desligado
de propósito (`app/android/app/src/main/AndroidManifest.xml`): mandaria dado
de saúde para a nuvem do Google sem ação da pessoa. O APK do CI era assinado
com a chave debug padrão, gerada de novo em cada run (deduzido pela leitura
de `.github/workflows/ci.yml`; não conferido comparando dois APKs).

## Opções consideradas

1. Chave de assinatura fixa nos APKs de teste + `android:hasFragileUserData`
   (Android 10+ pergunta "manter dados do app?" ao desinstalar).
2. Cópia automática numa pasta pública (Documentos/RLT) + "Restaurar" ao
   reinstalar. Mais trabalho (a importação não existe) e a cópia fica legível
   por outros apps com permissão de armazenamento.
3. Backup automático do Android (nuvem do Google). Descartado: dado de saúde
   sairia do aparelho sem ação da pessoa.

## Decisão

Opção 1: chave fixa nos segredos do repositório (`RLT_KEYSTORE_BASE64`,
`RLT_KEYSTORE_PASSWORD`, nunca no código) e `hasFragileUserData="true"`.

## Consequências

- Com a chave fixa, o APK novo instala por cima do antigo e os dados ficam.
- Ao desinstalar pelo sistema (Android 10+), aparece a opção de manter os
  dados; reinstalar com a mesma chave traz tudo de volta.
- A primeira troca da chave antiga para a fixa ainda exige uma última
  desinstalação.
- Android 9 ou anterior ignora o atributo: lá, desinstalar ainda apaga.
- Se a chave fixa for perdida, perde-se a atualização por cima. Guardar uma
  cópia fora do GitHub (o GitHub não deixa ler o segredo de volta).
- Não substitui a chave de lançamento (pendência em `docs/PENDENCIAS-V1.md`).
- Sem os segredos, o build continua funcionando com a chave debug padrão.
