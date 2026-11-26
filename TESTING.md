# Testing Baymax locally

Firebase and the AI key are disconnected for now, so testing runs entirely on
your PC: the Firebase Local Emulator Suite stands in for Auth + Firestore and an
offline keyword matcher stands in for the symptom AI.

## 1. Unit tests (algorithm)

```powershell
flutter test
```

Covers vitals grading, red flags, contraindications, the decision engine,
dosing, the "already taking" ingredient check and course records.

## 2. Firebase emulators

Needs Node.js and `firebase-tools` (`npm install -g firebase-tools`).

```powershell
firebase emulators:start --project demo-baymax --import=./.emulator-data --export-on-exit=./.emulator-data
```

Leave out `--import` the first time (the folder doesn't exist yet). Stop with
Ctrl+C so the data is exported. The Emulator UI is at http://127.0.0.1:4000.

## 3. Run the app against the emulators

```powershell
flutter run --dart-define=USE_FIREBASE_EMULATOR=true --dart-define=BAYMAX_OFFLINE_AI=true
```

- `USE_FIREBASE_EMULATOR` connects Auth/Firestore to `10.0.2.2` (the host PC
  from the Android emulator). For a real phone add
  `--dart-define=FIREBASE_EMULATOR_HOST=<your PC's LAN IP>`.
- `BAYMAX_OFFLINE_AI` replaces the AI with a phrase matcher. **Test builds
  only**: it doesn't understand negation ("no fever" still matches "fever").
- Cleartext HTTP to the emulators is allowed in debug builds only
  (`android/app/src/debug`).

### Test account (emulator only)

| Email | Password |
|---|---|
| `tester@baymax.test` | `Baymax!2026` |

It exists only in the local Auth emulator data (`.emulator-data/`, gitignored).
Create it again with Sign up if that folder is deleted.

### Sample vitals

On the check-up's first step, tap the flask icon (or "Use sample") to enter
test mode and move the sliders, e.g. 38.6 °C → fever, 40.5 °C → emergency,
SpO₂ 88 % → emergency. Results saved in test mode are marked as test data.

## 4. Reconnecting the real services

Step by step in [`docs/SETUP_GUIDE.md`](../docs/SETUP_GUIDE.md): create the Firebase project,
`flutterfire configure`, deploy `firestore.rules`, put the NVIDIA and Geoapify keys in `.env`, then
build without the two test defines above. Emulator builds keep working afterwards: they always use
the demo options in `lib/config/demo_firebase_options.dart`.
