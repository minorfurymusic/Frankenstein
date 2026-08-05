.PHONY: build test lint recon bootstrap

# Requer Flutter 3.35.5 (stable) e Dart 3.9.x no PATH — mesma versão usada
# para criar este esqueleto (Fase 2, Ciclo 1). `flutter build apk` requer
# Android SDK além disso; ambiente de dev/CI precisa ter os dois.

PACKAGES := health_core brain tool_registry activity nutrition entitlements share

# `pub get` primeiro, sempre — checkout limpo (CI, clone novo) não tem
# .dart_tool/ resolvido. Achado real do Ciclo 27: sem isso, lint/test
# passam local (porque eu já tinha rodado `pub get` na mão) e quebram no
# CI (checkout limpo). Não repetir.
bootstrap:
	@set -e; \
	for pkg in $(PACKAGES); do \
		echo "== dart pub get: $$pkg =="; \
		(cd packages/$$pkg && dart pub get); \
	done; \
	echo "== flutter pub get: app =="; \
	(cd app && flutter pub get)

build: bootstrap
	@cd app && flutter build apk --debug

test: bootstrap
	@set -e; \
	for pkg in $(PACKAGES); do \
		echo "== dart test: $$pkg =="; \
		(cd packages/$$pkg && dart test); \
	done; \
	echo "== flutter test: app =="; \
	(cd app && flutter test)

lint: bootstrap
	@set -e; \
	for pkg in $(PACKAGES); do \
		echo "== dart analyze: $$pkg =="; \
		(cd packages/$$pkg && dart analyze --fatal-infos); \
	done; \
	echo "== flutter analyze: app =="; \
	(cd app && flutter analyze --fatal-infos)

recon:
	@ls -1 docs/recon/*.md | grep -v _MODELO | wc -l | xargs -I{} echo "Fichas de reconhecimento prontas: {}/7"
