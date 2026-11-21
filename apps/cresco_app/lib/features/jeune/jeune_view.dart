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
        appBar: AppBar(
          title: const Text('Suivi du jeûne', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: vm.isBusy && vm.decision == null
            ? const Chargement()
            : ListView(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 30),
                children: [
                  if (vm.erreur != null) MessageErreur(vm.erreur!, reessayer: vm.charger),
                  if (vm.jeune == null) _Demarrer(vm: vm) else ..._enCours(context, vm),
                ],
              ),
      ),
    );
  }

  List<Widget> _enCours(BuildContext context, JeuneViewModel vm) {
    final j = vm.jeune!;
    final d = vm.decision!['decision']! as Json;
    final code = d['decision']! as String;
    final debut = DateTime.parse(j['debut']! as String).toLocal();
    final fin = DateTime.tryParse(j['fin_prevue'] as String? ?? '')?.toLocal();
    final h = vm.heures;
    final heure = DateFormat('HH:mm', 'fr_FR');
    final intention = (j['intention'] as String?) ?? '';
    return [
      Row(
        children: [
          const Expanded(child: Text('Jeûne', style: CrescoTextes.titrePage)),
          Pastille(
            libellesTypeJeune[j['type']] ?? '',
            fond: context.palette.surface,
            texteCouleur: context.palette.ink,
          ),
        ],
      ),
      const SizedBox(height: 14),
      CrescoCarte(
        child: Column(
          children: [
            const Align(alignment: Alignment.centerLeft, child: Surtitre('Jeûne en cours')),
            const SizedBox(height: 12),
            CadranJeune(
              heuresEcoulees: h,
              heuresPrevues: fin == null ? null : fin.difference(debut).inMinutes / 60,
              taille: 230,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(duree(h * 60), style: CrescoTextes.chiffre.copyWith(fontSize: 38)),
                  Text('écoulées', style: context.mutedStyle),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _Borne('Début', heure.format(debut)),
                _Borne('Fin prévue', fin == null ? '—' : heure.format(fin)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Phase estimée · ${libellesPhase[j['phase']] ?? ''}',
              style: TextStyle(color: context.palette.ink, fontWeight: FontWeight.w800, fontSize: 17),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      CrescoCarteSombre(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Surtitre(libellesDecision[code]!, couleur: context.palette.lime),
            const SizedBox(height: 8),
            Text(switch (code) {
              'ARRET' => 'Stop',
              'NORMALE' => 'Séance normale',
              'REPOS' || 'REPOS_ACTIF' => 'Marche, mobilité, prière',
              _ => 'Volume ${signe((nombre(d['volume']) * 100).round())} %',
            }, style: CrescoTextes.chiffre.copyWith(color: Colors.white, fontSize: 40)),
            const SizedBox(height: 8),
            Text(switch (d['alerte']) {
              'symptome' => 'Symptôme signalé : pas d’effort. Pense à rompre le jeûne.',
              'avis_medical' => 'Au-delà de 72 h : avis médical recommandé.',
              'limite_jeune_sec' => 'Jeûne sec au-delà de 24 h : à interrompre.',
              _ => code == 'ADAPTEE' ? 'RIR de 2 ou plus, pas d’échec, cardio doux ≤ 45 min' : 'Règle J-DECISION',
            }, style: const TextStyle(color: Colors.white, fontSize: 16)),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          if (j['type'] != 'sec')
            Expanded(
              child: CrescoCarte(
                onTap: () => vm.noter('eau', '250'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const IconeLibelle(Icons.local_drink_outlined, 'Eau'),
                    const SizedBox(height: 8),
                    Text(
                      '+ 250 ml',
                      style: TextStyle(color: context.palette.ink, fontWeight: FontWeight.w800, fontSize: 22),
                    ),
                  ],
                ),
              ),
            ),
          if (j['type'] != 'sec') const SizedBox(width: 12),
          Expanded(
            child: CrescoCarte(
              onTap: () => _signaler(context, vm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const IconeLibelle(Icons.monitor_heart_outlined, 'Symptômes'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          'Signaler',
                          style: TextStyle(color: context.palette.ink, fontWeight: FontWeight.w800, fontSize: 22),
                        ),
                      ),
                      Icon(Icons.chevron_right, color: context.palette.ink),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      if (intention.isNotEmpty || vm.moduleFoi) ...[
        const SizedBox(height: 12),
        CrescoCarte(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [Icon(Icons.lock_outline, size: 18), SizedBox(width: 8), Surtitre('Intention privée')],
              ),
              const SizedBox(height: 10),
              Text(intention.isEmpty ? '—' : intention, style: CrescoTextes.intention),
              if (vm.moduleFoi) ...[
                Divider(height: 26, color: context.palette.line),
                Text(versets['jeune']!.$1, style: context.verseStyle),
                Text(versets['jeune']!.$2, style: context.mutedStyle),
              ],
            ],
          ),
        ),
      ],
      const SizedBox(height: 18),
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
