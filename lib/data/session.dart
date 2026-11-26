import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'models.dart';
import 'repositories.dart';

enum SessionStage { starting, signedOut, loadingProfile, needsProfile, ready, offlineNoProfile }

/// The signed-in user, their live profile and today's dose schedule.
///
/// Lives above the navigator so every screen (including pushed ones) can read
/// it. Everything user-specific is torn down and rebuilt when the account
/// changes, so nothing leaks between accounts.
class Session extends ChangeNotifier {
  Session({required this.auth, required this.profiles, required this.medications}) {
    _authSub = auth.userChanges.listen(_onUser, onError: (_) {
      stage = SessionStage.signedOut;
      notifyListeners();
    });
  }

  final AuthRepository auth;
  final ProfileRepository profiles;
  final MedicationRepository medications;

  SessionStage stage = SessionStage.starting;
  User? user;
  UserProfile? profile;
  DoseSchedule? doses;

  String? get uid => user?.uid;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  void _onUser(User? u) {
    // The first event always counts, so a signed-out launch (null → null)
    // still leaves the "starting" stage.
    final changed = stage == SessionStage.starting || u?.uid != user?.uid;
    user = u;
    if (!changed) {
      notifyListeners(); // display name etc.
      return;
    }
    _profileSub?.cancel();
    _profileSub = null;
    doses?.dispose();
    doses = null;
    profile = null;

    if (u == null) {
      stage = SessionStage.signedOut;
      notifyListeners();
      return;
    }
    stage = SessionStage.loadingProfile;
    doses = DoseSchedule(uid: u.uid, repository: medications);
    _profileSub = profiles.snapshots(u.uid).listen((snap) {
      if (snap.exists) {
        profile = UserProfile.fromDoc(u.uid, snap.data()!);
        stage = SessionStage.ready;
      } else {
        profile = null;
        // "Missing" from the offline cache may just mean no connection yet.
        stage = snap.metadata.isFromCache ? SessionStage.offlineNoProfile : SessionStage.needsProfile;
      }
      notifyListeners();
    }, onError: (Object e) {
      debugPrint('Profile stream failed: $e');
      stage = SessionStage.offlineNoProfile;
      notifyListeners();
    });
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    doses?.dispose();
    super.dispose();
  }
}
