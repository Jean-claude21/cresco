import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class OnboardingViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();
  final Messages _messages = locator<Messages>();

  static const steps = 4;
  int step = 0;
  String goal = 'maintien';
  String level = 'intermediaire';
  final restDays = <int>{0};
  bool faith = false;
  bool gymDone = false;

  void next() {
    if (step < steps - 1) {
      step++;
      notifyListeners();
    }
  }

  void back() {
    if (step > 0) {
      step--;
      notifyListeners();
    }
  }

  void set(VoidCallback change) {
    change();
    notifyListeners();
  }

  Future<void> openGym() async {
    await _nav.navigateTo<void>(Routes.gymView);
    gymDone = true;
    notifyListeners();
  }

  /// Saves the answers to the profile, then opens the app. Offline, the profile can be set later.
  Future<void> finish() async {
    setBusy(true);
    try {
      await _api.modifierProfil({
        'objectif': goal,
        'niveau': level,
        'preferences': {'moduleFoi': faith, 'joursReposVerrouilles': restDays.toList()..sort()},
      });
    } on ErreurApi {
      _messages.afficher(message: 'Profil non enregistré : tu pourras le compléter dans Profil.');
    }
    setBusy(false);
    await _nav.clearStackAndShow<void>(Routes.accueilView);
  }
}

/// First launch after sign-up (mockup "Démarrage"): goal, rhythm, my gym, fasting and faith.
class OnboardingView extends StatelessWidget {
  const new({super.key});

  static const _days = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<OnboardingViewModel>.reactive(
      viewModelBuilder: OnboardingViewModel.new,
      builder: (context, vm, _) {
        final p = context.palette;
        final last = vm.step == OnboardingViewModel.steps - 1;
        return Scaffold(
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Semantics(
                    label: 'Étape ${vm.step + 1} sur ${OnboardingViewModel.steps}',
                    child: Row(
                      children: [
                        for (var i = 0; i < OnboardingViewModel.steps; i++) ...[
                          if (i > 0) const SizedBox(width: 6),
                          Expanded(
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              height: 6,
                              decoration: BoxDecoration(
                                color: i <= vm.step ? p.ink : p.line,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 380),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: ListView(
                      key: ValueKey(vm.step),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: switch (vm.step) {
                        0 => [
                          const _Title('Qu’est-ce que tu veux changer ?'),
                          const _Lead('Tes objectifs d’énergie et de séances partent de là.'),
                          for (final (id, label, hint) in const [
                            ('perte', 'Perdre du gras', 'Déficit modéré, force préservée'),
                            ('maintien', 'Être en forme', 'Garder mon poids, progresser'),
                            ('prise', 'Prendre du muscle', 'Léger surplus, volume suffisant'),
                          ])
                            _Choice(label: label, hint: hint, selected: vm.goal == id, onTap: () => vm.set(() => vm.goal = id)),
                        ],
                        1 => [
                          const _Title('Ton rythme, sans te mentir.'),
                          const _Lead('Mieux vaut trois séances tenues que cinq abandonnées.'),
                          for (final (id, label, hint) in const [
                            ('debutant', 'Débutant', 'Moins de 6 mois de musculation'),
                            ('intermediaire', 'Intermédiaire', '6 mois à 2 ans, je connais les mouvements'),
                            ('avance', 'Confirmé', 'Plus de 2 ans, je suis mes charges'),
                          ])
                            _Choice(label: label, hint: hint, selected: vm.level == id, onTap: () => vm.set(() => vm.level = id)),
                          const SizedBox(height: 12),
                          Text('Jours de repos verrouillés', style: context.overlineStyle),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var d = 0; d < 7; d++)
                                FilterChip(
                                  label: Text(_days[d]),
                                  selected: vm.restDays.contains(d),
                                  onSelected: (on) => vm.set(() => on ? vm.restDays.add(d) : vm.restDays.remove(d)),
                                ),
                            ],
                          ),
                        ],
                        2 => [
                          const _Title('Ma salle'),
                          const _Lead('Coche les machines de ta salle : tes séances et ton IA n’utiliseront que ça.'),
                          FilledButton.icon(
                            onPressed: vm.openGym,
                            icon: Icon(vm.gymDone ? Icons.check : Icons.place_outlined),
                            label: Text(vm.gymDone ? 'Ma salle est décrite' : 'Décrire ma salle'),
                          ),
                          const SizedBox(height: 10),
                          Text('Tu peux aussi le faire plus tard, depuis Entraînement.', style: context.mutedStyle),
                        ],
                        _ => [
                          const _Title('Jeûne et foi'),
                          const _Lead('Optionnel. Si tu jeûnes, tes séances s’adaptent aux phases de ton jeûne.'),
                          Material(
                            color: faithColor(p, on: vm.faith),
                            borderRadius: BorderRadius.circular(22),
                            child: SwitchListTile(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              title: Text(
                                'Module foi',
                                style: TextStyle(fontWeight: FontWeight.w800, color: vm.faith ? Colors.white : p.ink),
                              ),
                              subtitle: Text(
                                'Un verset et une intention privée pour accompagner tes jeûnes',
                                style: TextStyle(color: vm.faith ? const Color(0xFFB8B2E8) : p.muted),
                              ),
                              value: vm.faith,
                              onChanged: (v) => vm.set(() => vm.faith = v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Rien de tout ça n’est partagé. Avant un premier jeûne de plus de 24 h, quelques questions de '
                            'santé te sont posées. Pas de jeûne avant 18 ans.',
                            style: context.mutedStyle,
                          ),
                        ],
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Row(
                    children: [
                      if (vm.step > 0) ...[
                        IconButton.filled(
                          tooltip: 'Étape précédente',
                          onPressed: vm.back,
                          style: IconButton.styleFrom(
                            backgroundColor: p.surface,
                            foregroundColor: p.ink,
                            fixedSize: const Size(56, 56),
                          ),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: FilledButton(
                          onPressed: vm.isBusy ? null : (last ? vm.finish : vm.next),
                          child: Text(last ? 'C’est parti' : 'Continuer'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Night card when the faith module is on, the normal surface otherwise.
  static Color faithColor(CrescoPalette p, {required bool on}) => on ? const Color(0xFF15122E) : p.surface;
}

class _Title extends StatelessWidget {
  const new(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(text, style: CrescoTextes.titrePage.copyWith(fontSize: 30)));
}

class _Lead extends StatelessWidget {
  const new(this.text);
  final String text;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 18), child: Text(text, style: context.mutedStyle.copyWith(fontSize: 15)));
}

class _Choice extends StatelessWidget {
  const new({required this.label, required this.hint, required this.selected, required this.onTap});
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ink = selected ? p.onAction : p.ink;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          color: selected ? p.action : p.surface,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(label, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink)),
                        Text(hint, style: TextStyle(fontSize: 13, color: ink.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                  if (selected) Icon(Icons.check_circle, color: p.onAction),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
