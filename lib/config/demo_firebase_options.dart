import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;

/// Options for the Firebase Local Emulator Suite (`USE_FIREBASE_EMULATOR`).
///
/// Kept apart from `lib/firebase_options.dart`, which `flutterfire configure`
/// regenerates for the real project. "demo-" project IDs are reserved for the
/// emulators: no real project can exist under this name, so test builds can
/// never send anything to production.
abstract final class DemoFirebaseOptions {
  static const String projectId = 'demo-baymax';

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:android:0000000000000000000000',
    messagingSenderId: '000000000000',
    projectId: projectId,
    storageBucket: '$projectId.appspot.com',
  );

  /// True for placeholder options (a "demo-" project), i.e. no real Firebase
  /// project has been connected with `flutterfire configure` yet.
  static bool isDemo(FirebaseOptions options) => options.projectId.startsWith('demo-');
}
