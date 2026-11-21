import 'package:cresco_app/features/onboarding/onboarding_view.dart';
import 'package:cresco_app/ui/coach.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  setUp(preparer);

  testWidgets('picks a coach, then goal, rhythm, gym and faith, guided by that coach', (t) async {
    await taillerTelephone(t);
    await t.pumpWidget(enveloppe(const OnboardingView()));
    await t.pumpAndSettle();
    expect(find.text('Qui t’accompagne ?'), findsOneWidget);
    expect(find.text('Retour'), findsNothing);

    await t.tap(find.byKey(const ValueKey('coach-homme')));
    await t.pumpAndSettle();
    expect(currentCoach(), Coach.homme);

    await t.tap(find.text('Continuer'));
    await t.pumpAndSettle();
    expect(find.text('Qu’est-ce que tu veux changer ?'), findsOneWidget);
    // The chosen coach asks the question.
    final coach = t.widget<CoachIllustration>(find.byType(CoachIllustration));
    expect(coach.coach, Coach.homme);
    await t.tap(find.text('Prendre du muscle'));
    await t.pump();

    for (final title in ['Ton rythme, sans te mentir.', 'Ma salle', 'Jeûne et foi']) {
      await t.tap(find.text('Continuer'));
      await t.pumpAndSettle();
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text('C’est parti'), findsOneWidget);

    await t.tap(find.text('Retour'));
    await t.pumpAndSettle();
    expect(find.text('Décrire ma salle'), findsOneWidget);
  });
}
