import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/theme/rlt_colors.dart';
import 'package:frankstein/theme/rlt_theme.dart';
import 'package:frankstein/widgets/badges.dart';
import 'package:frankstein/widgets/health_area.dart';
import 'package:frankstein/widgets/medication_dose_card.dart';
import 'package:frankstein/widgets/message_composer.dart';
import 'package:frankstein/widgets/progress.dart';
import 'package:frankstein/widgets/proposal_card.dart';
import 'package:frankstein/widgets/rlt_navigation_bar.dart';
import 'package:frankstein/widgets/state_views.dart';
import 'package:frankstein/widgets/timeline_item.dart';

/// Monta [child] num app com o tema RLT, largura de celular (360 dp, a do
/// layout) e o brilho pedido.
Future<void> _pump(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light}) async {
  tester.view.physicalSize = const Size(360, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: RltTheme.light(),
    darkTheme: RltTheme.dark(),
    themeMode: brightness == Brightness.light ? ThemeMode.light : ThemeMode.dark,
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: child)),
  ));
  await tester.pump();
}

/// Carrega a Figtree embutida: sem isso o `flutter test` mede texto com a
/// fonte de teste (glifos quadrados, bem mais largos) e a largura não
/// representa o aparelho.
Future<void> _loadFigtree() async {
  final loader = FontLoader(kRltFontFamily);
  for (final w in [400, 500, 600, 700, 800]) {
    final bytes = File('assets/fonts/figtree/Figtree-w$w.ttf').readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  setUpAll(_loadFigtree);

  group('tema', () {
    test('cores vêm dos tokens do layout (Tokens.dc.html), nos dois temas', () {
      final light = RltTheme.light();
      final dark = RltTheme.dark();
      expect(light.colorScheme.primary, const Color(0xFF006A5E)); // --pri claro
      expect(dark.colorScheme.primary, const Color(0xFF81D5C5)); // --pri escuro
      expect(light.scaffoldBackgroundColor, const Color(0xFFF5FAF7)); // --surface claro
      expect(dark.scaffoldBackgroundColor, const Color(0xFF0E1513)); // --surface escuro
      expect(light.extension<RltColors>()!.water, const Color(0xFF1C6FA8));
      expect(dark.extension<RltColors>()!.protein, const Color(0xFFA8C8FF));
    });

    test('tipografia Figtree com a escala do layout', () {
      final t = RltTheme.light().textTheme;
      expect(t.bodyMedium!.fontFamily, kRltFontFamily);
      expect(t.displaySmall!.fontSize, 40);
      expect(t.headlineMedium!.fontSize, 28);
      expect(t.bodyMedium!.fontSize, 14);
      expect(t.bodyMedium!.height! * t.bodyMedium!.fontSize!, closeTo(20, 0.001));
    });

    test('botões com área de toque mínima de 48 dp', () {
      final style = RltTheme.light().filledButtonTheme.style!;
      expect(style.minimumSize!.resolve({}), const Size(48, 48));
    });

    test('formatNumber usa ponto no milhar e vírgula no decimal', () {
      expect(formatNumber(1120), '1.120');
      expect(formatNumber(68, decimals: 1), '68,0');
      expect(formatNumber(1234567), '1.234.567');
      expect(formatNumber(-1500), '-1.500');
      expect(formatNumber(78), '78');
    });
  });

  for (final brightness in Brightness.values) {
    group('componentes (${brightness.name})', () {
      testWidgets('cartão de proposta: pendente chama confirmar, editar e descartar', (tester) async {
        final calls = <String>[];
        await _pump(
          tester,
          ProposalCard(
            area: HealthArea.meal,
            title: 'Café da manhã — 3 ovos cozidos',
            detail: '234 kcal · P 19 g · C 2 g · G 16 g',
            whenLabel: 'hoje, 07:30',
            state: ProposalState.pending,
            onConfirm: () => calls.add('confirm'),
            onEdit: () => calls.add('edit'),
            onDiscard: () => calls.add('discard'),
          ),
          brightness: brightness,
        );
        expect(find.text('REFEIÇÃO'), findsOneWidget);
        await tester.tap(find.text('Confirmar'));
        await tester.tap(find.byTooltip('Editar Café da manhã — 3 ovos cozidos'));
        await tester.tap(find.text('Descartar'));
        expect(calls, ['confirm', 'edit', 'discard']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('cartão de proposta: editando, confirmado e descartado', (tester) async {
        await _pump(
          tester,
          Column(children: [
            ProposalCard(
              area: HealthArea.symptom,
              title: 'Dor de cabeça',
              state: ProposalState.editing,
              editor: const TextField(decoration: InputDecoration(labelText: 'Intensidade')),
              onConfirm: () {},
              onCancelEdit: () {},
            ),
            ProposalCard(
              area: HealthArea.water,
              title: 'Água — 2 L',
              detail: '2.000 ml',
              state: ProposalState.confirmed,
              savedIn: 'Nutrição › Água',
              onUndo: () {},
            ),
            ProposalCard(
              area: HealthArea.medication,
              title: 'Dipirona 500 mg',
              state: ProposalState.discarded,
              onUndo: () {},
            ),
          ]),
          brightness: brightness,
        );
        expect(find.text('Edite antes de confirmar'), findsOneWidget);
        expect(find.text('Cancelar'), findsOneWidget);
        expect(find.text('Salvo em Nutrição › Água'), findsOneWidget);
        expect(find.text('Descartado — nada foi salvo'), findsOneWidget);
        expect(find.text('Desfazer'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });

      testWidgets('cartão de remédio: próximo, atrasado e tomado', (tester) async {
        final calls = <String>[];
        await _pump(
          tester,
          Column(children: [
            MedicationDoseCard(
              name: 'Metformina',
              dose: '850 mg',
              time: '20:00',
              status: DoseCardStatus.upcoming,
              onTaken: () => calls.add('taken'),
              onSkipped: () => calls.add('skipped'),
            ),
            const MedicationDoseCard(name: 'Vitamina D', dose: '2.000 UI', time: '12:00', status: DoseCardStatus.overdue),
            MedicationDoseCard(
              name: 'Losartana',
              dose: '50 mg',
              time: '08:00',
              status: DoseCardStatus.taken,
              takenAt: '08:04',
              onUndo: () => calls.add('undo'),
            ),
          ]),
          brightness: brightness,
        );
        expect(find.text('PRÓXIMO'), findsOneWidget);
        expect(find.text('ATRASADO'), findsOneWidget);
        expect(find.text('Tomado às 08:04'), findsOneWidget);
        await tester.tap(find.text('Tomei').first);
        await tester.tap(find.text('Pulei').first);
        await tester.tap(find.text('Desfazer'));
        expect(calls, ['taken', 'skipped', 'undo']);
        expect(tester.takeException(), isNull);
      });

      testWidgets('anel, barras de macro, linha do tempo, selos, avisos e estados', (tester) async {
        final c = brightness == Brightness.light ? RltColors.light : RltColors.dark;
        var tapped = 0;
        await _pump(
          tester,
          Column(children: [
            const ProgressRing(value: 1120 / 1630, center: Text('1.120')),
            const ProgressRing(value: 1.4), // meta estourada não quebra
            MacroBar(label: 'Proteína', current: 78, goal: 122, color: c.protein),
            MacroBar(label: 'Gordura', current: 38, goal: 0, color: c.fat), // meta zerada não divide por zero
            TimelineItem(time: '07:30', area: HealthArea.meal, title: 'Café da manhã', detail: '3 ovos cozidos · 234 kcal', onTap: () => tapped++),
            const TimelineItem(time: '08:04', area: HealthArea.medication, title: 'Losartana 50 mg', detail: 'Tomado', isLast: true),
            const Wrap(children: [
              RltBadge(RltBadgeKind.estimate),
              RltBadge(RltBadgeKind.premium),
              RltBadge(RltBadgeKind.continuousUse),
              RltBadge(RltBadgeKind.overdue),
            ]),
            const HealthDisclaimer(),
            const StateCard(
              icon: Icons.restaurant_outlined,
              title: 'Nenhuma refeição hoje',
              message: 'Busque, leia o código de barras ou fotografe o prato.',
              actionLabel: 'Adicionar alimento',
              actionIcon: Icons.add,
            ),
            const StateCard(
              icon: Icons.directions_walk_outlined,
              title: 'Contagem de passos desligada',
              message: 'Permita “atividade física” para contar passos.',
              actionLabel: 'Permitir',
              tone: StateTone.permission,
            ),
            const OfflineBanner(),
            const LoadingCard(),
          ]),
          brightness: brightness,
        );
        expect(find.text('78 / 122 g'), findsOneWidget);
        expect(find.text('38 / 0 g'), findsOneWidget);
        expect(find.text('Premium'), findsOneWidget);
        expect(find.textContaining('não faz diagnóstico'), findsOneWidget);
        await tester.tap(find.text('Café da manhã'));
        expect(tapped, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('selo Premium nunca mostra preço', (tester) async {
        await _pump(tester, const RltBadge(RltBadgeKind.premium), brightness: brightness);
        expect(find.textContaining(RegExp(r'R\$|US\$|/mês|comprar', caseSensitive: false)), findsNothing);
      });
    });
  }

  group('campo de mensagem', () {
    testWidgets('com IA: microfone sem texto, enviar com texto', (tester) async {
      final sent = <String>[];
      await _pump(tester, MessageComposer(mode: ComposerMode.ai, onSend: sent.add));
      expect(find.byTooltip('Segure para gravar voz'), findsOneWidget);
      expect(find.byTooltip('Tirar foto'), findsOneWidget);
      expect(find.byTooltip('Anexar foto, arquivo, áudio ou vídeo'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  almocei arroz e feijão  ');
      await tester.pump();
      expect(find.byTooltip('Segure para gravar voz'), findsNothing);
      await tester.tap(find.byTooltip('Enviar'));
      await tester.pump();
      expect(sent, ['almocei arroz e feijão']);
      expect(find.text('almocei arroz e feijão'), findsNothing); // campo limpo
    });

    testWidgets('modo básico: sem anexo nem voz, só comando de texto', (tester) async {
      final sent = <String>[];
      await _pump(tester, MessageComposer(mode: ComposerMode.basic, onSend: sent.add));
      expect(find.text('Comando, ex.: registrar água 500ml'), findsOneWidget);
      expect(find.byTooltip('Segure para gravar voz'), findsNothing);
      expect(find.byTooltip('Tirar foto'), findsNothing);
      await tester.enterText(find.byType(TextField), 'registrar água 500ml');
      await tester.pump();
      await tester.tap(find.byTooltip('Enviar'));
      expect(sent, ['registrar água 500ml']);
    });

    testWidgets('segurar o microfone grava; soltar entrega a duração', (tester) async {
      var started = 0;
      Duration? ended;
      await _pump(
        tester,
        MessageComposer(
          mode: ComposerMode.ai,
          onSend: (_) {},
          onRecordStart: () => started++,
          onRecordEnd: (d) => ended = d,
        ),
      );
      final gesture = await tester.startGesture(tester.getCenter(find.byTooltip('Segure para gravar voz')));
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      expect(started, 1);
      expect(find.text('Arraste para a esquerda para cancelar'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(ended, isNotNull);
      expect(find.byTooltip('Segure para gravar voz'), findsOneWidget);
    });
  });

  testWidgets('fonte do sistema em 160% (como a prancheta InicioFonteGrande): cartões não estouram', (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: RltTheme.light(),
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 2400), textScaler: TextScaler.linear(1.6)),
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              ProposalCard(
                area: HealthArea.meal,
                title: 'Café da manhã — 3 ovos cozidos',
                detail: '234 kcal · P 19 g · C 2 g · G 16 g',
                whenLabel: 'hoje, 07:30',
                state: ProposalState.pending,
                onConfirm: () {},
                onEdit: () {},
                onDiscard: () {},
              ),
              ProposalCard(area: HealthArea.symptom, title: 'Dor de cabeça', state: ProposalState.editing, onConfirm: () {}, onCancelEdit: () {}),
              ProposalCard(area: HealthArea.water, title: 'Água — 2 L', state: ProposalState.confirmed, savedIn: 'Nutrição › Água', onUndo: () {}),
              MedicationDoseCard(name: 'Metformina', dose: '850 mg', time: '20:00', status: DoseCardStatus.upcoming, onTaken: () {}, onSkipped: () {}),
              const MacroBar(label: 'Carboidrato', current: 120, goal: 184, color: Colors.orange),
              const TimelineItem(time: '12:40', area: HealthArea.meal, title: 'Almoço', detail: 'Arroz, feijão, frango, salada · 640 kcal'),
            ]),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Confirmar'), findsNWidgets(2));
  });

  testWidgets('barra de navegação: 5 abas na ordem, Cérebro no centro', (tester) async {
    RltTab? chosen;
    await _pump(tester, RltNavigationBar(selected: RltTab.inicio, onSelected: (t) => chosen = t));
    final labels = RltTab.values.map((t) => t.label).toList();
    expect(labels, ['Início', 'Saúde', 'Cérebro', 'Nutrição', 'Exercícios']);
    for (final label in labels) {
      expect(find.text(label), findsOneWidget);
    }
    await tester.tap(find.byKey(const Key('nav_cerebro')));
    expect(chosen, RltTab.cerebro);
    await tester.tap(find.byKey(const Key('nav_exercicios')));
    expect(chosen, RltTab.exercicios);
  });
}
