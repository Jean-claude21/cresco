import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:stacked/stacked.dart';

/// Versets (Louis Segond 1910, domaine public) : FOI.md. Affichés seulement avec le module foi.
const versets = {
  'jeune': ('« Ton Père, qui voit dans le secret, te le rendra. »', 'Matthieu 6:18'),
  'reprise': ('« Lève-toi et mange, car le chemin est trop long pour toi. »', '1 Rois 19:7'),
};

const symptomes = ['vertiges', 'faiblesse marquée', 'palpitations', 'confusion', 'nausées', 'malaise'];

class JeuneViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final Messages _snack = locator<Messages>();
  final Session _session = locator<Session>();

  Json? decision;
  bool moduleFoi = false;
  String? erreur;
  Timer? _horloge;

  Json? get jeune => decision?['jeune'] as Json?;

  Future<void> charger() async {
    await runBusyFuture(
      Future(() async {
        try {
          decision = await _api.decisionJeune();
          final profil = await _api.profil();
          moduleFoi = (profil['preferences'] as Json?)?['moduleFoi'] == true;
          erreur = null;
        } on ErreurApi catch (e) {
          erreur = e.message;
        }
      }),
    );
    _horloge?.cancel();
    _horloge = Timer.periodic(const Duration(minutes: 1), (_) => notifyListeners());
  }

  double get heures {
    final debut = DateTime.tryParse(jeune?['debut'] as String? ?? '');
    return debut == null ? 0 : maintenant().difference(debut).inMinutes / 60;
  }

  bool get questionnaireFait => _session.cache('questionnaire-jeune')?['ok'] == true;

  Future<void> validerQuestionnaire() =>
      _session.mettreEnCache('questionnaire-jeune', {'ok': true, 'le': DateTime.now().toIso8601String()});

  Future<void> demarrer({
    required String type,
    required String motif,
    required String intention,
    required int heuresPrevues,
  }) async {
    try {
      final maintenant = DateTime.now().toUtc();
      await _api.demarrerJeune({
        'type': type,
        'motif': motif,
        'intention': intention,
        'debut': maintenant.toIso8601String(),
        'finPrevue': maintenant.add(Duration(hours: heuresPrevues)).toIso8601String(),
      });
      await charger();
    } on ErreurApi catch (e) {
      _snack.afficher(message: e.message);
    }
  }

  Future<void> noter(String type, String valeur) async {
    await _api.noterJeune(jeune!['id']! as String, type, valeur);
    _snack.afficher(message: type == 'symptome' ? 'Noté. Arrête l’effort et pense à rompre le jeûne.' : 'Noté');
    await charger();
  }

  Future<void> terminer() async {
    await _api.terminerJeune(jeune!['id']! as String);
    final reprise = decision?['reprise'] as Json?;
    decision = null;
    notifyListeners();
    _snack.afficher(
      message: 'Jeûne terminé. Reprise ${reprise?['mode'] == 'normale' ? 'normale' : 'progressive'}.',
      duration: const Duration(seconds: 4),
    );
    await charger();
  }

  @override
  void dispose() {
    _horloge?.cancel();
    super.dispose();
  }
}

/// Écran 4 (maquette 04-jeune) : cadran, phase, décision de séance, eau et symptômes, intention.
class JeuneView extends StatelessWidget {
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<JeuneViewModel>.reactive(
      viewModelBuilder: JeuneViewModel.new,
      onViewModelReady: (vm) => vm.charger(),
      builder: (context, vm, _) => Scaffold(
        appBar: AppBar(),
        body: vm.isBusy && vm.decision == null
            ? const Chargement()
            : ListView(
                padding: const EdgeInsets.fromLTRB(CrescoSpacing.margin, 0, CrescoSpacing.margin, 30),
                children: [
                  if (vm.erreur != null) MessageErreur(vm.erreur!, reessayer: vm.charger),
                  if (vm.jeune == null) _Demarrer(vm: vm) else ..._enCours(context, vm),
                ],
              ),
      ),
    );
  }

  List<Widget> _enCours(BuildContext context, JeuneViewModel vm) {
    final p = context.palette;
    final j = vm.jeune!;
    final d = vm.decision!['decision']! as Json;
    final code = d['decision']! as String;
    final debut = DateTime.parse(j['debut']! as String).toLocal();
    final fin = DateTime.tryParse(j['fin_prevue'] as String? ?? '')?.toLocal();
    final h = vm.heures;
    final heure = DateFormat('HH:mm', 'fr_FR');
    final intention = (j['intention'] as String?) ?? '';
    final decisionText = switch (code) {
      'ARRET' => 'Pas d’effort aujourd’hui',
      'NORMALE' => 'Séance normale',
      'REPOS' || 'REPOS_ACTIF' => 'Marche, mobilité, prière',
      _ => 'Séance adaptée : volume ${signe((nombre(d['volume']) * 100).round())} %',
    };
    final decisionDetail = switch (d['alerte']) {
      'symptome' => 'Symptôme signalé : pas d’effort. Pense à rompre le jeûne.',
      'avis_medical' => 'Au-delà de 72 h : avis médical recommandé.',
      'limite_jeune_sec' => 'Jeûne sec au-delà de 24 h : à interrompre.',
      _ =>
        code == 'ADAPTEE'
            ? 'RIR de 2 ou plus, pas d’échec, cardio doux ≤ 45 min (règle J-DECISION).'
            : 'Règle J-DECISION.',
    };
    return [
      Row(
        children: [
          const Expanded(child: Text('Jeûne', style: CrescoTextes.titrePage)),
          Pastille(libellesTypeJeune[j['type']] ?? '', fond: p.surface, texteCouleur: p.ink),
        ],
      ),
      const SizedBox(height: 4),
      Text('Jeûne en cours', style: context.mutedStyle.copyWith(fontSize: 15)),
      const SizedBox(height: 12),
      Center(
        child: CadranJeune(
          heuresEcoulees: h,
          heuresPrevues: fin == null ? null : fin.difference(debut).inMinutes / 60,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(duree(h * 60), style: CrescoTextes.chiffre.copyWith(fontSize: 44)),
              Text('écoulées', style: context.mutedStyle.copyWith(fontSize: 15)),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _Borne('Début', heure.format(debut))),
          Container(width: CrescoShape.border, height: 44, color: p.line),
          Expanded(child: _Borne('Fin prévue', fin == null ? '—' : heure.format(fin))),
        ],
      ),
      const SizedBox(height: 14),
      CrescoCarte(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Phase estimée', style: context.mutedStyle),
            const SizedBox(height: 2),
            Text(libellesPhase[j['phase']] ?? '', style: CrescoTextes.titreCarte.copyWith(fontSize: 22)),
            const SizedBox(height: 14),
            _Phases(current: j['phase'] as String?),
          ],
        ),
      ),
      const SizedBox(height: 12),
      CrescoCarte(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Décision du jour', style: context.mutedStyle),
            const SizedBox(height: 2),
            Text(
              decisionText,
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: code == 'ARRET' ? p.danger : p.ink),
            ),
            const SizedBox(height: 4),
            Text(decisionDetail, style: context.mutedStyle),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          if (j['type'] != 'sec') ...[
            Expanded(
              child: FilledButton.icon(
                onPressed: () => vm.noter('eau', '250'),
                style: FilledButton.styleFrom(backgroundColor: p.rest, foregroundColor: p.onRest),
                icon: const Icon(Icons.water_drop_outlined),
                label: const FittedBox(child: Text('+ 250 ml d’eau')),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: OutlinedButton(
              onPressed: () => _signaler(context, vm),
              child: const FittedBox(child: Text('Signaler un symptôme')),
            ),
          ),
        ],
      ),
      if (intention.isNotEmpty || vm.moduleFoi) ...[
        const SizedBox(height: 12),
        CrescoCarte(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18),
                  const SizedBox(width: 8),
                  Text('Intention privée', style: context.mutedStyle.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              Text(intention.isEmpty ? '—' : intention, style: CrescoTextes.intention.copyWith(fontSize: 20)),
              if (vm.moduleFoi) ...[
                Divider(height: 24, color: p.line),
                Text(versets['jeune']!.$1, style: context.verseStyle),
                Text(versets['jeune']!.$2, style: context.mutedStyle),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 16),
      OutlinedButton(onPressed: vm.terminer, child: const Text('Terminer le jeûne')),
    ];
  }

  Future<void> _signaler(BuildContext context, JeuneViewModel vm) async {
    final choix = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (final s in symptomes) ListTile(title: Text(s), onTap: () => Navigator.pop(context, s))],
        ),
      ),
    );
    if (choix != null) await vm.noter('symptome', choix);
  }
}

/// Fasting phases from J-PHASE, the current one highlighted in glacier blue.
class _Phases extends StatelessWidget {
  const new({required this.current});
  final String? current;

  static const _order = ['post_repas', 'glycogene', 'bascule', 'cetose'];

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final phases = [..._order, if (current == 'prolonge') 'prolonge'];
    final index = phases.indexOf(current ?? '');
    Color segment({required bool on}) => on ? p.rest : p.line;
    return Semantics(
      label: 'Phases du jeûne : ${phases.map((x) => libellesPhase[x]).join(', ')}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (final (i, phase) in phases.indexed)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Container(height: 2, color: i == 0 ? Colors.transparent : segment(on: i <= index)),
                      ),
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == index ? p.rest : (i < index ? p.ink : p.background),
                          border: Border.all(color: i == index ? p.rest : (i < index ? p.ink : p.line), width: 2),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: i == phases.length - 1 ? Colors.transparent : segment(on: i < index),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    child: Text(
                      (libellesPhase[phase] ?? '').split(' ').first,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: i == index ? FontWeight.w800 : FontWeight.w500,
                        color: i == index ? p.onRestSoft : p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Borne extends StatelessWidget {
  const new(this.libelle, this.valeur);
  final String libelle;
  final String valeur;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(libelle, style: context.mutedStyle),
      Text(valeur, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
    ],
  );
}

class _Demarrer extends StatefulWidget {
  const new({required this.vm});
  final JeuneViewModel vm;
  @override
  State<_Demarrer> createState() => _DemarrerState();
}

class _DemarrerState extends State<_Demarrer> {
  String type = 'intermittent';
  String motif = 'spirituel';
  int heures = 16;
  final intention = TextEditingController();

  @override
  void dispose() {
    intention.dispose();
    super.dispose();
  }

  int get heuresMax => type == 'sec' ? 24 : (type == 'partiel' ? 21 * 24 : 120);

  Future<bool> _questionnaire() async {
    if (widget.vm.questionnaireFait || (heures <= 24 && type != 'sec')) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Avant un jeûne long'),
        content: const Text(
          'Un jeûne de plus de 24 h ou sans eau est déconseillé sans avis médical en cas de diabète, grossesse ou allaitement, '
          'trouble du comportement alimentaire, traitement médicamenteux, ou avant 18 ans.\n\n'
          'Cresco ne pose aucun diagnostic. Confirmes-tu ne pas être concerné(e), ou avoir l’accord de ton médecin ?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Je confirme')),
        ],
      ),
    );
    if (ok ?? false) await widget.vm.validerQuestionnaire();
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final max = heuresMax;
    if (heures > max) heures = max;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Jeûne', style: CrescoTextes.titrePage),
        const SizedBox(height: 14),
        CrescoCarte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Surtitre('Type de jeûne'),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in libellesTypeJeune.entries)
                    ChoiceChip(
                      label: Text(t.value),
                      selected: type == t.key,
                      onSelected: (_) => setState(() => type = t.key),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Surtitre('Durée prévue : ${heures >= 48 ? '${heures ~/ 24} jours' : '$heures h'}'),
              Slider(
                value: heures.toDouble(),
                min: 12,
                max: max.toDouble(),
                divisions: (max - 12) ~/ (max > 48 ? 12 : 2),
                activeColor: context.palette.ink,
                onChanged: (v) => setState(() => heures = v.round()),
              ),
              if (type == 'sec') Text('Jeûne sec limité à 24 h, sans effort intense.', style: context.mutedStyle),
              const SizedBox(height: 10),
              const Surtitre('Motif'),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                showSelectedIcon: false,
                expandedInsets: EdgeInsets.zero,
                segments: const [
                  ButtonSegment(value: 'spirituel', label: Text('Spirituel')),
                  ButtonSegment(value: 'sante', label: Text('Santé')),
                  ButtonSegment(value: 'autre', label: Text('Autre')),
                ],
                selected: {motif},
                onSelectionChanged: (s) => setState(() => motif = s.first),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: intention,
                maxLength: 200,
                decoration: const InputDecoration(labelText: 'Intention (privée, facultative)'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        FilledButton(
          onPressed: () async {
            if (!await _questionnaire()) return;
            await widget.vm.demarrer(type: type, motif: motif, intention: intention.text.trim(), heuresPrevues: heures);
          },
          child: const Text('Commencer le jeûne'),
        ),
      ],
    );
  }
}
