import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ConnexionViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();

  bool inscription = false;
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
          }
          await _nav.clearStackAndShow<void>(Routes.accueilView);
        } on ErreurApi catch (e) {
          erreur = e.message;
        }
      }),
    );
  }
}

class ConnexionView extends StatefulWidget {
  const new({super.key});
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
      viewModelBuilder: ConnexionViewModel.new,
      builder: (context, vm, _) => Scaffold(
        body: SafeArea(
          // Formulaire court : tout est construit (une liste paresseuse retirerait le bouton de l'arbre
          // quand le clavier le pousse hors de l'écran).
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const Row(
                    children: [
                      Icon(Icons.eco, color: CrescoCouleurs.pin, size: 30),
                      SizedBox(width: 8),
                      Text(
                        'cresco',
                        style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: CrescoCouleurs.pin),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(vm.inscription ? 'Créer ton compte' : 'Bon retour', style: CrescoTextes.titrePage),
                  const SizedBox(height: 8),
                  const Text(
                    'Ta progression réelle, avec ton sommeil, ton alimentation et tes jeûnes.',
                    style: CrescoTextes.secondaire,
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
                    Text(vm.erreur!, style: const TextStyle(color: CrescoCouleurs.alerte)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: vm.isBusy ? null : () => vm.valider(_email.text, _mdp.text, _nom.text),
                    child: vm.isBusy
                        ? const SizedBox.square(
                            dimension: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: CrescoCouleurs.blanc),
                          )
                        : Text(vm.inscription ? 'Créer le compte' : 'Se connecter'),
                  ),
                  TextButton(
                    onPressed: vm.basculer,
                    child: Text(
                      vm.inscription ? 'J’ai déjà un compte' : 'Créer un compte',
                      style: const TextStyle(color: CrescoCouleurs.pin),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Cresco est une application de bien-être et de performance, pas un dispositif médical.',
                    style: CrescoTextes.secondaire,
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
