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
import 'package:cresco_app/features/training/template_editor_view.dart';
import 'package:cresco_app/features/training/training_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Aucun débordement sur un petit téléphone (360 × 740), en texte normal et agrandi à 130 %.
/// Un débordement lève une exception de rendu : le test échoue alors de lui-même.
void main() {
  setUp(preparer);

  final ecrans = <String, Widget Function()>{
    'connexion': () => const ConnexionView(),
    'aujourd’hui': () => const AccueilView(),
    'entraînement': () => const Scaffold(body: TrainingView()),
    'ma salle': () => const GymView(),
    'démarrage': () => const OnboardingView(),
    'nouvelle séance': () => const TemplateEditorView(),
    'séance': () => const SeanceView(),
    'intervalles': () => const IntervallesView(modele: intervallesParDefaut),
    'jeûne': () => const JeuneView(),
    'nutrition': () => const Scaffold(body: NutritionView()),
    'progrès': () => const Scaffold(body: ProgresView()),
    'profil': () => const ProfilView(),
    'mon corps': () => const BodyMapView(),
  };

  for (final echelle in [1.0, 1.3]) {
    for (final e in ecrans.entries) {
      testWidgets('${e.key} tient en 360 pt (texte × $echelle)', (t) async {
        t.view
          ..physicalSize = const Size(360 * 3, 740 * 3)
          ..devicePixelRatio = 3;
        addTearDown(t.view.reset);
        await t.pumpWidget(
          MediaQuery(
            data: MediaQueryData(size: const Size(360, 740), textScaler: TextScaler.linear(echelle)),
            child: enveloppe(e.value()),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        await t.pumpWidget(const SizedBox.shrink());
        await t.pump(const Duration(seconds: 1));
      });
    }
  }
}
