import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/coach.dart';
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

  static const steps = 5;
  int step = 0;
  Coach coach = currentCoach();
  String goal = 'maintien';
  String level = 'intermediaire';
  final restDays = <int>{0};
  int sessionsPerWeek = 3;
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

  Future<void> pickCoach(Coach c) async {
    coach = c;
    notifyListeners();
    await saveCoach(c, remote: false);
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
        'preferences': {
          'moduleFoi': faith,
          'joursReposVerrouilles': restDays.toList()..sort(),
          'coach': coach.name,
          'seancesParSemaine': sessionsPerWeek,
        },
      });
    } on ErreurApi {
      _messages.afficher(message: 'Profil non enregistré : tu pourras le compléter dans Profil.');
    }
    setBusy(false);
    await _nav.clearStackAndShow<void>(Routes.accueilView);
  }
}

/// First launch after sign-up (mockup G "Démarrage"): coach, goal, rhythm, my gym, fasting and faith.
/// The chosen coach asks each question.
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
                  padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 16, CrescoSpacing.margin, 4),
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
                                color: i <= vm.step ? p.effort : p.line,
                                borderRadius: const BorderRadius.all(Radius.circular(2)),
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
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 380),
                    transitionBuilder: (child, a) => FadeTransition(
                      opacity: a,
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                        child: child,
                      ),
                    ),
                    child: ListView(
                      key: ValueKey(vm.step),
                      padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 12, CrescoSpacing.margin, 20),
                      children: switch (vm.step) {
                        0 => [
                          const _Title('Qui t’accompagne ?'),
                          const _Lead(
                            'Ton coach t’accueille, t’explique et t’encourage. Tu pourras changer dans Profil.',
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final (i, c) in Coach.values.indexed) ...[
                                if (i > 0) const SizedBox(width: 12),
                                Expanded(
                                  child: _CoachChoice(coach: c, selected: vm.coach == c, onTap: () => vm.pickCoach(c)),
                                ),
                              ],
                            ],
                          ),
                        ],
                        1 => [
                          _Bubble(coach: vm.coach, pose: CoachPose.explique, text: 'On commence par ton objectif.'),
                          const _Title('Qu’est-ce que tu veux changer ?'),
                          for (final (id, label, hint) in const [
                            ('perte', 'Perdre du gras', 'Déficit modéré, force préservée'),
                            ('maintien', 'Être en forme', 'Garder mon poids, progresser'),
                            ('prise', 'Prendre du muscle', 'Léger surplus, volume suffisant'),
                          ])
                            _Choice(
                              label: label,
                              hint: hint,
                              selected: vm.goal == id,
                              onTap: () => vm.set(() => vm.goal = id),
                            ),
                        ],
                        2 => [
                          _Bubble(
                            coach: vm.coach,
                            pose: CoachPose.reflechit,
                            text: 'Mieux vaut trois séances tenues que cinq abandonnées.',
                          ),
                          const _Title('Ton rythme, sans te mentir.'),
                          for (final (id, label, hint) in const [
                            ('debutant', 'Débutant', 'Moins de 6 mois de musculation'),
                            ('intermediaire', 'Intermédiaire', '6 mois à 2 ans, je connais les mouvements'),
                            ('avance', 'Confirmé', 'Plus de 2 ans, je suis mes charges'),
                          ])
                            _Choice(
                              label: label,
                              hint: hint,
                              selected: vm.level == id,
                              onTap: () => vm.set(() => vm.level = id),
                            ),
                          const SizedBox(height: 12),
                          Text('Séances par semaine', style: context.overlineStyle),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var n = 2; n <= 6; n++)
                                ChoiceChip(
                                  key: ValueKey('seances-$n'),
                                  showCheckmark: false,
                                  label: Text('$n'),
                                  selected: vm.sessionsPerWeek == n,
                                  onSelected: (_) => vm.set(() => vm.sessionsPerWeek = n),
                                ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Jours de repos verrouillés', style: context.overlineStyle),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (var d = 0; d < 7; d++)
                                FilterChip(
                                  showCheckmark: false,
                                  label: Text(_days[d]),
                                  selected: vm.restDays.contains(d),
                                  onSelected: (on) => vm.set(() => on ? vm.restDays.add(d) : vm.restDays.remove(d)),
                                ),
                            ],
                          ),
                        ],
                        3 => [
                          _Bubble(coach: vm.coach, pose: CoachPose.carnet, text: 'Dis-moi ce qu’il y a dans ta salle.'),
                          const _Title('Ma salle'),
                          const _Lead('Coche tes machines : tes séances et ton IA n’utiliseront que ça.'),
                          FilledButton.icon(
                            onPressed: vm.openGym,
                            icon: Icon(vm.gymDone ? Icons.check : Icons.place_outlined),
                            label: Text(vm.gymDone ? 'Ma salle est décrite' : 'Décrire ma salle'),
                          ),
                          const SizedBox(height: 10),
                          Text('Tu peux aussi le faire plus tard, depuis Entraînement.', style: context.mutedStyle),
                        ],
                        _ => [
                          _Bubble(coach: vm.coach, pose: CoachPose.pouce, text: 'Dernière question, et c’est parti.'),
                          const _Title('Jeûne et foi'),
                          const _Lead('Optionnel. Si tu jeûnes, tes séances s’adaptent aux phases de ton jeûne.'),
                          Material(
                            color: p.background,
                            shape: CrescoShape.rectangle(p.line),
                            child: SwitchListTile(
                              title: const Text('Module foi', style: TextStyle(fontWeight: FontWeight.w800)),
                              subtitle: Text(
                                'Un verset et une intention privée pour accompagner tes jeûnes',
                                style: context.mutedStyle,
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
                  padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 0, CrescoSpacing.margin, 16),
                  child: Row(
                    children: [
                      if (vm.step > 0) ...[
                        Expanded(
                          child: OutlinedButton(onPressed: vm.back, child: const Text('Retour')),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        flex: 2,
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
}

class _Title extends StatelessWidget {
  const new(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: CrescoTextes.titrePage.copyWith(fontSize: 30)),
  );
}

class _Lead extends StatelessWidget {
  const new(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Text(text, style: context.mutedStyle.copyWith(fontSize: 15)),
  );
}

/// The coach, small, with a speech bubble.
class _Bubble extends StatelessWidget {
  const new({required this.coach, required this.pose, required this.text});
  final Coach coach;
  final CoachPose pose;
  final String text;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          CoachIllustration(coach: coach, pose: pose, height: 120),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 40),
              child: DecoratedBox(
                decoration: CrescoShape.outlined(p, fill: p.background, outline: p.ink),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, height: 1.3)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachChoice extends StatelessWidget {
  const new({required this.coach, required this.selected, required this.onTap});
  final Coach coach;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      selected: selected,
      button: true,
      label: coach.label,
      excludeSemantics: true,
      child: Material(
        color: selected ? p.effortSoft : p.background,
        shape: CrescoShape.rectangle(selected ? p.effort : p.line),
        child: InkWell(
          key: ValueKey('coach-${coach.name}'),
          customBorder: CrescoShape.rectangle(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                CoachIllustration(coach: coach, pose: CoachPose.salue, height: 190),
                const SizedBox(height: 8),
                Text(coach.label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                Icon(selected ? Icons.check_box : Icons.check_box_outline_blank, color: selected ? p.effort : p.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
          color: selected ? p.action : p.background,
          shape: CrescoShape.rectangle(selected ? p.action : p.line),
          child: InkWell(
            customBorder: CrescoShape.rectangle(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: ink),
                        ),
                        Text(hint, style: TextStyle(fontSize: 13, color: ink.withValues(alpha: 0.75))),
                      ],
                    ),
                  ),
                  Icon(
                    selected ? Icons.check_box : Icons.check_box_outline_blank,
                    color: selected ? p.effort : p.muted,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
