import 'package:flutter/material.dart';

/// Barres de message de l'app, par le ScaffoldMessenger de Flutter.
///
/// Remplace le SnackbarService de stacked_services (GetX) : ses barres se comportent comme des routes,
/// si bien que le bouton retour fermait la barre au lieu de quitter l'écran.
class Messages {
  final GlobalKey<ScaffoldMessengerState> cle = GlobalKey<ScaffoldMessengerState>();

  void afficher({required String message, Duration duration = const Duration(seconds: 3)}) {
    cle.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message), duration: duration));
  }
}
