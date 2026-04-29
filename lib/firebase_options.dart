// Generated from google-services.json — project: snap-01-a7b53
// Package: com.snap.it  |  Project number: 115132084252

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // ── Android — values taken directly from google-services.json ─────────────
  static const FirebaseOptions android = FirebaseOptions(
    apiKey:            'AIzaSyA4i8_jD-TA4pGl2nucbC3-Ewpn8JreUJU',
    appId:             '1:115132084252:android:fddd124ce3ff632212afd9',
    messagingSenderId: '115132084252',
    projectId:         'snap-01-a7b53',
    storageBucket:     'snap-01-a7b53.firebasestorage.app',
  );

  // ── iOS — add iOS app in Firebase console to get real values ──────────────
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey:            'AIzaSyA4i8_jD-TA4pGl2nucbC3-Ewpn8JreUJU',
    appId:             '1:115132084252:ios:placeholder',
    messagingSenderId: '115132084252',
    projectId:         'snap-01-a7b53',
    storageBucket:     'snap-01-a7b53.firebasestorage.app',
    iosBundleId:       'com.snap.it',
  );
}
