import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/heart_rate.dart';
import 'package:cresco_app/ui/workout_keep_alive.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class Etape {
  new({
    required this.libelle,
    required this.secondes,
    required this.vitesseMs,
    required this.repetition,
    required this.repetitions,
    required this.bloc,
  });
  final String libelle;
  final int secondes;
  final double? vitesseMs;
  final int repetition;
  final int repetitions;
  final int bloc;

  /// Internal units are SI, km/h only on screen (AGENTS.md).
  String get vitesseKmh => vitesseMs == null ? '—' : decimal(vitesseMs! * 3.6);
}

/// Flattens blocks → steps (MODELE_DONNEES.md) into one timeline.
List<Etape> aplatir(Json modele) {
  final etapes = <Etape>[];
  final blocs = (modele['blocs']! as List).cast<Json>();
  for (var b = 0; b < blocs.length; b++) {
    final rep = (blocs[b]['repeter']! as num).toInt();
    for (var r = 1; r <= rep; r++) {
      for (final e in (blocs[b]['etapes']! as List).cast<Json>()) {
        final t = (e['duree']! as Json)['temps_s'];
        if (t is! num) continue;
        final v = (e['cible']! as Json)['vitesse_ms'];
        etapes.add(
          Etape(
            libelle: e['libelle'] as String? ?? 'Étape',
            secondes: t.toInt(),
            vitesseMs: v is num ? v.toDouble() : null,
            repetition: r,
            repetitions: rep,
            bloc: b,
          ),
        );
      }
    }
  }
  return etapes;
}

/// `mm:ss` of [seconds].
String chrono(int seconds) =>
    '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';

class IntervallesViewModel extends BaseViewModel {
  new(this.modele, {DateTime Function()? clock}) : etapes = aplatir(modele), _clock = clock ?? DateTime.now;
  final Json modele;
  final List<Etape> etapes;
  final DateTime Function() _clock;
  final _tts = FlutterTts();
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();
  final HeartRateMonitor heartRate = HeartRateMonitor.instance;

  int index = 0;
  late int restant = etapes.first.secondes;
  bool enPause = true;

  /// True from the first start: tells « Démarrer » from « Reprendre ».
  bool demarre = false;
  bool termine = false;
  Timer? _minuteur;
  late final DateTime debut = _clock();

  /// End of the current step on the wall clock while running: the screen-off timer reads it, so a
  /// sleeping CPU never makes the session drift.
  DateTime? _finEtape;

  /// Heart-rate samples of each step, averaged into the saved series.
  final Map<int, List<int>> _fc = {};

  int get preavis => nombre((modele['annonces'] as Json?)?['preavis_s'], 15).toInt();
  bool get voix => (modele['annonces'] as Json?)?['voix'] != false;
  Etape get courante => etapes[index];
  Etape? get suivante => index + 1 < etapes.length ? etapes[index + 1] : null;

  /// Share of the current step already done.
  double get avancement => courante.secondes == 0 ? 1 : 1 - restant / courante.secondes;

  Future<void> demarrer() async {
    heartRate.addListener(_surFc);
    await sansEchec(() => _tts.setLanguage('fr-FR'));
    await sansEchec(() => _tts.setSpeechRate(0.5));
    // iOS: the voice cues keep the app alive with the screen off (audio background mode).
    await sansEchec(
      () => _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.duckOthers,
      ]),
    );
    await sansEchec(WakelockPlus.enable);
  }

  void basculerPause() {
    enPause = !enPause;
    if (enPause) {
      _minuteur?.cancel();
      unawaited(WorkoutKeepAlive.update(title: 'Séance en pause', text: '${courante.libelle} · ${chrono(restant)}'));
    } else {
      if (!demarre) {
        unawaited(WorkoutKeepAlive.start(title: _titreNotif, text: _texteNotif));
      }
      if (restant == courante.secondes) _annoncer('${courante.libelle}, ${courante.vitesseKmh} kilomètres heure');
      _finEtape = _clock().add(Duration(seconds: restant));
      _minuteur = Timer.periodic(const Duration(milliseconds: 500), (_) => tic());
    }
    demarre = true;
    notifyListeners();
  }

  String get _titreNotif => modele['nom'] as String? ?? 'Intervalles';
  String get _texteNotif => '${courante.libelle} · ${courante.vitesseKmh} km/h · ${chrono(restant)}';

  /// Advances to where the wall clock is: catches up every step missed while the app slept.
  @visibleForTesting
  void tic() {
    final fin = _finEtape;
    if (fin == null || termine || enPause) return;
    var reste = (fin.difference(_clock()).inMilliseconds / 1000).ceil();
    final avant = restant;
    while (reste <= 0) {
      final s = suivante;
      if (s == null) {
        _minuteur?.cancel();
        termine = true;
        restant = 0;
        _annoncer('Séance terminée. Bravo.');
        unawaited(WorkoutKeepAlive.stop());
        notifyListeners();
        return;
      }
      index++;
      _finEtape = _finEtape!.add(Duration(seconds: courante.secondes));
      reste = (_finEtape!.difference(_clock()).inMilliseconds / 1000).ceil();
      _annoncer('${courante.libelle}, ${courante.vitesseKmh} kilomètres heure');
      unawaited(HapticFeedback.heavyImpact());
    }
    restant = reste;
    final s = suivante;
    if (s != null && preavis > 0 && avant > preavis && restant <= preavis) {
      _annoncer('Dans $preavis secondes, passe à ${s.vitesseKmh} kilomètres heure');
      unawaited(HapticFeedback.mediumImpact());
    }
    if (restant != avant) {
      unawaited(WorkoutKeepAlive.update(title: _titreNotif, text: _texteNotif));
      notifyListeners();
    }
  }

  void _surFc() {
    final v = heartRate.bpm;
    if (v != null && demarre && !enPause && !termine) (_fc[index] ??= []).add(v);
    notifyListeners();
  }

  void _annoncer(String texte) {
    if (voix) unawaited(sansEchec(() => _tts.speak(texte)));
  }

  /// Average heart rate of step [i], when a sensor sent data during it.
  int? fcMoyenne(int i) {
    final v = _fc[i];
    if (v == null || v.isEmpty) return null;
    return (v.reduce((a, b) => a + b) / v.length).round();
  }

  Future<void> enregistrer() async {
    await _api.enregistrerSeance({
      'type': modele['type'] ?? 'course_tapis',
      'dureeMin': _clock().difference(debut).inMinutes.clamp(1, 600),
      'rpe': 7,
      'series': [
        for (final (i, e) in etapes.take(index + 1).indexed)
          {'vitesseMs': ?e.vitesseMs, 'dureeS': e.secondes, 'fc': ?fcMoyenne(i)},
      ],
    });
    _nav.back<void>();
  }

  Future<void> terminer() async {
    _minuteur?.cancel();
    termine = true;
    await WorkoutKeepAlive.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    heartRate.removeListener(_surFc);
    _minuteur?.cancel();
    unawaited(WorkoutKeepAlive.stop());
    unawaited(sansEchec(_tts.stop));
    unawaited(sansEchec(WakelockPlus.disable));
    super.dispose();
  }
}

/// Intervals (design G, effort mode, always dark): ring with the time left, target speed in
/// braise, next step announced, timeline, heart rate, fixed buttons at the bottom.
class IntervallesView extends StatelessWidget {
  const new({required this.modele, super.key});
  final Map<String, Object?> modele;

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<IntervallesViewModel>.reactive(
      viewModelBuilder: () => IntervallesViewModel(modele),
      onViewModelReady: (vm) => vm.demarrer(),
      builder: (context, vm, _) => Theme(
        data: crescoTheme(brightness: Brightness.dark, fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily),
        child: Builder(builder: (context) => _build(context, vm)),
      ),
    );
  }

  Widget _build(BuildContext context, IntervallesViewModel vm) {
    final p = context.palette;
    final e = vm.courante;
    final s = vm.suivante;
    final frise = vm.etapes.where((x) => x.bloc == e.bloc).toList();
    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Séance en cours', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: vm.termine
              ? FilledButton(
                  onPressed: vm.enregistrer,
                  style: effortButtonStyle(context),
                  child: const Text('Enregistrer la séance'),
                )
              : Row(
                  children: [
                    if (vm.demarre) ...[
                      Expanded(
                        child: OutlinedButton(
                          onPressed: vm.terminer,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: p.effort,
                            side: BorderSide(color: p.effort, width: CrescoShape.border),
                          ),
                          child: const Text('Terminer'),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      child: FilledButton.icon(
                        key: const ValueKey('intervalles-lecture'),
                        onPressed: vm.basculerPause,
                        style: effortButtonStyle(context),
                        icon: Icon(vm.enPause ? Icons.play_arrow : Icons.pause),
                        label: Text(vm.enPause ? (vm.demarre ? 'Reprendre' : 'Démarrer') : 'Pause'),
                      ),
                    ),
                  ],
                ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(modele['nom'] as String? ?? 'Intervalles', style: CrescoTextes.titrePage.copyWith(color: p.ink)),
          Text(
            e.repetitions > 1 ? '${e.libelle} · ${e.repetition} sur ${e.repetitions}' : e.libelle,
            style: TextStyle(fontSize: 17, color: p.muted),
          ),
          const SizedBox(height: 18),
          Center(
            child: ScoreRing(
              fraction: vm.termine ? 1 : vm.avancement,
              size: 236,
              stroke: 14,
              color: p.effort,
              track: p.line,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    vm.termine ? 'Fini' : chrono(vm.restant),
                    style: CrescoTextes.chiffre.copyWith(fontSize: 64, color: p.ink),
                  ),
                  Text(vm.termine ? 'bravo' : 'restantes', style: TextStyle(color: p.muted, fontSize: 15)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Vitesse cible', style: TextStyle(color: p.muted, fontSize: 15)),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: e.vitesseKmh),
                          TextSpan(text: ' km/h', style: CrescoTextes.chiffre.copyWith(fontSize: 26)),
                        ],
                      ),
                      style: CrescoTextes.chiffre.copyWith(fontSize: 56, color: p.effort),
                    ),
                  ],
                ),
              ),
              _HeartRate(vm: vm),
            ],
          ),
          if (s != null) ...[
            const SizedBox(height: 14),
            DecoratedBox(
              decoration: CrescoShape.outlined(p),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(Icons.volume_up_outlined, color: p.effort),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vm.demarre && !vm.termine && vm.restant <= vm.preavis
                                ? 'Dans ${vm.restant} s, passe à ${s.vitesseKmh} km/h'
                                : 'Ensuite : ${s.vitesseKmh} km/h',
                            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.ink),
                          ),
                          Text('${s.libelle} · ${dureeCourte(s.secondes)}', style: TextStyle(color: p.muted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (frise.length > 1) ...[
            const SizedBox(height: 18),
            Text(
              'Déroulé',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: p.ink),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 56,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final x in frise)
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height:
                            (x.vitesseMs ?? 0) >= (frise.map((f) => f.vitesseMs ?? 0).reduce((a, b) => a > b ? a : b))
                            ? 52
                            : 24,
                        decoration: BoxDecoration(
                          borderRadius: CrescoShape.borderRadius,
                          color: identical(x, e)
                              ? p.effort
                              : vm.etapes.indexOf(x) < vm.index
                              ? p.effort.withValues(alpha: 0.45)
                              : p.line,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text('Le minuteur et les annonces continuent écran éteint.', style: TextStyle(color: p.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

/// Live heart rate, or the button that connects a Bluetooth sensor.
class _HeartRate extends StatelessWidget {
  const new({required this.vm});
  final IntervallesViewModel vm;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bpm = vm.heartRate.bpm;
    if (vm.heartRate.connected) {
      return Semantics(
        label: bpm == null ? 'Capteur cardio connecté, en attente' : 'Fréquence cardiaque $bpm battements par minute',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.favorite, color: p.danger, size: 18),
                const SizedBox(width: 4),
                Text('FC', style: TextStyle(color: p.muted, fontSize: 15)),
              ],
            ),
            Text(bpm == null ? '—' : '$bpm', style: CrescoTextes.chiffre.copyWith(fontSize: 44, color: p.ink)),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      key: const ValueKey('capteur-cardio'),
      onPressed: () => _connect(context),
      // The theme stretches buttons to the full width: this one sits beside the speed.
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      icon: Icon(Icons.favorite_border, color: p.ink, size: 18),
      label: const Text('Capteur FC'),
    );
  }

  Future<void> _connect(BuildContext context) async {
    final monitor = vm.heartRate;
    if (!await monitor.available) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Active le Bluetooth pour connecter ton capteur cardio.')));
      }
      return;
    }
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => _SensorSheet(monitor: monitor),
    );
    await monitor.stopScan();
  }
}

class _SensorSheet extends StatelessWidget {
  const new({required this.monitor});
  final HeartRateMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Capteur cardio', style: CrescoTextes.titreCarte),
            const SizedBox(height: 4),
            Text('Ceinture, brassard ou montre en mode diffusion de la FC.', style: context.mutedStyle),
            const SizedBox(height: 12),
            StreamBuilder<List<ScanResult>>(
              stream: monitor.scan(),
              builder: (context, snap) {
                final found = snap.data ?? const [];
                if (found.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Row(
                      children: [
                        SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: p.ink)),
                        const SizedBox(width: 12),
                        const Text('Recherche des capteurs…'),
                      ],
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final r in found)
                      ListTile(
                        leading: Icon(Icons.favorite_border, color: p.ink),
                        title: Text(r.device.platformName.isEmpty ? 'Capteur sans nom' : r.device.platformName),
                        subtitle: Text('Signal ${r.rssi} dBm'),
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.pop(context);
                          try {
                            await monitor.connect(r.device);
                          } on Object {
                            messenger.showSnackBar(const SnackBar(content: Text('Connexion au capteur impossible.')));
                          }
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
