// Parcours complet de Cresco sur un vrai appareil, contre l'API de staging (CRESCO_API).
// Local : flutter test integration_test (appareil branché).
// Appareils réels : scripts/browserstack.mjs (APK de l'app + APK de test).
import 'dart:math';

import 'package:cresco_app/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Attend qu'un élément apparaisse (le réseau et les indicateurs animés empêchent pumpAndSettle).
  Future<void> attendre(WidgetTester t, Finder f, {Duration delai = const Duration(seconds: 40)}) async {
    final fin = DateTime.now().add(delai);
    while (DateTime.now().isBefore(fin)) {
      await t.pump(const Duration(milliseconds: 250));
      if (f.evaluate().isNotEmpty) return;
    }
    throw TestFailure('Introuvable après ${delai.inSeconds} s : $f');
  }

  Future<void> toucher(WidgetTester t, Finder f) async {
    await attendre(t, f);
    await t.ensureVisible(f.first);
    await t.pump(const Duration(milliseconds: 200));
    await t.tap(f.first);
    await t.pump(const Duration(milliseconds: 400));
  }

  /// Onglet de la barre du bas (le même libellé sert aussi de titre de page).
  Finder onglet(String libelle) => find.byKey(ValueKey('onglet-$libelle'));

  /// Bouton retour de l'AppBar, par son infobulle localisée (« Retour » en français ;
  /// pageBack() cherche « Back »).
  Future<void> retour(WidgetTester t) async {
    final loc = MaterialLocalizations.of(t.element(find.byType(Scaffold).last));
    await toucher(t, find.byTooltip(loc.backButtonTooltip));
  }

  Future<void> saisir(WidgetTester t, String libelle, String texte) async {
    final champ = find.widgetWithText(TextField, libelle);
    await attendre(t, champ);
    await t.enterText(champ, texte);
    await t.pump(const Duration(milliseconds: 200));
  }

  testWidgets('parcours complet : inscription → séance → intervalles → jeûne → nutrition → progrès → profil', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await app.main();
    await t.pump(const Duration(seconds: 1));

    // ---------------------------------------------------------------- Inscription
    await toucher(t, find.text('Créer un compte'));
    final email = 'parcours-${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(9999)}@cresco.test';
    await saisir(t, 'Prénom', 'Testeur');
    await saisir(t, 'E-mail', email);
    await saisir(t, 'Mot de passe (10 caractères minimum)', 'mot-de-passe-de-test');
    await toucher(t, find.text('Créer le compte'));

    // ---------------------------------------------------------------- Aujourd'hui
    await attendre(t, find.text('FORME DU JOUR'));
    expect(find.text('SÉANCE DU JOUR'), findsOneWidget);
    expect(find.text('ÉNERGIE DU JOUR'), findsOneWidget);

    // ---------------------------------------------------------------- Séance complète
    await toucher(t, find.text('Ouvrir la séance'));
    await attendre(t, find.text('Développé couché'));
    // Nouveau compte : pas d'historique, on fixe la charge à 40 kg pour la première série.
    for (var i = 0; i < 16; i++) {
      await t.ensureVisible(find.byTooltip('Plus 2,5 kg'));
      await t.tap(find.byTooltip('Plus 2,5 kg'));
      await t.pump(const Duration(milliseconds: 60));
    }
    expect(find.text('40'), findsOneWidget);
    var series = 0;
    while (find.textContaining('Valider la').evaluate().isNotEmpty && series < 40) {
      await toucher(t, find.widgetWithText(ChoiceChip, '2'));
      await toucher(t, find.textContaining('Valider la'));
      series++;
      if (find.byTooltip('Passer le repos').evaluate().isNotEmpty) await toucher(t, find.byTooltip('Passer le repos'));
    }
    expect(series, greaterThan(3));
    expect(find.text('Séance terminée'), findsOneWidget);
    await toucher(t, find.widgetWithText(ActionChip, '7'));
    await attendre(t, find.text('FORME DU JOUR'));

    // ---------------------------------------------------------------- Intervalles
    await toucher(t, onglet('Entraînement'));
    await toucher(t, find.text('Intervalles sur tapis'));
    await attendre(t, find.text('TEMPS RESTANT'));
    // Le minuteur démarre seul : on vérifie qu'il défile, puis on met en pause.
    await t.pump(const Duration(seconds: 3));
    expect(find.text('05:00'), findsNothing);
    await toucher(t, find.text('Mettre en pause'));
    expect(find.text('Reprendre'), findsOneWidget);
    await retour(t);
    await t.pump(const Duration(seconds: 1));

    // ---------------------------------------------------------------- Jeûne
    await toucher(t, onglet('Aujourd’hui'));
    await toucher(t, find.text('Suivi du jeûne'));
    await toucher(t, find.text('Commencer le jeûne'));
    await attendre(t, find.text('JEÛNE EN COURS'));
    expect(find.text('Phase estimée · Digestion'), findsOneWidget);
    await toucher(t, find.text('Terminer le jeûne'));
    await attendre(t, find.text('Commencer le jeûne'));
    await retour(t);
    await t.pump(const Duration(seconds: 1));

    // ---------------------------------------------------------------- Nutrition
    await toucher(t, onglet('Nutrition'));
    await attendre(t, find.text('BILAN ESTIMÉ · 7 JOURS'));
    await attendre(t, find.text('Mes plats'));

    // ---------------------------------------------------------------- Progrès : la séance compte
    await toucher(t, onglet('Progrès'));
    await attendre(t, find.text('VERDICT DE LA SEMAINE'));
    await attendre(t, find.text('Développé couché'));

    // ---------------------------------------------------------------- Profil et déconnexion
    await toucher(t, onglet('Aujourd’hui'));
    await toucher(t, find.byTooltip('Profil et réglages'));
    await attendre(t, find.text(email));
    await toucher(t, find.text('Module foi'));
    await toucher(t, find.text('Se déconnecter'));
    await attendre(t, find.text('Bon retour'));
  });
}
