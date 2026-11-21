/// Moteur de calcul Cresco (Dart). Chaque fonction correspond à une règle de
/// docs/science/CALCULS.md ou JEUNE.md et doit rester identique au moteur
/// TypeScript (packages/engine-ts) : les deux passent engine-spec/cases.json.
library;

import 'dart:math' as math;

typedef Json = Map<String, Object?>;

double _n(Object? v, [double defaut = 0]) => v == null ? defaut : (v as num).toDouble();
double _borne(double x, double min, double max) => math.min(max, math.max(min, x));
double _moyenne(List<double> xs) => xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;

// ------------------------------------------------------------------ C-PERF

double repsEffectives(num reps, num rir) => (reps + rir).toDouble();

/// C-PERF-2 : Brzycki jusqu'à 10 reps effectives, Epley au-delà.
Json e1rm(Json e) {
  final charge = _n(e['charge']);
  final r = repsEffectives(_n(e['reps']), _n(e['rir']));
  final brzycki = r <= 10;
  final valeur = brzycki ? charge * 36 / (37 - r) : charge * (1 + r / 30);
  final confiance = r <= 10 ? 'haute' : (r <= 12 ? 'moyenne' : 'basse');
  return {'valeur': valeur, 'confiance': confiance, 'formule': brzycki ? 'brzycki' : 'epley'};
}

/// C-PERF-3 : charge cible arrondie au pas du matériel.
Json chargeCible(Json e) {
  final r = repsEffectives(_n(e['reps']), _n(e['rir']));
  final m = _n(e['e1rm']);
  final brute = r <= 10 ? m * (37 - r) / 36 : m / (1 + r / 30);
  final pas = _n(e['pas']) > 0 ? _n(e['pas']) : 0.5;
  return {'valeur': (brute / pas).roundToDouble() * pas};
}

/// C-PERF-4 (heuristique)
Json ajustementSerie(Json e) {
  final ecart = _n(e['rirReel']) - _n(e['rirCible']);
  return {'facteur': ecart >= 2 ? 1.025 : (ecart <= -2 ? 0.95 : 1.0)};
}

/// C-PERF-5 : séries avec RIR ≤ 3 ; primaire 1, secondaire 0,5.
Json seriesEfficaces(Json e) {
  final total = <String, Object?>{};
  for (final s in (e['series']! as List).cast<Map<String, Object?>>()) {
    if (_n(s['rir']) > 3) continue;
    for (final m in (s['primaires']! as List).cast<String>()) {
      total[m] = _n(total[m]) + 1;
    }
    for (final m in (s['secondaires']! as List).cast<String>()) {
      total[m] = _n(total[m]) + 0.5;
    }
  }
  return total;
}

// ------------------------------------------------------------------ C-CHARGE

Json srpe(Json e) => {'valeur': _n(e['rpe']) * _n(e['minutes'])};

Json trimp(Json e) {
  final fcr = _borne((_n(e['fc']) - _n(e['fcRepos'])) / (_n(e['fcMax']) - _n(e['fcRepos'])), 0, 1);
  final homme = e['sexe'] == 'homme';
  final a = homme ? 0.64 : 0.86;
  final b = homme ? 1.92 : 1.67;
  return {'valeur': _n(e['minutes']) * fcr * a * math.exp(b * fcr)};
}

Json fcMax(Json e) => {'valeur': 208 - 0.7 * _n(e['age'])};
Json fcCible(Json e) => {'valeur': _n(e['fcRepos']) + _n(e['intensite']) * (_n(e['fcMax']) - _n(e['fcRepos']))};

/// Moyenne mobile exponentielle sur n jours (α = 2 / (n + 1)).
double ewma(List<double> valeurs, int jours) {
  if (valeurs.isEmpty) return 0;
  final alpha = 2 / (jours + 1);
  var m = valeurs.first;
  for (final v in valeurs.skip(1)) {
    m = m + alpha * (v - m);
  }
  return m;
}

Json ratioAiguChronique(Json e) {
  final charges = (e['charges']! as List).map(_n).toList();
  final aigue = ewma(charges, 7);
  final chronique = ewma(charges, 28);
  return {'aigue': aigue, 'chronique': chronique, 'ratio': chronique > 0 ? aigue / chronique : 1.0};
}

Json kcalMet(Json e) => {'valeur': _n(e['met']) * _n(e['poids']) * _n(e['heures'])};

// ------------------------------------------------------------------ C-RECUP

Json scoreSommeil(Json e) {
  final besoin = _n(e['besoinMin'], 480);
  final dormi = _n(e['dormiMin']);
  final duree = math.min(1, dormi / besoin).toDouble();
  final auLit = _n(e['auLitMin']);
  final efficacite = auLit > 0 ? math.min(1, dormi / auLit).toDouble() : 0.0;
  final profondMoyen = _n(e['profondMoyenPct']);
  final profond = e['profondPct'] != null && profondMoyen > 0
      ? math.min(1, _borne(_n(e['profondPct']) / profondMoyen, 0, 1.2)).toDouble()
      : duree;
  final regularite = e['ecartTypeMilieuMin'] != null ? 1 - math.min(1, _n(e['ecartTypeMilieuMin']) / 90) : 0.5;
  return {'valeur': 100 * (0.4 * duree + 0.2 * efficacite + 0.2 * profond + 0.2 * regularite)};
}

Json zScore(Json e) {
  final et = _n(e['ecartType']);
  return {'valeur': et > 0 ? (_n(e['valeur']) - _n(e['moyenne'])) / et : 0.0};
}

// ------------------------------------------------------------------ C-ENERGIE

Json bmr(Json e) {
  if (e['masseMaigre'] != null && _n(e['masseMaigre']) > 0) {
    return {'valeur': 370 + 21.6 * _n(e['masseMaigre']), 'formule': 'katch'};
  }
  final base = 10 * _n(e['poids']) + 6.25 * _n(e['taille']) - 5 * _n(e['age']);
  return {'valeur': base + (e['sexe'] == 'homme' ? 5 : -161), 'formule': 'mifflin'};
}

const nap = {'sedentaire': 1.4, 'peu_actif': 1.55, 'actif': 1.7, 'tres_actif': 1.9};
Json tdeeInitial(Json e) => {'valeur': _n(e['bmr']) * (nap[e['activite']] ?? 1.55)};

Json poidsLisse(Json e) {
  final alpha = _n(e['alpha'], 0.1);
  final serie = <double>[];
  for (final p in (e['pesees']! as List).map(_n)) {
    serie.add(serie.isEmpty ? p : serie.last + alpha * (p - serie.last));
  }
  return {'serie': serie};
}

Json tdeeAdaptatif(Json e) {
  final observe = _n(e['apportMoyen']) - (_n(e['tendanceFin']) - _n(e['tendanceDebut'])) * 7700 / _n(e['jours']);
  final sousSaisie = observe < _n(e['bmr']);
  final precedent = _n(e['tdeePrecedent']);
  return {
    'observe': observe,
    'valeur': sousSaisie ? precedent : 0.8 * precedent + 0.2 * observe,
    'sousSaisie': sousSaisie,
  };
}

Json verdictEnergie(Json e) {
  final tdee = _n(e['tdee']);
  final pct = tdee > 0 ? _n(e['bilanMoyen']) / tdee : 0.0;
  final fenetre = _n(e['joursFenetre']);
  final couverture = fenetre > 0 ? _n(e['joursSaisis']) / fenetre : 0.0;
  final verdict = pct < -0.05 ? 'deficit' : (pct > 0.05 ? 'surplus' : 'maintien');
  final confiance = fenetre >= 21 && couverture >= 0.9
      ? 'haute'
      : (fenetre >= 14 && couverture >= 0.8 ? 'moyenne' : 'basse');
  return {'verdict': verdict, 'confiance': confiance, 'pct': pct};
}

Json kcalMacros(Json e) => {
  'valeur': 4 * _n(e['glucides']) + 4 * _n(e['proteines']) + 9 * _n(e['lipides']) + 7 * _n(e['alcool']),
};

Json ciblesMacros(Json e) {
  final objectif = e['objectif'] as String? ?? 'maintien';
  final defaut = objectif == 'perte' ? -0.15 : (objectif == 'prise' ? 0.075 : 0.0);
  final brut = e['ajustement'] == null ? defaut : _n(e['ajustement']);
  final ajustement = objectif == 'perte'
      ? _borne(brut, -0.25, -0.1)
      : (objectif == 'prise' ? _borne(brut, 0.05, 0.1) : 0.0);
  final poids = _n(e['poids']);
  final kcal = math.max(_n(e['bmr']), _n(e['tdee']) * (1 + ajustement));
  final proteines = (objectif == 'perte' ? 2.2 : 1.6) * poids;
  final lipides = math.max(0.5 * poids, kcal * _borne(_n(e['partLipides'], 0.3), 0.25, 0.35) / 9);
  final glucides = math.max(0, (kcal - 4 * proteines - 9 * lipides) / 4).toDouble();
  return {'kcal': kcal, 'proteines': proteines, 'lipides': lipides, 'glucides': glucides};
}

double proteinesParRepas(double poids) => 0.4 * poids;

Json nutrimentsPlat(Json e) {
  final ingredients = (e['ingredients']! as List).cast<Map<String, Object?>>();
  final crue = ingredients.fold<double>(0, (s, i) => s + _n(i['masse']));
  final masse = _n(e['masseCuite']) > 0 ? _n(e['masseCuite']) : crue;
  double somme(String k) => ingredients.fold<double>(0, (s, i) => s + _n(i[k]) * _n(i['masse']) / 100);
  double par100(double x) => masse > 0 ? x / masse * 100 : 0;
  return {
    'kcal100': par100(somme('kcal100')),
    'proteines100': par100(somme('proteines100')),
    'glucides100': par100(somme('glucides100')),
    'lipides100': par100(somme('lipides100')),
    'masse': masse,
  };
}

// ------------------------------------------------------------------ C-FORME, C-AJUST

Json scoreForme(Json e) {
  double? opt(String k, double Function(double) f) => e[k] == null ? null : f(_n(e[k]));
  final composantes = <(double, double?)>[
    (0.35, opt('sommeil', (v) => v)),
    (0.25, opt('zVfc', (z) => _borne(50 + 15 * z, 0, 100))),
    (0.10, opt('zFcRepos', (z) => _borne(50 + 15 * z, 0, 100))),
    (0.20, opt('energie', (v) => _borne((v - 1) * 25 - 10 * _n(e['courbatures']), 0, 100))),
    (0.10, opt('ratioAiguChronique', (r) => _borne(100 - 50 * math.max(0, r - 1), 0, 100))),
  ];
  final presentes = composantes.where((c) => c.$2 != null).toList();
  final poids = presentes.fold<double>(0, (s, c) => s + c.$1);
  var valeur = poids > 0 ? presentes.fold<double>(0, (s, c) => s + c.$1 * c.$2!) / poids : 50.0;
  if (_n(e['heuresJeune']) > 16) valeur -= 10;
  final confiance = poids >= 0.9 ? 'haute' : (poids >= 0.55 ? 'moyenne' : 'basse');
  return {'valeur': _borne(valeur, 0, 100), 'confiance': confiance};
}

const _prudence = ['NORMALE', 'ADAPTEE', 'LEGERE', 'REPOS_ACTIF', 'REPOS', 'ARRET'];
const _volume = {'NORMALE': 0.0, 'ADAPTEE': -0.2, 'LEGERE': -0.5, 'REPOS_ACTIF': -1.0, 'REPOS': -1.0, 'ARRET': -1.0};

Json ajustementSeance(Json e) {
  final forme = _n(e['forme']);
  final decision = e['reposVerrouille'] == true
      ? 'REPOS'
      : (forme >= 75 ? 'NORMALE' : (forme >= 50 ? 'ADAPTEE' : 'LEGERE'));
  return {'decision': decision, 'volume': _volume[decision]};
}

// ------------------------------------------------------------------ C-PROG, C-VERDICT

Json penteE1rm(Json e) {
  final points = (e['points']! as List).cast<Map<String, Object?>>();
  if (points.length < 2) return {'kgParSemaine': 0.0, 'pctParSemaine': 0.0, 'suffisant': false};
  final mx = _moyenne(points.map((p) => _n(p['jour'])).toList());
  final my = _moyenne(points.map((p) => _n(p['e1rm'])).toList());
  var num = 0.0;
  var den = 0.0;
  for (final p in points) {
    num += (_n(p['jour']) - mx) * (_n(p['e1rm']) - my);
    den += math.pow(_n(p['jour']) - mx, 2);
  }
  final kg = (den > 0 ? num / den : 0) * 7;
  return {'kgParSemaine': kg, 'pctParSemaine': my > 0 ? kg / my * 100 : 0.0, 'suffisant': points.length >= 4};
}

const seuilsProgression = {'debutant': 1.0, 'intermediaire': 0.5, 'avance': 0.25};

Json contexteDefavorable(Json e) {
  final causes = <String>[
    if (_n(e['sommeilMoyenMin']) < 390) 'sommeil',
    if (_n(e['bilanPct']) < -0.15) 'deficit',
    if (_n(e['joursJeune']) >= 2) 'jeune',
    if (e['maladie'] == true) 'maladie',
  ];
  return {'defavorable': causes.isNotEmpty, 'causes': causes};
}

Json verdictProgression(Json e) {
  final seuil = seuilsProgression[e['niveau']] ?? 0.5;
  final pct = _n(e['pctParSemaine']);
  final verdict = pct >= seuil
      ? 'progression'
      : (e['contexteDefavorable'] == true
            ? 'maintien_reussite'
            : (_n(e['semainesSousSeuil']) >= 3 ? 'stagnation' : 'patience'));
  return {'verdict': verdict, 'seuil': seuil};
}

// ------------------------------------------------------------------ Jeûne

Json phaseJeune(Json e) {
  final h = _n(e['heures']);
  final phase = h < 12
      ? 'post_repas'
      : (h < 16 ? 'glycogene' : (h < 24 ? 'bascule' : (h < 72 ? 'cetose' : 'prolonge')));
  return {'phase': phase};
}

/// J-DECISION (heuristique) — symptôme > repos verrouillé > limites > phase > priorité spirituelle.
Json decisionJeune(Json e) {
  final type = e['type']! as String;
  final heures = _n(e['heures']);
  if ((e['symptomes'] as List? ?? const []).isNotEmpty) {
    return {'decision': 'ARRET', 'volume': -1.0, 'alerte': 'symptome'};
  }
  if (e['reposVerrouille'] == true) return {'decision': 'REPOS', 'volume': -1.0, 'alerte': null};
  if (type == 'sec' && heures > 24) return {'decision': 'ARRET', 'volume': -1.0, 'alerte': 'limite_jeune_sec'};
  String decision;
  String? alerte;
  if (type == 'partiel') {
    decision = 'NORMALE';
  } else {
    final h = type == 'sec' ? math.max(heures, 16) : heures;
    if (h <= 16 && type != 'sec') {
      decision = 'NORMALE';
    } else if (h < 24) {
      decision = 'ADAPTEE';
    } else if (h <= 72) {
      decision = 'LEGERE';
    } else {
      decision = 'REPOS_ACTIF';
      alerte = 'avis_medical';
    }
  }
  if (e['prioriteSpirituelle'] == true && decision != 'REPOS_ACTIF') {
    decision = _prudence[math.min(_prudence.indexOf(decision) + 1, _prudence.indexOf('REPOS_ACTIF'))];
  }
  return {'decision': decision, 'volume': decision == 'ADAPTEE' ? -0.25 : _volume[decision], 'alerte': alerte};
}

Json combinerDecisions(Json e) {
  final a = e['a']! as Map<String, Object?>;
  final b = e['b']! as Map<String, Object?>;
  final da = a['decision']! as String;
  final db = b['decision']! as String;
  final decision = _prudence.indexOf(da) >= _prudence.indexOf(db) ? da : db;
  final volumes = [a, b].where((x) => x['decision'] == decision).map((x) => _n(x['volume']));
  return {'decision': decision, 'volume': volumes.reduce(math.min)};
}

Json repriseJeune(Json e) {
  final type = e['type'];
  final h = _n(e['heures']);
  final mode = type == 'sec'
      ? 'rehydratation'
      : (type == 'partiel' || h < 24 ? 'normale' : (h > 120 ? 'tres_progressive' : 'progressive'));
  return {'mode': mode, 'proteinesRepas': proteinesParRepas(_n(e['poids']))};
}

Json effetJeune(Json e) {
  final pendant = (e['pendant']! as List).map(_n).toList();
  final hors = (e['hors']! as List).map(_n).toList();
  final effet = _moyenne(pendant) - _moyenne(hors);
  double variance(List<double> xs) {
    if (xs.length < 2) return 0;
    final m = _moyenne(xs);
    return xs.fold<double>(0, (s, x) => s + math.pow(x - m, 2)) / (xs.length - 1);
  }

  final se = math.sqrt(
    (pendant.isEmpty ? 0 : variance(pendant) / pendant.length) + (hors.isEmpty ? 0 : variance(hors) / hors.length),
  );
  return {
    'effet': effet,
    'ic80': [effet - 1.2816 * se, effet + 1.2816 * se],
    'suffisant': pendant.length >= 6,
  };
}

/// Fonctions par nom (comme FONCTIONS côté TypeScript).
const Map<String, Json Function(Json)> fonctions = {
  'e1rm': e1rm,
  'chargeCible': chargeCible,
  'ajustementSerie': ajustementSerie,
  'seriesEfficaces': seriesEfficaces,
  'srpe': srpe,
  'trimp': trimp,
  'fcMax': fcMax,
  'fcCible': fcCible,
  'ratioAiguChronique': ratioAiguChronique,
  'kcalMet': kcalMet,
  'scoreSommeil': scoreSommeil,
  'zScore': zScore,
  'bmr': bmr,
  'tdeeInitial': tdeeInitial,
  'poidsLisse': poidsLisse,
  'tdeeAdaptatif': tdeeAdaptatif,
  'verdictEnergie': verdictEnergie,
  'kcalMacros': kcalMacros,
  'ciblesMacros': ciblesMacros,
  'nutrimentsPlat': nutrimentsPlat,
  'scoreForme': scoreForme,
  'ajustementSeance': ajustementSeance,
  'penteE1rm': penteE1rm,
  'verdictProgression': verdictProgression,
  'contexteDefavorable': contexteDefavorable,
  'phaseJeune': phaseJeune,
  'decisionJeune': decisionJeune,
  'combinerDecisions': combinerDecisions,
  'repriseJeune': repriseJeune,
  'effetJeune': effetJeune,
};
