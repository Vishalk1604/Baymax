import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'config/demo_firebase_options.dart';
import 'core/glass/glass_runtime.dart';
import 'features/auth/firebase_setup_screen.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(['Figtree'], await rootBundle.loadString('assets/fonts/OFL-Figtree.txt'));
  });

  final settings = SettingsService();
  await settings.load();
  await GlassRuntime.init();

  // Emulator test builds always use the "demo-" options, so they can never
  // reach the real project, even after `flutterfire configure`.
  final options =
      AppConfig.useFirebaseEmulator ? DemoFirebaseOptions.android : DefaultFirebaseOptions.currentPlatform;

  // No real Firebase project is configured yet: explain how to connect one
  // instead of failing on sign-in.
  if (DemoFirebaseOptions.isDemo(options) && !AppConfig.useFirebaseEmulator) {
    runApp(FirebaseSetupApp(settings: settings));
    return;
  }

  await Firebase.initializeApp(options: options);
  if (AppConfig.useFirebaseEmulator) {
    final host = AppConfig.firebaseEmulatorHost;
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  }
  await NotificationService().init();

  runApp(BaymaxApp(settings: settings));
}
