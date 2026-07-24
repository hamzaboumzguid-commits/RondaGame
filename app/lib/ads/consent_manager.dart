import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Gère le consentement RGPD/UMP (User Messaging Platform) avant toute pub.
///
/// Flux Google recommandé :
///   1. requestConsentInfoUpdate — récupère l'état de consentement (géolocalisé
///      par le SDK : le formulaire n'apparaît que dans l'EEE / États régulés).
///   2. loadAndShowConsentFormIfRequired — affiche le formulaire si nécessaire.
///   3. on n'initialise MobileAds que si canRequestAds() est vrai.
///
/// Tout est encapsulé dans des gardes : un échec réseau (info update ou
/// chargement du formulaire) ne doit jamais faire tomber l'app ni bloquer le
/// démarrage. Hors EEE, requestConsentInfoUpdate revient en "notRequired" et on
/// initialise les pubs directement, sans aucun formulaire.
class ConsentManager {
  ConsentManager._();

  static bool _adsInitialized = false;

  /// Point d'entrée unique appelé au démarrage. N'attend jamais le réseau côté
  /// UI : lancez-la sans await depuis main().
  static Future<void> gatherConsentThenInitAds() async {
    try {
      await _requestConsentInfoUpdate();
      // Affiche le formulaire seulement s'il est requis (EEE). Ailleurs, no-op.
      await _loadAndShowConsentFormIfRequired();
    } catch (e) {
      // Réseau coupé, SDK indisponible, formulaire injoignable : on continue.
      // On tentera quand même d'initialiser les pubs ci-dessous ; le SDK ne
      // servira de pubs personnalisées que si le consentement le permet.
      debugPrint('Consentement UMP indisponible, on poursuit : $e');
    }

    bool canRequestAds;
    try {
      canRequestAds = await ConsentInformation.instance.canRequestAds();
    } catch (_) {
      // En cas d'échec de lecture, ne pas servir de pubs par prudence RGPD.
      canRequestAds = false;
    }

    if (canRequestAds) {
      await _initializeAds();
    }
  }

  static Future<void> _requestConsentInfoUpdate() {
    final completer = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!completer.isCompleted) completer.complete();
      },
      (error) {
        if (!completer.isCompleted) {
          completer.completeError(error.message);
        }
      },
    );
    return completer.future;
  }

  /// Le SDK expose une API à callback ; on l'attend via un Completer, et on
  /// remonte l'éventuelle erreur de formulaire pour la garde d'appel.
  static Future<void> _loadAndShowConsentFormIfRequired() {
    final completer = Completer<void>();
    ConsentForm.loadAndShowConsentFormIfRequired((formError) {
      if (completer.isCompleted) return;
      if (formError != null) {
        completer.completeError(formError.message);
      } else {
        completer.complete();
      }
    });
    return completer.future;
  }

  static Future<void> _initializeAds() async {
    if (_adsInitialized) return;
    _adsInitialized = true;
    await MobileAds.instance.initialize();
  }
}
