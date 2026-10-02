/// Formatação de data e hora no estilo do layout ("Hoje, 09:10", "Ontem,
/// 21:00", "Quarta, 07:40", "25/09"). Sem `intl`: os textos são poucos e
/// fixos em português (Conta > Preferências: idioma português).
library;

const _weekdays = ['Segunda', 'Terça', 'Quarta', 'Quinta', 'Sexta', 'Sábado', 'Domingo'];
const _weekdaysShort = ['S', 'T', 'Q', 'Q', 'S', 'S', 'D'];
const _months = ['jan', 'fev', 'mar', 'abr', 'mai', 'jun', 'jul', 'ago', 'set', 'out', 'nov', 'dez'];

String two(int n) => n.toString().padLeft(2, '0');

String hhmm(DateTime local) => '${two(local.hour)}:${two(local.minute)}';

String ddmm(DateTime local) => '${two(local.day)}/${two(local.month)}';

String ddmmyyyy(DateTime local) => '${two(local.day)}/${two(local.month)}/${local.year}';

String monthShort(int month) => _months[month - 1];

String weekdayInitial(DateTime local) => _weekdaysShort[local.weekday - 1];

/// Instante UTC gravado + fuso gravado junto (`.claude/rules/00-inviolaveis.md`:
/// timestamps em UTC, fuso à parte) → hora local de quando aconteceu.
DateTime localOf(DateTime utc, int tzOffsetMinutes) =>
    utc.toUtc().add(Duration(minutes: tzOffsetMinutes));

/// "Hoje, 09:10" / "Ontem, 21:00" / "Quarta, 07:40" (até 6 dias) / "25/09, 07:40".
String relativeDayTime(DateTime local, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final day = _dateOnly(local);
  final diff = today.difference(day).inDays;
  final time = hhmm(local);
  if (diff == 0) return 'Hoje, $time';
  if (diff == 1) return 'Ontem, $time';
  if (diff > 1 && diff < 7) return '${_weekdays[local.weekday - 1]}, $time';
  return '${ddmm(local)}, $time';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Lê número digitado no jeito brasileiro ou não: "68,4", "68.4", "1.200",
/// "1.200,5". `null` se não for número.
double? parseNumber(String text) {
  var s = text.trim().replaceAll(' ', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(s)) {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}
