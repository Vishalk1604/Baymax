/// Build-time configuration.
///
/// Values are injected by the Flutter tool, never typed into source:
///
///     flutter run --dart-define-from-file=.env
///     flutter build apk --dart-define-from-file=.env
///
/// `.env` is gitignored; copy `.env.example` to create it.
///
/// Anything compiled into the app can be extracted from the APK, so this only
/// keeps the key out of git. For a public release, move the LLM call behind a
/// server-side proxy (e.g. a Firebase Cloud Function) that holds the key.
class AppConfig {
  AppConfig._();

  /// API key for the LLM that reads symptom descriptions: an NVIDIA API key
  /// (`nvapi-…`, from build.nvidia.com) unless [llmBaseUrl] points elsewhere.
  static const String llmApiKey = String.fromEnvironment('BAYMAX_API_KEY');

  static bool get hasLlmKey => llmApiKey.isNotEmpty;

  /// Any OpenAI-compatible chat-completions endpoint. Default: NVIDIA's API.
  static const String llmBaseUrl = String.fromEnvironment(
    'BAYMAX_LLM_BASE_URL',
    defaultValue: 'https://integrate.api.nvidia.com/v1/chat/completions',
  );

  /// Model ID on that endpoint (copy it from the model's page on build.nvidia.com).
  static const String llmModel = String.fromEnvironment('BAYMAX_LLM_MODEL', defaultValue: 'nvidia/nemotron-3.5-bolt-e4b');

  /// Geoapify Places API key (OpenStreetMap data, free daily quota) for the
  /// clinic finder. Without it the app queries public Overpass servers, which
  /// are often overloaded.
  static const String geoapifyApiKey = String.fromEnvironment('GEOAPIFY_API_KEY');

  static bool get hasGeoapifyKey => geoapifyApiKey.isNotEmpty;

  // ── Local testing (no real Firebase project or API key needed) ──

  /// Connect Auth + Firestore to the Firebase Local Emulator Suite
  /// (`firebase emulators:start` in app/) instead of a real project.
  static const bool useFirebaseEmulator = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  /// Where the emulators run, as seen from the device. 10.0.2.2 is the host
  /// PC from inside the Android emulator; use the PC's LAN IP for a phone.
  static const String firebaseEmulatorHost =
      String.fromEnvironment('FIREBASE_EMULATOR_HOST', defaultValue: '10.0.2.2');

  /// Replace the LLM with a simple offline keyword matcher. TEST BUILDS ONLY:
  /// it understands far less than the real model.
  static const bool useOfflineSymptomMatcher = bool.fromEnvironment('BAYMAX_OFFLINE_AI');
}
