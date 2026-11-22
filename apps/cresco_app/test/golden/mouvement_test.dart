@Tags(['golden'])
library;

import 'package:cresco_app/features/gym/gym_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// « Voir le mouvement » from Ma salle: one machine, then a machine used for two exercises.
void main() {
  setUp(preparer);

  Future<void> charger(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await chargerImages(tester);
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('14 Mouvement', (tester) async {
    await taillerTelephone(tester);
    await tester.pumpWidget(enveloppe(const GymView()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    final bouton = find.byKey(const ValueKey('mouvement-exercise:presse-cuisses'));
    await tester.ensureVisible(bouton);
    await tester.pump();
    await tester.tap(bouton);
    await tester.pump(const Duration(milliseconds: 400));
    await charger(tester);
    // Middle of the push: the end pose.
    await tester.pump(const Duration(milliseconds: 900));
    await charger(tester);
    await expectLater(find.byWidgetPredicate((w) => w is MaterialApp), matchesGoldenFile('captures/14-mouvement-images.png'));

    // A machine with two exercises: one chip each.
    Navigator.of(tester.element(find.text('Presse à cuisses').last)).pop();
    await tester.pump(const Duration(milliseconds: 400));
    final pecDeck = find.byKey(const ValueKey('mouvement-material:pec-deck'));
    await tester.ensureVisible(pecDeck);
    await tester.pump();
    await tester.tap(pecDeck);
    await tester.pump(const Duration(milliseconds: 400));
    await charger(tester);
    await expectLater(find.byWidgetPredicate((w) => w is MaterialApp), matchesGoldenFile('captures/15-mouvement-poste.png'));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
}
