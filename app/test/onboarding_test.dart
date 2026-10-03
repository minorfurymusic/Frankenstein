import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frankstein/app_dependencies.dart';
import 'package:frankstein/card_image_capturer.dart';
import 'package:frankstein/confirmation_gate.dart';
import 'package:frankstein/main.dart';
import 'package:frankstein/screens/onboarding/onboarding_screen.dart';
import 'package:frankstein/share_sheet.dart';
import 'package:frankstein_profile/profile.dart';

import 'support/fonts.dart';

void main() {
  setUpAll(loadFigtree);

  late AppDependencies deps;
  late Widget app;

  setUp(() {
    final key = GlobalKey<NavigatorState>();
    deps = AppDependencies.inMemory(confirmationGate: AppConfirmationGate(key), shareSheet: FakeShareSheet(), imageCapturer: FakeCardImageCapturer());
    app = FrankstitApp(dependencies: deps, navigatorKey: key, onboarding: true);
  });
  tearDown(() => deps.close());

  test('primeiro uso aparece só sem perfil e sem ter concluído antes', () {
    expect(OnboardingScreen.shouldShow(deps), isTrue);
    deps.profileRepository.setSetting('onboarding_done', '1');
    expect(OnboardingScreen.shouldShow(deps), isFalse);
  });

  test('quem já tem perfil (APK antigo) não vê o primeiro uso', () {
    deps.profileRepository.save(Profile(sex: BiologicalSex.female, birthDate: DateTime(1990), heightMeters: 1.6));
    expect(OnboardingScreen.shouldShow(deps), isFalse);
  });

  testWidgets('percorre boas-vindas → privacidade → perfil (depois) → metas → passos (agora não) → IA (depois) e cai no Início', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();
    for (final k in ['onb_welcome_primary', 'onb_privacy_primary', 'onb_profile_secondary', 'onb_goals_primary', 'onb_permissions_secondary', 'onb_ai_primary']) {
      await tester.tap(find.byKey(Key(k)));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const Key('home_list')), findsOneWidget);
    expect(deps.profileRepository.getSetting('onboarding_done'), '1');
  });
}
