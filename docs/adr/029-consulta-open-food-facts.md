# ADR-29 — Código de barras não encontrado: consultar o Open Food Facts pela internet

**Status:** proposto (aguarda decisão do usuário)
**Data:** 2026-10-20

## Contexto

No teste no aparelho, a foto do código de barras de um energético Bally
voltou sem a marca e com calorias estimadas. O código de barras é só um
número: marca e calorias vêm de uma base de produtos, e o app só tem os
itens que a pessoa cadastrou. O ciclo de 2026-10-20 (commit `f75290c`)
fez a foto copiar o rótulo em vez de estimar. Faltam a marca e os valores
quando a tabela não aparece na foto.

Já decidido antes (`docs/OFFLINE-IA.md`, "Base de alimentos offline"):
subconjunto brasileiro do Open Food Facts **embarcado** no app. "Consulta
ao catálogo completo é complemento, nunca requisito." O embarcado está
parado: este ambiente não alcança o Open Food Facts (`docs/HISTORICO.md`,
ciclos da base de alimentos), e `docs/PENDENCIAS-V1.md` (seção 4) espera os
CSVs do usuário.

## Opções consideradas

1. **Só o embarcado** (já decidido): funciona sem internet. Depende dos
   CSVs e o app cresce dezenas de MB. Produto novo só entra na atualização.
2. **Consulta pela internet, por toque da pessoa**, quando o código não
   está no celular: botão "Buscar na base pública (Open Food Facts)" na
   tela "Produto não encontrado" e no Cérebro. Vai só o número do código.
   O resultado vira cartão para conferir e, ao confirmar, item da pessoa
   com o código (o leitor acha sozinho da próxima vez, sem rede).
3. Os dois: embarcado primeiro; a consulta pela internet só quando o
   embarcado não tiver o produto.

## Decisão

Pendente. Recomendação: opção 3, começando pela 2 (não depende dos CSVs).

## Consequências (se aceita a opção 2 ou 3)

- Primeira chamada de rede fora da IA. Respeita a regra 7 (só por ação
  explícita) e `.claude/rules/00-inviolaveis.md`: nenhum dado de saúde vai,
  só o número do código. Sem consulta automática nem em segundo plano.
- Licença (**de memória, não conferida nesta sessão**: a rede deste ambiente
  bloqueia `openfoodfacts.org`): base em ODbL 1.0, conteúdo em DbCL 1.0,
  fotos em CC BY-SA. Exige atribuição ("dados do Open Food Facts") na tela e
  em Conta › Sobre. O app não vai baixar as fotos. Conferir antes de aceitar.
- A API pede um User-Agent próprio e tem limite de leituras por minuto
  (também de memória). Sem chave nem conta.
- A cobertura brasileira é incompleta: o produto pode não estar lá. Nesse
  caso, segue o caminho atual (foto da tabela ou cadastrar à mão).
- Não dá para testar contra o serviço real neste ambiente: só com
  transporte falso aqui, e de verdade no celular.
