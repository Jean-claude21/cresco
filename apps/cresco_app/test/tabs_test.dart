import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/features/accueil/accueil_view.dart';
import 'package:cresco_app/ui/tabs.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stacked_services/stacked_services.dart';

import 'support.dart';

/// The tab bar stays under pages opened from a tab, and hides during effort.
void main() {
  setUp(preparer);

  Future<void> open(WidgetTester t) async {
    await taillerTelephone(t);
    await t.pumpWidget(
      MaterialApp(
        theme: crescoTheme(fontFamily: 'Roboto'),
        navigatorKey: StackedService.navigatorKey,
        navigatorObservers: [TabsObserver()],
        builder: tabShell,
        onGenerateRoute: StackedRouter().onGenerateRoute,
        home: const AccueilView(),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  Future<void> push(WidgetTester t, String route) async {
    unawaitedPush(route);
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
  }

  testWidgets('stays under Mon corps and brings back to the chosen tab', (t) async {
    await open(t);
    expect(find.byType(CrescoTabBar), findsOneWidget);
    await push(t, Routes.bodyMapView);
    expect(find.text('Séries efficaces de la semaine'), findsOneWidget);
    expect(find.byType(CrescoTabBar), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('onglet-Entraînement')));
    for (var i = 0; i < 6; i++) {
      await t.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('Séries efficaces de la semaine'), findsNothing);
    expect(Tabs.instance.index, 1);
    expect(find.text('Mes séances'), findsWidgets);
  });

  testWidgets('hides during a session', (t) async {
    await open(t);
    await push(t, Routes.seanceView);
    expect(find.byType(CrescoTabBar), findsNothing);
  });
}

void unawaitedPush(String route) {
  // Not awaited: the page stays open for the test.
  StackedService.navigatorKey!.currentState!.pushNamed(route);
}
