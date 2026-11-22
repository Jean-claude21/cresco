import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/coach.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

/// Default interval session: 6 × (1 min at 12 km/h, 1 min 30 at 9 km/h).
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

class TrainingViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService nav = locator<NavigationService>();

  Json? today;
  Json? gym;
  List<Json> templates = [];
  String? loadError;

  Future<void> load() async {
    setBusy(true);
    loadError = null;
    try {
      final results = await Future.wait([_api.seanceDuJour(), _api.templates()]);
      today = results[0] as Json;
      templates = results[1] as List<Json>;
    } on Exception {
      loadError = 'Tes séances n’ont pas pu se charger.';
    }
    try {
      gym = await _api.gym();
    } on Exception {
      // The gym card simply stays hidden.
    }
    setBusy(false);
  }

  Future<void> open(String route, {Object? arguments}) async {
    await nav.navigateTo<void>(route, arguments: arguments);
    await load();
  }

  Future<void> delete(String id) async {
    await _api.deleteTemplate(id);
    await load();
  }
}

/// "Mes séances": my gym, today's session, my saved sessions, intervals.
class TrainingView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<TrainingViewModel>.reactive(
      viewModelBuilder: TrainingViewModel.new,
      onViewModelReady: (vm) => vm.load(),
      builder: (context, vm, _) {
        final loaded = vm.today != null;
        final cards = <Widget>[
          if (vm.gym != null) _GymCard(vm.gym!, onTap: () => vm.open(Routes.gymView)),
          if (loaded) _TodayCard(vm.today!, onStart: () => vm.open(Routes.seanceView)),
          const Text('Mes séances', style: CrescoTextes.titreCarte),
          if (loaded && vm.templates.isEmpty)
            EmptyState(
              icon: Icons.fitness_center,
              illustration: const MyCoach(CoachPose.carnet, height: 220),
              title: 'Ta première séance t’attend',
              message: 'Compose-la avec les machines de ta salle, ou demande à ton IA de la préparer.',
              actionLabel: 'Créer ma séance',
              onAction: () => vm.open(Routes.templateEditorView),
              secondaryLabel: vm.gym?['gym'] == null ? 'Décrire ma salle' : null,
              onSecondary: () => vm.open(Routes.gymView),
            ),
          for (final t in vm.templates) _TemplateCard(t, vm: vm),
          _SessionRow(
            photo: CrescoPhoto.intervalles,
            title: 'Intervalles sur tapis',
            subtitle: '6 × 1 min à 12 km/h',
            onTap: () => vm.open(
              Routes.intervallesView,
              arguments: const IntervallesViewArguments(modele: intervallesParDefaut),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _askAi(context, vm),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const FittedBox(child: Text('Demander à mon IA', maxLines: 1)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('template-new'),
                  onPressed: () => vm.open(Routes.templateEditorView),
                  child: const Text('Nouvelle séance'),
                ),
              ),
            ],
          ),
        ];
        return PageCresco(
          titre: 'Mes séances',
          onRefresh: vm.load,
          enfants: [
            if (vm.isBusy && !loaded) const Chargement(),
            if (vm.loadError != null && !loaded) MessageErreur(vm.loadError!, reessayer: vm.load),
            for (final (i, c) in cards.indexed) FadeSlideIn(index: i, child: c),
          ],
        );
      },
    );
  }
}

class _GymCard extends StatelessWidget {
  const new(this.data, {required this.onTap});
  final Json data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final gym = data['gym'] as Json?;
    final count = (data['equipment'] as List<Object?>? ?? const []).length;
    return Material(
      color: gym == null ? p.warningSoft : p.surface,
      shape: CrescoShape.rectangle(gym == null ? p.onWarningSoft.withValues(alpha: 0.4) : p.line),
      child: InkWell(
        key: const ValueKey('gym-card'),
        customBorder: CrescoShape.rectangle(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                gym == null ? Icons.place_outlined : CrescoIcons.barbell,
                color: gym == null ? p.onWarningSoft : p.ink,
              ),
              if (gym != null)
                SizedBox(height: 36, child: VerticalDivider(width: 28, color: p.line))
              else
                const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gym == null ? 'Décris ta salle' : 'Ma salle',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                        color: gym == null ? p.onWarningSoft : p.ink,
                      ),
                    ),
                    Text(
                      gym == null
                          ? 'Coche tes machines : tes séances et ton IA n’utiliseront que ça.'
                          : '${gym['name']} · $count équipement${count > 1 ? 's' : ''}',
                      style: TextStyle(color: gym == null ? p.onWarningSoft : p.muted, fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: gym == null ? p.onWarningSoft : p.ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const new(this.today, {required this.onStart});
  final Json today;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final model = today['modele'] as Json?;
    final blocks = (model?['blocs'] as List<Object?>? ?? const []).cast<Json>();
    final code = (today['decision']! as Json)['decision']! as String;
    final exercises = blocks.expand((b) => (b['etapes']! as List<Object?>).cast<Json>()).length;
    final firstExercise = blocks.isEmpty
        ? null
        : ((blocks.first['etapes']! as List).first as Json)['exercice_id'] as String?;
    return Material(
      color: blocks.isEmpty ? p.surface : p.hero,
      shape: CrescoShape.rectangle(blocks.isEmpty ? p.line : null),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (blocks.isNotEmpty)
            Positioned.fill(
              left: null,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(colors: [Colors.transparent, Colors.black]).createShader(r),
                blendMode: BlendMode.dstIn,
                child: Opacity(
                  opacity: 0.55,
                  child: CrescoPhotoImage(CrescoPhoto.forExercise(firstExercise), width: 170),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aujourd’hui · ${libellesDecision[code] ?? ''}',
                  style: TextStyle(
                    color: blocks.isEmpty ? p.muted : p.onHeroMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  model?['nom'] as String? ?? 'Séance',
                  style: CrescoTextes.titrePage.copyWith(fontSize: 26, color: blocks.isEmpty ? p.ink : Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  blocks.isEmpty ? today['raison']! as String : '$exercises exercices · ${today['raison']}',
                  style: TextStyle(color: blocks.isEmpty ? p.muted : p.onHeroMuted, fontSize: 14, height: 1.4),
                ),
                if (blocks.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onStart,
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

/// How to have a session programmed by the user's AI (MCP), with the way to Profil for the access token.
Future<void> _askAi(BuildContext context, TrainingViewModel vm) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Demander à mon IA', style: CrescoTextes.titreCarte),
          const SizedBox(height: 10),
          const Text(
            'Ton assistant IA (Claude, ChatGPT…) se branche sur Cresco par le MCP. Il lit ta salle, ton '
            'historique et ta forme, puis te programme une séance : elle apparaît ici, avec les charges '
            'calculées par le moteur et les garde-fous de sécurité.',
            style: CrescoTextes.corps,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              unawaited(vm.open(Routes.profilView));
            },
            child: const Text('Obtenir mon accès dans Profil'),
          ),
        ],
      ),
    ),
  ),
);

/// Row of "Mes séances": photo thumbnail, name and detail, black play button.
class _SessionRow extends StatelessWidget {
  const new({required this.photo, required this.title, required this.subtitle, required this.onTap});
  final CrescoPhoto photo;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.surface,
      shape: CrescoShape.rectangle(p.line),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(borderRadius: CrescoShape.borderRadius, child: CrescoPhotoImage(photo, width: 72, height: 60)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                    Text(subtitle, style: context.mutedStyle),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: p.action, borderRadius: CrescoShape.borderRadius),
                child: Icon(Icons.play_arrow_rounded, color: p.onAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const new(this.template, {required this.vm});
  final Json template;
  final TrainingViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final blocks = ((template['contenu'] as Json?)?['blocs'] as List<Object?>? ?? const []).cast<Json>();
    final sets = blocks.fold<int>(0, (n, b) => n + (b['repeter']! as num).toInt());
    final byAi = template['cree_par'] == 'ia';
    final firstExercise = blocks.isEmpty
        ? null
        : ((blocks.first['etapes']! as List).first as Json)['exercice_id'] as String?;
    return CrescoCarte(
      padding: const EdgeInsets.fromLTRB(10, 10, 6, 10),
      onTap: () => _actions(context),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: CrescoShape.borderRadius,
            child: CrescoPhotoImage(CrescoPhoto.forExercise(firstExercise), width: 64, height: 56),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template['nom']! as String, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                const SizedBox(height: 2),
                Text(
                  '${blocks.length} exercice${blocks.length > 1 ? 's' : ''} · $sets séries${byAi ? ' · créée par ton IA' : ''}',
                  style: context.mutedStyle,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Faire ${template['nom']}',
            onPressed: () =>
                vm.open(Routes.seanceView, arguments: SeanceViewArguments(templateId: template['id']! as String)),
            style: IconButton.styleFrom(
              backgroundColor: p.action,
              foregroundColor: p.onAction,
              fixedSize: const Size(44, 44),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }

  Future<void> _actions(BuildContext context) async {
    final id = template['id']! as String;
    final name = template['nom']! as String;
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow_rounded),
              title: const Text('Faire cette séance maintenant'),
              onTap: () => Navigator.pop(context, 'run'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modifier'),
              onTap: () => Navigator.pop(context, 'edit'),
            ),
            ListTile(
              leading: Icon(Icons.delete_outline, color: context.palette.danger),
              title: Text('Supprimer', style: TextStyle(color: context.palette.danger)),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || choice == null) return;
    switch (choice) {
      case 'run':
        await vm.open(Routes.seanceView, arguments: SeanceViewArguments(templateId: id));
      case 'edit':
        await vm.open(Routes.templateEditorView, arguments: TemplateEditorViewArguments(template: template));
      case 'delete':
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Supprimer « $name » ?'),
            content: const Text(
              'La séance disparaît de ta liste. Les séances déjà faites restent dans ton historique.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Supprimer')),
            ],
          ),
        );
        if (ok ?? false) await vm.delete(id);
    }
  }
}
