import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Firebase web configuration for the SHOW client (project myanmar-health-9d171).
/// Web API keys are not secrets — they identify the project, not authorize it.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform => web;

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCx-P2V-WDVHgUu-Vyd2fVsiJBnfdP3jVk',
    appId: '1:545541480868:web:3fd90036bcfd510f89a131',
    messagingSenderId: '545541480868',
    projectId: 'myanmar-health-9d171',
    authDomain: 'myanmar-health-9d171.firebaseapp.com',
    storageBucket: 'myanmar-health-9d171.firebasestorage.app',
    measurementId: 'G-ZBSXVXESPM',
  );
}
