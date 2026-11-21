import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

/// Séance d'intervalles par défaut : 6 × (1 min à 12 km/h, 1 min 30 à 9 km/h).
const intervallesParDefaut = <String, Object?>{
  'nom': 'Intervalles 6 × 1 min',
  'type': 'course_tapis',
  'blocs': [
    {
      'repeter': 1,
      'etapes': [
        {
          'libelle': 'Échauffement',
          'duree': {'temps_s': 300},
          'cible': {'vitesse_ms': 2.22},
        },
      ],
    },
    {
      'repeter': 6,
      'etapes': [
        {
          'libelle': 'Rapide',
          'duree': {'temps_s': 60},
          'cible': {'vitesse_ms': 3.33},
        },
        {
          'libelle': 'Récupération',
          'duree': {'temps_s': 90},
          'cible': {'vitesse_ms': 2.5},
        },
      ],
    },
    {
      'repeter': 1,
      'etapes': [
        {
          'libelle': 'Retour au calme',
          'duree': {'temps_s': 240},
          'cible': {'vitesse_ms': 1.94},
        },
      ],
    },
  ],
  'annonces': {'preavis_s': 15, 'voix': true, 'vibration': true},
};

class EntrainementViewModel extends FutureViewModel<Json> {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();

  @override
  Future<Json> futureToRun() => _api.seanceDuJour();
}

class EntrainementView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<EntrainementViewModel>.reactive(
      viewModelBuilder: EntrainementViewModel.new,
      builder: (context, vm, _) {
        final d = vm.data;
        final modele = d?['modele'] as Json?;
        final blocs = (modele?['blocs'] as List?)?.cast<Json>() ?? const [];
        return PageCresco(
          titre: 'Entraînement',
          onRefresh: vm.initialise,
          enfants: [
            if (vm.isBusy && d == null) const Chargement(),
            if (vm.hasError) MessageErreur(vm.modelError.toString(), reessayer: vm.initialise),
            if (d != null)
              CrescoCarte(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Surtitre(libellesDecision[(d['decision']! as Json)['decision']] ?? ''),
                    const SizedBox(height: 8),
                    Text(modele?['nom'] as String? ?? 'Séance', style: CrescoTextes.titreCarte),
                    const SizedBox(height: 4),
                    Text(d['raison']! as String, style: CrescoTextes.secondaire),
                    const SizedBox(height: 12),
                    for (final b in blocs)
                      for (final e in (b['etapes']! as List).cast<Json>())
                        LigneMesure(
                          icone: Icons.fitness_center,
                          libelle: e['nom'] as String? ?? e['libelle'] as String? ?? '',
                          valeur:
                              '${b['repeter']} × ${(e['duree']! as Json)['reps'] ?? ''}'
                              '${(e['cible']! as Json)['charge_kg'] is num ? ' · ${decimal((e['cible']! as Json)['charge_kg'])} kg' : ''}',
                        ),
                    const SizedBox(height: 14),
                    FilledButton(
                      onPressed: blocs.isEmpty ? null : () => vm.nav.navigateTo<void>(Routes.seanceView),
                      child: const Text('Démarrer la séance'),
                    ),
                  ],
                ),
              ),
            CrescoCarte(
              onTap: () => vm.nav.navigateTo<void>(
                Routes.intervallesView,
                arguments: const IntervallesViewArguments(modele: intervallesParDefaut),
              ),
              child: const Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: CrescoCouleurs.sauge,
                    child: Icon(Icons.directions_run, color: CrescoCouleurs.pin),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Intervalles sur tapis', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        Text('6 × 1 min à 12 km/h · annonces vocales', style: CrescoTextes.secondaire),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const CrescoCarte(
              child: Text(
                'Demande à ton assistant IA (via le MCP de Cresco) de te programmer une séance : elle apparaîtra ici, '
                'avec les charges calculées par le moteur.',
                style: CrescoTextes.secondaire,
              ),
            ),
          ],
        );
      },
    );
  }
}
