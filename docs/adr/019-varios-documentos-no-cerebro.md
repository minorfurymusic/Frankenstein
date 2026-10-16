# ADR-19 — Vários documentos de uma vez no Cérebro: a IA identifica e cada um vai para o seu lugar

**Status:** aceito (decisão explícita do usuário, 2026-10-16)
**Data:** 2026-10-16

## Contexto

No teste no aparelho (docs/TESTE-APARELHO.md, itens 3 e 13), o usuário
mandou um print como "foto do prato" e recebeu só "não reconheci
alimentos". Depois pediu: mandar 2–3 fotos de uma vez (receita com
remédios e comorbidades, plano do nutricionista com seus dados e a dieta,
ficha da academia, histórico médico) e o sistema entender e guardar cada
informação no lugar certo.

Hoje o anexo do Cérebro exige escolher antes o tipo (prato, receita ou
exame), um arquivo por vez.

## Opções consideradas

1. Escolher o tipo de cada foto antes de enviar (hoje, estendido).
2. **A IA identifica** o tipo de cada arquivo e cada um vira um cartão.

Dados pessoais lidos do documento (peso, altura, % de gordura, doenças):
1. **Cartão separado**, item por item, para a pessoa decidir.
2. Só guardar o documento, sem mexer em perfil ou histórico.

Foto que não é de saúde:
1. **A IA diz em uma frase o que vê** e avisa que não há o que registrar.
2. Só avisar que não é prato, receita, exame, plano ou ficha.

## Decisão

As três primeiras opções em negrito, escolhidas pelo usuário
(2026-10-16, "Recomendado" nas três):

- Anexar aceita **vários arquivos** (fotos e PDFs). Antes de ler, a IA
  **separa**: para cada arquivo, o tipo — prato, receita, exame, plano
  alimentar, ficha de treino, histórico/relatório médico ou outro (com uma
  frase dizendo o que é).
- Cada arquivo segue para o leitor do seu tipo, já existentes (prato,
  receita, exame, plano alimentar — ADR-18) ou novo (ficha de treino), e
  vira **um cartão** com "Revisar e salvar" ou confirmar. Destinos: Saúde ›
  Receitas/Remédios, Saúde › Exames, Nutrição › Plano de refeições,
  Exercícios › Academia (plano), Saúde › Histórico médico.
- Na mesma separação, a IA **transcreve** dados pessoais escritos no
  documento: peso, altura, % de gordura, e itens de histórico (condição,
  alergia, cirurgia, vacina, consulta). Cada um vira **cartão separado**
  ("Atualizar altura: 183 cm", "Adicionar ao histórico: Hipertensão");
  nada é salvo sem confirmar.
- A IA **não deduz** doença a partir de remédio (ex.: enalapril não vira
  "hipertensão"): só o que está escrito. Não sugere dose (ADR-11,
  `.claude/rules/brain.md`).
- Arquivo "outro": a resposta diz o que a IA viu e que não há o que
  registrar.
- Consentimento antes do envio (ADR-11), dizendo quantos arquivos vão.

## Consequências

- **Fica mais fácil:** trazer de uma vez os papéis do médico, do
  nutricionista e da academia.
- **Custo:** uma chamada a mais à IA (a separação) por envio, mais uma por
  arquivo — na chave do usuário.
- **Fica mais difícil:** a separação pode errar o tipo; por isso todo
  destino passa pela revisão de sempre, e o cartão mostra o tipo entendido.
- **Passa a ser proibido:** gravar dado lido de documento sem cartão
  confirmado; deduzir diagnóstico de remédio.
