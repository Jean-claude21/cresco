import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/app/app.router.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart';
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:stacked_services/stacked_services.dart';

/// Bouton « + » : consigner une donnée en deux gestes.
Future<void> ouvrirSaisieRapide(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: CrescoCouleurs.calcaire,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Ajouter', style: CrescoTextes.titreCarte),
            const SizedBox(height: 12),
            _Action(
              Icons.qr_code_scanner,
              'Scanner un aliment',
              () => locator<NavigationService>().navigateTo<void>(Routes.scanView),
            ),
            _Action(Icons.bedtime_outlined, 'Ma nuit', () => _saisirNuit(context)),
            _Action(Icons.monitor_weight_outlined, 'Mon poids', () => _saisirNombre(context, 'Poids (kg)', 'poids')),
            _Action(
              Icons.straighten,
              'Tour de taille',
              () => _saisirNombre(context, 'Tour de taille (cm)', 'tour_taille'),
            ),
            _Action(Icons.favorite_border, 'VFC du matin (ms)', () => _saisirNombre(context, 'VFC rMSSD (ms)', 'vfc')),
            _Action(Icons.sentiment_satisfied_alt, 'Mon ressenti', () => _saisirRessenti(context)),
            _Action(
              Icons.nightlight_round,
              'Jeûne',
              () => locator<NavigationService>().navigateTo<void>(Routes.jeuneView),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Action extends StatelessWidget {
  const new(this.icone, this.libelle, this.onTap);
  final IconData icone;
  final String libelle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: CrescoCouleurs.sauge,
        child: Icon(icone, color: CrescoCouleurs.pin),
      ),
      title: Text(libelle, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).pop();
        onTap();
      },
    );
  }
}

void _confirmer(String message) => locator<Messages>().afficher(message: message, duration: const Duration(seconds: 2));

Future<void> _saisirNombre(BuildContext context, String libelle, String type) async {
  final controleur = TextEditingController();
  final valeur = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(libelle),
      content: TextField(
        controller: controleur,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.pop(context, double.tryParse(controleur.text.replaceAll(',', '.'))),
          child: const Text('Enregistrer'),
        ),
      ],
    ),
  );
  if (valeur == null || valeur <= 0) return;
  await locator<CrescoApi>().ajouterMesure(type, valeur);
  _confirmer('Enregistré');
}

Future<void> _saisirNuit(BuildContext context) async {
  final maintenant = DateTime.now();
  final coucher = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 23, minute: 0),
    helpText: 'Heure du coucher',
  );
  if (coucher == null || !context.mounted) return;
  final lever = await showTimePicker(
    context: context,
    initialTime: const TimeOfDay(hour: 7, minute: 0),
    helpText: 'Heure du lever',
  );
  if (lever == null) return;
  final dLever = DateTime(maintenant.year, maintenant.month, maintenant.day, lever.hour, lever.minute);
  var dCoucher = DateTime(maintenant.year, maintenant.month, maintenant.day, coucher.hour, coucher.minute);
  if (dCoucher.isAfter(dLever)) dCoucher = dCoucher.subtract(const Duration(days: 1));
  // Sans montre, on estime 92 % du temps au lit dormi (efficacité courante).
  final auLit = dLever.difference(dCoucher).inMinutes;
  await locator<CrescoApi>().ajouterNuit(dCoucher, dLever, (auLit * 0.92).round());
  _confirmer('Nuit enregistrée');
}

Future<void> _saisirRessenti(BuildContext context) async {
  var energie = 3;
  var courbatures = 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Comment te sens-tu ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Énergie : $energie / 5'),
            Slider(
              value: energie.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (v) => setState(() => energie = v.round()),
            ),
            Text('Courbatures : ${['aucune', 'légères', 'marquées', 'fortes'][courbatures]}'),
            Slider(
              value: courbatures.toDouble(),
              max: 3,
              divisions: 3,
              onChanged: (v) => setState(() => courbatures = v.round()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Enregistrer')),
        ],
      ),
    ),
  );
  if (ok != true) return;
  await locator<CrescoApi>().ajouterRessenti({'energie': energie, 'courbatures': courbatures});
  _confirmer('Ressenti enregistré');
}
