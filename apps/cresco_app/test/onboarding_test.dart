import 'package:cresco_app/features/onboarding/onboarding_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUp(preparer);

  testWidgets('walks through goal, rhythm, gym and faith', (t) async {
    await taillerTelephone(t);
    await t.pumpWidget(enveloppe(const OnboardingView()));
    await t.pumpAndSettle();
    expect(find.text('Qu’est-ce que tu veux changer ?'), findsOneWidget);
    expect(find.byTooltip('Étape précédente'), findsNothing);

    await t.tap(find.text('Prendre du muscle'));
    await t.pump();
    expect(find.byIcon(Icons.check_circle), findsOneWidget);

    await t.tap(find.text('Continuer'));
    await t.pumpAndSettle();
    expect(find.text('Ton rythme, sans te mentir.'), findsOneWidget);
    await t.tap(find.text('Continuer'));
    await t.pumpAndSettle();
    expect(find.text('Décrire ma salle'), findsOneWidget);
    await t.tap(find.text('Continuer'));
    await t.pumpAndSettle();
    expect(find.text('Module foi'), findsOneWidget);
    expect(find.text('C’est parti'), findsOneWidget);

    await t.tap(find.byTooltip('Étape précédente'));
    await t.pumpAndSettle();
    expect(find.text('Décrire ma salle'), findsOneWidget);
  });
}
