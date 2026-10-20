# Rodada de teste no aparelho — anotações

Problemas e pedidos vindos do teste no celular. Corrigir todos juntos,
com os prints, num ciclo de correções. Prints em `docs/teste-aparelho/`.

| # | Data | Onde | O que acontece | Esperado | Status |
|---|---|---|---|---|---|
| 1 | 2026-10-15 | Cérebro › mensagem enviada | Não dá para copiar o texto de uma mensagem que eu escrevi | Poder copiar (ex.: copiar, mudar algo e mandar de novo) | corrigido no código (segurar a mensagem: Copiar / Editar e mandar de novo) — conferir no aparelho |
| 2 | 2026-10-15 | Início / Exercícios › passos | Diz "Sem sensor de passos", mas contou passos (309, depois 401) | Contar passos e não mostrar o aviso. Causa provável: `hasSensor` pergunta ao serviço antes de ele terminar de ligar (`MainActivity.kt:67` devolve `false` com `stepService` nulo; `step_tracking_controller.dart:94-97`) | corrigido no código: sensor perguntado direto ao Android; última leitura entregue ao ligar; ponto da contagem guardado para contar o que foi andado com o app fechado — conferir no aparelho |
| 3 | 2026-10-15 | Cérebro › foto | Mandou uma imagem qualquer (print) e a resposta foi só "não reconheci alimentos" | Entender o que é a imagem (não só prato) e responder de acordo | corrigido no código (ADR-19): foto sem comida → a IA diz o que viu; Anexar › Vários documentos identifica o tipo — conferir no aparelho |

| 4 | 2026-10-15 | Calendário / data digitada | Em inglês; "28061990" recusado | Português, dd/mm/aaaa | corrigido no código (app em pt-BR) — conferir no aparelho |
| 5 | 2026-10-15 | Metas 747 kcal / carboidrato 0 g | — | Usuário confirmou: está certo (perder 300 g/dia, proteína alta) | não é problema |
| 6 | 2026-10-15 | Perfil › IMC no peso desejado | 253.814,7 ao digitar "1,83" (lido como 1,83 cm) | Aceitar altura em metros | corrigido no código |
| 7 | 2026-10-15 | Cérebro › bebida | Energético em g | ml | corrigido no código (IA marca bebida; mostra ml). 15 kcal em 1 L "zero" é estimativa da IA (bebidas zero têm poucas kcal) |
| 8 | 2026-10-15 | Cérebro › "O provedor de IA deu erro" | Erro frequente, some ao repetir | Repetir sozinho; dizer o código | corrigido no código: servidor ocupado (500/502/503/504) repete 2× sozinho; erro mostra o código HTTP e a mensagem do provedor — causa exata NÃO VERIFICADA (sem chave aqui) |
| 9 | 2026-10-15 | Cérebro › salvo direto? | — | Usuário confirmou: pediu confirmação | não é problema |
| 10 | 2026-10-15 | Cérebro › faixa do topo | Alta, feia | Compacta | corrigido no código (uma linha: "IA ativa · Gemini" + ícones) |
| 11 | 2026-10-15 | Conta › Dispositivos › Health Connect | Tocou e nada em 5 min | Abrir permissões | corrigido no código: espera no máx. 60 s, avisa, botão "Abrir o Health Connect", confere ao voltar. Causa de a tela não abrir NÃO VERIFICADA (sem aparelho) |
| 12 | 2026-10-15 | Remédios › aviso "Salvo" | Cobre o cartão | Não cobrir | aviso dura 2,5 s (antes 4 s) |
| 13 | 2026-10-16 | Cérebro › várias fotos | Pedido novo: mandar 2–3 fotos (receita, nutricionista, academia, histórico) e cada coisa ir para o lugar certo | — | decidido (ADR-19) e feito no código: Anexar › Vários documentos; cada arquivo vira cartão; peso/altura/% gordura e histórico em cartões separados — conferir no aparelho |

| 14 | 2026-10-16 | Passos | ~400 passos num dia com 1,2 km a pé; RLT não lia passos do Conexão Saúde (só sono e FC) | Passos do Android no RLT | feito no código (ADR-20): lê passos do Health Connect, uma fonte por dia, atualiza a cada 5 min com o app aberto — conferir no aparelho (tocar em "Permitir o que falta" em Conta › Dispositivos) |
| 15 | 2026-10-16 | Data digitada | Só números não aceita | Barras automáticas | feito no código: campo "Digite a data" com dd/mm/aaaa automático em todas as datas |
| 16 | 2026-10-16 | Primeiro uso › IA | Depois de colocar a chave, voltava com "Depois/Saber mais" | Seguir sozinho | feito no código: botão "Colocar minha chave"; com a chave salva, conclui o primeiro uso |

| 17 | 2026-10-16 | Academia › escolher exercício | Sem favoritos | Mais usados primeiro (a partir de 1 treino) | feito no código: seção "Mais usados" |
| 18 | 2026-10-16 | Treino ao vivo | Séries 2 e 3 vinham com 0 kg depois da 1ª com 34 kg; "0 kg" para peso do corpo | Herdar carga; mostrar "peso do corpo" | feito no código |
| 19 | 2026-10-16 | Adição rápida | Usuário espera buscar alimento com cálculo automático | — | a busca existe (Adicionar alimento › buscar, TACO, sem IA); "cafe" não achava "Café" — busca passou a ignorar acento |

| 20 | 2026-10-16 | Treino › gasto | 6 kcal por tempo de tela; carga não contava | Carga × repetições | feito no código (ADR-21): retas de Reis 2017 por exercício + geral; recuperação de Knausenberger 2014; carga total + barra somada; kcal por hora no resumo |
| 21 | 2026-10-16 | Alimentos › quantidade | Só gramas; café em g | Medidas caseiras, ml | feito no código: medida (ovo P/M/G, copo, colher, fio) × quantas; bebidas em ml; "Montar prato com ingredientes" na tela de adicionar. Dados novos (USDA/OFF) aguardando o usuário |

| 22 | 2026-10-16 | Passos | Sem registro à mão | Registrar por passos ou km | feito no código: "Registrar passos" (passos ou distância → passos pela passada), editar e excluir; somam por cima do celular |
| 23 | 2026-10-16 | Editar/excluir | Séries, exercícios e registros sem editar/excluir | Poder corrigir | feito no código: correção append-only (versão nova / excluído) — treino salvo (séries e treino), treino ao vivo, itens de refeição, linha do tempo do Início (água, peso, remédio, sintoma, pressão, atividades), registros do Corpo, sinais vitais, receitas, cadastro de remédio |
| 24 | 2026-10-16 | Preferências › Tema | 3 opções | Só Claro e Escuro | feito no código; sem escolha guardada, começa como o celular |
| 25 | 2026-10-16 | Cérebro › limite / ocupado | Erro 429 (limite) e depois 503 travaram a leitura de fotos; campo Modelo só salvava com Enter | Trocar de modelo sozinho e mostrar qual respondeu | feito no código (ADR-22): escada de modelos da chave, até 3 por pedido, começa onde parou e volta ao topo no dia seguinte; nome do modelo em cada resposta; Modelo vira lista "Automático" que salva na hora — conferir no aparelho |
| 26 | 2026-10-16 | Cérebro › café com açúcar | 2 copos (660 ml) com 15 g de açúcar cada: 240 kcal; esperado ≈ 120 | Açúcar contado uma vez | conta do app conferida (kcal do item = total da porção, `nutrition_store.dart:215`); causa provável: a IA contou o açúcar dentro do café e de novo como item — NÃO VERIFICADA (falta o print do cartão). Instrução da IA corrigida: o que vai na bebida é item próprio e a bebida conta só ela |
| 27 | 2026-10-16 | Cérebro › resumo do dia | "0,0 km de corrida/caminhada" com 3.590 passos | Distância também pelos passos | feito no código: "3.590 passos (≈ 2,7 km pela sua passada)"; corrida/caminhada só aparece quando gravada |
| 28 | 2026-10-16 | Cérebro › foto | Não dava para escrever junto com a foto | Foto + texto | feito no código: o anexo espera no campo; o texto vai junto para a IA |
| 29 | 2026-10-16 | Cérebro › cartão da refeição | Só gramas | Trocar alimento e refeição; observação que a IA usa para corrigir | feito no código: nome, quantidade, refeição e "Observação para a IA" → "Recalcular" (só texto, a foto não vai de novo) |
| 30 | 2026-10-16 | Cérebro › anexo enviado | Não dava para reenviar | Reenviar | feito no código: tocar no anexo › "Mandar de novo" |
| 31 | 2026-10-16 | Cérebro › remédio novo | Botão de editar apagado; pantoprazol com 2 horários; "desde 01/02" ignorado; "tenho hipertensão" sem cartão | Editar; data de início; histórico | feito no código: cartão do remédio editável (nome, dose, unidade, horários, desde); a IA lê "desde" e condição/alergia/cirurgia viram cartão do histórico |
| 32 | 2026-10-16 | Cérebro › copiar a minha mensagem | Não conseguia | Copiar e mandar de novo | o menu já existia ao segurar; agora abre também com um toque na mensagem — conferir no aparelho |
| 33 | 2026-10-16 | Cérebro › mensagem longa | Condição + 2 remédios + refeição: condição e refeição vieram, remédios não; "e os remédios?" funcionou | Tudo de uma vez | causa provável (a resposta da IA não foi vista): na correção anterior, a regra do histórico foi colada no meio da regra dos remédios, e a regra só falava em remédio "novo". Corrigido: remédio que a pessoa já toma também vai como cadastro; "registre TODAS"; remédio sem dose/horário não some — o app pede o que falta |
| 34 | 2026-10-16 | Cérebro › microfone | "Não funcionou" | Falar e mandar | causa exata NÃO VERIFICADA (sem aparelho e sem saber o que apareceu). Achados no código: tocar no microfone não fazia nada (só segurar gravava); microfone que não abria ficava calado; na 1ª vez a janela de permissão cortava o gesto. Feito: tocar começa e tocar de novo envia (segurar continua); X cancela; avisos quando não abre ou falta permissão |

## Prints recebidos (explicação do usuário pendente)

| Arquivo | Tela | Observação minha (a confirmar com o usuário) |
|---|---|---|
| `2026-10-15_01_perfil-data-nascimento.jpg` | Perfil › data de nascimento | Calendário em inglês ("Select date", "mm/dd/yyyy", "Invalid format", "Cancel") — o app não carrega o idioma português nos componentes do sistema |
| `2026-10-15_02_onb-passos.jpg` | Primeiro uso › Contar seus passos | — |
| `2026-10-15_03_onb-privacidade.jpg` | Primeiro uso › Seus dados ficam no seu celular | — |
| `2026-10-15_04_onb-boas-vindas.jpg` | Primeiro uso › RLT — Real Life Track | — |
| `2026-10-15_05_onb-perfil.jpg` | Primeiro uso › Seu perfil | — |
| `2026-10-15_06_onb-ia.jpg` | Primeiro uso › Quer ativar a IA? | — |
| `2026-10-15_07_dispositivos.jpg` | Conta › Dispositivos | Botão "Conectar pelo Health Connect" parece desativado |
| `2026-10-15_08_onb-metas-sugeridas.jpg` | Primeiro uso › Suas metas sugeridas | Valores estranhos: 747 kcal e Carboidrato 0 g |
| `2026-10-15_09_perfil-objetivo-imc.jpg` | Perfil › Objetivo | "IMC no peso desejado: 253.814,7" — valor impossível (provável erro de unidade da altura) |
| `2026-10-15_10_perfil-data-digitada.jpg` | Perfil › data de nascimento digitada | "28061990" recusado ("Invalid format"): campo espera mm/dd/yyyy, em inglês |
| `2026-10-15_11_cerebro-erro-provedor.jpg` | Cérebro › conversa | "1 litro de energético" virou "Energético sem açúcar 1.000 g" (gramas em vez de ml); "2 cachorros-quentes…" deu "O provedor de IA deu erro"; cabeçalho da IA cobre o topo da conversa |
| `2026-10-15_12_inicio-metas.jpg` | Início › Metas do dia | Mesmas metas estranhas (747 kcal, Carboidrato 0 g); cartão "Sem sensor de passos" — confirmar se o celular tem sensor |
| `2026-10-15_13_conta-cerebro-ia.jpg` | Conta › Cérebro (IA) | Chave digitada; ainda mostra "Modo básico ativo"; modelo "gemini-flash-latest" |
| `2026-10-15_14_cerebro-digitando.jpg` | Cérebro › digitando | Mensagem "bebi 2 litros e meio de água e 1 litros de energético sem açúcar" (origem do print 11) |
| `2026-10-15_15_cerebro-inicio.jpg` | Cérebro › tela inicial com IA ativa | — |
| `2026-10-15_16_cerebro-passos.jpg` | Cérebro › passos | Pedido "registre os 6000" deu erro do provedor e depois "não é possível registrar manualmente"; usuário pergunta como o app contou 309 passos (Início dizia "Sem sensor de passos") |
| `2026-10-15_17_cerebro-foto-print.jpg` | Cérebro › foto do prato | Enviado um print da tela como foto do prato: 1ª vez erro do provedor, 2ª "Não reconheci alimentos" |
| `2026-10-15_18_novo-exame-lido.jpg` | Saúde › Novo exame (lido pela IA) | Leitura de exame de sangue com valores e referências — parece ter funcionado |
| `2026-10-15_19_cerebro-agua-energetico.jpg` | Cérebro › água e energético | Salvo direto ("Salvo em Nutrição") — confirmar se passou pela confirmação; energético em g em vez de ml |
| `2026-10-15_20_cerebro-consentimento.jpg` | Cérebro › Antes do primeiro envio | — |
| 21 (fora do repositório) | Cérebro › exame em PDF | Laudo lido: "34 valores lidos", cartão com "Revisar e salvar" — parece ter funcionado |
| `2026-10-15_22_cerebro-passos-km.jpg` | Cérebro › passos | "4,8 km dão 179 passos?": erro do provedor, depois "Hoje: 309 passos"; a IA explica que o valor vem do sensor |
| 23–25 (fora do repositório) | Saúde › Novo exame (lista de valores) | Hemograma, leucograma, bioquímica, urina com referências do laboratório — parece ter funcionado |
| 26 (fora do repositório) | Saúde › Seções | Peso atual aparece; Exames "1 exame · último 05/05" |
| 27 (fora do repositório) | Cérebro › exame | Cartão do exame passou a "Salvo em Saúde › Exames" depois de revisar |
| 28, 30 (fora do repositório) | Saúde › Novo exame | Fim da lista (urina, campo Anotações) e bioquímica; unidade "mL/mim/1,73m²" copiada do laudo como está |
| 29 (fora do repositório) | Saúde › Exames e documentos | Marcadores acompanhados, 1 medição cada |
| 31 (fora do repositório) | Saúde › Seções | Remédios "1 ativo", mas o cartão do topo diz "Nada pendente hoje" com 2 doses atrasadas |
| 32–33 (fora do repositório) | Saúde › Novo remédio | Horários personalizados 07:00 e 18:00; lista de frequência abre por cima do formulário |
| 34 (fora do repositório) | Saúde › Remédios | Remédio criado às 18:31 já mostra a dose das 07:00 de hoje como ATRASADO; aviso "Salvo" cobre o cartão; botão "Novo remédio" cobre o aviso de rodapé; notificações desligadas |

Prints 21, 23 a 34 mostram exame de sangue real do usuário. O
repositório é público; por isso ficaram **fora** dele, só na sessão de
trabalho, até o usuário decidir (ver regra de dado de saúde / LGPD).

## Para testar no aparelho (funções novas, 2026-10-18)

| # | Onde | Como testar | Esperado |
|---|---|---|---|
| T1 | Saúde › Saúde mental | Tocar num rosto, completar energia/ansiedade/sentimentos, Salvar | "Humor salvo"; aparece na faixa de 30 dias e na lista; aba Saúde mostra "Último humor" |
| T2 | Saúde › Saúde mental | "Registrar sintoma (tristeza, ansiedade…)" | Atalhos de sintomas mentais; salvo no Histórico médico |
| T3 | Saúde › Saúde mental | Rolar até o fim | Aviso fixo CVV 188 / SAMU 192 |
| T4 | Cérebro | Tocar "Como estou?" (ou escrever "como eu tô?") | Mostra "O que foi para a IA", a análise e sugestões tocáveis |
| T5 | Cérebro | Com humor registrado, repetir T4 | A linha de humor (e de questionários) aparece sempre no que foi enviado |
| T6 | Cérebro (com plano de refeições) | "não aguento mais ovo" | Cartão "Trocar no plano — <refeição>" com antes → depois; confirmar muda o plano |
| T7 | Cérebro (com ficha de treino) | "enjoei do supino" → tocar numa opção | Cartão "Trocar na ficha"; confirmar troca o exercício (carga a definir) |
| T8 | Conta › Lembretes › Rotina | Ver o liga/desliga geral e os 4 tipos | Cada tipo desliga sozinho |
| T9 | Notificação de rotina | Registrar humor "Muito mal" 3 dias seguidos | No dia seguinte às 10h chega a notificação; abrir o app abre o Cérebro com a pergunta |
| T10 | Cérebro › refeição | "comi um bolo de chocolate" | Cartão normal; o açúcar passa a entrar no "Como estou?" |
| T11 | Conta › Permissões | Microfone negado | "Não permitida" + "Ativar" |
| T12 | Saúde › Saúde mental › Questionários | Responder PHQ-9 e GAD-7 | Pontuação e ponto de corte (10), sem diagnóstico; última pontuação aparece na linha; item 9 do PHQ-9 acima de "nenhuma vez" mostra o CVV |

## Rodada 2026-10-20 — código de barras e rótulo pelo Cérebro

Referência (rótulo do Trakinas que o usuário mandou, por 100 g): 459 kcal,
carbo 70 g, proteína 5,7 g, gordura 17 g. Porção 30 g = 2 6/7 biscoitos,
ou seja, 1 biscoito ≈ 10,5 g. O usuário cadastrou o Trakinas pelo código
de barras em Nutrição e citou três códigos: 7891097103841, 7622210674050,
7622210592750. Ainda não se sabe qual é o do Trakinas nem se o item
aparece como "Meu item".

| Hora | O que foi enviado | O que o app fez | Avaliação |
|---|---|---|---|
| 09:08 | Texto: "código 7622210592750, 9 biscoitos" | "Identifiquei pelo código: Oreo", 95 g, ≈ 456 kcal | **Errado.** A IA não tem acesso a nenhuma base de códigos de barras e mesmo assim afirmou ter identificado o produto |
| 09:09 | Foto do número do código + "9 biscoitos dessa marca" | "Não vi comida nesta foto" | Esperado hoje: a foto do prato só aceita comida |
| 09:10 | Texto: 40 g do 7622210674050 e 70 g do 7891097103841 | "Oreo 40 g, Bis 70 g", ≈ 549 kcal | **Errado**, mesmo motivo (produto inventado pelo número) |
| 09:11 | Texto: 50 g do 7891097103841 | "Bis 50 g", ≈ 260 kcal | **Errado**, mesmo motivo |
| 09:15 | Foto do código (Mondelēz) + "6 biscoitos desse código" | "Sem conexão com a IA" | Não verificado se foi a internet ou o tempo esgotado |
| 09:23 | Mesma foto + "6 biscoitos" | "Biscoito recheado 75 g", ≈ 354 kcal | Pelo rótulo seria 63 g e ≈ 289 kcal (+22%). Não usou o item cadastrado |
| 09:28–09:29 | Foto do rótulo + "4 biscoito" (3 vezes) | "Sem conexão com a IA" | Não verificado se foi a internet ou o tempo esgotado |
| 09:30 | Foto do rótulo + "4 biscoito" | "Biscoito recheado de chocolate 42 g", ≈ 193 kcal | **Certo**: 4 × 10,5 g = 42 g; 42 × 4,59 = 192,8 kcal. O cartão não mostra a hora |

Causas encontradas lendo o código (não confirmadas no aparelho):
- Pelo Cérebro, a refeição é sempre estimada pela IA (`log_estimated_meal`,
  `app/lib/ai/brain_ai.dart:15-20, 202-219`). O Cérebro não consulta os
  itens salvos nem os códigos de barras cadastrados: nenhum arquivo de
  `app/lib/ai/`, `app/lib/chat_router.dart` ou `app/lib/screens/brain/`
  menciona código de barras.
- "Sem conexão com a IA" aparece tanto sem internet quanto quando o
  pedido passa de 90 s (`packages/ai/lib/src/gemini_client.dart:350-356`,
  `HttpAiTransport` em `:55`; texto em `app/lib/ai/ai_settings.dart:216`).
  Pela tela, não dá para saber qual dos dois aconteceu.

Mais dois prints e uma informação do usuário (2026-10-20): os três
códigos são do Trakinas, de um queijo e de outro produto. A IA errou os três.

| Hora | Onde | O que aparece | Avaliação |
|---|---|---|---|
| 09:39 | Nutrição › Nova receita, ingrediente "Café" | Busca mostra "Café 2 kcal" duas vezes, além de "Café, infusão 10%" e "Café, pó, torrado 419 kcal". As medidas oferecidas para "Café" são gramas, colher de sopa, colher de chá e **fatia/unidade pequena** | **Errado**: falta xícara/ml, e não existe "fatia" de café. Os dois "Café 2 kcal" vêm de refeições estimadas pela IA e confirmadas, porque cada item confirmado vira um alimento novo (`app/lib/data/nutrition_store.dart:200-228`). A busca procura em todos os alimentos guardados (`packages/nutrition/lib/src/food_repository.dart:198-207`). "Café" sozinho não está na lista de bebidas (`app/lib/data/household_measures.dart:17-35`, que só reconhece "café, infusão" e "café coado") |
| 11:58 | Cérebro | "Repita o café da manhã salvo" → a IA diz que não vê o histórico; depois o app mostra o "Resumo de hoje" (586 kcal em 2 refeições) | Coerente com o desenho atual: a IA não recebe o que está salvo, e só o app responde perguntas sobre os dados, e só três tipos (`packages/ai/lib/src/chat_intents.dart:370-375`). Não existe pedido de "repetir refeição" |

## Para testar no aparelho (ADR-28, 2026-10-20)

| # | Onde | Como testar | Esperado |
|---|---|---|---|
| T13 | Cérebro | Com o Trakinas cadastrado pelo código, escrever "comi 6 biscoitos do <código do Trakinas>" | Cartão com o nome cadastrado e "kcal (dos seus itens salvos)", sem a etiqueta "Estimativa"; as gramas podem ser corrigidas no lápis |
| T14 | Cérebro | Escrever um código que não está cadastrado (ex.: o do queijo) | Aviso "O código … não está nos seus itens", sem cartão e sem nome inventado |
| T15 | Cérebro › foto | Foto com os números do código de barras + "6 biscoitos" | Igual a T13 (ou T14, se o código não estiver cadastrado). Foto só das barras, sem os números: não é garantido que a IA leia; o leitor de Nutrição › Código de barras é o caminho certo |
| T16 | Cérebro | "repete o café da manhã de ontem" (ou "repita o café da manhã salvo") | Cartão com os mesmos itens da refeição salva; confirmar grava uma refeição nova |
| T17 | Cérebro | "o que eu comi hoje?" / "o que comi ontem?" | Lista das refeições com hora, itens e kcal |
| T18 | Cérebro e Nutrição | "tomei um copo de café" e foto de um prato com bebida; depois Nutrição › Montar prato › buscar "café" | Bebida em ml no cartão e na Nutrição; medidas copo/xícara (sem "fatia"); o mesmo café estimado aparece uma vez só na busca |

