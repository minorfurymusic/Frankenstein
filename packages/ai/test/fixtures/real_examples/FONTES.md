# Exemplos reais para testar o Cérebro (anexos)

12 arquivos baixados da internet em 2026-10-06, todos com licença livre e
**sem dado de pessoa real** (fotos de prato não mostram pessoas; receitas e
laudos são documentos sintéticos, com dados fictícios). Usados só em teste;
não entram no app.

`expected.json` traz, para cada arquivo, o gabarito (`truth`) e a resposta
que uma leitura correta da IA devolveria (`ai_reply`). Os testes do app usam
`ai_reply` no lugar do Gemini (rede bloqueada no desenvolvimento);
`test/live_eval_test.dart` manda os arquivos ao Gemini de verdade e compara
com `truth` quando existe `GEMINI_API_KEY` no ambiente.

## pratos/ — Nutrition5k (Google Research), CC BY 4.0

Fotos de cima de pratos reais de refeitórios, com massa e calorias medidas
em balança (gabarito em `metadata/dish_metadata_cafe1.csv` do conjunto).

- Fonte: https://github.com/google-research-datasets/Nutrition5k
  (arquivos em `gs://nutrition5k_dataset`, `imagery/realsense_overhead/<dish>/rgb.png`)
- Licença: Creative Commons Attribution 4.0 —
  https://creativecommons.org/licenses/by/4.0/
- Crédito: Thames, Q. et al., "Nutrition5k: Towards Automatic Nutritional
  Understanding of Generic Food", CVPR 2021.
- Mudança feita aqui: PNG convertido para JPEG (qualidade 82).

| Arquivo | Prato | kcal medidas | gramas |
|---|---|---|---|
| dish_1565640812.jpg | folhas, feijão preto, frango | 297,9 | 234 |
| dish_1560455090.jpg | salsão, frango, pepino, tomate-cereja, cenoura | 60,2 | 155 |
| dish_1563900150.jpg | ovos mexidos, batata-doce | 202,3 | 154 |
| dish_1562691032.jpg | ovos mexidos, batata, brócolis, frutas | 419,7 | 415 |

## receitas/ — xdiag-privacy (Xdiag Tecnologias), Apache-2.0

Receitas sintéticas brasileiras, marcadas "SYNTHETIC" / "Documento
sintetico para teste, dados ficticios".

- Fonte: https://github.com/Xdiag-IA/xdiag-privacy (`tests/corpus/`)
- Licença: Apache License 2.0 — Copyright 2026 Xdiag Tecnologias
  (http://www.apache.org/licenses/LICENSE-2.0)
- Arquivos: `receituario_07.png`, `receituario_assinado_17.png`,
  `receita_controle_especial_08.png`.
- `receituario_07_foto.jpg` é **derivado** de `receituario_07.png` (feito
  aqui): papel girado sobre fundo, sombra, desfoque e JPEG, para simular a
  foto de celular. A busca não achou uma 4ª receita sintética distinta com
  licença livre acessível desta rede (`samples/prescricao_medica.png` do
  mesmo projeto é cópia idêntica de `receituario_07.png`).

## exames/ — Exames-de-Sangue (psrs2000), MIT

Laudos brasileiros sintéticos em PDF ("não correspondem a nenhuma pessoa
real", segundo o projeto), em quatro formatos de laboratório.

- Fonte: https://github.com/psrs2000/Exames-de-Sangue (`tests/fixtures/`)
- Licença: MIT — Copyright (c) 2026 psrs2000
- Arquivos: `laudo-blocos.pdf`, `laudo-tabela.pdf`, `laudo-bullets.pdf`,
  `laudo-coagulacao.pdf`. O gabarito veio do HTML de origem de cada PDF.
