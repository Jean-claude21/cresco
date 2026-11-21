import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacked_services/stacked_services.dart';

import 'support.dart';

/// Fin de séance : après la note d'effort, la séance est envoyée et l'écran se ferme.
void main() {
  setUp(preparer);

  testWidgets('valider toutes les séries puis noter l’effort ramène à l’écran précédent', (t) async {
    await taillerTelephone(t);
    await t.pumpWidget(
      MaterialApp(
        theme: crescoTheme(fontFamily: 'Roboto'),
        navigatorKey: StackedService.navigatorKey,
        onGenerateRoute: StackedRouter().onGenerateRoute,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => Navigator.of(context).pushNamed(Routes.seanceView),
                child: const Text('ACCUEIL'),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ACCUEIL'));
    for (var i = 0; i < 10; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    var series = 0;
    while (find.textContaining('Valider la').evaluate().isNotEmpty && series < 20) {
      await t.ensureVisible(find.widgetWithText(ChoiceChip, '2'));
      await t.tap(find.widgetWithText(ChoiceChip, '2'));
      await t.pump();
      await t.ensureVisible(find.textContaining('Valider la'));
      await t.tap(find.textContaining('Valider la'));
      await t.pump(const Duration(milliseconds: 200));
      series++;
      if (find.byTooltip('Passer le repos').evaluate().isNotEmpty) {
        await t.tap(find.byTooltip('Passer le repos'));
        await t.pump();
      }
    }
    expect(series, 4);
    expect(find.text('Séance terminée'), findsOneWidget);
    await t.ensureVisible(find.widgetWithText(ActionChip, '7'));
    await t.tap(find.widgetWithText(ActionChip, '7'));
    for (var i = 0; i < 15; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(t.takeException(), isNull);
    expect(find.text('ACCUEIL'), findsOneWidget);
    expect(find.text('Séance terminée'), findsNothing);
    await t.pump(const Duration(seconds: 5));
  });
}
