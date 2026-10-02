# Prompt para o Claude Design — RLT (Real Life Track)

> Gerado em 2026-10-02 a partir das decisões registradas em `docs/PRODUTO.md`,
> ADR-11 (IA em nuvem com chave do usuário), ADR-12 (Android apenas, nome RLT),
> ADR-7 (regras de assinatura dentro do app), `.claude/rules/share.md`,
> `.claude/rules/brain.md` e `docs/specs/nutricao.md`. Copie tudo abaixo da
> linha para o Claude Design.

---

Desenhe o aplicativo Android completo **RLT — Real Life Track**: um app de saúde
pessoal tudo-em-um, em português do Brasil.

## Como entregar

- Uma prancheta (artboard) por tela, celular Android, largura 360–412 dp.
- Material Design 3, tema claro **e** escuro.
- Para cada tela com dados, mostre também os estados: **vazio** (primeiro uso),
  **carregando**, **erro** e, quando existir, **sem permissão** e **sem internet**.
- Uma prancheta extra com os componentes reutilizáveis e os tokens (cores,
  tipografia, espaçamentos, raios).
- Acessibilidade: contraste AA, toque mínimo de 48 dp, layout que aguenta fonte
  grande do sistema.

## Sobre o produto

O RLT junta num só lugar: alimentação, água, remédios, histórico médico, sinais
vitais, corpo, passos, treino de academia e corrida. O centro do app é o
**Cérebro**: uma conversa igual a um chat com IA, onde a pessoa escreve, fala,
manda foto, PDF, áudio ou vídeo, e a IA organiza tudo no lugar certo do app.

Princípios que o design precisa transmitir:
- **Privacidade:** os dados ficam no celular. Sem conta, sem cadastro, sem anúncio.
- **Funciona offline:** tudo funciona sem internet. Só a IA do Cérebro usa internet,
  e só quando a pessoa envia uma mensagem.
- **Nada é gravado sem confirmação:** quando a IA entende algo, ela mostra cartões
  com o que vai registrar; a pessoa confirma, edita ou descarta cada um.

## Navegação

Barra inferior com **5 abas**, nesta ordem:
1. **Início**
2. **Saúde**
3. **Cérebro** (aba central, com destaque visual)
4. **Nutrição**
5. **Exercícios**

No topo do Início: avatar que abre **Conta e Configurações**, e um ícone de
lembretes/notificações.

---

## 0. Primeiro uso (onboarding)

1. Boas-vindas: o que é o RLT, em 3 telas curtas no máximo.
2. Privacidade: "seus dados ficam no seu celular" — explicação simples.
3. Perfil: sexo biológico (usado nas fórmulas), data de nascimento, altura, peso,
   nível de atividade, objetivo (perder peso, manter, ganhar massa, saúde geral).
4. Metas sugeridas, todas editáveis: calorias, proteína/carboidrato/gordura, água,
   passos. Mostrar de onde veio o número ("calculado pelo seu perfil").
5. Permissões, uma por vez, explicando o porquê: atividade física (contar passos),
   notificações (lembrete de remédio e água). Botão "agora não" sempre visível.
6. IA (opcional): "Quer ativar a IA? Você usa sua própria chave." — botões
   "Configurar agora" e "Depois".

## 1. Aba Início

Painel do dia — tudo o que importa hoje, num olhar.
- Saudação, data e seta para ver dias anteriores (ou calendário).
- **Metas do dia** com progresso: calorias (consumidas, meta, restantes),
  proteína/carboidrato/gordura, água, passos, minutos de exercício.
- **Remédios de hoje:** próximos horários, botões "tomei" e "pulei"; atrasados
  em destaque.
- **Sono da última noite** (quando houver pulseira conectada).
- **Linha do tempo do dia:** tudo em ordem cronológica — refeições, água,
  remédios, sintomas, treinos, corridas. Tocar abre o item.
- **Atalhos rápidos:** + água, + refeição, tomei remédio, iniciar treino,
  iniciar corrida, falar com o Cérebro.
- Sequência de dias com registro.
- Estados: dia vazio; passos sem permissão ("permitir contagem de passos");
  aparelho sem sensor de passos.

## 2. Aba Saúde

Tela inicial com atalhos para cada seção e um resumo (próximo remédio, último
sintoma, última medida de pressão, peso atual).

**2.1 Remédios**
- Lista dos remédios ativos: nome, dose, forma (comprimido, gota, injeção…),
  horários, "uso contínuo" ou "até dd/mm".
- Agenda do dia e da semana: tomado / pulado / atrasado.
- Cadastrar/editar remédio: nome, dose, forma, frequência e horários, início,
  fim ou uso contínuo, observações, receita vinculada, lembrete liga/desliga.
- Histórico de adesão (percentual de doses tomadas por período).

**2.2 Receitas médicas**
- Lista de receitas (foto ou PDF), médico, data, validade, remédios vinculados.
- Ver receita em tela cheia.

**2.3 Histórico médico**
- Diário de sintomas: registrar sintoma, intensidade (0–10), quando começou e
  terminou, observação.
- Condições e diagnósticos informados pela pessoa, alergias, cirurgias, vacinas.
- Consultas: data, especialidade, profissional, anotações.

**2.4 Exames e documentos**
- Enviar foto ou PDF de exame; categoria e data.
- Valores lidos (ex.: glicemia, colesterol) com gráfico de evolução de cada
  marcador.
- Selo "Premium" (sem preço) em "conectar prontuário de hospital".

**2.5 Sinais vitais**
- Pressão arterial, glicemia, frequência cardíaca, temperatura, saturação.
- Registro manual ou vindo da pulseira; gráficos por período.

**2.6 Corpo**
- Peso, % de gordura, medidas (cintura, quadril, braço, coxa…), IMC, relação
  cintura/altura. Gráfico de evolução e projeção até a meta.

**2.7 Sono**
- Noites, duração e fases, quando vier da pulseira.

Rodapé fixo da aba: "O RLT não faz diagnóstico nem prescrição. Em caso de
dúvida ou sintoma preocupante, procure um profissional de saúde."

## 3. Aba Cérebro

Igual a uma conversa com um assistente de IA.
- Lista de conversas e botão "nova conversa".
- Mensagens da pessoa e da IA, com suporte a imagem, PDF, áudio e vídeo dentro
  da conversa.
- **Campo de mensagem** com: anexar foto da galeria, tirar foto, anexar
  arquivo/PDF, anexar áudio ou vídeo, **segurar para gravar voz**, enviar.
- **Cartões de proposta** (o componente mais importante do app): quando a IA
  entende algo, ela responde com um cartão por item, cada um com o ícone da
  área de destino. Exemplo para a mensagem "bebi 2 L de água de manhã, comi 3
  ovos cozidos no café, acordei com dor de cabeça e tomei dipirona 500 mg às 9h":
  - [ícone água] Água — 2 L — hoje 08:00
  - [ícone refeição] Café da manhã — 3 ovos cozidos — 234 kcal (P 19 g · C 2 g · G 16 g)
  - [ícone sintoma] Sintoma — dor de cabeça — hoje, manhã
  - [ícone remédio] Remédio tomado — Dipirona 500 mg — hoje 09:00
  Cada cartão tem: confirmar, editar, descartar. E um botão "confirmar todos".
  Depois de confirmado, o cartão mostra onde foi salvo ("salvo em Nutrição").
- **Perguntas da IA** quando falta informação, com respostas rápidas em chips
  (ex.: "Em quais horários você toma esse remédio?").
- **Foto de prato com peso:** a IA mostra os alimentos que identificou, a
  porção estimada de cada um, calorias e macros, um selo **"estimativa"**, e a
  refeição sugerida pelo horário da foto (08:00 → café da manhã), tudo editável.
- **Foto de receita médica:** a IA mostra os remédios lidos, dose, horários e
  duração. Uso contínuo → propõe agenda até o fim do ano. Uso curto (ex.: 3 dias)
  → propõe só esses dias. Se faltar horário, pergunta.
- Estados:
  - **Sem chave de IA (modo básico):** o chat continua funcionando com comandos
    simples; mostrar exemplos clicáveis ("registrar água 500ml", "resumo de hoje")
    e um aviso discreto "Ative a IA em Conta > Cérebro para entender fotos e texto
    livre".
  - **Sem internet:** só o modo básico; mensagem explicando.
  - **Primeiro envio para a IA:** tela de consentimento dizendo qual empresa
    recebe os dados e o que é enviado; botões "concordo" e "não agora".
  - IA pensando; erro do provedor (chave inválida, limite atingido).
- Respostas sobre saúde sempre com o aviso curto de que o app não diagnostica
  nem prescreve.

## 4. Aba Nutrição

**4.1 Hoje**
- Anel de calorias (consumidas, meta, restantes) e barras de proteína,
  carboidrato e gordura.
- Refeições do dia: café da manhã, almoço, jantar, lanches — cada uma com seus
  alimentos, foto do prato (se houver), calorias, e "+ adicionar".
- Cartão de água com botões rápidos (+200, +300, +500 ml) e meta.

**4.2 Adicionar alimento** (quatro caminhos para a mesma ação)
- Buscar por nome (catálogo de alimentos brasileiros + itens próprios).
- Ler código de barras pela câmera, com digitação manual do código como
  alternativa.
- Adição rápida: nome + calorias (macros opcionais).
- Foto do prato (vai para o Cérebro analisar).
- Recentes e favoritos para adicionar com um toque.

**4.3 Detalhe do alimento**
- Tabela nutricional completa (calorias, carboidrato, açúcar, fibra, gordura,
  gordura saturada, proteína, sódio e micronutrientes quando houver).
- Quantidade e unidade, refeição, horário. Confirmar.

**4.4 Diário**
- Calendário com cada dia marcado como dentro/fora da meta; ao tocar, o dia
  com as refeições.

**4.5 Tendências**
- Calorias contra a meta, média de macros em 7/30/90 dias, água, peso contra a
  meta com previsão de quando chega lá.

**4.6 Dieta e metas**
- Meta calórica calculada (mostrar a fórmula usada e permitir ajuste manual),
  divisão de macros, plano de refeições (opcional).
- Preferências e restrições: vegetariano, vegano, sem lactose, sem glúten,
  alergias alimentares, alimentos que não gosta.

**4.7 Receitas e refeições próprias**
- Montar a partir de ingredientes, com nome, foto, porções; reutilizar depois.

**4.8 Galeria de pratos**
- Grade com as fotos dos pratos registrados, por data.

## 5. Aba Exercícios

**5.1 Hoje**
- Anel de passos com meta, minutos ativos, calorias gastas, treino planejado do
  dia, atalhos "iniciar treino" e "iniciar corrida".

**5.2 Passos**
- Histórico por dia, semana e mês; meta; status do sensor (ativo, sem
  permissão, aparelho sem sensor). Nota: a contagem continua com a tela
  bloqueada — existe uma notificação fixa "RLT contando seus passos".

**5.3 Academia**
- Planos de treino: lista; criar/editar plano (exercícios, séries, repetições,
  carga, descanso).
- Biblioteca de exercícios: busca e filtro por grupo muscular.
- **Treino ao vivo:** exercício atual, série atual, carga e repetições editáveis,
  esforço percebido (RPE), cronômetro de descanso, marcar série concluída,
  próximo exercício, finalizar.
- Histórico de treinos, recordes pessoais, gráfico de progressão por exercício.

**5.4 Corrida e caminhada**
- Iniciar (escolher corrida ou caminhada).
- **Tela ao vivo:** tempo, distância, ritmo atual e médio, mapa da rota, pausar/
  retomar, pausa automática indicada, finalizar. Funciona com a tela bloqueada.
- Resumo: mapa da rota, parciais por km, elevação, ritmo médio, calorias.
- Histórico; exportar GPX.

**5.5 Outras atividades**
- Registro manual: tipo (natação, bike, futebol…), duração, intensidade →
  calorias estimadas.

**5.6 Compartilhar treino ou corrida**
- **Pré-visualização obrigatória** do cartão exatamente como vai sair.
- Interruptores por campo; **peso, IMC, calorias e medidas desligados por
  padrão**.
- Rota da corrida com o começo e o fim escondidos (privacidade de onde a pessoa
  mora).
- Botão "compartilhar" abre o compartilhamento do Android. Nunca publica sozinho.
- Nada de saúde clínica (exame, receita, remédio, diagnóstico) pode virar cartão.

## 6. Conta e Configurações (pelo avatar)

- **Perfil:** dados usados nas fórmulas (sexo biológico, nascimento, altura,
  peso, atividade, objetivo, % de gordura opcional).
- **Metas:** calorias, macros, água, passos, sono.
- **Cérebro (IA):** escolher o provedor de IA, colar a chave, testar a chave,
  ver exatamente o que é enviado, termo de consentimento, apagar a chave. Explicar
  o modo básico (sem chave).
- **Assinatura:** plano atual e recursos Premium com selo. Tela "Já assinei" com
  dois campos: e-mail e código, e "reenviar código".
  **Regra rígida: nenhum preço, nenhum valor, nenhum link ou texto dizendo onde
  comprar** — só o estado do plano e o selo "Premium".
- **Permissões:** passos, notificações, câmera, microfone, localização (corrida),
  dados de saúde da pulseira — cada uma com status e atalho para ativar.
- **Dispositivos:** conectar pulseira/relógio (via Health Connect do Android).
- **Lembretes:** remédios, água, treino — horários e liga/desliga.
- **Privacidade e dados:** exportar todos os dados (sempre grátis, sem limite),
  apagar todos os dados (com confirmação forte).
- **Preferências:** tema claro/escuro/sistema, unidades métricas, idioma
  (português).
- **Sobre:** versão, licenças de código aberto, aviso de que o app não
  diagnostica nem prescreve.

## 7. Componentes reutilizáveis (prancheta própria)

Cartão de proposta da IA (com estados: pendente, editando, confirmado,
descartado) · anel de progresso · barra de macro · item da linha do tempo · chip
de resposta rápida · selo "estimativa" · selo "Premium" (sem preço) · cartão de
remédio com "tomei/pulei" · aviso de saúde · estado vazio · estado sem
permissão · estado sem internet · campo de mensagem com anexos e gravação de voz.

## O que NÃO desenhar

- Anúncios de qualquer tipo.
- Login, cadastro ou senha (não existe conta; só o "Já assinei" para quem paga).
- Preço, valor ou botão de comprar dentro do app.
- Publicação automática em rede social.
- Qualquer tela em que a IA dê diagnóstico, sugira remédio ou mude dose.
- Telas de iPhone.
