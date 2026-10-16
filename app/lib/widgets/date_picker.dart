import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../format.dart';

/// Data digitada só com números: as barras entram sozinhas (dd/mm/aaaa).
class DateMaskFormatter extends TextInputFormatter {
  const DateMaskFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final d = digits.length > 8 ? digits.substring(0, 8) : digits;
    final b = StringBuffer();
    for (var i = 0; i < d.length; i++) {
      if (i == 2 || i == 4) b.write('/');
      b.write(d[i]);
    }
    final text = b.toString();
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

/// "28/06/1990" → data; `null` se incompleta ou inexistente (31/02).
DateTime? parseDdMmYyyy(String s) {
  final m = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(s.trim());
  if (m == null) return null;
  final day = int.parse(m[1]!), month = int.parse(m[2]!), year = int.parse(m[3]!);
  final d = DateTime(year, month, day);
  return d.year == year && d.month == month && d.day == day ? d : null;
}

/// Escolher data: digitar (com as barras automáticas) ou tocar no
/// calendário — no lugar do seletor do Android, cujo campo de texto não
/// aceita só números.
Future<DateTime?> showRltDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) =>
    showDialog<DateTime>(
      context: context,
      builder: (_) => _RltDateDialog(initial: initialDate, first: firstDate, last: lastDate),
    );

class _RltDateDialog extends StatefulWidget {
  final DateTime initial;
  final DateTime first;
  final DateTime last;
  const _RltDateDialog({required this.initial, required this.first, required this.last});

  @override
  State<_RltDateDialog> createState() => _RltDateDialogState();
}

class _RltDateDialogState extends State<_RltDateDialog> {
  late DateTime _selected = _clamp(widget.initial);
  late final _text = TextEditingController(text: ddmmyyyy(_selected));
  String? _error;

  DateTime _clamp(DateTime d) {
    final day = DateTime(d.year, d.month, d.day);
    if (day.isBefore(widget.first)) return widget.first;
    if (day.isAfter(widget.last)) return DateTime(widget.last.year, widget.last.month, widget.last.day);
    return day;
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _typed(String s) {
    if (s.length < 10) {
      setState(() => _error = null);
      return;
    }
    final d = parseDdMmYyyy(s);
    final lastDay = DateTime(widget.last.year, widget.last.month, widget.last.day);
    setState(() {
      if (d == null) {
        _error = 'Data inexistente';
      } else if (d.isBefore(widget.first) || d.isAfter(lastDay)) {
        _error = 'Fora do período permitido';
      } else {
        _error = null;
        _selected = d;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      content: SizedBox(
        width: 330,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              key: const Key('date_text'),
              controller: _text,
              keyboardType: TextInputType.number,
              inputFormatters: const [DateMaskFormatter()],
              decoration: InputDecoration(labelText: 'Digite a data', hintText: 'dd/mm/aaaa', errorText: _error),
              onChanged: _typed,
            ),
            CalendarDatePicker(
              key: ValueKey(_selected),
              initialDate: _selected,
              firstDate: widget.first,
              lastDate: widget.last,
              onDateChanged: (d) => setState(() {
                _selected = d;
                _error = null;
                _text.text = ddmmyyyy(d);
              }),
            ),
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        TextButton(
          key: const Key('date_ok'),
          onPressed: _error != null || (_text.text.isNotEmpty && _text.text.length < 10) ? null : () => Navigator.of(context).pop(_selected),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
