# Auditoria de licenças — os 7 repositórios

**Não é parecer jurídico.** Sou um agente de código, não advogado, e isso
não substitui um. Isso é um mapa das restrições que encontrei, com a fonte
de cada afirmação e, onde a resposta depende de interpretação legal (não de
fato verificável), digo isso explicitamente em vez de decidir por você.

Fonte de cada ficha: `docs/recon/<repo>.md`. Todas as licenças abaixo foram
lidas literalmente do arquivo `LICENSE`/`LICENSE.txt`/`LICENSE.md` de cada
clone, **exceto Gadgetbridge**, cuja ficha foi produzida fora deste
ambiente por leitura no navegador (`codeberg.org` bloqueado pelo proxy) —
sinalizado na tabela.

## Matriz por repositório

| Repositório | Licença (literal) | Sublicenças por subdiretório | Verificação |
|---|---|---|---|
| MLC LLM | Apache-2.0 | 6 submódulos `3rdparty/` lidos no Ciclo B (2026-08-05): `argparse` MIT, `googletest` BSD-3-Clause, `stb` MIT/Unlicense, `tokenizers-cpp` Apache-2.0, `tvm`/`relax` Apache-2.0 (+ 6 licenças vendorizadas em `tvm/licenses/`, todas permissivas), `xgrammar` Apache-2.0. Todas permissivas, nenhuma copyleft — não muda a conclusão desta auditoria | clone + leitura direta |
| OpenTracks | Apache-2.0 | nenhuma encontrada | clone + leitura direta |
| FoodYou | GPL-3.0 | nenhuma encontrada | clone + leitura direta |
| OpenNutriTracker | GPL-3.0 | nenhuma encontrada | clone + leitura direta |
| wger | **AGPL-3.0** | fontes estáticas (`wger/core/static/fonts/`) sob Apache-2.0; `licenses.json` é catálogo de licenças de **conteúdo** (exercícios: CC-BY-SA 3/4, CC0), não licença de código | clone + leitura direta |
| Fasten Health (`fasten-onprem`) | GPL-3.0 | nenhuma encontrada. Nota: "Fasten Connect" é produto proprietário separado, fora deste repositório — não avaliado | clone + leitura direta |
| Gadgetbridge | **AGPL-3.0** | `net/osmand` (OsmAnd) GPLv3; `org/bouncycastle` MIT; `com/android/nQuant` Apache; `org/concentus` BSD-3; `GBDaoGenerator/.../greenrobot` (greenDAO fork) GPLv3; `SearchPreferenceHighlighter.java` MIT | **leitura no navegador, sem clone** — ressalva na ficha |

**Licença mais restritiva do conjunto: AGPL-3.0** (wger e Gadgetbridge) —
cobre uso via rede (§13), não só distribuição de binário. GPL-3.0 é o
segundo nível (FoodYou, OpenNutriTracker, Fasten Health). Apache-2.0 é
permissivo puro (MLC LLM no core, OpenTracks).

## Cenário A — absorção por link/cópia de código dos 7

Premissa: todo o código dos 7 é linkado ou copiado para dentro do
mesmo trabalho combinado (o app cliente e/ou um binário/processo de
servidor único), não chamado por rede como serviço externo.

**(1) Licença obrigatória do produto final:** o trabalho combinado tem de
ser distribuído sob **AGPL-3.0**. Isso não é interpretação — é como as
próprias licenças definem compatibilidade: Apache-2.0 pode ser incorporado
em obra coberta por GPLv3/AGPLv3 (via `WebSearch`, resumo consistente com o
texto histórico da FSF: "Apache 2.0 software can be included in GPLv3
projects... the combined work as a whole must be distributed under
AGPL 3.0" quando combinado com código AGPL); GPLv3 e AGPLv3 permitem
linkagem mútua explícita e o resultado combinado segue AGPLv3, a licença
mais forte presente. **Ressalva de fonte:** não consegui abrir
`gnu.org/licenses/license-list.html` diretamente neste ambiente (403 — ver
abaixo), então essa afirmação vem de resumo de busca, não do texto
primário da FSF lido por mim.

**(2) Distribuir na Google Play e na App Store:**
- **Google Play:** não encontrei proibição de política contra apps
  GPL/AGPL — é observação, não confirmação de política atual da Play
  Store (não li os termos da Play Store neste ciclo). Como dado real: o
  próprio wger publica um cliente na Play Store
  (`play.google.com/store/apps/details?id=de.wger.flutter`, citado
  literalmente no `README.md` do clone) — mas não sei a licença desse app
  cliente específico (é outro repositório, não um dos 7; não abri, não
  cito).
- **App Store (Apple):** **aqui a resposta depende de interpretação, e há
  precedente histórico de conflito**, não uma proibição escrita clara.
  Em 2010 a FSF confrontou a Apple sobre o GNU Go estar na App Store sob
  GPLv2: a posição da FSF foi que os Termos de Uso da App Store (limite de
  5 dispositivos, proibição de redistribuição) violam a cláusula da GPL
  que proíbe "restrições adicionais" sobre quem recebe o programa
  (GPLv2 §6; GPLv3 tem cláusula equivalente). Isso não decidiu a questão
  em tribunal — foi resolvido por remoção/negociação caso a caso, não por
  uma regra geral. Aplicações GPL/AGPL continuam aparecendo na App Store
  hoje (o próprio wger, se o cliente Flutter for de fato GPL/AGPL, o que
  não confirmei). **Não afirmo que é proibido nem que é permitido** — é
  risco de conflito de termos, não achado técnico.

**(3) Código-fonte precisa ser aberto, para quem:** sim, o trabalho
combinado inteiro (client + qualquer servidor que rode o mesmo código
combinado), sob AGPL-3.0:
- Para qualquer pessoa que **receba o binário** (quem baixa o APK/IPA,
  Play Store, App Store, F-Droid) — obrigação padrão de copyleft.
- Para qualquer pessoa que **interaja com ele pela rede**, mesmo sem
  baixar nada — AGPL-3.0 §13, a cláusula que a GPL comum não tem.

**(4) O painel B2B em servidor dispara a cláusula de rede da AGPL §13?**
**Sim, sem ambiguidade, neste cenário** — porque a premissa do Cenário A é
que o código AGPL está linkado/copiado dentro do mesmo processo que serve
o painel B2B. Qualquer profissional de saúde ou paciente que acessar o
painel pela rede passa a ter direito ao código-fonte correspondente, pela
própria definição de §13. `docs/B2B.md:31-33` já registra essa consequência
e propõe a rota `/source` com o tarball da versão em execução — decisão já
tomada pelo time, coerente com esta leitura.

## Cenário B — Gadgetbridge, wger e Fasten federados por rede/app separado; sem linkar código

Premissa: esses três **não** entram no binário/processo do Frankstein.
MLC LLM, OpenTracks, FoodYou e OpenNutriTracker **não estão nesta lista** —
o cenário como você descreveu não os move para federação, então trato-os
como ainda linkados/copiados no cliente, igual ao Cenário A.

**Nuance que muda o resultado, e que a ficha do Gadgetbridge já registrava:**
os três "federados" não são federados do mesmo jeito:
- **wger:** REST — `docs/ARQUITETURA.md:16` já descreve "wger (REST)" como
  camada separada. Processo de servidor distinto, chamado por API.
- **Fasten:** FHIR — mesma linha do ARQUITETURA.md, "Fasten (FHIR)".
  Processo de servidor distinto, protocolo padrão de saúde.
- **Gadgetbridge:** **não é uma chamada de rede a um serviço do
  Gadgetbridge.** É leitura do Android Health Connect, um provedor de dados
  do sistema operacional. O Frankstein nunca fala com o Gadgetbridge nem
  com código dele, direta ou indiretamente — fala com o Android. É uma
  federação ainda mais fraca que wger/Fasten: não há sequer uma chamada de
  API entre os dois programas.

**(1) Licença obrigatória do produto final:** o app cliente ainda linka
FoodYou e OpenNutriTracker (GPL-3.0) e MLC LLM/OpenTracks (Apache-2.0,
compatível com GPLv3 numa via). Resultado: o **cliente precisa ser
GPL-3.0** — cai de AGPL-3.0 para GPL-3.0 em relação ao Cenário A, mas
**não vira permissivo**. Os serviços federados mantêm suas próprias
licenças como programas separados: wger AGPL-3.0, Fasten GPL-3.0,
Gadgetbridge AGPL-3.0 — nenhum deles "vaza" a licença para o Frankstein
neste cenário, pelo raciocínio do item seguinte.

**(2) Distribuir na Google Play e na App Store:** mesma situação do
Cenário A quanto à App Store — o cliente ainda é GPL-3.0 (por causa de
FoodYou/OpenNutriTracker), então o mesmo risco histórico de conflito com
os Termos de Uso da App Store se aplica, independente da AGPL. Federar
wger/Fasten/Gadgetbridge não resolve esse ponto — só evita agravar de
GPL-3.0 para AGPL-3.0. Google Play: mesma observação do Cenário A, sem
achado de proibição.

**(3) Código-fonte precisa ser aberto, para quem:**
- O **cliente** (GPL-3.0): para quem recebe o binário — mesma obrigação
  padrão de sempre, sem a cláusula de rede da AGPL (o cliente em si não é
  AGPL neste cenário).
- **wger**, se hospedado pelo Frankstein: precisa oferecer o código-fonte
  (da versão em execução, incluindo qualquer modificação) a quem
  **interage com o wger pela rede** — a obrigação é do wger como programa,
  não necessariamente do que chama a API dele. Ver item 4.
- **Fasten** (GPL-3.0, sem cláusula de rede): obrigação de fonte só para
  quem recebe o binário/imagem, não para quem usa via rede — GPL comum não
  tem §13.
- **Gadgetbridge:** nenhuma obrigação de fonte recai sobre o Frankstein —
  não há combinação de código nem chamada de API entre os dois. O usuário
  já tem o Gadgetbridge (ou não) por conta própria; o Frankstein só lê o
  Health Connect.

**(4) O painel B2B em servidor dispara a cláusula de rede da AGPL §13?**
**Aqui a resposta depende de interpretação legal — não é fato
verificável, é a pergunta mais disputada de todo o copyleft de rede.**
Duas leituras coexistem, e não encontrei uma delas resolvida como "a
correta" em nenhuma fonte que li:
- **Leitura permissiva (posição comum da FSF em FAQs):** processos
  separados que se comunicam por uma interface de rede bem definida
  (API REST/FHIR) não formam necessariamente um "trabalho combinado".
  Nessa leitura, o painel B2B do Frankstein (processo próprio) chamando a
  API do wger (processo próprio) não obriga o painel B2B a virar AGPL —
  só o wger, como programa, precisa oferecer sua própria fonte a quem
  interage com ele pela rede.
- **Leitura conservadora:** se o acoplamento for estreito (mesma sessão de
  usuário, autenticação compartilhada, a interface do wger é apresentada
  como parte do produto do Frankstein, por exemplo embutida em iframe),
  algumas leituras tratam isso como um serviço combinado sob a ótica do
  §13, o que estenderia a obrigação de fonte ao conjunto.

**O que já está decidido e não depende dessa interpretação:**
`docs/B2B.md:31-33` já assume a leitura conservadora por precaução —
"AGPL no servidor implica oferecer o código a quem usa o serviço pela
rede: crie a rota `/source`... Vende-se hospedagem, marca, suporte e
integração, não segredo de código." Isso cobre a obrigação do wger em
qualquer uma das duas leituras. O que **não** está decidido é se o
restante do painel B2B (código próprio do Frankstein: seats, CareLink,
RBAC, billing) também precisa ser aberto — isso só seria obrigatório na
leitura conservadora, e é uma decisão de ADR-5/ADR-8, não uma conclusão
desta auditoria.

## Ressalvas de método

- Não consegui abrir `gnu.org/licenses/license-list.html` nem
  `gnu.org/licenses/gpl-faq.html` diretamente neste ciclo — ambos
  retornaram 403 ao `WebFetch` (não é bloqueio do proxy deste ambiente,
  como confirmei em `$HTTPS_PROXY/__agentproxy/status`: não houve entrada
  de `connect_rejected` para `gnu.org`; o próprio site recusou a
  requisição). As afirmações de compatibilidade de licença vêm de
  resultados de `WebSearch`, que resumem — não citam literalmente — o
  texto da FSF. Se este documento for base para uma decisão de ADR-5, vale
  a pena alguém ler `gnu.org/licenses/license-list.html` direto, fora
  deste ambiente, como foi feito para a ficha do Gadgetbridge.
- A ficha do Gadgetbridge não teve clone nem build — toda a linha dela
  nesta matriz carrega essa ressalva.
- ~~As 6 licenças de submódulo do MLC LLM (`3rdparty/`) não foram lidas~~
  — **resolvido no Ciclo B** (2026-08-05): todas permissivas (MIT, BSD-3,
  Apache-2.0, MIT/Unlicense). Ver `docs/recon/mlc-llm.md`.
- Este documento não resolve o ADR-4a (Gadgetbridge escreve ou só lê do
  Health Connect) nem o ADR-5 (licenciamento e modelo de distribuição) —
  ele dá o mapa para essas decisões, não a decisão em si.

## Fechamento (2026-08-09) — item 9 da Definição de Pronto do MVP

As decisões que este documento mapeava, sem tomar, estão todas tomadas
agora — ADR-4, ADR-4a e ADR-5 aceitas (`docs/adr/000-pendentes.md`,
11/11). Registro aqui, num lugar só, qual cenário e quais opções deste
documento viraram decisão real:

- **Cenário adotado: B** ("federados por rede/app separado; sem linkar
  código") — wger e Fasten entram por FEDERATE (REST/FHIR), nunca linkados
  ao binário do Frankstein. Gadgetbridge nem chega a ser uma chamada de
  API: o Frankstein lê o Android Health Connect, que o Gadgetbridge
  escreve (`docs/adr/004a-gadgetbridge.md`, aceita).
- **OpenNutriTracker: PORT, não cópia/link.** Cliente reimplementa o
  módulo de nutrição a partir de `docs/specs/nutricao.md`, clean room
  obrigatório (`docs/adr/005-licenciamento-distribuicao.md`, aceita,
  Opção 3). Não é o Cenário A nem o B puro — é a saída que evita o
  copyleft do OpenNutriTracker entrar no cliente de qualquer jeito.
- **Licença do cliente Frankstein: Apache-2.0.** MLC LLM e OpenTracks já
  eram Apache-2.0 (WRAP, ADR-1); OpenNutriTracker deixa de ser GPL-3.0 no
  cliente porque entra por PORT, não por link. Nenhum copyleft no cliente.
- **Licença do servidor autoral: AGPL-3.0**, por escolha (ADR-3/ADR-8,
  ambas aceitas) — não por obrigação de nenhum dos 7 repositórios.
- **wger (AGPL-3.0) e Fasten (GPL-3.0) continuam com suas próprias
  licenças**, como programas separados — não "vazam" para o Frankstein
  (Cenário B, item 1). Se "wger hospedado" virar produto Premium
  (`docs/MONETIZACAO.md`), a obrigação de fonte da AGPL §13 é do wger
  como programa, mitigada pela rota `/source` já decidida
  (`docs/B2B.md:31-33`), independente de qual leitura do §13 (permissiva
  ou conservadora, Cenário B item 4) for a correta — não precisou esperar
  essa pergunta jurídica em aberto se resolver.
- **Distribuição:** multi-canal (`docs/adr/007-canais-distribuicao-pagamento.md`,
  aceita) — cliente Apache-2.0 não colide com termos de loja do jeito que
  GPL-3.0 colidiria (o precedente FSF×Apple de 2010 fica como bônus
  histórico, não como base da decisão — `docs/adr/005-...md` já registra
  isso invertido de propósito).

**O que este fechamento não resolve** (não era o papel dele): custo de
engenharia de reimplementar o módulo de nutrição (`docs/adr/004-wger-fasten.md`
"Não verificado"); requisito específico de LGPD pra log de acesso B2B
(`docs/adr/008-...md`); textos primários da FSF nunca lidos diretamente
neste ambiente (ressalva de método acima, ainda vale). Esses seguem como
débito de cada ADR específica, não deste documento.
