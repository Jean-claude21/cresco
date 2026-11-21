import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/features/accueil/saisie_rapide.dart';
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

  /// Days of the current week (Monday = 0) with at least one session done.
  Set<int> trainedDays = {};

  @override
  Future<Json> futureToRun() async {
    final today = await _api.aujourdhui();
    try {
      final now = maintenant();
      final monday = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      trainedDays = {
        for (final s in await _api.recentSessions())
          if (DateTime.tryParse(s['le'] as String? ?? '')?.toLocal() case final d? when !d.isBefore(monday))
            d.weekday - 1,
      };
    } on Exception {
      // The week strip simply shows no session.
    }
    return today;
  }

  Future<void> refresh() => initialise();

  /// Opens [route], then reloads: a finished session or fast changes today's numbers.
  Future<void> open(String route) async {
    await nav.navigateTo<void>(route);
    await refresh();
  }
}

/// Today (mockup G "Aujourd’hui"): week strip, shortcuts, form, today's session, energy, fasting, body.
class TodayView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TodayViewModel>.reactive(
      viewModelBuilder: TodayViewModel.new,
      builder: (context, vm, _) {
        final d = vm.data;
        final cards = <Widget>[
          _Week(trained: vm.trainedDays),
          _Shortcuts(
            onSession: () => vm.open(Routes.seanceView),
            onMeal: () => ouvrirSaisieRapide(context),
            onFast: () => vm.open(Routes.jeuneView),
            onSleep: () => logNight(context),
          ),
          if (d != null) ...[
            _FormCard(d['forme']! as Json),
            _SessionCard(d['seance']! as Json, onOpen: () => vm.open(Routes.seanceView)),
            _EnergyCard(d['energie']! as Json),
            _FastRow(d['jeune'] as Json?, onTap: () => vm.open(Routes.jeuneView)),
            _Row(
              icon: Icons.accessibility_new,
              title: 'Mon corps',
              subtitle: 'Le travail de chaque muscle cette semaine',
              onTap: () => vm.open(Routes.bodyMapView),
            ),
          ],
        ];
        return PageCresco(
          titre: 'Bonjour',
          onRefresh: vm.refresh,
          entete: IconButton.outlined(
            tooltip: 'Profil et réglages',
            onPressed: () => vm.open(Routes.profilView),
            style: IconButton.styleFrom(
              fixedSize: const Size(44, 44),
              side: BorderSide(color: context.palette.line, width: CrescoShape.border),
            ),
            icon: const Icon(Icons.person_outline),
          ),
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

/// Date and the days of the week; today is outlined, days with a session are filled.
class _Week extends StatelessWidget {
  const new({required this.trained});
  final Set<int> trained;

  static const _letters = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final now = maintenant();
    final date = DateFormat('EEEE d MMMM', 'fr_FR').format(now);
    final today = now.weekday - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${date[0].toUpperCase()}${date.substring(1)}', style: context.mutedStyle.copyWith(fontSize: 15)),
        const SizedBox(height: 10),
        Semantics(
          label: 'Cette semaine : ${trained.length} séance${trained.length > 1 ? 's' : ''}',
          excludeSemantics: true,
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: trained.contains(i) ? p.ink : null,
                        borderRadius: CrescoShape.borderRadius,
                        border: Border.all(
                          color: i == today ? p.effort : (trained.contains(i) ? p.ink : p.line),
                          width: i == today ? 2 : CrescoShape.border,
                        ),
                      ),
                      child: Text(
                        _letters[i],
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: trained.contains(i) ? p.background : (i > today ? p.muted : p.ink),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Shortcuts extends StatelessWidget {
  const new({required this.onSession, required this.onMeal, required this.onFast, required this.onSleep});
  final VoidCallback onSession;
  final VoidCallback onMeal;
  final VoidCallback onFast;
  final VoidCallback onSleep;

  @override
  Widget build(BuildContext context) {
    final items = [
      (ShortcutIcon.seance, 'Séance', onSession),
      (ShortcutIcon.repas, 'Repas', onMeal),
      (ShortcutIcon.jeune, 'Jeûne', onFast),
      (ShortcutIcon.sommeil, 'Sommeil', onSleep),
    ];
    return Row(
      children: [
        for (final (i, (icon, label, onTap)) in items.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Material(
              color: context.palette.surface,
              shape: CrescoShape.rectangle(context.palette.line),
              child: InkWell(
                customBorder: CrescoShape.rectangle(),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    children: [
                      ShortcutIconImage(icon, size: 44),
                      const SizedBox(height: 4),
                      FittedBox(
                        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Outlined card used on this screen; tappable when [onTap] is set.
class _Card extends StatelessWidget {
  const new({required this.child, this.onTap, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: CrescoShape.rectangle(p.line),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Form score ring (braise) with its inputs and how it is computed.
class _FormCard extends StatelessWidget {
  const new(this.form);
  final Json form;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final c = form['composantes']! as Json;
    final value = nombre(form['valeur']);
    final rows = [
      ('Sommeil', duree(c['dormiMin'])),
      ('VFC', c['vfc'] == null ? '—' : '${entier(c['vfc'])} ms'),
      ('Ressenti', c['energie'] == null ? '—' : '${entier(c['energie'])}/5'),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Forme du jour', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          const SizedBox(height: 12),
          Row(
            children: [
              ScoreRing(
                fraction: value / 100,
                size: 104,
                color: p.effort,
                track: p.line,
                child: Semantics(
                  label: 'Forme ${entier(value)} sur 100',
                  child: ExcludeSemantics(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(entier(value), style: CrescoTextes.chiffre.copyWith(fontSize: 36)),
                        Text('/100', style: context.mutedStyle.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (final (label, v) in rows)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(label, style: context.mutedStyle.copyWith(fontSize: 15))),
                            Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                          ],
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => _explain(context),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 40)),
                        child: const Text(
                          'Comment c’est calculé',
                          style: TextStyle(decoration: TextDecoration.underline),
                        ),
                      ),
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

/// Black card: today's session as decided by the engine, with one braise button.
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
    return Material(
      color: p.hero,
      shape: CrescoShape.rectangle(p.background.computeLuminance() < 0.2 ? p.line : null),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            left: null,
            child: ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [Colors.transparent, Colors.black]).createShader(r),
              blendMode: BlendMode.dstIn,
              child: const Opacity(opacity: 0.55, child: CrescoPhotoImage(CrescoPhoto.seanceDuJour, width: 170)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Séance du jour',
                  style: TextStyle(color: p.onHeroMuted, fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  noSession ? libellesDecision[code]! : session['nom']! as String,
                  style: CrescoTextes.titrePage.copyWith(color: Colors.white, fontSize: 28),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(detail, style: TextStyle(color: p.onHeroMuted, fontSize: 14, height: 1.4)),
                ],
                if (!noSession) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onOpen,
                      style: effortButtonStyle(context),
                      child: const Text('Démarrer la séance'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EnergyCard extends StatelessWidget {
  const new(this.energy);
  final Json energy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final day = energy['jour']! as Json;
    final targets = energy['cibles'] as Json?;
    if (energy['ciblesSuspendues'] == true || targets == null) {
      return _Card(
        child: Text(
          'Cibles suspendues pendant le jeûne',
          style: TextStyle(color: p.ink, fontWeight: FontWeight.w800, fontSize: 16),
        ),
      );
    }
    final kcal = nombre(day['kcal']);
    final kcalTarget = nombre(targets['kcal']);
    final protein = nombre(day['proteines']);
    final proteinTarget = nombre(targets['proteines']);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: entier((kcalTarget - kcal).clamp(0, 99999))),
                TextSpan(
                  text: ' kcal restantes',
                  style: TextStyle(
                    fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0,
                  ),
                ),
              ],
            ),
            style: CrescoTextes.chiffre.copyWith(fontSize: 34),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: Text('Protéines', style: context.mutedStyle.copyWith(fontSize: 15))),
              Text(
                '${entier(protein)} / ${entier(proteinTarget)} g',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          BarreProgres(valeur: proteinTarget > 0 ? protein / proteinTarget : 0),
        ],
      ),
    );
  }
}

class _FastRow extends StatelessWidget {
  const new(this.fast, {required this.onTap});
  final Json? fast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = fast?['jeune'] as Json?;
    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          const ShortcutIconImage(ShortcutIcon.jeune, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  f == null ? 'Suivi du jeûne' : 'Jeûne en cours',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                if (f == null) Text('Aucun jeûne en cours', style: context.mutedStyle),
                if (f != null) Text(libellesPhase[f['phase']] ?? '', style: context.mutedStyle),
              ],
            ),
          ),
          if (f != null)
            Text(
              duree(nombre(f['heures']) * 60),
              style: CrescoTextes.chiffre.copyWith(fontSize: 24, color: p.onRestSoft),
            )
          else
            Icon(Icons.chevron_right, color: p.ink),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const new({required this.icon, required this.title, required this.subtitle, required this.onTap});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return _Card(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.effortSoft, borderRadius: CrescoShape.borderRadius),
            child: Icon(icon, color: p.onEffortSoft),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text(subtitle, style: context.mutedStyle),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: p.ink),
        ],
      ),
    );
  }
}
