# Revisão do layout RLT (Claude Design) — 2026-10-02

Fonte: artefato `https://claude.ai/artifact/EWnNAae2HmQzih87QMTVqK` (canvas do
Claude Design). Cópia local em `docs/design/rlt-layout/` — `canvas.json` + 81
pranchetas `*.dc.html`, cada uma com tema claro e escuro. É **referência
visual**, não código do app: nada daqui entra no APK.

## 1. Cobertura contra `docs/design/PROMPT-CLAUDE-DESIGN.md`

| Seção do prompt | Pranchetas | Situação |
|---|---|---|
| 0. Onboarding | Main, Login, OnbPrivacidade, OnbPerfil, OnbMetas, OnbPermissoes, OnbIA | coberto |
| 1. Início | Inicio, InicioEstados, InicioCalendario, Lembretes, InicioFonteGrande | coberto (+ teste com fonte do sistema em 160%) |
| 2.1 Remédios | Remedios, RemediosEstados, RemediosAgenda, RemedioForm, RemediosAdesao | coberto |
| 2.2 Receitas médicas | Receitas, ReceitasEstados | coberto |
| 2.3 Histórico médico | Historico, SintomaForm, HistoricoEstados | coberto (alergias, consultas, vacinas presentes) |
| 2.4 Exames | Exames, ExameMarcador, ExamesEstados | coberto; selo Premium só em "importar do hospital" |
| 2.5 Sinais vitais | Vitais, VitaisEstados | coberto |
| 2.6 Corpo | Corpo, CorpoEstados | coberto |
| 2.7 Sono | Sono, SonoEstados | coberto (via Health Connect) |
| 3. Cérebro | CerebroConversas, CerebroChat, CerebroCartoesEstados, CerebroFotoPrato, CerebroReceita, CerebroEntradas, CerebroConsentimento, CerebroEstados | coberto — "confirmar todos", "salvo em…", selo "estimativa", receita contínua → agenda até 31/12, uso curto → só os dias, pergunta de horário com chips |
| 4. Nutrição | NutricaoHoje, NutricaoEstados, AdicionarAlimento, CodigoBarras, AdicaoRapida, DetalheAlimento, NutricaoDiario, NutricaoTendencias, GaleriaPratos, DietaMetas, ReceitasProprias | coberto (4.1 a 4.8) |
| 5. Exercícios | ExerciciosHoje, ExerciciosEstados, Passos, Academia, PlanoTreino, AcademiaEstados, TreinoAoVivo, CorridaIniciar, CorridaAoVivo, CorridaResumo, CorridaHistorico, CorridaEstados, OutrasAtividades, Compartilhar | coberto — RPE, biblioteca, recordes, pausa automática, GPX, notificação fixa "contando seus passos" |
| 6. Conta | Conta, ContaExcluir, ContaPerfil, ContaMetas, ContaCerebro, ContaAssinatura, ContaPermissoes, ContaDispositivos, ContaLembretes, ContaPrivacidade, ContaPreferencias, ContaSobre, ContaEstados | coberto |
| 7. Componentes | Componentes, Tokens | coberto |

Nenhuma seção do prompt ficou sem prancheta.

## 2. Regras do projeto (varredura automática do texto visível)

| Regra | Resultado |
|---|---|
| Preço, valor, link de compra (ADR-7) | 0 violações. Os 36 acertos da busca são falsos positivos: "a**pagar**" ("Apagar chave", "Apagar todos os dados"). |
| Anúncios | 0 violações. Os 12 acertos são o texto "sem anúncios". |
| Login além do Google (ADR-13) | 0 violações. Login só tem "Entrar com Google" (estados: padrão, carregando, erro, sem internet). O único "senha" é "o PDF pode estar protegido por senha" (Exames). |
| IA diagnostica, sugere remédio ou muda dose | 0. A receita diz "Nunca muda dose nem sugere remédio"; aviso de saúde em 22 pranchetas. |
| Publicação automática em rede social | 0. Compartilhar: "Abre o compartilhamento do Android. Nada é publicado sozinho." |
| Compartilhar: peso/IMC/calorias desligados por padrão | ok — pelo estilo dos interruptores: Distância, Tempo, Ritmo, Rota ligados; Data, Calorias, Peso e IMC desligados. Começo/fim da rota escondidos. |
| Saúde clínica em cartão | ok — "Exames, receitas, remédios e diagnósticos nunca entram em cartões." |
| iPhone/iOS (ADR-12) | 0 |
| Emoji | 0 |
| Consentimento antes do 1º envio à IA (ADR-11) | ok — CerebroConsentimento diz o que vai e o que nunca vai (histórico de saúde, conta Google). |

## 3. Divergência encontrada — PORTÃO (monetização)

`ContaAssinatura` lista três recursos Premium:

1. "Conectar prontuário de hospital" — **bate** com `docs/MONETIZACAO.md:21`.
2. "Relatórios para levar à consulta" — **não está** na lista Premium. Relatório
   gerado no aparelho é função local; `docs/MONETIZACAO.md:13` diz que tudo que
   roda no aparelho é grátis e sem limite.
3. "Mais espaço para fotos e exames" — **não está** na lista. Armazenamento local
   não tem limite; o que é pago é backup/sincronização em nuvem
   (`docs/MONETIZACAO.md:19`).

Recomendação: na implementação, a tela Assinatura usa a lista de
`docs/MONETIZACAO.md` (backup criptografado e sincronização, acesso web,
prontuário de hospital, histórico em nuvem, conta familiar, suporte
prioritário) e mantém o visual do design. Precisa de aprovação.

## 4. Sistema visual (de `Tokens.dc.html`)

- Paleta Material 3 verde-azulado, tema claro e escuro, 22 tokens por tema
  (`--surface`, `--pri #006A5E` / `#81D5C5`, `--err`, `--ok`, e cores de dado:
  `--prot`, `--carb`, `--fat`, `--water`, `--sleep`).
- Fonte **Figtree**, uma família, números tabulares. Escala: Display 40/48,
  Título 1 28/36, Título 2 24/32, Título 3 20/28, Cartão 18/24, Pequeno 16/22,
  Corpo grande 16/24, Corpo 14/20, Legenda 12/16, Rótulo 12/16.
- Espaçamento 4/8/12/16/24/32/48 dp. Raios: chip 8, campo 8 8 0 0, ícone 12,
  cartão 16, navegação 20, botão 24, folha/tela 28.
- Toque mínimo 48×48 dp; contraste AA nos dois temas.
- O design carrega a fonte do Google Fonts (rede). **No app ela vai empacotada
  no APK** (regra 7: nada de rede sem ação do usuário). Licença da Figtree:
  NÃO VERIFICADA — conferir (esperado: SIL OFL 1.1) antes de empacotar.

## 5. Ordem proposta de implementação (tudo antes da rodada única de teste)

- **A. Fundação visual:** `ThemeData` claro/escuro com os tokens, Figtree
  empacotada, componentes da prancheta Componentes, navegação de 5 abas + Conta
  pelo avatar, nome "RLT" e ícone no Android.
- **B. Telas sobre dados que já existem:** Início, Nutrição (Hoje, adicionar,
  adição rápida, detalhe), Exercícios (Hoje, Passos, Academia, Corrida —
  parte sem GPS real), Saúde (Remédios, Sintomas, Vitais, Corpo), Cérebro em
  modo básico, Conta > Privacidade (exportar/apagar).
- **C. Telas que pedem dado novo:** Perfil e Metas (depende das fórmulas),
  onboarding, lembretes (notificação local), receitas médicas e exames
  (foto/PDF), histórico médico (condições, consultas), diário, tendências,
  galeria, receitas próprias, dieta e preferências.
- **D. Integrações:** IA em nuvem com chave do usuário, câmera e código de
  barras (ZXing), GPS e mapa (osmdroid/MapLibre), Health Connect, assinatura
  do lado do cliente.
- **E. Por último:** servidor e login Google de verdade (ADR-13).
