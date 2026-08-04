---
paths:
  - "packages/activity/**"
  - "**/*gps*"
  - "**/*workout*"
  - "**/*pedometer*"
---
# Regras de atividade física (passos, treino, corrida)

Passos:
- Foreground service no Android. A contagem NÃO pode parar com a tela bloqueada.
  Esse é o bug que matou o projeto anterior: trate como requisito, não como detalhe.

Corrida/caminhada:
- Gravação incremental (nunca só ao final) e recuperação de sessão após crash.
- Descarte pontos com precisão pior que 20 m. Filtro de ruído antes de calcular pace.
- Orçamento: menos de 8% de bateria por hora. Meça e registre em docs/PERF.md.
- Chamada, tela apagada e app em background não podem interromper a gravação.
- Exportação/importação GPX obrigatória.

Privacidade:
- Rota é dado de localização sensível. Ao compartilhar, ofusque automaticamente
  os primeiros e últimos 300 m.
