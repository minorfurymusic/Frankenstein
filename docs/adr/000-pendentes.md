# ADRs

Todas as 11 estão registradas (Ciclos 9-19, revisões em curso a partir daí).
**7 aceitas** (ADR-1, 2, 3, 6, 7, 9, 10), **4 propostas** (ADR-4, 4a, 5, 8)
— análise pronta, decisão ainda sua. Nenhuma vira "aceita" sem confirmação
explícita.

| ADR | Assunto | Bloqueia | Status |
|---|---|---|---|
| [ADR-1](001-shell-multiplataforma.md) | Shell do app e estratégia multiplataforma | F2 | **aceito** |
| [ADR-2](002-modelo-llm.md) | Modelo LLM, quantização, RAM mínima, perfis A/B/C | F5 | **aceito** |
| [ADR-3](003-fonte-verdade-sync.md) | Fonte da verdade dos dados e estratégia de sync | F3 | **aceito** |
| [ADR-4](004-wger-fasten.md) | wger/Fasten: obrigatório, opcional ou substituído? | F13 | proposto |
| [ADR-4a](004a-gadgetbridge.md) | Gadgetbridge: FEDERATE via Health Connect ou fork sob AGPL? | F9 | proposto |
| [ADR-5](005-licenciamento-distribuicao.md) | Licenciamento e modelo de distribuição (revisão 3: fundamentação corrigida, clean room obrigatório, ficha fora das fontes de implementação) | tudo | proposto |
| [ADR-6](006-sem-anuncios.md) | Sem anúncios em nenhuma superfície | — | **aceito** |
| [ADR-7](007-canais-distribuicao-pagamento.md) | Canais de distribuição e meios de pagamento (revisão 3: mecanismo de vínculo do entitlement definido, regra de comunicação de plano utilizável) | F11 | **aceito** |
| [ADR-8](008-multitenant-b2b-consentimento.md) | Multi-tenant B2B e modelo de consentimento (revisão 1: isolamento de banco decidido — schema separado por Organization, custo justificado por `docs/CUSTOS.md`) | F14 | proposto |
| [ADR-9](009-gps.md) | GPS: precisão x bateria x privacidade | F8 | **aceito** |
| [ADR-10](010-substitutos-livres.md) | Substitutos livres de dependências proprietárias | F2 | **aceito** |

`_MODELO.md` neste diretório é o template usado em todas.
