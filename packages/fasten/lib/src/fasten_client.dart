import 'fasten_document_sample.dart';

/// Fonte de documentos clínicos do Fasten Health — o Frankstein nunca
/// linka o código do Fasten nem embute nada dele; fala com a API FHIR
/// (padrão HL7, não proprietária do Fasten) dele, self-hosted, com URL e
/// credencial informados explicitamente pelo usuário
/// (`.claude/rules/00-inviolaveis.md`: "Sem chamada de rede fora da
/// camada de sync explícita"). Abstraído pelo mesmo motivo de
/// `WgerClient`/`WearableDataSource`: a implementação real precisa de um
/// servidor Fasten de verdade rodando e alcançável, que este ambiente
/// não tem.
///
/// **Implementação real, não feita neste ciclo:** um `HttpFastenClient`
/// sobre um cliente FHIR — exige instância Fasten real (self-hosted, URL
/// + credencial do usuário) pra validar contra a API de verdade.
abstract class FastenClient {
  Future<List<FastenDocumentSample>> fetchDocuments({required DateTime from, required DateTime to});
}

/// Fonte de fixture — só para teste, mesmo papel de
/// `FixtureWgerClient`/`FixtureWearableDataSource`.
class FixtureFastenClient implements FastenClient {
  final List<FastenDocumentSample> documents;
  FixtureFastenClient({this.documents = const []});

  @override
  Future<List<FastenDocumentSample>> fetchDocuments({required DateTime from, required DateTime to}) async {
    return documents.where((d) => !d.recordedAt.isBefore(from) && !d.recordedAt.isAfter(to)).toList();
  }
}
