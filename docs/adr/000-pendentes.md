# ADRs

27 registradas. **26 em vigor, 1 substituída** (ADR-2, pela ADR-11 em
2026-10-02). ADR-1 e ADR-7 foram alteradas pela ADR-12 (Android apenas); a
ADR-7 também pela ADR-13 (login Google substitui o código de "Já assinei"
quando houver servidor).
A ADR-14 alterou `docs/MONETIZACAO.md` (relatório para consulta é Premium).
Nenhuma virou "aceita" sem confirmação explícita do usuário.

| ADR | Assunto | Bloqueia | Status |
|---|---|---|---|
| [ADR-1](001-shell-multiplataforma.md) | Shell do app e estratégia multiplataforma (iOS removido pela ADR-12) | F2 | **aceito, alterado** |
| [ADR-2](002-modelo-llm.md) | Modelo LLM, quantização, RAM mínima, perfis A/B/C | F5 | **substituído por ADR-11** |
| [ADR-3](003-fonte-verdade-sync.md) | Fonte da verdade dos dados e estratégia de sync | F3 | **aceito** |
| [ADR-4](004-wger-fasten.md) | wger/Fasten: obrigatório, opcional ou substituído? (revisão 1: consequência de licença fundamentada em `docs/LICENSE-AUDIT.md` Cenário B + `docs/adr/005-...md`, cliente Apache-2.0) | F13 | **aceito** |
| [ADR-4a](004a-gadgetbridge.md) | Gadgetbridge: FEDERATE via Health Connect (revisão 2: permissão de escrita confirmada no APK publicado via F-Droid + documentação oficial, trazida por você) | F9 | **aceito** |
| [ADR-5](005-licenciamento-distribuicao.md) | Licenciamento e modelo de distribuição (revisão 4: limpeza — item desatualizado do "Não verificado" resolvido; decisão de fundo sólida desde a revisão 3) | tudo | **aceito** |
| [ADR-6](006-sem-anuncios.md) | Sem anúncios em nenhuma superfície | — | **aceito** |
| [ADR-7](007-canais-distribuicao-pagamento.md) | Canais de distribuição e meios de pagamento (revisão 3: mecanismo de vínculo do entitlement definido, regra de comunicação de plano utilizável; App Store removida pela ADR-12) | F11 | **aceito, alterado** |
| [ADR-8](008-multitenant-b2b-consentimento.md) | Multi-tenant B2B e modelo de consentimento (revisão 1: isolamento de banco decidido — schema separado por Organization, custo justificado por `docs/CUSTOS.md`) | F14 | **aceito** |
| [ADR-9](009-gps.md) | GPS: precisão x bateria x privacidade (revisão 1: gravador próprio; revisão 2: integração com o OpenTracks instalado) | F8 | **aceito, revisado** |
| [ADR-10](010-substitutos-livres.md) | Substitutos livres de dependências proprietárias | F2 | **aceito** |
| [ADR-11](011-cerebro-nuvem-chave-usuario.md) | Cérebro em nuvem com a chave de API do próprio usuário (substitui ADR-2; revisão 1: provedor Gemini) | F5 | **aceito, revisado** |
| [ADR-12](012-android-only-nome-rlt.md) | Android apenas; nome do produto RLT — Real Life Track | — | **aceito** |
| [ADR-13](013-login-google-obrigatorio.md) | Login com Google obrigatório (mecanismo técnico decidido na fase do servidor) | servidor | **aceito (produto); técnico em aberto** |
| [ADR-14](014-recursos-premium-relatorio.md) | Relatório para consulta é Premium; "mais espaço" removido da tela Assinatura | — | **aceito** |
| [ADR-15](015-formulas-saude.md) | Fórmulas de saúde (Mifflin-St Jeor / Katch-McArdle, METs 2024, ISSN, IMC, cintura/altura, US Navy) | metas | **aceito; coeficientes a conferir** |
| [ADR-16](016-valores-exame-unidade-do-laudo.md) | Valores de exame na unidade do laudo (exceção à regra de SI, só para exames) | exames | **aceito** |
| [ADR-17](017-peso-desejado.md) | Peso desejado comanda o objetivo (perder/manter ±1 kg/ganhar), previsão pelo ritmo | metas | **aceito** |
| [ADR-18](018-plano-de-refeicoes.md) | Plano de refeições: importar do profissional (IA transcreve), montar ou pedir sugestão à IA (sugestão, sempre avisada) | nutrição | **aceito** |
| [ADR-19](019-varios-documentos-no-cerebro.md) | Vários documentos de uma vez no Cérebro: a IA identifica o tipo, cada um vira cartão; dados pessoais lidos em cartão separado; foto qualquer: diz o que vê | cérebro | **aceito** |
| [ADR-20](020-passos-pelo-health-connect.md) | Passos: Health Connect como fonte principal (total por dia), contador do app como reserva; uma fonte por dia; atualiza com o app aberto | passos | **aceito** |
| [ADR-21](021-gasto-musculacao-por-carga.md) | Gasto da musculação por carga × repetições (retas de Reis 2017 por exercício + geral), recuperação de Knausenberger 2014, carga total + barra somada; altera ADR-15 | metas | **aceito** |
| [ADR-22](022-escada-de-modelos.md) | Escada de modelos da IA: sem cota ou ocupado, passa para o próximo (até 3 por pedido); nome do modelo em cada resposta | cérebro | **aceito** |
| [ADR-23](023-saude-mental.md) | Saúde mental: humor do dia, sintomas mentais, PHQ-9/GAD-7 com texto oficial, aviso CVV/SAMU; tudo no celular | saúde | **aceito** |
| [ADR-24](024-avisos-de-rotina-locais.md) | Aviso de quebra de rotina calculado no celular, sem IA em segundo plano | lembretes | **aceito** |
| [ADR-25](025-analise-como-estou.md) | "Como estou?": a IA recebe só resumos; humor entra sempre que registrado (revisão de 2026-10-18) | cérebro | **aceito, revisado** |
| [ADR-26](026-trocas-equivalentes-no-plano.md) | A IA pode propor trocas equivalentes no plano do profissional, sem mudar metas | cérebro | **aceito** |
| [ADR-27](027-cerebro-conversa.md) | O Cérebro conversa como a IA da pessoa, com avisos e travas mínimas | cérebro | **aceito** |

`_MODELO.md` neste diretório é o template usado em todas.
