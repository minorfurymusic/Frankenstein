import 'wger_set_log_sample.dart';

/// Fonte de séries de treino do wger — o Frankstein nunca linka o
/// código do wger nem embute nada dele; fala com a API REST v2 pública
/// dele (`/api/v2/workoutlog/`, autenticação por token), self-hosted,
/// com URL e token informados explicitamente pelo usuário
/// (`.claude/rules/00-inviolaveis.md`: "Sem chamada de rede fora da
/// camada de sync explícita"). Abstraído pelo mesmo motivo de
/// `WearableDataSource`/`StepSensor`/`BarcodeDecoder`: a implementação
/// real precisa de um servidor wger de verdade rodando e alcançável, que
/// este ambiente não tem.
///
/// **Implementação real, não feita neste ciclo:** um `HttpWgerClient`
/// sobre `package:http` — exige instância wger real (self-hosted, URL +
/// token do usuário) pra validar contra a API de verdade. Registrar isso
/// aqui sem poder provar seria "feito" sem prova (`CLAUDE.md`, regra 1).
abstract class WgerClient {
  Future<List<WgerSetLogSample>> fetchSetLogs({required DateTime from, required DateTime to});
}

/// Fonte de fixture — só para teste, mesmo papel que
/// `FixtureWearableDataSource` (`packages/wearable`) e
/// `FixtureBarcodeDecoder` (`packages/nutrition`).
class FixtureWgerClient implements WgerClient {
  final List<WgerSetLogSample> setLogs;
  FixtureWgerClient({this.setLogs = const []});

  @override
  Future<List<WgerSetLogSample>> fetchSetLogs({required DateTime from, required DateTime to}) async {
    return setLogs.where((s) => !s.recordedAt.isBefore(from) && !s.recordedAt.isAfter(to)).toList();
  }
}
