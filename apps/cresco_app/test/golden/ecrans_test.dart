@Tags(['golden'])
library;

import 'package:cresco_app/features/accueil/accueil_view.dart';
import 'package:cresco_app/features/body/body_map_view.dart';
import 'package:cresco_app/features/connexion/connexion_view.dart';
import 'package:cresco_app/features/gym/gym_view.dart';
import 'package:cresco_app/features/intervalles/intervalles_view.dart';
import 'package:cresco_app/features/jeune/jeune_view.dart';
import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:cresco_app/features/onboarding/onboarding_view.dart';
import 'package:cresco_app/features/profil/profil_view.dart';
import 'package:cresco_app/features/progres/progres_view.dart';
import 'package:cresco_app/features/seance/seance_view.dart';
import 'package:cresco_app/features/training/training_view.dart';
import 'package:cresco_app/features/welcome/welcome_view.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support.dart';

/// Captures de contrôle des écrans (comme dym) : `flutter test --tags golden --update-goldens`.
void main() {
  setUp(preparer);

  Future<void> capturer(
    WidgetTester tester,
    Widget ecran,
    String nom, {
    Brightness brightness = Brightness.light,
  }) async {
    await taillerTelephone(tester);
    await tester.pumpWidget(
      brightness == Brightness.light
          ? enveloppe(ecran)
          : MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: crescoTheme(fontFamily: 'Roboto', brightness: brightness),
              home: ecran,
            ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await chargerImages(tester);
    await tester.pump(const Duration(milliseconds: 400));
    await expectLater(find.byWidgetPredicate((w) => w is MaterialApp), matchesGoldenFile('captures/$nom.png'));
    // Démonte l'écran et vide les minuteurs (repos, horloge) avant la fin du test.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('01 Aujourd’hui', (t) => capturer(t, const AccueilView(), '01-aujourdhui'));
  testWidgets('02 Séance', (t) => capturer(t, const SeanceView(), '02-seance'));
  testWidgets(
    '03 Intervalles',
    (t) => capturer(t, const IntervallesView(modele: intervallesParDefaut), '03-intervalles'),
  );
  testWidgets('04 Jeûne', (t) => capturer(t, const JeuneView(), '04-jeune'));
  testWidgets('05 Progrès', (t) => capturer(t, const Scaffold(body: ProgresView()), '05-progres'));
  testWidgets('06 Nutrition', (t) => capturer(t, const Scaffold(body: NutritionView()), '06-nutrition'));
  testWidgets('07 Entraînement', (t) => capturer(t, const Scaffold(body: TrainingView()), '07-entrainement'));
  testWidgets('08 Profil', (t) => capturer(t, const ProfilView(), '08-profil'));
  testWidgets('09 Connexion', (t) => capturer(t, const ConnexionView(), '09-connexion'));
  for (final (nom, fichier, ecran) in [
    ('Aujourd’hui', '01-aujourdhui', const AccueilView()),
    ('Séance', '02-seance', const SeanceView()),
    ('Jeûne', '04-jeune', const JeuneView()),
    ('Progrès', '05-progres', const Scaffold(body: ProgresView())),
    ('Nutrition', '06-nutrition', const Scaffold(body: NutritionView())),
  ]) {
    testWidgets('$nom (sombre)', (t) => capturer(t, ecran, '$fichier-sombre', brightness: Brightness.dark));
  }
  testWidgets('12 Ma salle', (t) => capturer(t, const GymView(), '12-ma-salle'));
  testWidgets('00 Bienvenue', (t) => capturer(t, const WelcomeView(), '00-bienvenue'));
  testWidgets('13 Démarrage', (t) => capturer(t, const OnboardingView(), '13-demarrage'));
  testWidgets('10 Mon corps', (t) => capturer(t, const BodyMapView(), '10-mon-corps'));
  testWidgets(
    '11 Mon corps (sombre)',
    (t) => capturer(t, const BodyMapView(), '11-mon-corps-sombre', brightness: Brightness.dark),
  );
}
