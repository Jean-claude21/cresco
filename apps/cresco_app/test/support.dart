import 'dart:convert';
import 'dart:io';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart' show maintenant;
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_app/ui/tabs.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Heure figée des captures : jeudi 15 janvier 2026, 13 h 30.
final heureDesCaptures = DateTime(2026, 1, 15, 13, 30);

/// Réponses de l'API, au format des services du serveur (apps/server/src/services.ts).
final reponses = <String, Object?>{
  '/v1/aujourdhui': {
    'streakDays': 12,
    'forme': {
      'valeur': 68,
      'confiance': 'haute',
      'composantes': {
        'sommeil': 72,
        'dormiMin': 365,
        'vfc': 42,
        'fcRepos': 54,
        'energie': 3,
        'ratioAiguChronique': 1.1,
      },
    },
    'seance': {
      'decision': {'decision': 'ADAPTEE', 'volume': -0.2},
      'raison': 'Volume réduit après une nuit courte',
      'nom': 'Haut du corps',
      'type': 'muscu',
    },
    'energie': {
      'tdee': 2600,
      'ciblesSuspendues': false,
      'cibles': {'kcal': 2150, 'proteines': 150, 'lipides': 72, 'glucides': 240},
      'jour': {'kcal': 1510, 'proteines': 94},
    },
    'jeune': null,
  },
  // Sessions of the screenshot week (Thursday 15 January 2026): Monday and Tuesday.
  '/v1/seances': [
    {'id': 's2', 'le': '2026-01-13T18:30:00Z', 'type': 'muscu', 'series': <Object>[]},
    {'id': 's1', 'le': '2026-01-12T18:30:00Z', 'type': 'muscu', 'series': <Object>[]},
  ],
  '/v1/gym': {
    'gym': {'id': 'g1', 'name': 'Basic-Fit Bastille', 'chain': 'Basic-Fit'},
    'equipment': ['exercise:leg-curl', 'exercise:presse-cuisses', 'material:halteres'],
    'catalog': [
      {'key': 'exercise:leg-curl', 'label': 'Leg curl', 'kind': 'machine'},
      {'key': 'exercise:presse-cuisses', 'label': 'Presse à cuisses', 'kind': 'machine'},
      {'key': 'exercise:tirage-vertical', 'label': 'Tirage vertical', 'kind': 'machine'},
      {'key': 'material:barre', 'label': 'Barres et disques', 'kind': 'free'},
      {'key': 'material:halteres', 'label': 'Haltères', 'kind': 'free'},
      {'key': 'material:tapis', 'label': 'Tapis de course', 'kind': 'cardio'},
    ],
    'presets': {
      'Basic-Fit': ['exercise:leg-curl', 'material:barre'],
    },
  },
  '/v1/modeles-seance': [
    {
      'id': '7b1c2a4e-0000-4000-8000-000000000001',
      'nom': 'Haut du corps',
      'type': 'muscu',
      'cree_par': 'ia',
      'contenu': {
        'blocs': [
          {
            'repeter': 3,
            'etapes': [
              {
                'exercice_id': 'developpe-couche-barre',
                'duree': {'reps': 8},
                'cible': {'rir': 2, 'charge_kg': 'auto'},
                'repos_s': 120,
              },
            ],
          },
        ],
      },
    },
  ],
  '/v1/muscles': {
    'rule': 'C-PERF-5',
    'days': 7,
    'guideline': 10,
    'muscles': [
      {'muscle': 'quadriceps', 'effectiveSets': 12},
      {
        'muscle': 'pectoraux',
        'effectiveSets': 8.5,
        'weeks': [6, 7, 6.5, 8.5],
        'trend': 'hausse',
        'recovery': {'pct': 69, 'heuresAvantPret': 11},
      },
      {'muscle': 'dos', 'effectiveSets': 6},
      {'muscle': 'epaules', 'effectiveSets': 4},
      {'muscle': 'triceps', 'effectiveSets': 3.5},
    ],
  },
  '/v1/seances/du-jour': {
    'decision': {'decision': 'ADAPTEE', 'volume': -0.2},
    'raison': 'Volume réduit après une nuit courte',
    'modele': {
      'nom': 'Haut du corps',
      'type': 'muscu',
      'blocs': [
        {
          'repeter': 2,
          'etapes': [
            {
              'exercice_id': 'developpe-couche-barre',
              'nom': 'Développé couché',
              'duree': {'reps': 8},
              'cible': {'rir': 2, 'charge_kg': 72.5},
              'repos_s': 150,
            },
          ],
        },
        {
          'repeter': 2,
          'etapes': [
            {
              'exercice_id': 'rowing-barre',
              'nom': 'Rowing barre',
              'duree': {'reps': 10},
              'cible': {'rir': 2, 'charge_kg': 60},
              'repos_s': 120,
            },
          ],
        },
      ],
    },
  },
  '/v1/exercices': [
    {
      'id': 'developpe-couche-barre',
      'nom': 'Développé couché',
      'consignes': 'Omoplates serrées, barre au bas des pectoraux, pieds ancrés.',
      'liens': <Object?>[],
      'muscles_primaires': ['pectoraux'],
      'muscles_secondaires': ['triceps', 'epaules'],
    },
    {
      'id': 'chest-press',
      'nom': 'Chest press',
      'consignes': 'Dos collé au dossier, poignées à hauteur de poitrine.',
      'liens': <Object?>[],
      'muscles_primaires': ['pectoraux'],
      'muscles_secondaires': ['triceps'],
    },
  ],
  '/v1/energie': {
    'bmr': 1780,
    'tdee': 2410,
    'source': 'adaptatif',
    'sousSaisie': false,
    'cibles': {'kcal': 2150, 'proteines': 150, 'lipides': 72, 'glucides': 240},
    'ciblesSuspendues': false,
    'jour': {'kcal': 1510, 'proteines': 94},
    'bilan': {'moyen7j': -260, 'verdict': 'deficit', 'confiance': 'moyenne', 'pct': -0.108},
  },
  '/v1/plats': [
    {
      'id': '00000000-0000-0000-0000-000000000101',
      'nom': 'Jollof de poulet',
      'nutriments': {'kcal100': 168, 'proteines100': 15.6},
      'portions': 4,
      'massePortion': 350,
      'tags': ['proteines'],
      'cree_par': 'utilisateur',
    },
    {
      'id': '00000000-0000-0000-0000-000000000102',
      'nom': 'Bowl saumon quinoa',
      'nutriments': {'kcal100': 152, 'proteines100': 9.5},
      'tags': ['proteines', 'rapide'],
      'cree_par': 'utilisateur',
    },
    {
      'id': '00000000-0000-0000-0000-000000000103',
      'nom': 'Omelette épinards',
      'nutriments': {'kcal100': 128, 'proteines100': 9.6},
      'tags': ['rapide', 'vegetarien'],
      'cree_par': 'utilisateur',
    },
    {
      'id': '00000000-0000-0000-0000-000000000104',
      'nom': 'Lentilles corail coco',
      'nutriments': {'kcal100': 112, 'proteines100': 5.3},
      'tags': ['vegetarien', 'daniel'],
      'cree_par': 'utilisateur',
    },
    {
      'id': '00000000-0000-0000-0000-000000000105',
      'nom': 'Poulet yassa',
      'nutriments': {'kcal100': 149, 'proteines100': 11.4},
      'tags': ['proteines'],
      'cree_par': 'utilisateur',
    },
    {
      'id': '00000000-0000-0000-0000-000000000106',
      'nom': 'Skyr fruits rouges',
      'nutriments': {'kcal100': 84, 'proteines100': 8},
      'tags': ['rapide', 'vegetarien'],
      'cree_par': 'utilisateur',
    },
  ],
  '/v1/progression': {
    'verdict': 'progression',
    'explication': 'Ta force estimée monte au rythme attendu pour ton niveau.',
    'seancesSemaine': 4,
    'objectifSeancesSemaine': 5,
    'record': {'exerciceId': 'chest-press', 'nom': 'Chest press', 'chargeKg': 60, 'reps': 8},
    'exercices': [
      {
        'nom': 'Développé couché',
        'dernier': 96.7,
        'pctParSemaine': 1.2,
        'points': [
          {'e1rm': 88},
          {'e1rm': 89.4},
          {'e1rm': 90.6},
          {'e1rm': 91.9},
          {'e1rm': 93.1},
          {'e1rm': 94.2},
          {'e1rm': 95.5},
          {'e1rm': 96.7},
        ],
      },
    ],
    'energie': {'moyen7j': -260, 'verdict': 'deficit', 'confiance': 'moyenne'},
    'poidsLisse': 73.8,
    'sommeilMoyenMin': 430,
  },
  '/v1/jeunes/en-cours/decision': {
    'jeune': {
      'id': '00000000-0000-0000-0000-000000000002',
      'type': 'intermittent',
      'motif': 'spirituel',
      'intention': 'Faire de la place au silence.',
      'debut': heureDesCaptures.toUtc().subtract(const Duration(hours: 17, minutes: 30)).toIso8601String(),
      'fin_prevue': heureDesCaptures.toUtc().add(const Duration(minutes: 30)).toIso8601String(),
      'heures': 17.5,
      'phase': 'bascule',
    },
    'decision': {'decision': 'ADAPTEE', 'volume': -0.25, 'alerte': null},
    'reprise': {'mode': 'normale', 'proteinesRepas': 30},
  },
  '/v1/moi': {
    'id': 'u1',
    'email': 'demo@cresco.test',
    'nom': 'Démo',
    'sexe': 'homme',
    'niveau': 'intermediaire',
    'objectif': 'maintien',
    'taille_cm': 180,
    'preferences': {
      'moduleFoi': true,
      'prioriteSpirituelle': false,
      'joursReposVerrouilles': <int>[0],
    },
  },
};

/// Prépare le localisateur avec une fausse API et les polices réelles (pour des captures lisibles).
Future<void> preparer() async {
  maintenant = () => heureDesCaptures;
  Tabs.instance.reset();
  TestWidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  SharedPreferences.setMockInitialValues({'jeton': 'cr_test'});
  await locator.reset();
  await setupLocator();
  final session = await Session.charger();
  final client = MockClient((requete) async {
    // Les écritures sont acceptées comme par le vrai serveur.
    if (requete.method != 'GET') return http.Response(jsonEncode({'id': 'cree'}), 201);
    final corps = reponses[requete.url.path];
    if (corps == null) return http.Response(jsonEncode({'erreur': 'Introuvable'}), 404);
    return http.Response.bytes(utf8.encode(jsonEncode(corps)), 200, headers: {'content-type': 'application/json'});
  });
  locator
    ..registerSingleton<Session>(session)
    ..registerSingleton<CrescoApi>(CrescoApi(session, client: client))
    ..registerSingleton<Messages>(Messages());
  await _chargerPolices();
}

Future<void> _chargerPolices() async {
  // Roboto et Material Icons (Apache 2.0, licences dans test/polices) : versionnées avec les tests
  // pour un rendu identique partout (le SDK Linux de la CI ne les fournit pas).
  const dossier = 'test/polices';
  Future<ByteData> lire(String f) async => ByteData.sublistView(await File('$dossier/$f').readAsBytes());
  // La police de titre embarquée par cresco_ui, sous le nom qu'utilise le thème.
  Future<ByteData> lirePaquet(String f) async =>
      ByteData.sublistView(await File('../../packages/cresco_ui/fonts/$f').readAsBytes());
  final serif = FontLoader(CrescoTextes.serif)
    ..addFont(lirePaquet('Gelasio[wght].ttf'))
    ..addFont(lirePaquet('Gelasio-Italic[wght].ttf'));
  await serif.load();
  final sans = FontLoader(CrescoTextes.sans)..addFont(lirePaquet('Inter[opsz,wght].ttf'));
  await sans.load();
  final condensed = FontLoader(CrescoTextes.condensed)
    ..addFont(lirePaquet('BarlowCondensed-Bold.ttf'))
    ..addFont(lirePaquet('BarlowCondensed-ExtraBold.ttf'));
  await condensed.load();
  for (final famille in ['Roboto']) {
    final loader = FontLoader(famille)
      ..addFont(lire('roboto-regular.ttf'))
      ..addFont(lire('roboto-bold.ttf'))
      ..addFont(lire('roboto-black.ttf'))
      ..addFont(lire('roboto-italic.ttf'));
    await loader.load();
  }
  final icones = FontLoader('MaterialIcons')..addFont(lire('materialicons-regular.otf'));
  await icones.load();
  for (final style in ['Regular', 'Bold']) {
    await (FontLoader('packages/cresco_ui/Phosphor$style')..addFont(lirePaquet('Phosphor-$style.ttf'))).load();
  }
}

/// Enveloppe un écran dans le thème Cresco, au format d'un iPhone (402 × 874 pt).
Widget enveloppe(Widget ecran) => MaterialApp(
  debugShowCheckedModeBanner: false,
  navigatorObservers: [TabsObserver()],
  builder: tabShell,
  theme: crescoTheme(fontFamily: 'Roboto'),
  home: ecran,
);

Future<void> taillerTelephone(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(402 * 2, 874 * 2)
    ..devicePixelRatio = 2;
  addTearDown(tester.view.reset);
}

/// Decodes every image on screen (coaches, photos, body masks) and the body label maps, so
/// screenshots and taps see them: image decoding is real I/O, outside the test's fake clock.
Future<void> chargerImages(WidgetTester t) async {
  await t.runAsync(() async {
    await BodyMap.precache();
    for (final e in find.byType(Image).evaluate()) {
      await precacheImage((e.widget as Image).image, e);
    }
  });
  await t.pump();
}
