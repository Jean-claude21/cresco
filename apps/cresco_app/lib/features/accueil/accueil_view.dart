import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/features/nutrition/nutrition_view.dart';
import 'package:cresco_app/features/progres/progres_view.dart';
import 'package:cresco_app/features/today/today_view.dart';
import 'package:cresco_app/features/training/training_view.dart';
import 'package:cresco_app/ui/health_sync.dart';
import 'package:cresco_app/ui/tabs.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class AccueilViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();

  /// Sends what was entered offline, then imports the last days from Health Connect or Apple
  /// Santé when the user turned it on.
  Future<void> synchroniser() async {
    try {
      await _api.synchroniser();
    } on Exception {
      // Retried at the next launch.
    }
    try {
      await HealthSync(_api).sync();
    } on Object {
      // Retried at the next launch.
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
      // The tab bar lives in TabShell (lib/ui/tabs.dart), under every page opened from a tab.
      builder: (context, vm, _) => _Home(
        child: ListenableBuilder(
          listenable: Tabs.instance,
          builder: (context, _) => Scaffold(
            // A tab is rebuilt on each visit: its data is always fresh
            // (a finished session shows up at once in Progrès).
            body: KeyedSubtree(
              key: ValueKey(Tabs.instance.index),
              child: const [TodayView(), TrainingView(), NutritionView(), ProgresView()][Tabs.instance.index],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tells [Tabs] that the home shell is in the navigation stack while it is mounted.
class _Home extends StatefulWidget {
  const new({required this.child});
  final Widget child;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  @override
  void initState() {
    super.initState();
    Tabs.instance.homeMounted = true;
  }

  @override
  void dispose() {
    Tabs.instance.homeMounted = false;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
