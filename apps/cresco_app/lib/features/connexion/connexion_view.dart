import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/coach.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ConnexionViewModel extends BaseViewModel {
  new({bool signUp = false}) : inscription = signUp;

  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();

  bool inscription;
  String? erreur;

  void basculer() {
    inscription = !inscription;
    erreur = null;
    notifyListeners();
  }

  Future<void> valider(String email, String motDePasse, String nom) async {
    erreur = null;
    if (!email.contains('@')) {
      erreur = 'Adresse e-mail invalide';
    } else if (motDePasse.length < 10) {
      erreur = 'Le mot de passe doit faire au moins 10 caractères';
    }
    if (erreur != null) return notifyListeners();
    await runBusyFuture(
      Future(() async {
        try {
          if (inscription) {
            await _api.inscription(email.trim(), motDePasse, nom.trim());
          } else {
            await _api.connexion(email.trim(), motDePasse);
            try {
              await syncCoachFrom(await _api.profil());
            } on ErreurApi {
              // The coach stays the local one until the profile loads.
            }
          }
          // A new account first goes through the startup questions (goal, rhythm, gym, faith).
          await _nav.clearStackAndShow<void>(inscription ? Routes.onboardingView : Routes.accueilView);
        } on ErreurApi catch (e) {
          erreur = e.message;
        }
      }),
    );
  }
}

/// Sign in or sign up, opened from the welcome screen.
class ConnexionView extends StatefulWidget {
  const new({super.key, this.signUp = false});

  /// Opens directly on account creation ("Créer un compte" on the welcome screen).
  final bool signUp;
  @override
  State<ConnexionView> createState() => _ConnexionViewState();
}

class _ConnexionViewState extends State<ConnexionView> {
  final _email = TextEditingController();
  final _mdp = TextEditingController();
  final _nom = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _mdp.dispose();
    _nom.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ConnexionViewModel>.reactive(
      viewModelBuilder: () => ConnexionViewModel(signUp: widget.signUp),
      builder: (context, vm, _) => Scaffold(
        appBar: AppBar(),
        body: SafeArea(
          top: false,
          // Short form: everything is built (a lazy list would drop the button from the tree
          // when the keyboard pushes it off screen).
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(vm.inscription ? 'Créer ton compte' : 'Bon retour', style: CrescoTextes.titrePage),
                  const SizedBox(height: 8),
                  Text(
                    'Ta progression réelle, avec ton sommeil, ton alimentation et tes jeûnes.',
                    style: context.mutedStyle,
                  ),
                  const SizedBox(height: 28),
                  if (vm.inscription) ...[
                    TextField(
                      controller: _nom,
                      decoration: const InputDecoration(labelText: 'Prénom'),
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _mdp,
                    decoration: const InputDecoration(labelText: 'Mot de passe (10 caractères minimum)'),
                    obscureText: true,
                    textInputAction: TextInputAction.done,
                    autofillHints: [if (vm.inscription) AutofillHints.newPassword else AutofillHints.password],
                    onSubmitted: (_) {
                      if (!vm.isBusy) unawaited(vm.valider(_email.text, _mdp.text, _nom.text));
                    },
                  ),
                  if (vm.erreur != null) ...[
                    const SizedBox(height: 12),
                    Text(vm.erreur!, style: TextStyle(color: context.palette.danger)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: vm.isBusy ? null : () => vm.valider(_email.text, _mdp.text, _nom.text),
                    child: vm.isBusy
                        ? SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: context.palette.onAction),
                          )
                        : Text(vm.inscription ? 'Créer le compte' : 'Se connecter'),
                  ),
                  TextButton(
                    onPressed: vm.basculer,
                    child: Text(
                      vm.inscription ? 'J’ai déjà un compte' : 'Créer un compte',
                      style: TextStyle(color: context.palette.ink),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Cresco est une application de bien-être et de performance, pas un dispositif médical.',
                    style: context.mutedStyle,
                    textAlign: TextAlign.center,
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
