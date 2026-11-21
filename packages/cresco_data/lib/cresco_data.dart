/// Accès aux données Cresco : l'app est un client de l'API publique (ADR « l'API d'abord »).
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

typedef Json = Map<String, Object?>;

/// Adresse de l'API : `--dart-define=CRESCO_API=…`, sinon le staging.
const apiParDefaut = String.fromEnvironment(
  'CRESCO_API',
  defaultValue: 'https://cresco-staging.169.58.86.123.sslip.io',
);

class ErreurApi implements Exception {
  new(this.status, this.message);
  final int status;
  final String message;
  bool get horsLigne => status == 0;
  @override
  String toString() => message;
}

/// Jeton et adresse du serveur, conservés sur l'appareil.
class Session {
  new(this._prefs);
  final SharedPreferences _prefs;

  static Future<Session> charger() async => Session(await SharedPreferences.getInstance());

  String? get jeton => _prefs.getString('jeton');
  String get api => _prefs.getString('api') ?? apiParDefaut;
  bool get connecte => jeton != null;

  Future<void> enregistrer(String jeton) => _prefs.setString('jeton', jeton);
  Future<void> changerApi(String url) => _prefs.setString('api', url.replaceAll(RegExp(r'/$'), ''));
  Future<void> deconnecter() => _prefs.remove('jeton');

  Json? cache(String cle) {
    final brut = _prefs.getString('cache:$cle');
    return brut == null ? null : jsonDecode(brut) as Json;
  }

  Future<void> mettreEnCache(String cle, Object? valeur) => _prefs.setString('cache:$cle', jsonEncode(valeur));

  List<Json> get enAttente => (_prefs.getStringList('attente') ?? const []).map((s) => jsonDecode(s) as Json).toList();
  Future<void> _ecrireAttente(List<Json> l) => _prefs.setStringList('attente', l.map(jsonEncode).toList());
  Future<void> ajouterEnAttente(Json requete) => _ecrireAttente([...enAttente, requete]);
  Future<void> viderAttente(int n) => _ecrireAttente(enAttente.skip(n).toList());
}

/// Client HTTP de l'API Cresco. Les lectures importantes sont mises en cache pour le hors ligne ;
/// les écritures de séance et de repas partent en file d'attente si le réseau manque.
class CrescoApi {
  new(this.session, {http.Client? client}) : _http = client ?? http.Client();
  final Session session;
  final http.Client _http;

  Future<Object?> requete(String methode, String route, {Object? corps, bool authentifie = true}) async {
    final uri = Uri.parse('${session.api}$route');
    final entetes = {
      'Content-Type': 'application/json',
      if (authentifie && session.jeton != null) 'Authorization': 'Bearer ${session.jeton}',
    };
    http.Response res;
    try {
      final req = http.Request(methode, uri)..headers.addAll(entetes);
      if (corps != null) req.body = jsonEncode(corps);
      res = await http.Response.fromStream(await _http.send(req).timeout(const Duration(seconds: 20)));
    } on Exception {
      throw ErreurApi(0, 'Pas de connexion au serveur');
    }
    final texte = utf8.decode(res.bodyBytes);
    final donnees = texte.isEmpty ? null : jsonDecode(texte);
    if (res.statusCode >= 400) {
      final message = donnees is Map && donnees['erreur'] is String
          ? donnees['erreur']! as String
          : 'Erreur ${res.statusCode}';
      throw ErreurApi(res.statusCode, message);
    }
    return donnees;
  }

  Future<Json> _lireAvecCache(String cle, String route) async {
    try {
      final r = (await requete('GET', route))! as Json;
      await session.mettreEnCache(cle, r);
      return r;
    } on ErreurApi catch (e) {
      final c = session.cache(cle);
      if (e.horsLigne && c != null) return c;
      rethrow;
    }
  }

  Future<void> _ecrireOuMettreEnAttente(String route, Json corps) async {
    try {
      await requete('POST', route, corps: corps);
    } on ErreurApi catch (e) {
      if (!e.horsLigne) rethrow;
      await session.ajouterEnAttente({'route': route, 'corps': corps});
    }
  }

  /// Renvoie au serveur ce qui a été saisi hors ligne. Retourne le nombre envoyé.
  Future<int> synchroniser() async {
    final attente = session.enAttente;
    var envoyes = 0;
    for (final r in attente) {
      try {
        await requete('POST', r['route']! as String, corps: r['corps']);
        envoyes++;
      } on ErreurApi catch (e) {
        if (e.horsLigne) break;
        envoyes++; // refus définitif du serveur : on ne bloque pas la file
      }
    }
    await session.viderAttente(envoyes);
    return envoyes;
  }

  // ----------------------------------------------------------------- Compte
  Future<void> inscription(String email, String motDePasse, String nom) async {
    final r =
        (await requete(
              'POST',
              '/v1/auth/inscription',
              corps: {'email': email, 'motDePasse': motDePasse, 'nom': nom},
              authentifie: false,
            ))!
            as Json;
    await session.enregistrer(r['jeton']! as String);
  }

  Future<void> connexion(String email, String motDePasse) async {
    final r =
        (await requete(
              'POST',
              '/v1/auth/connexion',
              corps: {'email': email, 'motDePasse': motDePasse},
              authentifie: false,
            ))!
            as Json;
    await session.enregistrer(r['jeton']! as String);
  }

  Future<Json> profil() => _lireAvecCache('profil', '/v1/moi');
  Future<Json> modifierProfil(Json patch) async => (await requete('PATCH', '/v1/moi', corps: patch))! as Json;
  Future<void> supprimerCompte() async {
    await requete('DELETE', '/v1/moi');
    await session.deconnecter();
  }

  // ----------------------------------------------------------------- Synthèses
  Future<Json> aujourdhui() => _lireAvecCache('aujourdhui', '/v1/aujourdhui');
  Future<Json> seanceDuJour() => _lireAvecCache('seance-du-jour', '/v1/seances/du-jour');
  Future<Json> progression() => _lireAvecCache('progression', '/v1/progression');

  /// Effective sets per muscle over the last 7 days (C-PERF-5), cached for offline use.
  Future<Json> muscleVolume() => _lireAvecCache('muscles', '/v1/muscles');
  Future<Json> energie() => _lireAvecCache('energie', '/v1/energie');

  // ----------------------------------------------------------------- Entraînement
  Future<List<Json>> exercices() async => ((await requete('GET', '/v1/exercices'))! as List).cast<Json>();
  Future<void> enregistrerSeance(Json seance) => _ecrireOuMettreEnAttente('/v1/seances', seance);
  Future<void> ajouterLienVideo(String exerciceId, String url) async =>
      await requete('POST', '/v1/exercices/$exerciceId/liens', corps: {'url': url});

  // ----------------------------------------------------------------- Corps et sommeil
  Future<void> ajouterMesure(String type, double valeur) =>
      _ecrireOuMettreEnAttente('/v1/mesures', {'type': type, 'valeur': valeur});
  Future<void> ajouterNuit(DateTime coucher, DateTime lever, int dormiMin) => _ecrireOuMettreEnAttente('/v1/nuits', {
    'coucher': coucher.toUtc().toIso8601String(),
    'lever': lever.toUtc().toIso8601String(),
    'dormiMin': dormiMin,
  });
  Future<void> ajouterRessenti(Json ressenti) => _ecrireOuMettreEnAttente('/v1/ressentis', ressenti);

  // ----------------------------------------------------------------- Nutrition
  Future<Json> alimentParCode(String code) async => (await requete('GET', '/v1/aliments?code=$code'))! as Json;
  Future<List<Json>> chercherAliments(String q) async =>
      ((await requete('GET', '/v1/aliments?q=${Uri.encodeQueryComponent(q)}'))! as List).cast<Json>();
  Future<Json> creerAliment(Json aliment) async => (await requete('POST', '/v1/aliments', corps: aliment))! as Json;
  Future<List<Json>> plats() async => ((await requete('GET', '/v1/plats'))! as List).cast<Json>();
  Future<Json> creerPlat(Json plat) async => (await requete('POST', '/v1/plats', corps: plat))! as Json;
  Future<void> ajouterRepas(Json repas) => _ecrireOuMettreEnAttente('/v1/repas', repas);

  // ----------------------------------------------------------------- Jeûne
  Future<List<Json>> jeunes() async => ((await requete('GET', '/v1/jeunes'))! as List).cast<Json>();
  Future<Json> demarrerJeune(Json jeune) async => (await requete('POST', '/v1/jeunes', corps: jeune))! as Json;
  Future<Json?> decisionJeune() async {
    try {
      return await _lireAvecCache('decision-jeune', '/v1/jeunes/en-cours/decision');
    } on ErreurApi catch (e) {
      if (e.status == 404) return null;
      rethrow;
    }
  }

  Future<void> terminerJeune(String id) async => await requete('POST', '/v1/jeunes/$id/terminer');
  Future<void> noterJeune(String id, String type, String valeur) =>
      _ecrireOuMettreEnAttente('/v1/jeunes/$id/evenements', {'type': type, 'valeur': valeur});
  Future<Json> effetJeune() async => (await requete('GET', '/v1/jeunes/effet'))! as Json;

  // ----------------------------------------------------------------- Jetons (IA, MCP)
  Future<Json> creerJeton(String nom, List<String> scopes) async =>
      (await requete('POST', '/v1/jetons', corps: {'nom': nom, 'scopes': scopes}))! as Json;
}
