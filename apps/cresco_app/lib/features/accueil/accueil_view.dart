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

  // Same thin line icons for every state, as in the mockup: only the label marks the active tab.
  static const List<(IconData, String)> _items = [
    (Icons.calendar_today_outlined, 'Aujourd’hui'),
    (Icons.fitness_center_outlined, 'Entraînement'),
    (Icons.restaurant_outlined, 'Nutrition'),
    (Icons.signal_cellular_alt, 'Progrès'),
  ];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget tab(int i) {
      final (icon, label) = _items[i];
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
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: p.ink),
                  const SizedBox(height: 3),
                  FittedBox(
                    child: Text(
                      label,
                      style: TextStyle(fontSize: 12, fontWeight: on ? FontWeight.w800 : FontWeight.w400, color: p.ink),
                    ),
                  ),
                  const SizedBox(height: 3),
                  // Underline of the active tab.
                  AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 200),
                    width: on ? 40 : 0,
                    height: 2.5,
                    color: p.ink,
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
        // Grows with large text instead of clipping the labels.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 66),
          child: Row(
            children: [
              tab(0),
              tab(1),
              SizedBox(
                width: 72,
                // heightFactor 1: the bar stays as tall as its content, not the whole screen.
                child: Center(
                  heightFactor: 1,
                  child: SizedBox.square(
                    dimension: 44,
                    child: FloatingActionButton(
                      heroTag: 'plus',
                      elevation: 0,
                      highlightElevation: 0,
                      shape: const CircleBorder(),
                      backgroundColor: p.action,
                      foregroundColor: p.onAction,
                      tooltip: 'Ajouter une donnée',
                      onPressed: onAdd,
                      child: const Icon(Icons.add, size: 26),
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
