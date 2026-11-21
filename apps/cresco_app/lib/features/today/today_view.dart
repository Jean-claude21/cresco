import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class TodayViewModel extends FutureViewModel<Json> {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();

  @override
  Future<Json> futureToRun() => _api.aujourdhui();

  Future<void> refresh() => initialise();

  /// Opens [route], then reloads: a finished session or fast changes today's numbers.
  Future<void> open(String route) async {
    await nav.navigateTo<void>(route);
    await refresh();
  }
}

/// Today (mockup "Aujourd’hui"): form score, today's session, energy, fasting, body map.
class TodayView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TodayViewModel>.reactive(
      viewModelBuilder: TodayViewModel.new,
      builder: (context, vm, _) {
        final d = vm.data;
        final cards = <Widget>[
          if (d != null) ...[
            _FormCard(d['forme']! as Json),
            _SessionCard(d['seance']! as Json, onOpen: () => vm.open(Routes.seanceView)),
            _EnergyAndFast(
              energy: d['energie']! as Json,
              fast: d['jeune'] as Json?,
              onFast: () => vm.open(Routes.jeuneView),
            ),
            _BodyCard(onTap: () => vm.open(Routes.bodyMapView)),
          ],
        ];
        return PageCresco(
          titre: 'Les jours forts font les résultats.',
          onRefresh: vm.refresh,
          surTitre: _Header(onProfile: () => vm.open(Routes.profilView)),
          enfants: [
            if (vm.isBusy && d == null) const Chargement(),
            if (vm.hasError && d == null) MessageErreur('Ta journée n’a pas pu se charger.', reessayer: vm.refresh),
            for (final (i, c) in cards.indexed) FadeSlideIn(index: i, child: c),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const new({required this.onProfile});
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final date = DateFormat('EEEE d MMMM', 'fr_FR').format(maintenant());
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${date[0].toUpperCase()}${date.substring(1)}',
              style: TextStyle(color: p.muted, fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton.filled(
            tooltip: 'Profil et réglages',
            onPressed: onProfile,
            style: IconButton.styleFrom(
              backgroundColor: p.surface,
              foregroundColor: p.ink,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.person_outline),
          ),
        ],
      ),
    );
  }
}

/// Black hero card: form score ring, its inputs, and how it is computed.
class _FormCard extends StatelessWidget {
  const new(this.form);
  final Json form;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = form['composantes']! as Json;
    final value = nombre(form['valeur']);
    final inputs = [
      'Sommeil ${duree(c['dormiMin'])}',
      if (c['vfc'] != null) 'VFC ${entier(c['vfc'])} ms',
      if (c['energie'] != null) 'ressenti ${entier(c['energie'])}/5',
    ].join(' · ');
    return _Card(
      color: p.hero,
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ScoreRing(
            fraction: value / 100,
            child: Semantics(
              label: 'Forme ${entier(value)} sur 100',
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(entier(value), style: CrescoTextes.chiffre.copyWith(color: Colors.white, fontSize: 34)),
                    Text('forme', style: TextStyle(color: p.onHeroMuted, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 150, maxWidth: 190),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FORME DU JOUR', style: context.overlineStyle.copyWith(color: p.lime)),
                const SizedBox(height: 6),
                Text(inputs, style: TextStyle(color: p.onHeroMuted, fontSize: 14, height: 1.4)),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => _explain(context),
                  style: TextButton.styleFrom(
                    foregroundColor: p.lime,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 44),
                    textStyle: Theme.of(context).textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800, fontSize: 14),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(child: Text('Comment c’est calculé')),
                      Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _explain(BuildContext context) {
    final confidence = form['confiance'] as String? ?? 'inconnue';
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Forme du jour · règle C-FORME', style: CrescoTextes.titreCarte),
              const SizedBox(height: 12),
              const Text(
                'Sommeil 35 %, VFC 25 %, fréquence cardiaque au repos 10 %, ressenti 20 %, fatigue 10 %. '
                'Chaque mesure est comparée à ta propre moyenne.',
                style: CrescoTextes.corps,
              ),
              const SizedBox(height: 10),
              Text('Confiance : $confidence.', style: context.mutedStyle),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lime card: today's session as decided by the engine.
class _SessionCard extends StatelessWidget {
  const new(this.session, {required this.onOpen});
  final Json session;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final decision = session['decision']! as Json;
    final code = decision['decision']! as String;
    final noSession = const {'ARRET', 'REPOS', 'REPOS_ACTIF'}.contains(code);
    final volume = nombre(decision['volume']);
    final detail = [
      if (volume < 0 && !noSession) 'Volume ${signe((volume * 100).round())} %',
      ?session['raison'] as String?,
    ].join(' · ');
    return _Card(
      color: noSession ? p.surface : p.lime,
      onTap: noSession ? null : onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SÉANCE DU JOUR', style: context.overlineStyle.copyWith(color: noSession ? p.muted : p.onLime)),
          const SizedBox(height: 6),
          Text(
            noSession ? libellesDecision[code]! : session['nom']! as String,
            style: CrescoTextes.titrePage.copyWith(color: noSession ? p.ink : p.onLime, fontSize: 28),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              detail,
              style: TextStyle(color: noSession ? p.muted : const Color(0xFF33372F), fontSize: 14, height: 1.4),
            ),
          ],
          if (!noSession) ...[
            const SizedBox(height: 14),
            Material(
              color: p.onLime,
              shape: const StadiumBorder(),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, color: p.lime),
                      const SizedBox(width: 8),
                      Text(
                        'Ouvrir la séance',
                        style: TextStyle(color: p.lime, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
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

/// Energy and fasting tiles: side by side when there is room, stacked otherwise
/// (narrow phones, large text).
class _EnergyAndFast extends StatelessWidget {
  const new({required this.energy, required this.fast, required this.onFast});
  final Json energy;
  final Json? fast;
  final VoidCallback onFast;

  @override
  Widget build(BuildContext context) {
    final energyTile = _EnergyTile(energy);
    final fastTile = _FastTile(fast, onTap: onFast);
    return LayoutBuilder(
      builder: (context, box) {
        final roomy = box.maxWidth >= 340 && MediaQuery.textScalerOf(context).scale(10) <= 11.5;
        if (!roomy) return Column(children: [energyTile, const SizedBox(height: 12), fastTile]);
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: energyTile),
              const SizedBox(width: 12),
              Expanded(child: fastTile),
            ],
          ),
        );
      },
    );
  }
}

class _EnergyTile extends StatelessWidget {
  const new(this.energy);
  final Json energy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final day = energy['jour']! as Json;
    final targets = energy['cibles'] as Json?;
    final suspended = energy['ciblesSuspendues'] == true || targets == null;
    final kcal = nombre(day['kcal']);
    final kcalTarget = nombre(targets?['kcal']);
    final protein = nombre(day['proteines']);
    final proteinTarget = nombre(targets?['proteines']);
    return _Card(
      color: p.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ÉNERGIE DU JOUR', style: context.overlineStyle.copyWith(color: p.muted)),
          const SizedBox(height: 8),
          if (suspended)
            Text(
              'Cibles suspendues pendant le jeûne',
              style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 16),
            )
          else ...[
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: entier((kcalTarget - kcal).clamp(0, 99999))),
                  TextSpan(
                    text: ' kcal restantes',
                    style: TextStyle(
                      fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: p.muted,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
              style: CrescoTextes.chiffre.copyWith(color: p.ink, fontSize: 26),
            ),
            const SizedBox(height: 12),
            Text(
              'Protéines ${entier(protein)} / ${entier(proteinTarget)} g',
              style: TextStyle(color: p.ink, fontSize: 13, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            _Bar(value: proteinTarget > 0 ? protein / proteinTarget : 0, color: p.ink, track: p.line),
          ],
        ],
      ),
    );
  }
}

class _FastTile extends StatelessWidget {
  const new(this.fast, {required this.onTap});
  final Json? fast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = fast?['jeune'] as Json?;
    return _Card(
      color: p.fast,
      padding: const EdgeInsets.all(16),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.nightlight_round, color: p.onFast),
          const SizedBox(height: 8),
          Text(
            f == null ? 'Suivi du jeûne' : 'Jeûne en cours · ${duree(nombre(f['heures']) * 60)}',
            style: TextStyle(color: p.onFast, fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            f == null ? 'Aucun jeûne en cours' : libellesPhase[f['phase']] ?? '',
            style: TextStyle(color: p.onFast, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _BodyCard extends StatelessWidget {
  const new({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Card(
      color: p.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: p.lime, borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.accessibility_new, color: p.onLime),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mon corps',
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 16),
                ),
                Text('Le travail de chaque muscle cette semaine', style: TextStyle(color: p.muted, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: p.ink),
        ],
      ),
    );
  }
}

/// Rounded card used on this screen; tappable when [onTap] is set.
class _Card extends StatelessWidget {
  const new({required this.color, required this.child, this.onTap, this.padding = const EdgeInsets.all(18)});
  final Color color;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(26),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const new({required this.value, required this.color, required this.track});
  final double value;
  final Color color;
  final Color track;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 8, color: color, backgroundColor: track),
    );
  }
}
