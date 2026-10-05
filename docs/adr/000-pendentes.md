# ADRs

17 registradas. **16 em vigor, 1 substituída** (ADR-2, pela ADR-11 em
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
| [ADR-9](009-gps.md) | GPS: precisão x bateria x privacidade (revisão 1: gravador próprio no Android, sem OpenTracks) | F8 | **aceito, revisado** |
| [ADR-10](010-substitutos-livres.md) | Substitutos livres de dependências proprietárias | F2 | **aceito** |
| [ADR-11](011-cerebro-nuvem-chave-usuario.md) | Cérebro em nuvem com a chave de API do próprio usuário (substitui ADR-2; revisão 1: provedor Gemini) | F5 | **aceito, revisado** |
| [ADR-12](012-android-only-nome-rlt.md) | Android apenas; nome do produto RLT — Real Life Track | — | **aceito** |
| [ADR-13](013-login-google-obrigatorio.md) | Login com Google obrigatório (mecanismo técnico decidido na fase do servidor) | servidor | **aceito (produto); técnico em aberto** |
| [ADR-14](014-recursos-premium-relatorio.md) | Relatório para consulta é Premium; "mais espaço" removido da tela Assinatura | — | **aceito** |
| [ADR-15](015-formulas-saude.md) | Fórmulas de saúde (Mifflin-St Jeor / Katch-McArdle, METs 2024, ISSN, IMC, cintura/altura, US Navy) | metas | **aceito; coeficientes a conferir** |
| [ADR-16](016-valores-exame-unidade-do-laudo.md) | Valores de exame na unidade do laudo (exceção à regra de SI, só para exames) | exames | **aceito** |

`_MODELO.md` neste diretório é o template usado em todas.
