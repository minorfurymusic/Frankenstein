# Frankstein — instruções do projeto

App de saúde 7-em-1, offline-first, com LLM local (MLC LLM) como cérebro que
recebe comandos em linguagem natural e distribui para os módulos.
Código aberto (copyleft). **Sem anúncios. Sem telemetria. Sem rastreador.**

## REGRAS INVIOLÁVEIS

1. Proibido dizer "feito", "corrigido", "funcionando" ou "integrado" sem colar a
   saída literal do comando que provou isso. Sem prova, o status é NÃO VERIFICADO.
2. Proibido citar arquivo, classe, API ou pacote que você não abriu.
   Cite sempre `caminho:linha`.
3. Se um ciclo não alterou o repositório, escreva `CICLO SEM PROGRESSO — causa: X`.
   Nunca reapresente um documento existente como se fosse trabalho novo.
4. Máximo 3 tentativas no mesmo erro. Na 3ª, pare e reporte BLOQUEIO com opções.
5. Todo código temporário leva `// TODO(frankstein): <o que falta>` e entra na
   seção "Débito Técnico" do relatório do ciclo.
6. Nunca adicione dependência proprietária: SDK de anúncio, ML Kit, Google Play
   Services, Firebase, Pixel/SDK social. Viola a licença copyleft dos módulos
   GPL/AGPL. Alternativas livres: ZXing, Tesseract, MapLibre/osmdroid,
   notificações locais.
7. Nada de rede sem ação explícita do usuário. O app funciona 100% offline.
8. Relatórios, comentários de decisão e ADRs em português. Código em inglês.

## ANTES DE COMEÇAR QUALQUER TAREFA

Leia `STATUS.md` (estado atual — histórico completo de ciclos fica em
`docs/HISTORICO.md`, consulte só sob demanda, não por hábito).
Declare em UMA linha o objetivo único deste ciclo.
Depois leia SOMENTE o documento da área que vai tocar:

- produto, escopo, fases ....... docs/PRODUTO.md
- arquitetura, camadas ......... docs/ARQUITETURA.md
- cérebro, LLM, offline ........ docs/OFFLINE-IA.md
- planos, pagamento ............ docs/MONETIZACAO.md
- custo de servidor ............ docs/CUSTOS.md
- profissionais, pacientes ..... docs/B2B.md
- decisão já tomada ............ docs/adr/

Não leia os outros. Não invente o conteúdo deles.

## LOOP DE EXECUÇÃO

ORIENTAR → INVESTIGAR → PLANEJAR → EXECUTAR → PROVAR → RELATAR → PORTÃO

Um ciclo = um objetivo. Ao chegar num portão (licença, custo, arquitetura, UX,
dado de saúde), PARE e pergunte antes de codificar.

## RELATÓRIO OBRIGATÓRIO AO FIM DO CICLO

```
## CICLO <N> — <objetivo>
Status: CONCLUÍDO | PARCIAL | FALHOU | BLOQUEADO | SEM PROGRESSO
### O que mudou de fato   (arquivo:linha + hash do commit)
### Prova                 (saída literal, sem edição)
### Não verificado
### Débito técnico criado
### Bloqueios / decisões que preciso de você
### Próximo ciclo proposto
```

## COMANDOS

- build:  `make build`
- testes: `make test`
- lint:   `make lint`

Nenhum ciclo termina sem `make test` executado e a saída colada.

## FASE ATUAL

**Fase 2 — esqueleto do monorepo (F2, `docs/PRODUTO.md`).**
Fases 0 (reconhecimento) e 1 (ADRs) concluídas — ver `docs/adr/000-pendentes.md`.
Shell Flutter em `app/`, pacotes vazios em `packages/*` conforme
`docs/ARQUITETURA.md`. Nenhum módulo, LLM ou banco implementado ainda —
isso entra fase a fase, cada um com sua própria ADR/ficha já aceita antes
de codificar.
