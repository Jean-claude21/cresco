import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class NutritionViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();
  final Messages _snack = locator<Messages>();

  Json? energie;
  List<Json> plats = [];
  List<Json> resultats = [];
  String? erreur;

  Future<void> charger() async {
    await runBusyFuture(
      Future(() async {
        try {
          energie = await _api.energie();
          plats = await _api.plats();
          erreur = null;
        } on ErreurApi catch (e) {
          erreur = e.message;
        }
      }),
    );
  }

  Future<void> chercher(String q) async {
    if (q.trim().length < 2) return;
    try {
      resultats = await _api.chercherAliments(q.trim());
    } on ErreurApi catch (e) {
      _snack.afficher(message: e.message);
    }
    notifyListeners();
  }

  Future<void> ajouterPortion({required double masse, String? alimentId, String? platId}) async {
    await _api.ajouterRepas({
      'type': 'repas',
      'portions': [
        {'alimentId': ?alimentId, 'platId': ?platId, 'masse': masse},
      ],
    });
    _snack.afficher(message: 'Repas ajouté', duration: const Duration(seconds: 2));
    resultats = [];
    await charger();
  }

  Future<void> creerAliment(Json aliment) async {
    final a = await _api.creerAliment(aliment);
    resultats = [a, ...resultats];
    notifyListeners();
  }

  Future<void> creerPlat(String nom, List<(Json, double)> ingredients, double? masseCuite) async {
    try {
      await _api.creerPlat({
        'nom': nom,
        'ingredients': [
          for (final (a, m) in ingredients) {'alimentId': a['id'], 'masse': m},
        ],
        'masseCuite': ?masseCuite,
      });
      await charger();
    } on ErreurApi catch (e) {
      _snack.afficher(message: e.message);
    }
  }
}

class NutritionView extends StatefulWidget {
  const new({super.key});
  @override
  State<NutritionView> createState() => _NutritionViewState();
}

class _NutritionViewState extends State<NutritionView> {
  final _recherche = TextEditingController();
  final _panier = <(Json, double)>[];

  @override
  void dispose() {
    _recherche.dispose();
    super.dispose();
  }

  Future<double?> _demanderMasse(BuildContext context, String nom) async {
    final c = TextEditingController(text: '100');
    return await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(nom),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(suffixText: 'g'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
          TextButton(
            onPressed: () => Navigator.pop(context, double.tryParse(c.text.replaceAll(',', '.'))),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<NutritionViewModel>.reactive(
      viewModelBuilder: NutritionViewModel.new,
      onViewModelReady: (vm) => vm.charger(),
      builder: (context, vm, _) {
        final e = vm.energie;
        final cibles = e?['cibles'] as Json?;
        final bilan = e?['bilan'] as Json?;
        return PageCresco(
          titre: 'Nutrition',
          onRefresh: vm.charger,
          enfants: [
            if (vm.erreur != null) MessageErreur(vm.erreur!, reessayer: vm.charger),
            if (e != null)
              CrescoCarte(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Surtitre('Bilan estimé · 7 jours'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ChiffreUnite(signe(nombre(bilan?['moyen7j']).round()), 'kcal/j'),
                        Pastille(
                          'Confiance ${bilan?['confiance'] ?? ''}',
                          fond: context.palette.warningSoft,
                          texteCouleur: context.palette.onWarningSoft,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(switch (bilan?['verdict']) {
                      'deficit' => 'Déficit',
                      'surplus' => 'Surplus',
                      _ => 'Maintien',
                    }, style: TextStyle(fontWeight: FontWeight.w800, color: context.palette.ink, fontSize: 17)),
                    Text(
                      'Dépense ${e['source'] == 'adaptatif' ? 'mesurée' : 'estimée'} : ${entier(e['tdee'])} kcal/j'
                      '${e['sousSaisie'] == true ? ' · saisie probablement incomplète' : ''}',
                      style: context.mutedStyle,
                    ),
                    if (cibles != null) ...[
                      Divider(height: 26, color: context.palette.line),
                      LigneMesure(
                        icone: Icons.local_fire_department_outlined,
                        libelle: 'Cible',
                        valeur: '${entier(cibles['kcal'])} kcal',
                      ),
                      LigneMesure(
                        icone: Icons.egg_outlined,
                        libelle: 'Protéines',
                        valeur: '${entier(cibles['proteines'])} g',
                      ),
                      LigneMesure(
                        icone: Icons.water_drop_outlined,
                        libelle: 'Lipides',
                        valeur: '${entier(cibles['lipides'])} g',
                      ),
                      LigneMesure(icone: Icons.grain, libelle: 'Glucides', valeur: '${entier(cibles['glucides'])} g'),
                    ] else
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text('Cibles suspendues pendant le jeûne.', style: context.mutedStyle),
                      ),
                  ],
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recherche,
                    decoration: const InputDecoration(hintText: 'Chercher un aliment', prefixIcon: Icon(Icons.search)),
                    onSubmitted: vm.chercher,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(backgroundColor: context.palette.action, minimumSize: const Size(56, 56)),
                  tooltip: 'Scanner un code-barres',
                  onPressed: () async {
                    await vm.nav.navigateTo<void>(Routes.scanView);
                    await vm.charger();
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ],
            ),
            for (final a in vm.resultats)
              CrescoCarte(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a['nom']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${entier(a['kcal100'])} kcal · ${decimal(a['proteines100'])} g prot. / 100 g'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Ajouter au plat en cours',
                        icon: const Icon(Icons.playlist_add),
                        onPressed: () async {
                          final m = await _demanderMasse(context, 'Masse crue dans le plat');
                          if (m != null) setState(() => _panier.add((a, m)));
                        },
                      ),
                      IconButton(
                        tooltip: 'Manger maintenant',
                        icon: Icon(Icons.add_circle, color: context.palette.ink),
                        onPressed: () async {
                          final m = await _demanderMasse(context, a['nom']! as String);
                          if (m != null) await vm.ajouterPortion(alimentId: a['id']! as String, masse: m);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            if (_recherche.text.length >= 2)
              TextButton.icon(
                onPressed: () => _creerAliment(context, vm),
                icon: const Icon(Icons.add),
                label: const Text('Créer cet aliment'),
              ),
            if (_panier.isNotEmpty)
              CrescoCarte(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Surtitre('Plat en préparation'),
                    for (final (a, m) in _panier) Text('${a['nom']} · ${entier(m)} g'),
                    const SizedBox(height: 10),
                    FilledButton(
                      onPressed: () => _enregistrerPlat(context, vm),
                      child: const Text('Enregistrer dans Mes plats'),
                    ),
                  ],
                ),
              ),
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Mes plats', style: CrescoTextes.titreCarte),
            ),
            if (vm.plats.isEmpty)
              Text(
                'Compose un plat avec tes ingrédients, ou demande à ton assistant IA de l’ajouter via le MCP : le moteur calcule les nutriments.',
                style: context.mutedStyle,
              ),
            for (final p in vm.plats)
              CrescoCarte(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(p['nom']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${entier((p['nutriments']! as Json)['kcal100'])} kcal / 100 g'
                    '${p['cree_par'] == 'ia' ? ' · ajouté par ton IA' : ''}',
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.add_circle, color: context.palette.ink),
                    tooltip: 'Manger une portion',
                    onPressed: () async {
                      final m = await _demanderMasse(context, p['nom']! as String);
                      if (m != null) await vm.ajouterPortion(platId: p['id']! as String, masse: m);
                    },
                  ),
                ),
              ),
            Text('Données produits : Open Food Facts (ODbL).', style: context.mutedStyle),
          ],
        );
      },
    );
  }

  Future<void> _creerAliment(BuildContext context, NutritionViewModel vm) async {
    final champs = {
      for (final k in ['kcal100', 'proteines100', 'glucides100', 'lipides100']) k: TextEditingController(),
    };
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_recherche.text),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in champs.entries)
              TextField(
                controller: e.value,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      '${{'kcal100': 'kcal', 'proteines100': 'Protéines', 'glucides100': 'Glucides', 'lipides100': 'Lipides'}[e.key]} pour 100 g',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Créer')),
        ],
      ),
    );
    if (ok != true) return;
    await vm.creerAliment({
      'nom': _recherche.text.trim(),
      for (final e in champs.entries) e.key: double.tryParse(e.value.text.replaceAll(',', '.')) ?? 0,
    });
  }

  Future<void> _enregistrerPlat(BuildContext context, NutritionViewModel vm) async {
    final nom = TextEditingController();
    final cuit = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nouveau plat'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nom,
              decoration: const InputDecoration(labelText: 'Nom du plat'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: cuit,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Masse cuite totale (g, facultatif)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    );
    if (ok != true || nom.text.trim().isEmpty) return;
    await vm.creerPlat(nom.text.trim(), List.of(_panier), double.tryParse(cuit.text));
    setState(_panier.clear);
  }
}
