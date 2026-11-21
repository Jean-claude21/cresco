import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked_services/stacked_services.dart';

/// First screen when signed out (mockup G "Bienvenue"): the two coaches, one sentence,
/// and the two Picnic-style buttons side by side.
class WelcomeView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final nav = locator<NavigationService>();
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 12, CrescoSpacing.margin, 20),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight - 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  FadeSlideIn(
                    child: Center(child: CoachDuo(height: (box.maxHeight * 0.46).clamp(220, 380))),
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(
                    index: 1,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          const TextSpan(text: 'Bienvenue sur '),
                          TextSpan(
                            text: 'Cresco',
                            style: TextStyle(color: p.effort),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: CrescoTextes.titrePage.copyWith(fontSize: 34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FadeSlideIn(
                    index: 2,
                    child: Text(
                      'Ta séance du jour, adaptée à ta forme.',
                      textAlign: TextAlign.center,
                      style: context.mutedStyle.copyWith(fontSize: 16, color: p.ink),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => nav.navigateTo<void>(Routes.connexionView),
                          child: const Text('Se connecter'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => nav.navigateTo<void>(
                            Routes.connexionView,
                            arguments: const ConnexionViewArguments(signUp: true),
                          ),
                          child: const Text('Créer un compte'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cresco est une application de bien-être et de performance, pas un dispositif médical.',
                    textAlign: TextAlign.center,
                    style: context.mutedStyle.copyWith(fontSize: 12),
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
