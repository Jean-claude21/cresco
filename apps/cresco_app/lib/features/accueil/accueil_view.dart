import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/features/accueil/saisie_rapide.dart';
import 'package:cresco_app/features/aujourdhui/aujourdhui_view.dart';
import 'package:cresco_app/features/entrainement/entrainement_view.dart';
import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:cresco_app/features/progres/progres_view.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class AccueilViewModel extends IndexTrackingViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();

  /// Renvoie au serveur les saisies faites hors ligne.
  Future<void> synchroniser() async {
    try {
      await _api.synchroniser();
    } on Exception {
      // Réessayé au prochain lancement.
    }
  }
}

/// Coquille : quatre destinations et le bouton « + » de saisie rapide (DESIGN.md).
class AccueilView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<AccueilViewModel>.reactive(
      viewModelBuilder: AccueilViewModel.new,
      onViewModelReady: (vm) => vm.synchroniser(),
      builder: (context, vm, _) => Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: vm.currentIndex,
          children: const [AujourdhuiView(), EntrainementView(), NutritionView(), ProgresView()],
        ),
        bottomNavigationBar: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: _Onglets(index: vm.currentIndex, onTap: vm.setIndex),
                ),
                const SizedBox(width: 10),
                SizedBox.square(
                  dimension: 66,
                  child: FloatingActionButton(
                    heroTag: 'plus',
                    elevation: 0,
                    shape: const CircleBorder(),
                    backgroundColor: CrescoCouleurs.pin,
                    foregroundColor: CrescoCouleurs.blanc,
                    tooltip: 'Ajouter une donnée',
                    onPressed: () => ouvrirSaisieRapide(context),
                    child: const Icon(Icons.add, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ),
        floatingActionButton: vm.currentIndex == 0
            ? Padding(
                padding: const EdgeInsets.only(bottom: 70),
                child: IconButton(
                  tooltip: 'Profil et réglages',
                  onPressed: () => vm.nav.navigateTo<void>(Routes.profilView),
                  icon: const Icon(Icons.person_outline),
                ),
              )
            : null,
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      ),
    );
  }
}

class _Onglets extends StatelessWidget {
  const new({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const List<(IconData, String)> _items = [
    (Icons.wb_sunny_outlined, 'Aujourd’hui'),
    (Icons.fitness_center, 'Entraînement'),
    (Icons.ramen_dining_outlined, 'Nutrition'),
    (Icons.trending_up, 'Progrès'),
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: CrescoCouleurs.blanc,
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: CrescoCouleurs.filet),
        boxShadow: const [BoxShadow(color: CrescoCouleurs.ombre, blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: Semantics(
                  selected: i == index,
                  button: true,
                  label: _items[i].$2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(30),
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: i == index ? CrescoCouleurs.sauge : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(_items[i].$1, size: 22, color: CrescoCouleurs.encre),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          child: Text(
                            _items[i].$2,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                              color: i == index ? CrescoCouleurs.pin : CrescoCouleurs.texteSecondaire,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
