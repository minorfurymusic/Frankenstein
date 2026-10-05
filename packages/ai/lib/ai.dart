/// IA em nuvem com a chave do próprio usuário (ADR-11). Provedor atual:
/// Gemini, por REST direto. Toda chamada nasce de uma ação da pessoa
/// (enviar mensagem, anexar arquivo, pedir sugestão); toda saída é validada
/// por JSON Schema e chega como estimativa a conferir.
library;

export 'src/exam_reading.dart';
export 'src/gemini_client.dart';
