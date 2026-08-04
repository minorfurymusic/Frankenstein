.PHONY: build test lint recon

build:
	@echo "ERRO: alvo 'build' ainda não implementado. Fase 2 do plano." && exit 1

test:
	@echo "ERRO: alvo 'test' ainda não implementado. Fase 2 do plano." && exit 1

lint:
	@echo "ERRO: alvo 'lint' ainda não implementado. Fase 2 do plano." && exit 1

recon:
	@ls -1 docs/recon/*.md | grep -v _MODELO | wc -l | xargs -I{} echo "Fichas de reconhecimento prontas: {}/7"
