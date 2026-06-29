// File generated manually based on google-services.json details.
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.windows:
        return web;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyBZZFzuC8dpTKYj-M7lQaU3T-W1rv8UOxQ',
    appId: '1:82684853945:web:e1d47fc1bbee1278602568',
    messagingSenderId: '82684853945',
    projectId: 'movie-de00a',
    authDomain: 'movie-de00a.firebaseapp.com',
    storageBucket: 'movie-de00a.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBZZFzuC8dpTKYj-M7lQaU3T-W1rv8UOxQ',
    appId: '1:82684853945:android:e1d47fc1bbee1278602568',
    messagingSenderId: '82684853945',
    projectId: 'movie-de00a',
    storageBucket: 'movie-de00a.firebasestorage.app',
  );
}
