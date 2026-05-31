import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show kIsWeb;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    throw UnsupportedError('Firebase not configured for this platform.');
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCW7n3yCR5ep2I1cImredfeFtrF_-mCm9A',
    appId: '1:438378994669:web:563bc7f72999d1cffb65e4',
    messagingSenderId: '438378994669',
    projectId: 'acro-debate',
    authDomain: 'acro-debate.firebaseapp.com',
    databaseURL: 'https://acro-debate-default-rtdb.firebaseio.com',
    storageBucket: 'acro-debate.firebasestorage.app',
  );
}
