import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Firebase [GastroQR] project configuration.
class GastroQRFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCjywqW45yPsJG7uHxxa-ekBssmYTGq94A",
    appId: "1:524485753883:web:046be48cfa6c19840d0cbe",
    messagingSenderId: "524485753883",
    projectId: "gastroqr-5dcdb",
    authDomain: "gastroqr-5dcdb.firebaseapp.com",
    storageBucket: "gastroqr-5dcdb.firebasestorage.app",
    measurementId: "G-4EB0PFRP4J",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCjywqW45yPsJG7uHxxa-ekBssmYTGq94A",
    appId: "1:524485753883:android:c4b8d7a1e0b9c2f6d5e4a3",
    messagingSenderId: "524485753883",
    projectId: "gastroqr-5dcdb",
    storageBucket: "gastroqr-5dcdb.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyCjywqW45yPsJG7uHxxa-ekBssmYTGq94A",
    appId: "1:524485753883:ios:f1e2d3c4b5a69788d7c6b5",
    messagingSenderId: "524485753883",
    projectId: "gastroqr-5dcdb",
    storageBucket: "gastroqr-5dcdb.firebasestorage.app",
    iosBundleId: 'com.gastromind.app',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: "AIzaSyCjywqW45yPsJG7uHxxa-ekBssmYTGq94A",
    appId: "1:524485753883:ios:f1e2d3c4b5a69788d7c6b5", // Same as iOS usually
    messagingSenderId: "524485753883",
    projectId: "gastroqr-5dcdb",
    storageBucket: "gastroqr-5dcdb.firebasestorage.app",
    iosBundleId: 'com.gastromind.app',
  );
}
