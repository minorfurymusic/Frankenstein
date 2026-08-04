# PRODUTO — Frankstein

## Visão
Um aplicativo de saúde 7-em-1, offline-first, onde um LLM local é o cérebro que
recebe comandos em linguagem natural e distribui para os módulos. Os dados de
saúde do usuário não saem do aparelho, salvo ação explícita dele.

## Os 7 insumos

| Projeto | Papel | Stack esperada (CONFIRMAR na Fase 0) |
|---|---|---|
| MLC LLM | Cérebro: inferência local com aceleração de hardware | C++/Python/TVM + bindings móveis |
| Flutter Steps Tracker | Pedômetro, metas diárias | Flutter |
| Gadgetbridge | Ponte BLE para pulseiras/relógios | Android — **Android-only** |
| FoodYou | Diário alimentar offline | Android/Compose |
| OpenNutriTracker | Calorias, macros, código de barras | Flutter |
| wger | Planos de treino e dieta, catálogo | Django + REST, self-hosted |
| Fasten Health | Prontuário pessoal (PHR/FHIR) | Go, self-hosted |

Toda afirmação acima é hipótese. Linguagem, licença e estado de manutenção são
confirmados lendo o repositório em `refs/`, na Fase 0.

## Módulos próprios (não vêm dos 7)
- **Academia:** planos, sessão ao vivo, séries/repetições/carga, RPE, recordes, progressão.
- **Corrida e caminhada:** GPS, rota, pace, splits por km, elevação, pausa automática, GPX.
- **Compartilhamento social:** cards de treino, corrida, sequência de dias e recorde.

## Padrões de absorção (escolher um por repositório, via ADR)
- **PORT** — reimplementar a lógica no shell.
- **WRAP** — embutir o módulo nativo e expor por platform channel.
- **FEDERATE** — subir o serviço e falar por API.
- **VENDOR** — consumir como dependência/binário.
- **HARVEST** — extrair só dados/regras, descartar o código.

## Fases

```
F0  Reconhecimento dos 7 repositórios + auditoria de licença   <- ESTAMOS AQUI
F1  ADRs (decisões de arquitetura)
F2  Esqueleto do monorepo + CI + Makefile
F3  Health Data Core
F4  Passos (foreground service)
F5  Cérebro com 1 ferramenta só
F6  Nutrição + código de barras
F7  Academia: planos + sessão + séries
F8  Corrida/caminhada com GPS
F9  Wearable BLE
F10 Entitlements
F11 Pagamentos (um canal só)
F12 Compartilhamento social
F13 wger + Fasten
F14 Painel B2B (produto separado, depois do MVP)
```

## Definição de Pronto do MVP (em aparelho Android real)
1. Passos contados com a tela bloqueada por 8h, batendo com o sistema (±5%).
2. Refeição registrada por código de barras, com macros no dashboard.
3. Pulseira BLE sincroniza FC e sono para o Health Data Core.
4. "Quantas calorias comi hoje e quanto andei?" respondido pelo LLM local, offline.
5. Plano de treino prescrito, executado com séries e carga, progressão visível.
6. Corrida de 5 km gravada com tela bloqueada, rota e splits corretos, bateria medida.
7. Card de corrida compartilhado no Instagram com rota ofuscada e nada clínico.
8. Assinatura ativada por Pix; entitlement chega ao app e sobrevive 7 dias offline.
9. `docs/LICENSE-AUDIT.md` fechado e modelo de distribuição decidido.

## Fora de escopo (não implementar)
- Anúncios de qualquer tipo.
- Diagnóstico, prescrição ou conduta clínica pela IA.
- Publicação automática em redes sociais.
- Qualquer coleta de telemetria.
