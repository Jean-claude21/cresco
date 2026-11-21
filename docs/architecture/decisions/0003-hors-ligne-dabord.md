# ADR-0003 : hors ligne d'abord

**Statut** : accepté (21/11/2026)

## Contexte
En salle, le réseau est souvent mauvais. Une séance ou un minuteur de jeûne ne doivent jamais dépendre du réseau.

## Décision
- L'app écrit d'abord dans sa base locale (Drift/SQLite), puis synchronise avec l'API.
- Les identifiants sont générés côté client (UUID v7).
- Conflits : les données saisies (séries, repas) sont en ajout seul ; pour les modèles et les préférences, la dernière écriture l'emporte, avec un historique.
- Les verdicts lourds (TDEE adaptatif, verdict hebdo, `J-EFFET`) sont calculés par le serveur, puis mis en cache sur l'appareil.

## Conséquences
- Lecteur de séance fiable partout.
- Logique de synchronisation à spécifier dès la fondation.
