import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class AujourdhuiViewModel extends FutureViewModel<Json> {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();

  @override
  Future<Json> futureToRun() => _api.aujourdhui();

  Future<void> rafraichir() async {
    await initialise();
  }
}

/// Écran 1 (maquette 01-aujourdhui) : forme du jour, séance ajustée, énergie, jeûne.
class AujourdhuiView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<AujourdhuiViewModel>.reactive(
      viewModelBuilder: AujourdhuiViewModel.new,
      builder: (context, vm, _) {
        final d = vm.data;
        return PageCresco(
          titre: 'Aujourd’hui',
          onRefresh: vm.rafraichir,
          surTitre: Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              children: [
                const Icon(Icons.eco, color: CrescoCouleurs.pin),
                const SizedBox(width: 6),
                const Text(
                  'cresco',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: CrescoCouleurs.pin),
                ),
                const Spacer(),
                Text(DateFormat('EEE d MMMM', 'fr_FR').format(DateTime.now()), style: CrescoTextes.secondaire),
                const SizedBox(width: 44),
              ],
            ),
          ),
          enfants: [
            if (vm.isBusy && d == null) const Chargement(),
            if (vm.hasError) MessageErreur(vm.modelError.toString(), reessayer: vm.rafraichir),
            if (d != null) ...[
              _CarteForme(d['forme']! as Json),
              _CarteSeance(d['seance']! as Json, onOuvrir: () => vm.nav.navigateTo<void>(Routes.seanceView)),
              _CarteEnergie(d['energie']! as Json),
              _CarteJeune(d['jeune'] as Json?, onTap: () => vm.nav.navigateTo<void>(Routes.jeuneView)),
            ],
          ],
        );
      },
    );
  }
}

class _CarteForme extends StatelessWidget {
  const new(this.forme);
  final Json forme;

  @override
  Widget build(BuildContext context) {
    final c = forme['composantes']! as Json;
    final valeur = nombre(forme['valeur']);
    return CrescoCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Surtitre('Forme du jour')),
              Tooltip(
                message:
                    'Sommeil 35 %, VFC 25 %, FC repos 10 %, ressenti 20 %, fatigue 10 % (règle C-FORME). Confiance : ${forme['confiance']}.',
                child: const Icon(Icons.info_outline, color: CrescoCouleurs.texteSecondaire),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Anneau(
                fraction: valeur / 100,
                taille: 140,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entier(valeur), style: CrescoTextes.chiffre.copyWith(fontSize: 44)),
                    const Text('sur 100', style: CrescoTextes.secondaire),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    LigneMesure(icone: Icons.bedtime_outlined, libelle: 'Sommeil', valeur: duree(c['dormiMin'])),
                    const Divider(height: 1, color: CrescoCouleurs.filet),
                    LigneMesure(
                      icone: Icons.monitor_heart_outlined,
                      libelle: 'VFC',
                      valeur: c['vfc'] == null ? '—' : '${entier(c['vfc'])} ms',
                    ),
                    const Divider(height: 1, color: CrescoCouleurs.filet),
                    LigneMesure(
                      icone: Icons.sentiment_satisfied_alt,
                      libelle: 'Ressenti',
                      valeur: c['energie'] == null ? '—' : '${entier(c['energie'])} / 5',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CarteSeance extends StatelessWidget {
  const new(this.seance, {required this.onOuvrir});
  final Json seance;
  final VoidCallback onOuvrir;

  @override
  Widget build(BuildContext context) {
    final decision = seance['decision']! as Json;
    final code = decision['decision']! as String;
    final pasDeSeance = const {'ARRET', 'REPOS', 'REPOS_ACTIF'}.contains(code);
    final volume = nombre(decision['volume']);
    return CrescoCarteSombre(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.fitness_center, color: CrescoCouleurs.pousse, size: 20),
              SizedBox(width: 10),
              Surtitre('Séance du jour', couleur: CrescoCouleurs.pousse),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            pasDeSeance ? libellesDecision[code]! : seance['nom']! as String,
            style: CrescoTextes.titreCarte.copyWith(color: CrescoCouleurs.blanc, fontSize: 34),
          ),
          const SizedBox(height: 8),
          Text(
            [if (volume < 0 && !pasDeSeance) 'Volume ${signe((volume * 100).round())} %', seance['raison']].join(' · '),
            style: const TextStyle(color: CrescoCouleurs.blanc, fontSize: 16),
          ),
          if (!pasDeSeance) ...[
            const SizedBox(height: 18),
            Material(
              color: CrescoCouleurs.pousse,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onOuvrir,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Ouvrir la séance',
                        style: TextStyle(color: CrescoCouleurs.pinSombre, fontWeight: FontWeight.w800, fontSize: 17),
                      ),
                      SizedBox(width: 12),
                      Icon(Icons.arrow_forward, color: CrescoCouleurs.pinSombre),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarteEnergie extends StatelessWidget {
  const new(this.energie);
  final Json energie;

  @override
  Widget build(BuildContext context) {
    final jour = energie['jour']! as Json;
    final cibles = energie['cibles'] as Json?;
    if (energie['ciblesSuspendues'] == true || cibles == null) {
      return const CrescoCarte(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Surtitre('Énergie du jour'),
            SizedBox(height: 10),
            Text('Cibles suspendues pendant le jeûne', style: CrescoTextes.titreCarte),
            SizedBox(height: 6),
            Text('Aucune invitation à manger tant que ton jeûne est en cours.', style: CrescoTextes.secondaire),
          ],
        ),
      );
    }
    final kcalCible = nombre(cibles['kcal']);
    final kcal = nombre(jour['kcal']);
    final prot = nombre(jour['proteines']);
    final protCible = nombre(cibles['proteines']);
    return CrescoCarte(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: Surtitre('Énergie du jour')),
              Text('${entier(kcal)} / ${entier(kcalCible)} kcal', style: CrescoTextes.secondaire),
            ],
          ),
          const SizedBox(height: 10),
          ChiffreUnite(entier((kcalCible - kcal).clamp(0, 99999)), 'kcal restantes'),
          const SizedBox(height: 14),
          BarreProgres(valeur: kcalCible > 0 ? kcal / kcalCible : 0),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1, color: CrescoCouleurs.filet),
          ),
          Row(
            children: [
              const Expanded(
                child: Text('Protéines', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
              ),
              Text(
                '${entier(prot)} / ${entier(protCible)} g',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ],
          ),
          const SizedBox(height: 10),
          BarreProgres(valeur: protCible > 0 ? prot / protCible : 0, couleur: CrescoCouleurs.eucalyptus),
        ],
      ),
    );
  }
}

class _CarteJeune extends StatelessWidget {
  const new(this.jeune, {required this.onTap});
  final Json? jeune;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final j = jeune?['jeune'] as Json?;
    return CrescoCarte(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 26,
            backgroundColor: CrescoCouleurs.sauge,
            child: Icon(Icons.nightlight_round, color: CrescoCouleurs.pin),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  j == null ? 'Suivi du jeûne' : 'Jeûne en cours · ${duree(nombre(j['heures']) * 60)}',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                Text(
                  j == null ? 'Aucun jeûne en cours' : libellesPhase[j['phase']] ?? '',
                  style: CrescoTextes.secondaire,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
