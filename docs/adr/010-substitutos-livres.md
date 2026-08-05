# ADR-10 — Substitutos livres de dependências proprietárias

**Status:** proposto
**Data:** 2026-08-05

## Contexto

`CLAUDE.md` (regra inviolável 6) e `.claude/rules/licenca.md:17-28` já
proíbem SDK de anúncio, Google Play Services/ML Kit/Firebase e SDK social
proprietário, com uma lista de substitutos livres específica. Essa lista
já existe como regra — nunca foi confrontada com o que os 7 repositórios
de fato usam. É isso que esta ADR faz: formaliza a regra e registra o que
foi (e o que **não foi**) verificado nas fichas de reconhecimento.

## Opções consideradas

1. **Manter a lista de substitutos já definida em `.claude/rules/licenca.md`**,
   sem alteração, e adicionar como próximo passo obrigatório uma auditoria
   de dependências por repositório antes de qualquer WRAP/VENDOR virar
   código real.
2. **Permitir exceções caso a caso** (ex.: usar Firebase Cloud Messaging só
   para notificação push, sem o resto do Firebase) — rejeitada: `CLAUDE.md`
   já lista Firebase como proibido "qualquer módulo", sem exceção, e abrir
   uma aqui contradiria uma regra inviolável sem motivo novo.

## Decisão

**Opção 1.** A lista de substitutos já definida vale como está:

| Necessidade | Proibido | Substituto livre |
|---|---|---|
| Código de barras | ML Kit | ZXing (Apache-2.0) |
| OCR | ML Kit | Tesseract (Apache-2.0) |
| Mapas | Google Maps SDK | MapLibre / osmdroid |
| Notificações | Firebase Cloud Messaging | notificações locais do sistema |
| Compartilhamento | SDK social proprietário | share sheet nativo, sem SDK |

Antes de qualquer dependência nova entrar no monorepo (Fase 2 em diante):
nome, versão e licença registrados no relatório do ciclo; se a licença não
for permissiva ou compatível com o copyleft do projeto (ver
`docs/LICENSE-AUDIT.md`), o ciclo para e pergunta — não decide sozinho.

**Isto está proposto, não aceito.** É portão de licença.

## Consequências

- **Fica mais fácil:** a lista já existe, testada contra as regras
  inegociáveis do projeto — não é preciso escolher de novo cada substituto
  quando a Fase 2 chegar.
- **Fica mais difícil:** nenhuma das 7 fichas de reconhecimento fez
  auditoria de dependência transitiva completa contra esta lista — ver
  "Não verificado" abaixo. Isso vira trabalho obrigatório antes de WRAP ou
  VENDOR de qualquer um dos 7, não депois.
- **Passa a ser proibido:** adicionar qualquer dependência (direta ou
  transitiva) que puxe Play Services/ML Kit/Firebase por baixo, mesmo que
  o pacote de fachada pareça livre — checar a árvore de dependência
  inteira, não só o nome do pacote raiz.

## Não verificado

Das 7 fichas, só a do **Gadgetbridge** checou explicitamente ausência de
Firebase/Play Services/SDK de anúncio/rastreador (`docs/recon/gadgetbridge.md`,
seção Técnico: "Nenhum Firebase, Play Services, SDK de anúncio ou
rastreador. Coerente com a distribuição via F-Droid.") — e essa ficha nem
teve clone, foi leitura de navegador. Para os outros 6, não fiz esse grep
específico:

- Não sei se o **OpenNutriTracker** usa ZXing (ou outra lib) para código
  de barras — a Definição de Pronto do MVP (`docs/PRODUTO.md:61`) depende
  disso especificamente.
- Não sei se **wger** ou **Fasten Health**, ao rodar `uv sync`/`go build`
  (Ciclos 5 e 6), puxaram alguma dependência transitiva da lista proibida
  — as dezenas de pacotes resolvidos não foram auditados um a um contra
  esta lista, só contra "instalou ou não instalou".
- **MLC LLM, OpenTracks, FoodYou** não tiveram build completo (submódulos
  vazios, ou Maven do Google bloqueado neste ambiente) — dependência
  transitiva não verificada por falta de build, não por ausência do
  problema.

Proponho essa auditoria de dependência como ciclo próprio, depois das
ADRs, antes da Fase 2 (`F2` em `docs/PRODUTO.md`) começar de fato.
