# Pendências para a versão 1.0 — RLT

Fonte única do que falta (2026-10-20). Atualize ao fechar cada item.
"Confirmado" = o usuário disse que funcionou no celular dele. Testes
automáticos (`make test`) não contam como confirmação no aparelho.

## 1. Confirmado pelo usuário no celular

| Área | Função |
|---|---|
| Cérebro (IA) | Chave do Gemini salva, IA ativa; troca automática de modelo quando a cota acaba |
| Cérebro | Foto do prato vira refeição estimada; foto com texto junto |
| Cérebro | Ficha de treino escrita à mão lida por foto |
| Cérebro | Exame em PDF lido e salvo em Saúde › Exames |
| Cérebro | Áudio (microfone) |
| Cérebro | Remédios e doença pelo chat (cadastro com horários, histórico médico) |
| Cérebro | Refeição por texto |
| Cérebro | Conversa, cartão de humor, caminhada/atividade e ida e volta (APK `d0297c3`, "testei e está ok") |
| Conta | Tela de permissões |
| Geral | Português (pt-BR), data dd/mm/aaaa, tema claro/escuro |

## 2. Feito, só com teste automático (NÃO VERIFICADO no celular)

- Passos: Health Connect a cada 5 min, contagem com tela bloqueada, passos à mão por distância.
- Nutrição: busca TACO sem acento, medidas caseiras, "Montar prato", código de barras, cartão de refeição editável com "Recalcular", plano de refeições, trocas no plano.
- Academia: treino ao vivo, carga herdada, "mais usados", gasto por carga (ADR-21), troca de exercício na ficha.
- Corrida/caminhada com GPS real (rota, ritmo, bateria).
- Editar/excluir registros.
- Saúde mental: humor do dia, faixa de 30 dias, sintomas mentais, PHQ-9/GAD-7, aviso CVV.
- "Como estou?" (resumos da semana).
- Avisos de rotina e liga/desliga por tipo.
- Vários documentos de uma vez.
- Exportação de dados, lembretes, sono e batimentos do relógio, card de compartilhamento.

## 3. Decisões que dependem do usuário

Números de `docs/DECISOES-PENDENTES.md`.

| # | Pendência |
|---|---|
| 3 | Vídeo no Cérebro (adiado pelo usuário: gasta cota) |
| 4, 7, 8, 11, 14 | Itens "Confere?" sem resposta |
| 10 | Metas de dias passados usam o peso de hoje |
| 12 | Política de privacidade e termos de uso (texto jurídico, LGPD, advogado) |
| 13 | "Fotografar tabela nutricional" quando o código de barras não acha |
| 15 | Especificação de nutrição: incluir foto do prato e texto no Cérebro |
| 16 | Avaliação ao vivo com a chave do usuário (`packages/ai/test/live_eval_test.dart`) |
| 17 | Ícone do app (usuário vai mandar) |
| — | Lista de palavras + comandos simples sem IA; voz sem IA (Vosk) — propostos, sem resposta |

## 4. Dados

- Base de alimentos USDA/Open Food Facts traduzida: aguardando os CSVs do usuário. TBCA bloqueada (licença paga).
- Peso dos ovos P/M/G e coluna "líquido" da base nova (`app/lib/data/household_measures.dart:17,40`).
- Coeficientes de MET (ADR-15) conferidos só em fonte secundária.

## 5. Código (`TODO(frankstein)`)

- Passos por hora (`packages/activity/lib/src/steps_repository.dart:122`).
- Mapa offline na corrida (`app/lib/screens/exercise/activity_screens.dart:332`).
- Conta Google: nome/foto, apagar conta no servidor, entitlement assinado (`account_screen.dart:62`, `account_more_screens.dart:153,322`, `home_screen.dart:326`).
- Texto jurídico (`about_screen.dart:74`).

## 6. Segurança e privacidade

- Apagar do repositório público os prints 8, 9, 12 e 18 de `docs/teste-aparelho/` (têm dado de saúde do usuário).

## 7. Definição de Pronto da 1.0 (`docs/PRODUTO.md`)

| # | Critério | Situação |
|---|---|---|
| 1 | Passos com tela bloqueada 8 h, ±5% do sistema | Não medido |
| 2 | Refeição por código de barras no painel | Feito; não confirmado no celular |
| 3 | Relógio sincroniza batimentos e sono | Permissão ok; dados não confirmados |
| 4 | Perguntas sem IA (roteador) e com IA | Com IA ok; sem IA não testado |
| 5 | Plano de treino → execução → progressão | Parcial; progressão não confirmada |
| 6 | Corrida 5 km, tela bloqueada, rota, parciais, bateria medida | Não feito no celular (`docs/PERF.md`) |
| 7 | Card de corrida no Instagram, rota ofuscada | Não testado |
| 8 | Assinatura por Pix, entitlement 7 dias offline | Falta o servidor (F10/F11) |
| 9 | Auditoria de licenças fechada | Feito (ADR-5) |

Fora da tabela, necessário para lançar:
- Servidor: login com Google (ADR-13), entitlement assinado, apagar conta, prontuário Premium.
- APK de lançamento: chave de assinatura própria (os APKs de teste usam uma chave fixa de teste, ADR-28), versão, ícone.
- ADR-28: cadastrar os segredos `RLT_KEYSTORE_BASE64` e `RLT_KEYSTORE_PASSWORD` no GitHub; depois, confirmar no celular que o APK novo instala por cima e que "manter dados" aparece ao desinstalar.
- Canal de distribuição (ADR-7).
- wger/Fasten: código pronto, nunca falou com servidor real.
- Painel B2B (F14): depois da 1.0.

## Ordem sugerida

1. Usuário responde as decisões da seção 3, manda o ícone e os CSVs de alimentos.
2. Rodada de testes no celular dos itens 1–7 da seção 7, com roteiro.
3. Servidor (login, assinatura por Pix).
4. Lançamento (chave, textos legais, loja).
