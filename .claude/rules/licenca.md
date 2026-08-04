---
paths:
  - "**/pubspec.yaml"
  - "**/pubspec.lock"
  - "**/build.gradle"
  - "**/build.gradle.kts"
  - "**/*.podspec"
  - "**/Podfile"
  - "**/package.json"
  - "**/go.mod"
  - "**/requirements*.txt"
---
# Regras de licença ao mexer em dependências

O projeto é copyleft (GPL/AGPL herdados dos módulos absorvidos).

PROIBIDO adicionar, em qualquer sabor de build:
- SDKs de anúncio (AdMob, Meta Audience Network, AppLovin, Unity Ads)
- Google Play Services, ML Kit, Firebase (qualquer módulo)
- SDKs sociais proprietários (Facebook SDK, Pixel, TikTok SDK)
- Qualquer binário sem fonte disponível

USE no lugar:
- código de barras .... ZXing (Apache-2.0)
- OCR ................. Tesseract (Apache-2.0)
- mapas ............... MapLibre / osmdroid
- notificações ........ notificações locais do sistema
- compartilhamento .... share sheet nativo (sem SDK)

Antes de adicionar QUALQUER dependência nova:
1. Registre nome, versão e licença no relatório do ciclo.
2. Se a licença não for permissiva ou compatível com copyleft, PARE e pergunte.
