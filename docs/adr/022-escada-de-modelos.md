# ADR-22 — Escada de modelos da IA: sem cota ou ocupado, passa sozinho para o próximo

**Status:** aceito (decisão explícita do usuário, 2026-10-16)
**Data:** 2026-10-16

## Contexto

No teste no aparelho (docs/TESTE-APARELHO.md, item 25), a chave gratuita
do Google bateu no limite (erro 429) e depois o servidor ficou ocupado
(503); a leitura de fotos travou os testes. A cota grátis da API do Google
é por projeto **e por modelo**: quando um modelo esgota, outro ainda
responde. O campo "Modelo" de Conta › Cérebro só salvava com Enter.

## Decisão

- **Escada** de modelos, do melhor para o mais leve: Gemini Flash de versão
  mais nova primeiro, depois as mais antigas, depois os Flash-Lite. Fora:
  Pro (cota grátis mínima), modelos de imagem, voz, embedding,
  experimentais e versões datadas repetidas.
- A lista vem dos modelos que a própria chave pode usar (GET da lista de
  modelos, só nomes, ao tocar "Testar e salvar" ou "Atualizar lista").
  Sem a lista, vale uma escada padrão.
- Sem cota (429) ou ocupado (500/502/503/504): passa para o próximo, **no
  máximo 3 modelos por pedido**, cada um uma vez. Modelo inexistente (404)
  é pulado sem contar. Chave recusada não desce a escada.
- O próximo pedido **começa onde parou**; no dia novo da cota (meia-noite
  do Pacífico) volta ao melhor.
- Os 3 falharam: "O limite gratuito do Google acabou nos modelos que tentei
  (3)… ative o faturamento no Google AI Studio" (ou "servidores ocupados").
- Cada resposta da IA mostra o **nome do modelo** que respondeu (o nome
  que o Google dá, ex.: "Gemini 2.5 Flash").
- Conta › Cérebro › Modelo vira lista: "Automático (recomendado)" ou um
  modelo fixo (sem descer), salvo na hora.

## Consequências

- **Fica mais fácil:** continuar usando a IA grátis depois de esgotar o
  melhor modelo.
- **Custo:** zero no servidor; na chave do usuário, até 3 pedidos por
  mensagem quando há erro de cota (pedido recusado não gasta cota).
- **Fica mais difícil:** a qualidade varia conforme o modelo; por isso o
  nome aparece em cada resposta, e tudo continua passando pela revisão.
