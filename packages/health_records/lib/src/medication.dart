/// Forma farmacêutica — só pra exibição e ícone; não muda o cálculo de agenda.
enum MedicationForm {
  tablet,
  capsule,
  drops,
  liquid,
  injection,
  topical,
  inhaler,
  other;

  String get wireValue => name;

  static MedicationForm fromWireValue(String value) => MedicationForm.values.firstWhere(
        (f) => f.name == value,
        orElse: () => throw ArgumentError('forma de remédio desconhecida: $value'),
      );
}

/// Data local sem hora (`2026-10-02`). Datas de início/fim de tratamento são
/// do calendário do usuário, não instantes UTC — guardar como texto evita o
/// dia "andar" por causa de fuso ou horário de verão.
class LocalDate implements Comparable<LocalDate> {
  final int year;
  final int month;
  final int day;

  LocalDate(this.year, this.month, this.day) {
    final check = DateTime.utc(year, month, day);
    if (check.year != year || check.month != month || check.day != day) {
      throw ArgumentError('data inválida: $year-$month-$day');
    }
  }

  factory LocalDate.parse(String iso) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(iso);
    if (match == null) throw ArgumentError('data precisa ser YYYY-MM-DD: $iso');
    return LocalDate(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
  }

  factory LocalDate.fromDateTime(DateTime dt) => LocalDate(dt.year, dt.month, dt.day);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  int get _ordinal => DateTime.utc(year, month, day).millisecondsSinceEpoch;

  @override
  int compareTo(LocalDate other) => _ordinal.compareTo(other._ordinal);

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;

  @override
  bool operator ==(Object other) => other is LocalDate && compareTo(other) == 0;

  @override
  int get hashCode => _ordinal.hashCode;

  @override
  String toString() => toIso();
}

/// Converte "08:30" em minutos desde 00:00 (510).
int parseTimeOfDay(String hhmm) {
  final match = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$').firstMatch(hhmm);
  if (match == null) throw ArgumentError('horário precisa ser HH:mm: $hhmm');
  return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
}

String formatTimeOfDay(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

/// Remédio em uso — é catálogo (plano), não `HealthEvent`: as doses tomadas
/// ou puladas é que viram eventos (`medication_dose`). Mesmo papel que
/// `WorkoutPlan` tem para sessões de treino.
///
/// [endDate] nulo = uso contínuo. A regra "uso contínuo agenda até o fim do
/// ano" (pedido do usuário, 2026-10-02) é um padrão de quem cadastra (IA ou
/// tela), não do modelo — o modelo aceita qualquer fim ou nenhum.
class Medication {
  final String id;
  final String name;
  final double doseAmount;
  final String doseUnit;
  final MedicationForm form;

  /// Horários do dia, em minutos desde 00:00, hora local. Ordenados, sem repetição.
  final List<int> timesOfDay;
  final LocalDate startDate;
  final LocalDate? endDate;
  final String? notes;
  final bool remindersEnabled;

  Medication({
    required this.id,
    required this.name,
    required this.doseAmount,
    required this.doseUnit,
    this.form = MedicationForm.other,
    required List<int> timesOfDay,
    required this.startDate,
    this.endDate,
    this.notes,
    this.remindersEnabled = true,
  }) : timesOfDay = (timesOfDay.toSet().toList()..sort()) {
    if (name.trim().isEmpty) throw ArgumentError('remédio precisa de nome');
    if (doseAmount <= 0) throw ArgumentError('dose precisa ser maior que zero');
    if (doseUnit.trim().isEmpty) throw ArgumentError('dose precisa de unidade');
    if (timesOfDay.isEmpty) throw ArgumentError('remédio precisa de pelo menos um horário');
    if (timesOfDay.any((t) => t < 0 || t >= 24 * 60)) {
      throw ArgumentError('horário fora de 00:00–23:59');
    }
    final end = endDate;
    if (end != null && end.isBefore(startDate)) {
      throw ArgumentError('fim do tratamento antes do início');
    }
  }

  bool get isContinuous => endDate == null;

  /// Remédio vale nesse dia (entre início e fim, inclusive).
  bool isActiveOn(LocalDate date) {
    if (date.isBefore(startDate)) return false;
    final end = endDate;
    return end == null || !date.isAfter(end);
  }
}

/// Uma dose prevista na agenda de um dia.
class ScheduledDose {
  final Medication medication;
  final LocalDate date;
  final int timeOfDay;

  ScheduledDose({required this.medication, required this.date, required this.timeOfDay});

  /// Chave estável da dose prevista ("2026-10-02T08:00") — gravada no evento
  /// `medication_dose` para ligar "tomei" à dose certa da agenda.
  String get scheduledLocal => '${date.toIso()}T${formatTimeOfDay(timeOfDay)}';
}
