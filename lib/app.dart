import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'data/repositories.dart';
import 'data/session.dart';
import 'features/auth/auth_gate.dart';
import 'services/settings_service.dart';

class BaymaxApp extends StatelessWidget {
  const BaymaxApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        Provider(create: (_) => AuthRepository()),
        Provider(create: (_) => ProfileRepository()),
        Provider(create: (_) => CheckupRepository()),
        Provider(create: (_) => MedicationRepository()),
        Provider(create: (_) => AppointmentRepository()),
        Provider(create: (_) => ClinicRepository()),
        ChangeNotifierProvider(
          create: (context) => Session(
            auth: context.read<AuthRepository>(),
            profiles: context.read<ProfileRepository>(),
            medications: context.read<MedicationRepository>(),
          ),
        ),
      ],
      child: Consumer<SettingsService>(
        builder: (context, settings, _) => MaterialApp(
          title: 'Baymax',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          home: const AuthGate(),
          builder: (context, child) {
            final media = MediaQuery.of(context);
            final dark = Theme.of(context).brightness == Brightness.dark;
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
              // Large accessibility text is honoured up to 1.35× so layouts
              // stay usable.
              child: MediaQuery(
                data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: 1.35)),
                child: child!,
              ),
            );
          },
        ),
      ),
    );
  }
}
