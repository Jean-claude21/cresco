import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ProfilViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final Session session = locator<Session>();
  final NavigationService _nav = locator<NavigationService>();
  final SnackbarService _snack = locator<SnackbarService>();

  Json? profil;
  String? jetonMcp;

  Future<void> charger() async {
    await runBusyFuture(Future(() async => profil = await _api.profil()));
  }

  Json get preferences => (profil?['preferences'] as Json?) ?? const {};

  Future<void> modifier(Json patch) async {
    try {
      profil = await _api.modifierProfil(patch);
    } on ErreurApi catch (e) {
      _snack.showSnackbar(message: e.message);
    }
    notifyListeners();
  }

  Future<void> modifierPreference(String cle, Object valeur) => modifier({
    'preferences': {cle: valeur},
  });

  /// Jeton pour brancher son IA (Claude Code, etc.) au serveur MCP. Montré une seule fois.
  Future<void> creerJetonMcp() async {
    final r = await _api.creerJeton('Assistant IA (MCP)', [
      'entrainement:lecture',
      'entrainement:ecriture',
      'nutrition:lecture',
      'nutrition:ecriture',
      'sommeil:lecture',
      'corps:lecture',
      'jeune:lecture',
    ]);
    jetonMcp = r['token'] as String?;
    notifyListeners();
  }

  Future<void> deconnecter() async {
    await session.deconnecter();
    await _nav.clearStackAndShow<void>(Routes.connexionView);
  }

  Future<void> supprimer() async {
    await _api.supprimerCompte();
    await _nav.clearStackAndShow<void>(Routes.connexionView);
  }
}

class ProfilView extends StatelessWidget {
  const new({super.key});

  static const _jours = ['Dim', 'Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam'];

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ProfilViewModel>.reactive(
      viewModelBuilder: ProfilViewModel.new,
      onViewModelReady: (vm) => vm.charger(),
      builder: (context, vm, _) {
        final p = vm.profil;
        final repos = ((vm.preferences['joursReposVerrouilles'] as List?) ?? const [])
            .cast<num>()
            .map((n) => n.toInt())
            .toSet();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Profil et réglages', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          body: p == null
              ? const Chargement()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
                  children: [
                    Text(p['nom'] as String? ?? '', style: CrescoTextes.titrePage),
                    Text(p['email']! as String, style: CrescoTextes.secondaire),
                    const SizedBox(height: 16),
                    CrescoCarte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Surtitre('Profil'),
                          const SizedBox(height: 8),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            expandedInsets: EdgeInsets.zero,
                            segments: const [
                              ButtonSegment(value: 'homme', label: Text('Homme')),
                              ButtonSegment(value: 'femme', label: Text('Femme')),
                            ],
                            selected: {p['sexe'] as String? ?? 'homme'},
                            onSelectionChanged: (s) => vm.modifier({'sexe': s.first}),
                          ),
                          const SizedBox(height: 10),
                          _ChampNombre(
                            libelle: 'Taille (cm)',
                            valeur: p['taille_cm'],
                            onChanged: (v) => vm.modifier({'taille_cm': v}),
                          ),
                          _ChampDate(
                            valeur: DateTime.tryParse(p['naissance'] as String? ?? ''),
                            onChanged: (d) => vm.modifier({'naissance': DateFormat('yyyy-MM-dd').format(d)}),
                          ),
                          const SizedBox(height: 16),
                          const Text('Niveau', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 6),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            expandedInsets: EdgeInsets.zero,
                            segments: const [
                              ButtonSegment(value: 'debutant', label: Text('Débutant')),
                              ButtonSegment(value: 'intermediaire', label: Text('Interm.')),
                              ButtonSegment(value: 'avance', label: Text('Avancé')),
                            ],
                            selected: {p['niveau']! as String},
                            onSelectionChanged: (s) => vm.modifier({'niveau': s.first}),
                          ),
                          const SizedBox(height: 10),
                          const Text('Objectif', style: TextStyle(fontWeight: FontWeight.w700)),
                          SegmentedButton<String>(
                            showSelectedIcon: false,
                            expandedInsets: EdgeInsets.zero,
                            segments: const [
                              ButtonSegment(value: 'perte', label: Text('Perte')),
                              ButtonSegment(value: 'maintien', label: Text('Maintien')),
                              ButtonSegment(value: 'prise', label: Text('Prise')),
                            ],
                            selected: {p['objectif']! as String},
                            onSelectionChanged: (s) => vm.modifier({'objectif': s.first}),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CrescoCarte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Surtitre('Jours de repos verrouillés'),
                          const SizedBox(height: 4),
                          const Text('Jamais remplis par le plan ni par l’IA.', style: CrescoTextes.secondaire),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            children: [
                              for (var j = 0; j < 7; j++)
                                FilterChip(
                                  label: Text(_jours[j]),
                                  selected: repos.contains(j),
                                  onSelected: (on) => vm.modifierPreference(
                                    'joursReposVerrouilles',
                                    (on ? ({...repos, j}) : (repos..remove(j))).toList()..sort(),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CrescoCarte(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Module foi', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text(
                              'Versets, intention et sens du jeûne. Donnée sensible, jamais partagée sans permission.',
                            ),
                            value: vm.preferences['moduleFoi'] == true,
                            onChanged: (v) => vm.modifierPreference('moduleFoi', v),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Priorité spirituelle', style: TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: const Text(
                              'Pendant un jeûne spirituel, proposer la version la plus légère de la séance.',
                            ),
                            value: vm.preferences['prioriteSpirituelle'] == true,
                            onChanged: vm.preferences['moduleFoi'] == true
                                ? (v) => vm.modifierPreference('prioriteSpirituelle', v)
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    CrescoCarte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Surtitre('Ton IA (MCP)'),
                          const SizedBox(height: 6),
                          Text('Serveur MCP : ${vm.session.api}/mcp', style: CrescoTextes.secondaire),
                          const SizedBox(height: 10),
                          if (vm.jetonMcp == null)
                            OutlinedButton(onPressed: vm.creerJetonMcp, child: const Text('Créer un jeton pour mon IA'))
                          else ...[
                            const Text(
                              'Copie ce jeton maintenant : il ne sera plus affiché.',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            SelectableText(vm.jetonMcp!, style: const TextStyle(fontFamily: 'monospace')),
                            TextButton.icon(
                              onPressed: () => Clipboard.setData(ClipboardData(text: vm.jetonMcp!)),
                              icon: const Icon(Icons.copy),
                              label: const Text('Copier'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    OutlinedButton(onPressed: vm.deconnecter, child: const Text('Se déconnecter')),
                    TextButton(
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Supprimer mon compte ?'),
                            content: const Text(
                              'Toutes tes données sont supprimées définitivement. Cette action est irréversible.',
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
                            ],
                          ),
                        );
                        if (ok ?? false) await vm.supprimer();
                      },
                      child: const Text('Supprimer mon compte', style: TextStyle(color: CrescoCouleurs.alerte)),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _ChampNombre extends StatelessWidget {
  const new({required this.libelle, required this.valeur, required this.onChanged});
  final String libelle;
  final Object? valeur;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: TextFormField(
        initialValue: valeur is num ? '${(valeur! as num).round()}' : '',
        decoration: InputDecoration(labelText: libelle),
        keyboardType: TextInputType.number,
        onFieldSubmitted: (t) {
          final v = double.tryParse(t.replaceAll(',', '.'));
          if (v != null) onChanged(v);
        },
      ),
    );
  }
}

/// Date de naissance : sélecteur natif plutôt qu'une saisie au format technique.
class _ChampDate extends StatelessWidget {
  const new({required this.valeur, required this.onChanged});
  final DateTime? valeur;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(CrescoMesures.rayonPetit),
        onTap: () async {
          final maintenant = DateTime.now();
          final choix = await showDatePicker(
            context: context,
            initialDate: valeur ?? DateTime(maintenant.year - 30),
            firstDate: DateTime(maintenant.year - 100),
            lastDate: DateTime(maintenant.year - 12),
            initialEntryMode: DatePickerEntryMode.calendarOnly,
            helpText: 'Date de naissance',
          );
          if (choix != null) onChanged(choix);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Date de naissance',
            suffixIcon: Icon(Icons.calendar_today_outlined),
          ),
          isEmpty: valeur == null,
          child: Text(valeur == null ? '' : DateFormat('d MMMM y', 'fr_FR').format(valeur!), style: CrescoTextes.corps),
        ),
      ),
    );
  }
}
