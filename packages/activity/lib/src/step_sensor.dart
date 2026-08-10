import 'steps_sample.dart';

/// Fonte de leituras do sensor de passos.
///
/// **A implementação real do Android (foreground service +
/// `TYPE_STEP_COUNTER` via platform channel) não está nesta fase** —
/// exige um aparelho ou emulador de verdade para validar que a contagem
/// não para com a tela bloqueada (`.claude/rules/activity.md`: "esse é o
/// bug que matou o projeto anterior; trate como requisito, não como
/// detalhe"). Este ambiente de desenvolvimento não tem SDK Android nem
/// `/dev/kvm` (mesmo limite do Ciclo 27, `docs/HISTORICO.md`) — não dá
/// pra fingir que essa parte foi testada. O que existe aqui é a lógica
/// de agregação ([StepsRepository]), testável sem hardware, atrás desta
/// interface — a implementação Android entra depois como uma classe
/// nova, sem mudar [StepsRepository].
abstract class StepSensor {
  Stream<StepsSample> get readings;
}
