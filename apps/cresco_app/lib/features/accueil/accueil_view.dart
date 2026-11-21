import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/accueil/saisie_rapide.dart';
import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:cresco_app/features/progres/progres_view.dart';
import 'package:cresco_app/features/today/today_view.dart';
import 'package:cresco_app/features/training/training_view.dart';
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
        // A tab is rebuilt on each visit: its data is always fresh
        // (a finished session shows up at once in Progrès).
        body: KeyedSubtree(
          key: ValueKey(vm.currentIndex),
          child: const [TodayView(), TrainingView(), NutritionView(), ProgresView()][vm.currentIndex],
        ),
        bottomNavigationBar: _TabBar(
          index: vm.currentIndex,
          onTap: vm.setIndex,
          onAdd: () => ouvrirSaisieRapide(context),
        ),
      ),
    );
  }
}

/// Bottom bar of mockup G: four labeled tabs around a round "+" (quick entry).
class _TabBar extends StatelessWidget {
  const new({required this.index, required this.onTap, required this.onAdd});
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  static const List<(IconData, IconData, String)> _items = [
    (Icons.home_outlined, Icons.home, 'Aujourd’hui'),
    (Icons.fitness_center_outlined, Icons.fitness_center, 'Entraînement'),
    (Icons.restaurant_outlined, Icons.restaurant, 'Nutrition'),
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Progrès'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tab(int i) {
      final (icon, activeIcon, label) = _items[i];
      final on = i == index;
      return Expanded(
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            key: ValueKey('onglet-$label'),
            onTap: () => onTap(i),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? activeIcon : icon, size: 24, color: on ? p.effort : p.ink),
                  const SizedBox(height: 2),
                  FittedBox(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                        color: on ? p.ink : p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: p.background,
        border: Border(
          top: BorderSide(color: p.line, width: CrescoShape.border),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              tab(0),
              tab(1),
              SizedBox(
                width: 72,
                child: Center(
                  child: SizedBox.square(
                    dimension: 48,
                    child: FloatingActionButton(
                      heroTag: 'plus',
                      elevation: 0,
                      highlightElevation: 0,
                      shape: const CircleBorder(),
                      backgroundColor: p.action,
                      foregroundColor: p.onAction,
                      tooltip: 'Ajouter une donnée',
                      onPressed: onAdd,
                      child: const Icon(Icons.add, size: 28),
                    ),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}
