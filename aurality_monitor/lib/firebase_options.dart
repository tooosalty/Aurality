// PLACEHOLDER: Run `flutterfire configure` to generate this file automatically.
// Replace every TODO value below with the actual values from your Firebase project.
// See: https://firebase.flutter.dev/docs/cli/

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  // TODO: Replace with values from your google-services.json / GoogleService-Info.plist
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO_WEB_API_KEY',
    appId: 'TODO_WEB_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    storageBucket: 'TODO_PROJECT_ID.appspot.com',
    databaseURL: 'https://TODO_PROJECT_ID-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO_ANDROID_API_KEY',
    appId: 'TODO_ANDROID_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    storageBucket: 'TODO_PROJECT_ID.appspot.com',
    databaseURL: 'https://TODO_PROJECT_ID-default-rtdb.firebaseio.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'TODO_IOS_API_KEY',
    appId: 'TODO_IOS_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    storageBucket: 'TODO_PROJECT_ID.appspot.com',
    databaseURL: 'https://TODO_PROJECT_ID-default-rtdb.firebaseio.com',
    iosBundleId: 'com.yourcompany.aurityMonitor',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'TODO_MACOS_API_KEY',
    appId: 'TODO_MACOS_APP_ID',
    messagingSenderId: 'TODO_SENDER_ID',
    projectId: 'TODO_PROJECT_ID',
    storageBucket: 'TODO_PROJECT_ID.appspot.com',
    databaseURL: 'https://TODO_PROJECT_ID-default-rtdb.firebaseio.com',
    iosBundleId: 'com.yourcompany.aurityMonitor',
  );
}
