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
        return PageCresco(
          titre: 'Nutrition',
          onRefresh: vm.charger,
          enfants: [
            if (vm.erreur != null) MessageErreur(vm.erreur!, reessayer: vm.charger),
            if (e != null) _TodaySummary(energy: e),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recherche,
                    decoration: const InputDecoration(hintText: 'Chercher un aliment', prefixIcon: Icon(Icons.search)),
                    onChanged: (_) => setState(() {}),
                    onSubmitted: vm.chercher,
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: context.palette.action,
                    foregroundColor: context.palette.onAction,
                    fixedSize: const Size(56, 56),
                  ),
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
                        icon: Icon(Icons.add_box, color: context.palette.effort),
                        onPressed: () => _portion(
                          context,
                          a['nom']! as String,
                          (m) => vm.ajouterPortion(alimentId: a['id']! as String, masse: m),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_recherche.text.length >= 2)
              OutlinedButton.icon(
                onPressed: () => _creerAliment(context, vm),
                icon: const Icon(Icons.add),
                label: const Text('Créer cet aliment'),
              ),
            if (_panier.isNotEmpty)
              CrescoCarte(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Plat en préparation', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
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
                'Compose un plat avec tes ingrédients, ou demande à ton assistant IA de l’ajouter via le MCP : '
                'le moteur calcule les nutriments.',
                style: context.mutedStyle,
              )
            else
              _DishGrid(
                dishes: vm.plats,
                onAdd: (p) => _portion(
                  context,
                  p['nom']! as String,
                  (m) => vm.ajouterPortion(platId: p['id']! as String, masse: m),
                ),
              ),
            if (e?['bilan'] != null) _WeekSummary(energy: e!),
            Text('Données produits : Open Food Facts (ODbL).', style: context.mutedStyle.copyWith(fontSize: 12)),
          ],
        );
      },
    );
  }

  /// Bottom sheet "name · grams − +" with the black "Ajouter au repas" button (mockup G).
  Future<void> _portion(BuildContext context, String name, Future<void> Function(double grams) add) async {
    final grams = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => _PortionSheet(name: name),
    );
    if (grams != null) await add(grams);
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

/// Today's remaining energy and protein, from the engine's targets.
class _TodaySummary extends StatelessWidget {
  const new({required this.energy});
  final Json energy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final targets = energy['cibles'] as Json?;
    final day = energy['jour'] as Json? ?? const {};
    if (targets == null || energy['ciblesSuspendues'] == true) {
      return CrescoCarte(
        padding: const EdgeInsets.all(14),
        child: Text(
          'Cibles suspendues pendant le jeûne.',
          style: TextStyle(color: p.ink, fontWeight: FontWeight.w700),
        ),
      );
    }
    final left = (nombre(targets['kcal']) - nombre(day['kcal'])).clamp(0, 99999);
    return DecoratedBox(
      decoration: CrescoShape.outlined(p, fill: p.effortSoft, outline: p.effort.withValues(alpha: 0.35)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${entier(left)} kcal',
                style: TextStyle(color: p.onEffortSoft, fontWeight: FontWeight.w900),
              ),
              TextSpan(text: ' restantes · protéines ${entier(day['proteines'])} / ${entier(targets['proteines'])} g'),
            ],
          ),
          style: TextStyle(color: p.ink, fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// "Mes plats" as a two-column grid of tiles with a braise "+".
class _DishGrid extends StatelessWidget {
  const new({required this.dishes, required this.onAdd});
  final List<Json> dishes;
  final ValueChanged<Json> onAdd;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, box) {
        final columns = box.maxWidth >= 320 && MediaQuery.textScalerOf(context).scale(10) <= 11.5 ? 2 : 1;
        final width = (box.maxWidth - (columns - 1) * 10) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final d in dishes)
              SizedBox(
                width: width,
                child: Material(
                  color: p.surface,
                  shape: CrescoShape.rectangle(p.line),
                  child: InkWell(
                    customBorder: CrescoShape.rectangle(),
                    onTap: () => onAdd(d),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const ShortcutIconImage(ShortcutIcon.repas, size: 48),
                              const Spacer(),
                              Semantics(
                                button: true,
                                label: 'Manger une portion de ${d['nom']}',
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(color: p.effort, borderRadius: CrescoShape.borderRadius),
                                  child: Icon(Icons.add, color: p.onEffort, size: 20),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(d['nom']! as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(
                            [
                              '${entier((d['nutriments']! as Json)['kcal100'])} kcal / 100 g',
                              if ((d['nutriments']! as Json)['proteines100'] is num)
                                '${decimal((d['nutriments']! as Json)['proteines100'])} g prot.',
                              if (d['cree_par'] == 'ia') 'ajouté par ton IA',
                            ].join(' · '),
                            style: context.mutedStyle.copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Seven-day energy summary, estimated by the engine (C-ENERGIE).
class _WeekSummary extends StatelessWidget {
  const new({required this.energy});
  final Json energy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final summary = energy['bilan']! as Json;
    return CrescoCarte(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bilan estimé · 7 jours', style: context.mutedStyle.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ChiffreUnite(signe(nombre(summary['moyen7j']).round()), 'kcal/j', taille: 34),
              Pastille('Confiance ${summary['confiance'] ?? ''}', fond: p.warningSoft, texteCouleur: p.onWarningSoft),
            ],
          ),
          const SizedBox(height: 6),
          Text(switch (summary['verdict']) {
            'deficit' => 'Déficit',
            'surplus' => 'Surplus',
            _ => 'Maintien',
          }, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          Text(
            'Dépense ${energy['source'] == 'adaptatif' ? 'mesurée' : 'estimée'} : ${entier(energy['tdee'])} kcal/j'
            '${energy['sousSaisie'] == true ? ' · saisie probablement incomplète' : ''}',
            style: context.mutedStyle,
          ),
        ],
      ),
    );
  }
}

/// Grams of one portion, by steps of 25 g.
class _PortionSheet extends StatefulWidget {
  const new({required this.name});
  final String name;

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  double grams = 200;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 0, CrescoSpacing.margin, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(widget.name, style: CrescoTextes.titreCarte.copyWith(fontSize: 22))),
                DecoratedBox(
                  decoration: CrescoShape.outlined(p, fill: p.background, outline: p.ink),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Moins 25 g',
                        onPressed: grams > 25 ? () => setState(() => grams -= 25) : null,
                        icon: const Icon(Icons.remove),
                      ),
                      Text('${entier(grams)} g', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      IconButton(
                        tooltip: 'Plus 25 g',
                        onPressed: grams < 1500 ? () => setState(() => grams += 25) : null,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(context, grams), child: const Text('Ajouter au repas')),
          ],
        ),
      ),
    );
  }
}
