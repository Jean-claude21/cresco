import 'dart:async';

import 'package:cresco_app/app/app.locator.dart';
import 'package:cresco_app/ui/commun.dart';
import 'package:cresco_app/ui/messages.dart';
import 'package:cresco_data/cresco_data.dart' hide Json;
import 'package:cresco_ui/cresco_ui.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:stacked/stacked.dart';
import 'package:stacked_services/stacked_services.dart';

class ScanViewModel extends BaseViewModel {
  final CrescoApi _api = locator<CrescoApi>();
  final NavigationService _nav = locator<NavigationService>();
  final Messages _snack = locator<Messages>();

  Json? produit;
  String? erreur;
  String? _dernier;

  Future<void> detecte(String code) async {
    if (code == _dernier || isBusy) return;
    _dernier = code;
    erreur = null;
    await runBusyFuture(
      Future(() async {
        try {
          produit = await _api.alimentParCode(code);
        } on ErreurApi catch (e) {
          erreur = '${e.message} ($code)';
        }
      }),
    );
  }

  Future<void> manger(double masse) async {
    await _api.ajouterRepas({
      'type': 'repas',
      'portions': [
        {'alimentId': produit!['id'], 'masse': masse},
      ],
    });
    // Quitter l'écran d'abord : avec une barre de message ouverte, back() fermerait la barre
    // au lieu de l'écran (NavigationService s'appuie sur GetX).
    _nav.back<void>();
    _snack.afficher(
      message: 'Ajouté : ${entier(nombre(produit!['kcal100']) * masse / 100)} kcal',
      duration: const Duration(seconds: 2),
    );
  }
}

class ScanView extends StatefulWidget {
  const new({super.key});
  @override
  State<ScanView> createState() => _ScanViewState();
}

class _ScanViewState extends State<ScanView> {
  final _masse = TextEditingController(text: '100');

  @override
  void dispose() {
    _masse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ViewModelBuilder<ScanViewModel>.reactive(
      viewModelBuilder: ScanViewModel.new,
      builder: (context, vm, _) => Scaffold(
        appBar: AppBar(
          title: const Text('Scanner un aliment', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        body: Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(CrescoMesures.rayon),
                  child: MobileScanner(
                    onDetect: (capture) {
                      final code = capture.barcodes.firstOrNull?.rawValue;
                      if (code != null) unawaited(vm.detecte(code));
                    },
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
              child: vm.isBusy
                  ? const Chargement()
                  : vm.produit == null
                  ? Text(vm.erreur ?? 'Vise le code-barres du produit.', style: CrescoTextes.secondaire)
                  : CrescoCarte(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(vm.produit!['nom']! as String, style: CrescoTextes.titreCarte.copyWith(fontSize: 24)),
                          Text(
                            '${entier(vm.produit!['kcal100'])} kcal · ${decimal(vm.produit!['proteines100'])} g prot. · '
                            '${decimal(vm.produit!['glucides100'])} g gluc. · ${decimal(vm.produit!['lipides100'])} g lip. / 100 g',
                            style: CrescoTextes.secondaire,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _masse,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Quantité', suffixText: 'g'),
                          ),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () {
                              final m = double.tryParse(_masse.text.replaceAll(',', '.'));
                              if (m != null && m > 0) unawaited(vm.manger(m));
                            },
                            child: const Text('Ajouter à mon journal'),
                          ),
                          const SizedBox(height: 6),
                          const Text('Source : Open Food Facts (ODbL).', style: CrescoTextes.secondaire),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
