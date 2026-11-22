import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_engine/cresco_engine.dart' as moteur;
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

  /// Sets how many servings dish [id] makes, then refreshes "Mes plats".
  Future<Json?> setDishPortions(String id, num portions) async {
    try {
      final updated = await _api.setDishPortions(id, portions);
      plats = [
        for (final d in plats)
          if (d['id'] == id) updated else d,
      ];
      notifyListeners();
      return updated;
    } on ErreurApi catch (e) {
      _snack.afficher(message: e.message);
      return null;
    }
  }

  Future<void> ajouterPortion({required double masse, String? alimentId, String? platId}) async {
    await _api.ajouterRepas({
      'type': mealOf(maintenant()).$1,
      'portions': [
        {'alimentId': ?alimentId, 'platId': ?platId, 'masse': masse},
      ],
    });
    _snack.afficher(message: 'Ajouté au ${mealOf(maintenant()).$2}', duration: const Duration(seconds: 2));
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

/// Meal of the moment: API type and the French label used in "Ajouter au …".
(String, String) mealOf(DateTime now) => switch (now.hour) {
  < 10 => ('petit_dejeuner', 'petit-déjeuner'),
  < 15 => ('dejeuner', 'déjeuner'),
  < 18 => ('collation', 'goûter'),
  _ => ('diner', 'dîner'),
};

/// Filters of "Mes plats": tag stored on the dish, and its label.
const dishFilters = [
  ('proteines', 'Riche en protéines'),
  ('rapide', 'Rapide'),
  ('vegetarien', 'Végétarien'),
  ('daniel', 'Jeûne Daniel'),
];

class NutritionView extends StatefulWidget {
  const new({super.key});
  @override
  State<NutritionView> createState() => _NutritionViewState();
}

class _NutritionViewState extends State<NutritionView> {
  final _recherche = TextEditingController();
  final _panier = <(Json, double)>[];
  final _filters = <String>{};

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
        final query = _recherche.text.trim().toLowerCase();
        final dishes = [
          for (final d in vm.plats)
            if ((query.isEmpty || (d['nom']! as String).toLowerCase().contains(query)) &&
                _filters.every(((d['tags'] as List<Object?>?) ?? const []).contains))
              d,
        ];
        return PageCresco(
          titre: 'Mes plats',
          onRefresh: vm.charger,
          surTitre: const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Nutrition', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          ),
          enfants: [
            if (vm.erreur != null) MessageErreur(vm.erreur!, reessayer: vm.charger),
            if (e != null) _TodaySummary(energy: e),
            TextField(
              controller: _recherche,
              decoration: InputDecoration(
                hintText: 'Qu’est-ce que tu as dans ton frigo ?',
                hintStyle: TextStyle(fontSize: 15, color: context.palette.ink),
                fillColor: context.palette.background,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Scanner un code-barres',
                  onPressed: () async {
                    await vm.nav.navigateTo<void>(Routes.scanView);
                    await vm.charger();
                  },
                  icon: const Icon(Icons.qr_code_scanner),
                ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              onSubmitted: vm.chercher,
            ),
            _Filters(
              selected: _filters,
              onToggle: (tag) => setState(() => _filters.contains(tag) ? _filters.remove(tag) : _filters.add(tag)),
            ),
            if (vm.plats.isEmpty)
              Text(
                'Compose un plat avec tes ingrédients, ou demande à ton assistant IA de l’ajouter via le MCP : '
                'le moteur calcule les nutriments.',
                style: context.mutedStyle,
              )
            else if (dishes.isEmpty)
              Text('Aucun plat ne correspond. Retire un filtre ou cherche un aliment.', style: context.mutedStyle)
            else
              _DishGrid(
                dishes: dishes,
                onAdd: (d) => _portion(
                  context,
                  d['nom']! as String,
                  (m) => vm.ajouterPortion(platId: d['id']! as String, masse: m),
                  nutrients: d['nutriments'] as Json? ?? const {},
                  dish: d,
                  vm: vm,
                ),
              ),
            if (vm.resultats.isNotEmpty) const Text('Aliments', style: CrescoTextes.titreCarte),
            for (final a in vm.resultats)
              CrescoCarte(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(a['nom']! as String, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    '${entier(a['kcal100'])} kcal · ${decimal(a['proteines100'])} g prot. / 100 g'
                    '${a['source_attribution'] == null ? '' : ' · ${a['source_attribution']}'}',
                  ),
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
                          nutrients: a,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (query.length >= 2 && vm.resultats.isEmpty)
              OutlinedButton(
                onPressed: () => vm.chercher(_recherche.text),
                child: const Text('Chercher dans les aliments'),
              ),
            if (query.length >= 2)
              TextButton(onPressed: () => _creerAliment(context, vm), child: const Text('Créer cet aliment')),
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
            Text('Données produits : Open Food Facts (ODbL).', style: context.mutedStyle.copyWith(fontSize: 12)),
          ],
        );
      },
    );
  }

  /// Bottom panel of mockup G: what is eaten (servings of a dish, or grams of a food), its kcal,
  /// then the black "Ajouter au …" button.
  Future<void> _portion(
    BuildContext context,
    String name,
    Future<void> Function(double grams) add, {
    required Json nutrients,
    Json? dish,
    NutritionViewModel? vm,
  }) async {
    final grams = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _PortionSheet(name: name, nutrients: nutrients, dish: dish, vm: vm),
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
    final text = targets == null || energy['ciblesSuspendues'] == true
        ? 'Cibles suspendues pendant le jeûne'
        : '${entier((nombre(targets['kcal']) - nombre(day['kcal'])).clamp(0, 99999))} kcal restantes · '
              'protéines ${entier(day['proteines'])} / ${entier(targets['proteines'])} g';
    return DecoratedBox(
      decoration: CrescoShape.outlined(p, fill: p.effortSoft, outline: Colors.transparent),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

/// The four filter buttons in a 2 × 2 grid, outlined, filled once selected.
class _Filters extends StatelessWidget {
  const new({required this.selected, required this.onToggle});
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget button(String tag, String label) {
      final on = selected.contains(tag);
      return Expanded(
        child: Semantics(
          selected: on,
          child: OutlinedButton(
            key: ValueKey('filter-$tag'),
            onPressed: () => onToggle(tag),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 40),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              backgroundColor: on ? p.action : null,
              foregroundColor: on ? p.onAction : p.ink,
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            child: FittedBox(child: Text(label)),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              button(dishFilters[r * 2].$1, dishFilters[r * 2].$2),
              const SizedBox(width: 12),
              button(dishFilters[r * 2 + 1].$1, dishFilters[r * 2 + 1].$2),
            ],
          ),
        ],
      ],
    );
  }
}

/// "Mes plats" as a two-column grid: photo, braise "+", name, kcal and protein per 100 g.
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
        final width = (box.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final d in dishes)
              SizedBox(
                width: width,
                child: Material(
                  color: p.surface,
                  shape: CrescoShape.rectangle(p.line),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onAdd(d),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            DishPhoto(d['nom']! as String, height: width * 0.62),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Semantics(
                                button: true,
                                label: 'Ajouter ${d['nom']}',
                                child: Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(color: p.effort, borderRadius: CrescoShape.borderRadius),
                                  child: Icon(Icons.add, color: p.onEffort, size: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['nom']! as String,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  '${entier((d['nutriments']! as Json)['kcal100'])} kcal',
                                  if ((d['nutriments']! as Json)['proteines100'] is num)
                                    '${decimal((d['nutriments']! as Json)['proteines100'])} g prot.',
                                ].join(' · '),
                                style: context.mutedStyle.copyWith(fontSize: 15),
                              ),
                              Text('pour 100 g', style: context.mutedStyle.copyWith(fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
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

/// What is eaten: half servings of a dish (mass of one serving from the engine), or grams of a
/// food by steps of 25 g. The kcal shown come from the engine too (C-ENERGIE-9).
class _PortionSheet extends StatefulWidget {
  const new({required this.name, required this.nutrients, this.dish, this.vm});
  final String name;
  final Json nutrients;
  final Json? dish;
  final NutritionViewModel? vm;

  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late Json? dish = widget.dish;
  double servings = 1;
  double grams = 150;

  double? get _servingMass => (dish?['massePortion'] as num?)?.toDouble();
  bool get _byServing => _servingMass != null;

  Json get _eaten => moteur.portion({
    'kcal100': widget.nutrients['kcal100'] ?? 0,
    'proteines100': widget.nutrients['proteines100'] ?? 0,
    if (_byServing) ...{'massePortion': _servingMass, 'portions': servings} else 'masse': grams,
  });

  String get _servingsLabel {
    final n = servings == servings.roundToDouble() ? entier(servings) : decimal(servings);
    return '$n portion${servings > 1 ? 's' : ''}';
  }

  Future<void> _editServings() async {
    final d = dish;
    final vm = widget.vm;
    if (d == null || vm == null) return;
    var n = ((d['portions'] as num?) ?? 1).toDouble();
    final chosen = await showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('Ce plat fait'),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Une portion de moins',
                onPressed: n > 1 ? () => setLocal(() => n--) : null,
                icon: const Icon(Icons.remove),
              ),
              Text('${entier(n)} portion${n > 1 ? 's' : ''}', style: CrescoTextes.titreCarte),
              IconButton(
                tooltip: 'Une portion de plus',
                onPressed: n < 50 ? () => setLocal(() => n++) : null,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(context, n), child: const Text('Enregistrer')),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    final updated = await vm.setDishPortions(d['id']! as String, chosen);
    if (updated != null && mounted) setState(() => dish = updated);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final eaten = _eaten;
    final mass = nombre(eaten['masse']);
    final made = ((dish?['portions'] as num?) ?? 1).toDouble();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 0, CrescoSpacing.margin, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.name, style: CrescoTextes.titreCarte.copyWith(fontSize: 22)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _byServing ? _servingsLabel : '${entier(grams)} g',
                        style: TextStyle(color: p.ink, fontSize: 17, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${_byServing ? '${entier(mass)} g · ' : ''}${entier(eaten['kcal'])} kcal · '
                        '${decimal(eaten['proteines'])} g de protéines',
                        style: context.mutedStyle,
                      ),
                    ],
                  ),
                ),
                DecoratedBox(
                  decoration: CrescoShape.outlined(p, fill: p.background, outline: p.ink),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: _byServing ? 'Une demi-portion de moins' : 'Moins 25 g',
                        onPressed: _byServing
                            ? (servings > 0.5 ? () => setState(() => servings -= 0.5) : null)
                            : (grams > 25 ? () => setState(() => grams -= 25) : null),
                        icon: const Icon(Icons.remove),
                      ),
                      IconButton(
                        tooltip: _byServing ? 'Une demi-portion de plus' : 'Plus 25 g',
                        onPressed: _byServing
                            ? (servings < 6 ? () => setState(() => servings += 0.5) : null)
                            : (grams < 1500 ? () => setState(() => grams += 25) : null),
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (dish != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('plat-portions'),
                  onPressed: _editServings,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Text(
                    'Le plat entier fait ${entier(made)} portion${made > 1 ? 's' : ''}',
                    style: const TextStyle(decoration: TextDecoration.underline),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, mass),
              child: Text('Ajouter au ${mealOf(maintenant()).$2}'),
            ),
          ],
        ),
      ),
    );
  }
}
