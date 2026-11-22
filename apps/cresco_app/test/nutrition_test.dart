import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Eating a dish by servings: the engine gives grams and kcal of what is eaten.
void main() {
  setUp(preparer);

  testWidgets('a dish is eaten by half servings, with its grams and kcal', (t) async {
    await taillerTelephone(t);
    await t.pumpWidget(enveloppe(const Scaffold(body: NutritionView())));
    for (var i = 0; i < 5; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    await t.tap(find.text('Jollof de poulet'));
    await t.pumpAndSettle();
    expect(find.text('1 portion'), findsOneWidget);
    // 350 g × 168 kcal / 100 g = 588 kcal (C-ENERGIE-9, engine).
    expect(find.textContaining('350 g · 588 kcal'), findsOneWidget);
    expect(find.text('Le plat entier fait 4 portions'), findsOneWidget);
    await t.tap(find.byTooltip('Une demi-portion de plus'));
    await t.pump();
    expect(find.text('1,5 portions'), findsOneWidget);
    expect(find.textContaining('525 g · 882 kcal'), findsOneWidget);
  });
}
