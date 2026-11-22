# Conformité, sécurité, licences

## Données de santé (RGPD)

Le sommeil, la fréquence cardiaque, le poids, l'alimentation, le jeûne et les **convictions religieuses** (module foi) sont des **catégories particulières de données** (RGPD, article 9).

- **Consentement explicite**, séparé par catégorie (santé, foi), révocable.
- Hébergement **dans l'UE**. Le serveur Coolify doit être chez un hébergeur européen.
- **Export** complet (JSON) et **suppression** du compte en un geste.
- Minimisation : le module foi ne stocke que ce que l'utilisateur saisit lui-même.
- API tierces : permissions fines (OAuth), révocables, journal des accès.
- L'hébergement HDS (hébergeur de données de santé) n'est en principe pas exigé pour une app de bien-être hors parcours de soin. **À faire valider par un juriste** avant le lancement commercial.

## Pas un dispositif médical

- Formulation « bien-être et performance ». Aucun diagnostic, aucune promesse thérapeutique.
- Avertissement à l'inscription et dans le module jeûne.

## Sécurité de l'utilisateur

| Garde-fou | Règle |
|---|---|
| Questionnaire avant le premier jeûne long (> 24 h) | Diabète, grossesse ou allaitement, troubles du comportement alimentaire, médicaments, moins de 18 ans : jeûne long déconseillé, avis médical |
| Jeûne à l'eau > 72 h | Alerte, avis médical recommandé |
| Jeûne sec | Limité à 24 h dans l'app, aucun effort intense |
| Symptômes (vertiges, palpitations, confusion, malaise) | Arrêt immédiat de la séance, conseil de rompre le jeûne |
| Déficit calorique | Jamais au-delà de 25 % du TDEE, jamais sous le métabolisme de base |
| Séances générées par l'IA | Validées par le moteur : progression max par semaine, blessures déclarées, volume max |
| Mineurs | Pas de jeûne, pas de déficit proposé |

## Licences des données

| Source | Licence | Obligations |
|---|---|---|
| Open Food Facts | ODbL (base), CC BY-SA (photos) | Citer la source, repartager les améliorations de la base |
| Ciqual 2020 (ANSES), 2 298 aliments intégrés (`0007_ciqual.sql`, généré par `docs/science/ciqual/generer.py`) | Licence ouverte Etalab, CC BY 4.0 sur Zenodo | Citer « Anses. 2020. Table de composition nutritionnelle des aliments Ciqual » ; la source est affichée à côté de chaque aliment |
| Démonstrations d'exercices | Produites avec ChatGPT pour Cresco (deux positions par exercice, `docs/design/medias/exercices`) | Ne jamais récupérer les vidéos d'autres plateformes |

## Marques tierces

Les liens vidéo (par exemple Basic-Fit) sont **ajoutés par l'utilisateur**. Cresco n'utilise ni le nom ni le logo d'une salle et n'intègre pas leurs vidéos sans accord.

## Stores

Abonnements via les achats intégrés Apple et Google (RevenueCat). Pas de lien de paiement externe dans l'app.
