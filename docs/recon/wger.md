# Ficha de reconhecimento — wger

> `docs/recon/_MODELO.md` é o template de ADR, não de ficha de repositório
> (débito técnico registrado em `STATUS.md` no Ciclo 1).

**Repositório:** https://github.com/wger-project/wger.git
**Commit avaliado:** `b1714bc5ac0f7e8666bed6d029e56c41adabddaa` (2026-07-29)

## Licença

Lida literalmente de `LICENSE.txt` na raiz do clone: **GNU Affero General
Public License, Version 3** (cabeçalho: "GNU AFFERO GENERAL PUBLIC LICENSE
/ Version 3, 19 November 2007", Copyright FSF) — bate com o badge do
`README.md` ("AGPLv3 License").

**Divergência confirmada por subdiretório** (você pediu para registrar
explicitamente):
- `wger/core/static/fonts/LICENSE.txt` — **Apache License, Version 2.0**
  (cabeçalho verificado literalmente), cobrindo só as fontes estáticas
  empacotadas, não o código.
- `wger/core/fixtures/licenses.json` — não é licença de código, é dado: a
  tabela de licenças de **conteúdo** (exercícios) que o próprio wger
  cataloga para uso interno — CC-BY-SA 3/4, CC0, entre outras. É uma
  feature do produto (licenciar cada exercício individualmente), não uma
  licença do repositório.
- `wger/core/views/license.py` e `wger/core/models/license.py` — código
  Python do app que implementa essa feature de licenciamento de conteúdo,
  sob a mesma AGPL-3.0 do resto do repositório (nenhum cabeçalho de licença
  próprio encontrado nesses arquivos).

**Relevante para ADR-5:** AGPL-3.0 é o regime mais restritivo confirmado
até agora entre os repositórios com ficha pronta (mais forte que GPL-3.0
do FoodYou/OpenNutriTracker: AGPL cobre uso via rede, não só distribuição).
Isso é decisivo se `docs/B2B.md` previr wger hospedado como serviço — AGPL
obriga a disponibilizar o código-fonte também para usuários que só acessam
via rede, não apenas para quem recebe o binário.

## Stack observada

Confirmado abrindo o repositório: **Python/Django**
(`pyproject.toml`: `requires-python = ">=3.12"`, build backend `hatchling`,
gerenciado com `uv`/`uv.lock`), self-hosted — bate com a hipótese em
`docs/PRODUTO.md`. Há também `package.json`/`package-lock.json` (frontend
JS, não investigado a fundo neste ciclo).

## Build

**Tentei compilar/instalar.** `uv sync --python 3.12` (timeout 180s):
resolveu e instalou todas as dependências com sucesso, incluindo o próprio
pacote `wger==2.7.0a1` em modo editável — sem erro.

Em seguida `uv run python manage.py check` (timeout 60s): **falhou**, mas
não por erro de build — parou em
`django.core.exceptions.ImproperlyConfigured: Set the DJANGO_DB_ENGINE
environment variable`. É configuração de ambiente ausente (banco de dados
não configurado), não um defeito no código nem no processo de instalação.
Não configurei banco de dados nem variáveis de ambiente para ir além disso
— fora do escopo deste ciclo de reconhecimento.

## Observações

- Dependência de banco de dados (Postgres, a julgar por `psycopg`/
  `psycopg-binary` nas dependências resolvidas) — relevante para
  `docs/B2B.md` se wger for oferecido hospedado.
- `.venv` criado por `uv sync` fica em `refs/wger/.venv/`, dentro de
  `refs/`, que já está no `.gitignore` — nada vazou pro controle de versão.
