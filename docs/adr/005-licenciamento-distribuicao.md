# ADR-5 — Licenciamento e modelo de distribuição

**Status:** proposto
**Data:** 2026-08-05

## Contexto

Esta é a ADR que `docs/adr/000-pendentes.md` marca como bloqueando "tudo"
— e a única que só faz sentido depois de todas as outras, porque a
licença final do produto é consequência do que cada ADR anterior decidiu
sobre onde cada um dos 7 repositórios entra. Não decido nada aqui que já
não esteja implícito nas ADRs propostas nos Ciclos 10-18; esta ADR só
junta as peças:

- **ADR-1 (proposta):** Flutter shell. OpenTracks (Apache-2.0) e MLC LLM
  (Apache-2.0 core) entram por WRAP — linkados ao cliente.
- **ADR-4 (proposta):** wger (AGPL-3.0) e Fasten (GPL-3.0) opcionais,
  **federados** — não linkados ao cliente nem ao binário do Frankstein.
- **ADR-4a (proposta):** Gadgetbridge (AGPL-3.0) via Health Connect — nem
  federado, nem linkado, sem contato de código nenhum.
- **`docs/VIABILITY.md` (Ciclo 8):** recomenda OpenNutriTracker
  (GPL-3.0) sobre FoodYou (GPL-3.0) para o módulo de nutrição — os dois
  são GPL-3.0, então a escolha entre eles não muda a licença resultante,
  só qual código de fato entra linkado.

Isso é, na estrutura de `docs/LICENSE-AUDIT.md` (Ciclo 7), o **Cenário B**
quase exato: só que em vez de nenhum dos GPL-3.0 entrar linkado, um deles
(OpenNutriTracker) entra — porque nutrição, ao contrário de wger/Fasten/
Gadgetbridge, está no núcleo do MVP grátis, sem depender de rede.

`STATUS.md`, em "Decisões já tomadas", já registra "Código aberto,
copyleft aceito" — isto não é uma pergunta em aberto sobre *se* o projeto
é copyleft, é sobre *qual* copyleft e *onde* ele se aplica.

## Opções consideradas

1. **Seguir o Cenário B de `docs/LICENSE-AUDIT.md` até o fim:** cliente
   GPL-3.0 (forçado pelo OpenNutriTracker linkado, compatível com
   Apache-2.0 do MLC LLM/OpenTracks numa via só); qualquer componente de
   servidor autoral do Frankstein (B2B, entitlements, relay de sync — ADR-3,
   ADR-8) **não é legalmente forçado** a AGPL só por chamar a API do wger
   por rede (leitura permissiva registrada em `docs/LICENSE-AUDIT.md`),
   mas o projeto **escolhe** AGPL-3.0 para esses componentes por
   princípio, não por obrigação — coerente com "copyleft aceito" já
   decidido, e evita depender da leitura permissiva se ela nunca for
   testada em tribunal.
2. **Cliente GPL-3.0, servidor autoral proprietário** (só o que é
   legalmente obrigatório fica aberto: o wger, se hospedado). Tecnicamente
   permitido pela leitura permissiva de `docs/LICENSE-AUDIT.md`, mas
   contradiz "Código aberto, copyleft aceito" já registrado em `STATUS.md`
   — não é uma opção real dado o que já foi decidido, só registro que
   existiria.
3. **Descartar OpenNutriTracker também** (harvest/reescrever), deixando só
   Apache-2.0 (MLC LLM, OpenTracks) linkado no cliente — abriria caminho
   para um cliente permissivo em vez de GPL-3.0. Não é o que
   `docs/VIABILITY.md` recomendou, e reabriria a decisão de nutrição do
   Ciclo 8 sem motivo novo — `CLAUDE.md` regra 3 pede para não reabrir
   decisão sem motivo.

## Decisão

**Opção 1.** Modelo de licenciamento proposto:

- **Cliente (app):** GPL-3.0. Todo binário distribuído (Play Store, App
  Store, F-Droid, APK direto) carrega essa licença e a obrigação padrão de
  oferecer código-fonte a quem recebe o binário.
- **Componentes de servidor autorais do Frankstein** (entitlements, B2B,
  relay de sync — ADR-3/ADR-8): **AGPL-3.0 por escolha**, não por
  obrigação legal estrita nesta configuração federada. Cobre uso via rede
  (§13) para qualquer usuário do painel B2B ou da API de sync.
- **wger, se hospedado para B2B:** expõe o próprio código-fonte via rota
  `/source`, decisão já tomada em `docs/B2B.md:31-33` — mantida sem
  alteração.
- **Modelo de distribuição:** multi-canal, conforme ADR-7 (proposta) —
  Google Play, App Store, F-Droid/APK direto, Web como preferencial para
  pagamento.

**Isto está proposto, não aceito.** É a ADR mais consequente do projeto —
"bloqueia tudo" segundo `docs/adr/000-pendentes.md`. Não deveria ser
aceita sem você revisar as 8 ADRs que ela sintetiza, e sem resolver as
pendências que herda de cada uma (submódulos do MLC LLM, direção do
Gadgetbridge, isolamento multi-tenant, regras de loja no Brasil).

## Consequências

- **Fica mais fácil:** o modelo de licenciamento deixa de ser uma
  incógnita por repositório — vira uma regra única (GPL-3.0 cliente,
  AGPL-3.0 servidor autoral) aplicável a qualquer código novo que o
  projeto escrever, sem precisar reabrir a pergunta a cada módulo.
- **Fica mais difícil:** GPL-3.0 no cliente carrega o mesmo risco
  histórico de atrito com os Termos de Uso da App Store já registrado em
  `docs/LICENSE-AUDIT.md` (caso FSF x Apple/GNU Go, 2010) — não resolvido
  por esta ADR, só herdado. AGPL-3.0 por escolha no servidor (não por
  obrigação) significa manter uma rota `/source` também para componentes
  que a leitura permissiva não exigiria — custo de implementação que uma
  leitura mais permissiva evitaria.
- **Passa a ser proibido:** qualquer distribuição do cliente sem oferta de
  código-fonte correspondente; qualquer componente de servidor autoral
  fechado "porque a lei não obriga" — a escolha de princípio desta ADR
  fecha essa porta mesmo onde a obrigação legal é discutível.

## Não verificado (herdado das ADRs anteriores, não resolvido aqui)

- ~~Licenças dos 6 submódulos do MLC LLM~~ — resolvido no Ciclo B
  (2026-08-05), todas permissivas, não muda esta ADR.
- Direção real do Gadgetbridge no Health Connect, confirmada só por busca
  indexada (ADR-4a).
- Se o App Store aceita GPL-3.0 hoje na prática para contas novas — só
  precedente histórico, não regra atual verificada (`docs/LICENSE-AUDIT.md`).
- Regras de link de pagamento externo confirmadas para o Brasil
  especificamente (ADR-7).
- Texto primário da FSF sobre compatibilidade de licença — só resumo de
  `WebSearch` em todo o projeto até aqui, nunca leitura direta de
  `gnu.org` (bloqueado neste ambiente).
