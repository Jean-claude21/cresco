import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/accueil/saisie_rapide.dart';
import 'package:cresco_app/features/entrainement/entrainement_view.dart';
import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:cresco_app/features/progres/progres_view.dart';
import 'package:cresco_app/features/today/today_view.dart';
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
        // Un onglet est reconstruit à chaque visite : ses données sont toujours à jour
        // (une séance terminée apparaît aussitôt dans Progrès).
        body: KeyedSubtree(
          key: ValueKey(vm.currentIndex),
          child: const [TodayView(), EntrainementView(), NutritionView(), ProgresView()][vm.currentIndex],
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
                    backgroundColor: context.palette.action,
                    foregroundColor: context.palette.onAction,
                    tooltip: 'Ajouter une donnée',
                    onPressed: () => ouvrirSaisieRapide(context),
                    child: const Icon(Icons.add, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Onglets extends StatelessWidget {
  const new({required this.index, required this.onTap});
  final int index;
  final ValueChanged<int> onTap;

  static const List<(IconData, String)> _items = [
    (Icons.home_outlined, 'Aujourd’hui'),
    (Icons.fitness_center, 'Entraînement'),
    (Icons.restaurant_outlined, 'Nutrition'),
    (Icons.bar_chart_rounded, 'Progrès'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(33),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (var i = 0; i < _items.length; i++)
            Expanded(
              child: Semantics(
                selected: i == index,
                button: true,
                label: _items[i].$2,
                excludeSemantics: true,
                child: Tooltip(
                  message: _items[i].$2,
                  child: InkWell(
                    key: ValueKey('onglet-${_items[i].$2}'),
                    borderRadius: BorderRadius.circular(26),
                    onTap: () => onTap(i),
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        width: i == index ? 64 : 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: i == index ? p.action : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(_items[i].$1, size: 24, color: i == index ? p.onAction : p.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
