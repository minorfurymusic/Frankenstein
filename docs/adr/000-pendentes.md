# ADRs pendentes

| ADR | Assunto | Bloqueia |
|---|---|---|
| ADR-1 | Shell do app e estratégia multiplataforma (o que degrada no iOS) | F2 |
| ADR-2 | Modelo LLM, quantização, RAM mínima, perfis A/B/C | F5 |
| ADR-3 | Fonte da verdade dos dados e estratégia de sync | F3 |
| ADR-4 | wger/Fasten: obrigatório, opcional ou substituído? | F13 |
| ADR-4a | Gadgetbridge: FEDERATE via Health Connect ou fork sob AGPL? A pergunta que decide é se o Gadgetbridge escreve passos, FC e sono no Android Health Connect ou apenas lê de lá — `androidx.health.connect.client` prova integração, não a direção. Investigado no Ciclo 7 — achado (com ressalva de fonte) em `docs/recon/gadgetbridge.md`, seção "Achado (Ciclo 7)": Gadgetbridge escreve no Health Connect, via `WebSearch` (site bloqueado pelo proxy para leitura direta). | F9 |
| ADR-5 | Licenciamento e modelo de distribuição | tudo |
| ADR-6 | ~~**Sem anúncios**~~ — **ACEITA**, registrada em `docs/adr/006-sem-anuncios.md` | — |
| ADR-7 | Canais de distribuição e meios de pagamento | F11 |
| ADR-8 | Multi-tenant B2B e modelo de consentimento | F14 |
| ADR-9 | GPS: precisão x bateria x privacidade | F8 |
| ADR-10 | Substitutos livres de dependências proprietárias | F2 |
