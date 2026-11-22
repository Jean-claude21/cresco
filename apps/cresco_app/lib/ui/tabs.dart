import 'dart:async';

import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/features/accueil/saisie_rapide.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:stacked_services/stacked_services.dart';

/// Selected tab, whether the home shell is in the stack, and the page on top of it.
///
/// The tab bar stays under every page opened from a tab (Mon corps, Ma salle, Jeûne, Profil…)
/// and hides during effort and before sign-in ([hiddenOn]). DESIGN.md, « Barre d’onglets ».
class Tabs extends ChangeNotifier {
  new _private();
  static final Tabs instance = Tabs._private();

  /// Full-screen pages: effort (no leaving a session by mistake), camera, sign-in and first settings.
  /// Bienvenue is not listed: its route is `/`, and the home shell is never under it.
  static const Set<String> hiddenOn = {
    Routes.seanceView,
    Routes.intervallesView,
    Routes.scanView,
    Routes.connexionView,
    Routes.onboardingView,
  };

  int _index = 0;
  int get index => _index;

  bool _homeMounted = false;
  bool get homeMounted => _homeMounted;
  set homeMounted(bool value) {
    if (value == _homeMounted) return;
    _homeMounted = value;
    _notify();
  }

  final List<String?> _pages = [];

  /// Name of the page route on top, null for an unnamed one.
  String? get topPage => _pages.isEmpty ? null : _pages.last;

  bool get barVisible => _homeMounted && !hiddenOn.contains(topPage);

  void select(int i) {
    _index = i;
    notifyListeners();
  }

  /// Back to the home shell, tab [i] selected.
  void open(int i) {
    StackedService.navigatorKey?.currentState?.popUntil((r) => r.settings.name == Routes.accueilView || r.isFirst);
    select(i);
  }

  /// Back to a fresh state (tests).
  void reset() {
    _index = 0;
    _pages.clear();
    _homeMounted = false;
  }

  // Navigator callbacks can come during a build: listeners are told after it.
  void _notify() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => notifyListeners());
    } else {
      notifyListeners();
    }
  }
}

/// Keeps [Tabs.topPage] in step with the app navigator. Page routes only: sheets and dialogs
/// open above the bar.
class TabsObserver extends NavigatorObserver {
  List<String?> get _pages => Tabs.instance._pages;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is! PageRoute) return;
    _pages.add(route.settings.name);
    Tabs.instance._notify();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _remove(oldRoute);
    if (newRoute != null) didPush(newRoute, null);
  }

  void _remove(Route<dynamic> route) {
    if (route is! PageRoute) return;
    final i = _pages.lastIndexOf(route.settings.name);
    if (i >= 0) _pages.removeAt(i);
    Tabs.instance._notify();
  }
}

/// `MaterialApp.builder`: the app navigator, with the tab bar under it when [Tabs.barVisible].
Widget tabShell(BuildContext context, Widget? child) => _TabShell(child: child ?? const SizedBox.shrink());

class _TabShell extends StatelessWidget {
  const new({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Tabs.instance,
      builder: (context, _) {
        final tabs = Tabs.instance;
        // The keyboard covers the bar: the page keeps all the room left.
        final visible = tabs.barVisible && MediaQuery.viewInsetsOf(context).bottom == 0;
        return Column(
          children: [
            Expanded(
              // The bar takes the bottom safe area: pages above it no longer pad for it.
              child: MediaQuery.removePadding(context: context, removeBottom: visible, child: child),
            ),
            if (visible)
              Material(
                type: MaterialType.transparency,
                child: CrescoTabBar(
                  index: tabs.index,
                  onTap: tabs.open,
                  onAdd: () {
                    final overlay = StackedService.navigatorKey?.currentState?.overlay?.context;
                    if (overlay != null) unawaited(ouvrirSaisieRapide(overlay));
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Bottom bar of mockup G: four labeled tabs around a round "+" (quick entry).
class CrescoTabBar extends StatelessWidget {
  const new({required this.index, required this.onTap, required this.onAdd, super.key});
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  // Phosphor line icons, as in mockup G2: regular stroke, bold for the active tab with its bold label and underline.
  static const List<(IconData, IconData, String)> _items = [
    (CrescoIcons.calendar, CrescoIcons.calendarBold, 'Aujourd’hui'),
    (CrescoIcons.barbell, CrescoIcons.barbellBold, 'Entraînement'),
    (CrescoIcons.forkKnife, CrescoIcons.forkKnifeBold, 'Nutrition'),
    (CrescoIcons.chartBar, CrescoIcons.chartBarBold, 'Progrès'),
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
              padding: const EdgeInsets.only(top: 7, bottom: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(on ? activeIcon : icon, size: 24, color: p.ink),
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
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 200),
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
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              tab(0),
              tab(1),
              SizedBox(
                width: 72,
                // heightFactor 1: the bar stays as tall as its content, not the whole screen.
                child: Center(
                  heightFactor: 1,
                  // Outside the navigator: no overlay for a tooltip, the label goes to accessibility.
                  child: SizedBox.square(
                    dimension: 40,
                    child: FloatingActionButton(
                      key: const ValueKey('ajouter-donnee'),
                      heroTag: null,
                      elevation: 0,
                      highlightElevation: 0,
                      shape: const CircleBorder(),
                      backgroundColor: p.action,
                      foregroundColor: p.onAction,
                      onPressed: onAdd,
                      child: const Icon(Icons.add, size: 26, semanticLabel: 'Ajouter une donnée'),
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
