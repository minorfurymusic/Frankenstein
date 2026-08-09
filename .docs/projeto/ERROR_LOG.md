# ERROR_LOG — Frankstein

> Gerado pela skill `project-recorder`. Todos os erros abaixo são reais,
> já documentados em `docs/HISTORICO.md` ou nos commits — nenhum
> inventado pra preencher o formato. Ordem cronológica.

### Erro — Loop autônomo (`/loop`) parou sozinho, sem avisar
**Contexto:** execução overnight agendada via `ScheduleWakeup`.
**Sintoma:** parou de commitar depois do Ciclo 8, ~9h sem atividade, sem erro reportado.
**Causa:** não identificada com certeza — falha silenciosa do agendamento.
**Solução:** reportado com honestidade (prova: timestamps do `git log`), retomado de forma síncrona com o usuário presente em vez de confiar em agendamento.
**Referência:** `docs/HISTORICO.md`, seção sobre a falha do `/loop`.

### Erro — Hook `PostToolUse` lia campo que não existe
**Contexto:** construção dos hooks de `.claude/settings.json`.
**Sintoma:** lógica de limpar o marker de `make test` dependia de `tool_error`, campo que a documentação descrevia mas o harness real não envia.
**Causa:** `PostToolUse` real manda `tool_response: {stdout, stderr, ...}`, sem sinal explícito de sucesso/falha.
**Solução:** reescrito pra limpar o marker em qualquer `git commit` que chegue ao `PostToolUse` (negações de `PreToolUse` nunca chegam lá).
**Referência:** `.claude/hooks/post-bash.sh`.

### Erro — Regex do hook não pegava `make test;` sem espaço
**Contexto:** `.claude/hooks/pre-bash.sh`/`post-bash.sh`.
**Sintoma:** `make test;` (ponto e vírgula colado, sem espaço) não batia no limite `([[:space:]]|$)`.
**Solução:** limite trocado para `([;&|[:space:]]|$)`.

### Erro — Hook bloqueava `ls packages/ server/` por engano
**Contexto:** detecção de escrita em `packages/`/`server/` antes das ADR-1/2/3 aceitas.
**Sintoma:** qualquer `>` na linha (incluindo `2>&1`) era tratado como indício de escrita.
**Solução:** regex combinada, verbo de escrita (mkdir/touch/tee/cp/mv/git add) amarrado contextualmente ao caminho, não duas greps independentes.

### Erro — CI quebrou no primeiro push real (Ciclo 27)
**Contexto:** push do esqueleto do monorepo, run `31053024984`.
**Sintoma:** `dart analyze`/`dart test` falhavam em checkout limpo: `Target of URI doesn't exist: 'package:test/test.dart'`.
**Causa:** `Makefile` nunca rodava `dart pub get`/`flutter pub get` — só "funcionava" localmente porque isso já tinha sido rodado manualmente antes de testar o Makefile.
**Solução:** alvo `bootstrap` novo, dependência de `build`/`test`/`lint`. Confirmado simulando checkout limpo antes de repush.
**Referência:** commit `386b711`.

### Erro — Android SDK inacessível no sandbox de dev (ambiente, não corrigível daqui)
**Contexto:** `make build` (Android) e emulador, Ciclo 27.
**Sintoma:** `dl.google.com` bloqueado pelo proxy; sem `/dev/kvm`.
**Solução:** não é bug, é limite de ambiente — confirmado por 3 caminhos independentes, não insistido uma 4ª vez (regra do `CLAUDE.md`). Prova alternativa: `flutter build linux` + `xvfb-run`. CI em `ubuntu-latest` prova o critério de aceite de verdade (runs `31055829550`/`31056058975`, ambos `success`).

### Erro — ADR-5 rejeitou a opção certa por má leitura da regra 3 do `CLAUDE.md` (achado pelo usuário)
**Contexto:** revisão 1 da ADR-5 (licenciamento).
**Sintoma:** descartei a opção PORT (reimplementação) achando que reabrir a discussão violava "não reabrir decisão sem motivo novo".
**Causa:** confundi "qual repositório usar" (já decidido em `docs/VIABILITY.md`) com "como absorvê-lo" (nunca decidido).
**Solução:** reaberto e reanalisado depois da correção do usuário.

### Erro — ADR-5 apoiada num precedente não verificado (achado pelo usuário)
**Contexto:** revisão 2 da ADR-5.
**Sintoma:** fundamentação principal dependia do conflito GPL×App Store, que a própria ADR listava como "não verificado" (precedente de 2010).
**Solução:** fundamentação invertida — motivo principal virou "não herdar manutenção de repositório de terceiro", independente de fato não verificado. Precedente de 2010 rebaixado a bônus.

### Erro — Vazamento na cadeia de clean room (achado pelo usuário)
**Contexto:** ADR-5 e `.claude/rules/port.md`, antes da revisão 3.
**Sintoma:** `docs/recon/opennutritracker.md` era tratada como referência válida de "o que o módulo faz" — mas essa ficha foi escrita lendo o código-fonte do OpenNutriTracker, contaminando a cadeia de clean room.
**Solução:** ficha removida das fontes válidas de implementação; `docs/specs/nutricao.md` (escrita a partir do `README.md` público) virou a única fonte permitida.

### Erro — Rascunho da ADR-4 com afirmação errada sobre licença do cliente (autocorrigido)
**Contexto:** revisão 1 da ADR-4 (wger/Fasten), Ciclo 31.
**Sintoma:** um rascunho intermediário dizia "o cliente seria GPL-3.0 por causa de FoodYou/OpenNutriTracker".
**Causa:** errado em dois pontos — a ADR-5 já decidiu cliente Apache-2.0 (via PORT), e o FoodYou nunca foi adotado (`docs/VIABILITY.md`, só "avaliar").
**Solução:** verificado contra `docs/VIABILITY.md` e `docs/adr/005-...md` antes de fechar o ciclo; corrigido antes do commit, nunca chegou a ficar na ADR.

## Padrão observado

A maioria dos erros documentados aqui foi pega **antes** de virar commit — pelo usuário (regra 3, precedente não verificado, vazamento de clean room) ou pela própria disciplina de verificação (ADR-4). Os erros que *chegaram* a commit são todos de infraestrutura (hooks, CI, Makefile), corrigidos no ciclo seguinte com prova literal.
