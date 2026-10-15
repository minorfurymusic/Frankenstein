# Rodada de teste no aparelho — anotações

Problemas e pedidos vindos do teste no celular. Corrigir todos juntos,
com os prints, num ciclo de correções. Prints em `docs/teste-aparelho/`.

| # | Data | Onde | O que acontece | Esperado | Status |
|---|---|---|---|---|---|
| 1 | 2026-10-15 | Cérebro › mensagem enviada | Não dá para copiar o texto de uma mensagem que eu escrevi | Poder copiar (ex.: copiar, mudar algo e mandar de novo) | aberto |

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
