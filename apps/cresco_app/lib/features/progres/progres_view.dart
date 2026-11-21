import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';

class ProgresViewModel extends FutureViewModel<Json> {
  final CrescoApi _api = locator<CrescoApi>();
  int exercice = 0;

  @override
  Future<Json> futureToRun() => _api.progression();

  void choisir(int i) {
    exercice = i;
    notifyListeners();
  }
}

const libellesVerdict = {
  'progression': 'Tu progresses',
  'maintien_reussite': 'Maintien = réussite',
  'stagnation': 'Stagnation',
  'patience': 'Patience',
  'donnees_insuffisantes': 'Encore un peu de données',
};

/// Écran 5 (maquette 05-progres) : verdict expliqué, tendance e1RM, énergie, poids, sommeil.
class ProgresView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ProgresViewModel>.reactive(
      viewModelBuilder: ProgresViewModel.new,
      builder: (context, vm, _) {
        final d = vm.data;
        final exercices = (d?['exercices'] as List?)?.cast<Json>() ?? const [];
        final ex = exercices.isEmpty ? null : exercices[vm.exercice.clamp(0, exercices.length - 1)];
        final energie = d?['energie'] as Json?;
        return PageCresco(
          titre: 'Progrès',
          onRefresh: vm.initialise,
          enfants: [
            if (vm.isBusy && d == null) const Chargement(),
            if (vm.hasError) MessageErreur(vm.modelError.toString(), reessayer: vm.initialise),
            if (d != null) ...[
              CrescoCarteSombre(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Surtitre('Verdict de la semaine', couleur: context.palette.lime),
                    const SizedBox(height: 10),
                    Text(
                      libellesVerdict[d['verdict']] ?? '',
                      style: CrescoTextes.titreCarte.copyWith(color: Colors.white, fontSize: 34),
                    ),
                    const SizedBox(height: 8),
                    Text(d['explication']! as String, style: const TextStyle(color: Colors.white, fontSize: 16)),
                  ],
                ),
              ),
              if (ex != null)
                CrescoCarte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Expanded(child: Surtitre('FORCE ESTIMÉE · e1RM', majuscules: false)),
                          Text('28 jours', style: context.mutedStyle),
                        ],
                      ),
                      const SizedBox(height: 6),
                      DropdownButton<int>(
                        value: vm.exercice.clamp(0, exercices.length - 1),
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        style: Theme.of(context).textTheme.titleLarge!
                            .copyWith(fontSize: 22, fontWeight: FontWeight.w800, color: context.palette.ink),
                        items: [
                          for (var i = 0; i < exercices.length; i++)
                            DropdownMenuItem(value: i, child: Text(exercices[i]['nom']! as String)),
                        ],
                        onChanged: (i) => vm.choisir(i ?? 0),
                      ),
                      Row(
                        children: [
                          Expanded(child: ChiffreUnite(decimal(ex['dernier']), 'kg')),
                          Text(
                            '${nombre(ex['pctParSemaine']) >= 0 ? '+' : ''}${decimal(ex['pctParSemaine'], chiffres: 2)} %/sem.',
                            style: context.mutedStyle,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      CourbeTendance(
                        valeurs: [for (final p in (ex['points']! as List).cast<Json>()) nombre(p['e1rm'])],
                      ),
                    ],
                  ),
                )
              else
                CrescoCarte(
                  child: Text(
                    'Enregistre quelques séances de musculation pour voir ta courbe de force.',
                    style: context.mutedStyle,
                  ),
                ),
              if (energie != null)
                CrescoCarte(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Surtitre('Bilan énergie estimé · 7 jours'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          ChiffreUnite(signe(nombre(energie['moyen7j']).round()), 'kcal/j'),
                          Pastille(
                            'Confiance ${energie['confiance']}',
                            fond: context.palette.warningSoft,
                            texteCouleur: context.palette.onWarningSoft,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: CrescoCarte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconeLibelle(
                            Icons.straighten,
                            'Poids lissé',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          ChiffreUnite(decimal(d['poidsLisse']), 'kg', taille: 34),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: CrescoCarte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const IconeLibelle(
                            Icons.bedtime_outlined,
                            'Sommeil moyen',
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(duree(d['sommeilMoyenMin']), style: CrescoTextes.chiffre.copyWith(fontSize: 34)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
