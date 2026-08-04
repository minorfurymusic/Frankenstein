# STATUS — Frankstein

> Este arquivo só é fonte de verdade na branch `main`. Todo ciclo termina com
> merge para `main` antes do próximo começar — sessões futuras que abrirem a
> partir de outra branch estão lendo estado desatualizado.

**Fase:** 0 — Reconhecimento
**Ciclo atual:** 5
**Objetivo do ciclo 5:** produzir `docs/recon/wger.md`

## Progresso

| Fase | Item | Status |
|---|---|---|
| 0 | Ficha MLC LLM | pronta (`docs/recon/mlc-llm.md`) |
| 0 | Ficha OpenTracks | pronta (`docs/recon/opentracks.md`) |
| 0 | Ficha Gadgetbridge | **BLOQUEADA** desde 2026-08-04 — codeberg.org barrado pelo proxy do ambiente (`connect_rejected`, 403 na CONNECT). Não conta para as 7; retomar quando o acesso for liberado. |
| 0 | Ficha FoodYou | pronta (`docs/recon/foodyou.md`) |
| 0 | Ficha OpenNutriTracker | pronta (`docs/recon/opennutritracker.md`) |
| 0 | Ficha wger | pendente |
| 0 | Ficha Fasten Health | pendente |
| 0 | docs/LICENSE-AUDIT.md | pendente |
| 0 | docs/VIABILITY.md | pendente |
| 1 | ADR-1 a ADR-10 | pendente |

## Decisões já tomadas (não reabrir sem motivo novo)

- Código aberto, copyleft aceito.
- **Sem anúncios em nenhuma superfície.** Sistema de anúncios foi cancelado.
- Offline-first: a IA roda no aparelho do usuário.
- Grátis = tudo que roda no aparelho. Pago = tudo que consome servidor.
- Monetização: assinatura R$20/US$10 + B2B para profissionais de saúde.
- Escopo inclui módulo de academia (planos, treino, corrida/caminhada com GPS)
  e compartilhamento social (Instagram, TikTok, Facebook).

## Débito técnico

- `docs/recon/_MODELO.md` contém o template de ADR, não um template de ficha
  de repositório. Descoberto no Ciclo 1. As fichas usam a estrutura de campos
  pedida no Ciclo 1-6 (commit, licença literal, build) em vez do modelo.
  // TODO(frankstein): decidir e escrever o template correto de ficha em
  `docs/recon/_MODELO.md`, ou renomear o atual para o lugar certo em
  `docs/adr/`.
- Licenças dos 6 submódulos de `3rdparty/` do MLC LLM (`argparse`,
  `tokenizers-cpp`, `googletest`, `tvm`/`relax`, `stb`, `xgrammar`) não
  avaliadas — clone raso não trouxe o conteúdo. Bloqueia fechamento do ADR-5
  para este repositório.

## Histórico de ciclos

- **Ciclo 0 — organizar estrutura de diretórios do kit inicial.** O kit havia
  sido desempacotado com todos os arquivos soltos na raiz do repositório, sem
  a estrutura que `CLAUDE.md`/`COMECE-AQUI.md` pressupõem. Movidos para
  `docs/`, `docs/adr/`, `docs/recon/`, `.claude/rules/`, `.claude/commands/`
  e `scripts/`. Adicionado `.gitignore` (ausente). Nenhuma ficha de
  reconhecimento foi criada; ciclo 1 (`docs/recon/mlc-llm.md`) continua
  pendente.
- **Ciclo 0.6 — alinhar troca Flutter Steps Tracker → OpenTracks.** O papel de
  "corrida, caminhada e GPS" passou de Flutter Steps Tracker para OpenTracks
  em `docs/PRODUTO.md` e nesta tabela de progresso. `scripts/clone-refs.sh`:
  entrada renomeada para `opentracks` (minúsculas), comentário de cabeçalho
  atualizado, clone de um repositório não aborta mais os demais (erros
  acumulados e resumidos no fim, `exit 1` se algum falhar), hash curto do
  HEAD impresso após cada clone bem-sucedido. Registrado em `docs/PRODUTO.md`
  que o pedômetro do celular não vem de nenhum dos 7 — é código próprio.
  Clone ainda não executado; licença do OpenTracks (permissiva vs. copyleft)
  segue não verificada até a ficha de reconhecimento.
- **Ciclo 1 — ficha de reconhecimento do MLC LLM.** Criado
  `docs/recon/mlc-llm.md`: commit `2f78caa4`, licença Apache-2.0 lida
  literalmente de `LICENSE`/`NOTICE`. Build não tentado (submódulos
  `3rdparty/` vazios por clone raso; build real exige TVM + LLVM + backend
  de GPU, fora de escopo). Achado: `docs/recon/_MODELO.md` é o template de
  ADR, não de ficha — registrado em "Débito técnico".
- **Ciclo 2 — ficha de reconhecimento do OpenTracks.** Criado
  `docs/recon/opentracks.md`: commit `3c23a9f5`, licença Apache-2.0
  (permissiva pura — único caso assim no conjunto até agora, relevante para
  ADR-5). Stack confirmada: Android/Java puro (não Flutter). Build
  tentado (`./gradlew tasks`): Gradle 9.0.0 baixou ok, falhou resolvendo o
  Android Gradle Plugin — `dl.google.com` bloqueado pelo proxy do ambiente
  (403), e não há Android SDK instalado.
- **Ciclo 3 — ficha de reconhecimento do FoodYou.** Criado
  `docs/recon/foodyou.md`: commit `00637df9`, licença GPL-3.0 lida
  literalmente de `LICENSE`. Stack real é Kotlin Multiplatform (600 `.kt`),
  não "Android/Compose" como `docs/PRODUTO.md` descrevia — não corrigido
  neste ciclo, anotado para o próximo que tocar aquele arquivo. Build
  tentado (`./gradlew tasks`): mesma causa raiz do OpenTracks —
  `dl.google.com` bloqueado pelo proxy, plugin `com.android.application`
  não resolvido.
- **Ciclo 4 — ficha de reconhecimento do OpenNutriTracker.** Criado
  `docs/recon/opennutritracker.md`: commit `9ab14fe3`, licença GPL-3.0
  lida literalmente de `LICENSE`, bate com o badge do README. Stack
  confirmada: Flutter/Dart, 451 arquivos `.dart` — único Flutter confirmado
  entre os 5 avaliados até agora. Build não tentado: `flutter`/`dart` não
  estão instalados neste ambiente.
