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
              _VerdictCard(verdict: d['verdict'] as String?, explanation: d['explication']! as String),
              if (ex != null)
                CrescoCarte(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DropdownButton<int>(
                        value: vm.exercice.clamp(0, exercices.length - 1),
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        style: CrescoTextes.titreCarte.copyWith(fontSize: 22, color: context.palette.ink),
                        items: [
                          for (var i = 0; i < exercices.length; i++)
                            DropdownMenuItem(value: i, child: Text(exercices[i]['nom']! as String)),
                        ],
                        onChanged: (i) => vm.choisir(i ?? 0),
                      ),
                      Text('e1RM · 28 jours', style: context.mutedStyle),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          ChiffreUnite(decimal(ex['dernier']), 'kg', taille: 40),
                          Text(
                            '${nombre(ex['pctParSemaine']) >= 0 ? '+' : ''}'
                            '${decimal(ex['pctParSemaine'], chiffres: 2)} % / semaine',
                            style: TextStyle(
                              color: nombre(ex['pctParSemaine']) >= 0 ? context.palette.effort : context.palette.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
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
                _InfoRow(
                  icon: Icons.bolt_outlined,
                  title: 'Bilan énergie · 7 jours',
                  value: '${signe(nombre(energie['moyen7j']).round())} kcal/j',
                  detail: 'estimé, confiance ${energie['confiance']}',
                ),
              _InfoRow(
                icon: Icons.monitor_weight_outlined,
                title: 'Poids lissé',
                value: '${decimal(d['poidsLisse'])} kg',
              ),
              _InfoRow(icon: Icons.bedtime_outlined, title: 'Sommeil moyen', value: duree(d['sommeilMoyenMin'])),
              OutlinedButton(onPressed: () => _explain(context), child: const Text('Comment c’est calculé')),
            ],
          ],
        );
      },
    );
  }
}

Future<void> _explain(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Comment c’est calculé', style: CrescoTextes.titreCarte),
          const SizedBox(height: 12),
          const Text(
            'Force estimée : e1RM de tes meilleures séries (règle C-PERF-2), tendance sur 28 jours (C-PROG-1). '
            'Verdict de la semaine : progression comparée au rythme attendu pour ton niveau, en tenant compte '
            'du sommeil, de l’énergie et des jeûnes (C-VERDICT).',
            style: CrescoTextes.corps,
          ),
          const SizedBox(height: 10),
          Text('Toutes les formules sont dans le moteur ; ton IA peut les lire par le MCP.', style: context.mutedStyle),
        ],
      ),
    ),
  ),
);

/// Week verdict: big title, a braise arrow when you progress, and its cause.
class _VerdictCard extends StatelessWidget {
  const new({required this.verdict, required this.explanation});
  final String? verdict;
  final String explanation;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return CrescoCarte(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Verdict de la semaine', style: context.mutedStyle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Flexible(
                child: Text(libellesVerdict[verdict] ?? '', style: CrescoTextes.titrePage.copyWith(fontSize: 30)),
              ),
              if (verdict == 'progression') ...[
                const SizedBox(width: 8),
                Icon(Icons.north_east, color: p.effort, size: 30),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(explanation, style: const TextStyle(fontSize: 15, height: 1.4)),
        ],
      ),
    );
  }
}

/// "Icon · title · value" row of the week summary.
class _InfoRow extends StatelessWidget {
  const new({required this.icon, required this.title, required this.value, this.detail});
  final IconData icon;
  final String title;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return CrescoCarte(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, color: context.palette.ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                if (detail != null) Text(detail!, style: context.mutedStyle),
              ],
            ),
          ),
          Text(value, style: CrescoTextes.chiffre.copyWith(fontSize: 22)),
        ],
      ),
    );
  }
}
