import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/widgets/date_picker.dart';

void main() {
  test('só números: as barras entram sozinhas', () {
    const f = DateMaskFormatter();
    String type(String s) => f.formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: s)).text;
    expect(type('2'), '2');
    expect(type('280'), '28/0');
    expect(type('28061990'), '28/06/1990');
    expect(type('280619901'), '28/06/1990');
    expect(type('28/06/1990'), '28/06/1990');
  });

  test('data inexistente não vale', () {
    expect(parseDdMmYyyy('28/06/1990'), DateTime(1990, 6, 28));
    expect(parseDdMmYyyy('31/02/1990'), isNull);
    expect(parseDdMmYyyy('28/06/19'), isNull);
  });

  testWidgets('digitar 28061990 escolhe 28/06/1990', (tester) async {
    DateTime? picked;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => picked = await showRltDatePicker(
            context: context,
            initialDate: DateTime(2000),
            firstDate: DateTime(1900),
            lastDate: DateTime(2026, 10, 16),
          ),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('date_text')), '28061990');
    await tester.pumpAndSettle();
    expect(find.text('28/06/1990'), findsOneWidget);
    await tester.tap(find.byKey(const Key('date_ok')));
    await tester.pumpAndSettle();
    expect(picked, DateTime(1990, 6, 28));
  });
}
