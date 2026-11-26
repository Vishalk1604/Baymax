import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../baymax/models/baymax_models.dart';
import '../config/app_config.dart';
import '../services/medication_utils.dart';
import 'models.dart';

FirebaseFirestore get _db => FirebaseFirestore.instance;
DocumentReference<Map<String, dynamic>> _user(String uid) => _db.collection('users').doc(uid);

// ─────────────────────────────────────────────────────────────── Auth ──

class AuthRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;

  Stream<User?> get userChanges => _auth.userChanges();
  User? get currentUser => _auth.currentUser;

  // Passwords were always trimmed at sign-up; keep that so old accounts log in.
  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());

  Future<void> signUp({required String name, required String email, required String password}) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
    await cred.user?.updateDisplayName(name.trim());
  }

  Future<void> sendPasswordReset(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> signOut() => _auth.signOut();

  /// Re-authenticates, erases every document under users/{uid}, then deletes
  /// the account itself.
  Future<void> deleteAccount(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) throw StateError('Not signed in');
    await user.reauthenticateWithCredential(EmailAuthProvider.credential(email: user.email!, password: password.trim()));
    await _deleteUserData(user.uid);
    await user.delete();
  }

  Future<void> _deleteUserData(String uid) async {
    final root = _user(uid);
    final meds = await root.collection('Medication').get();
    for (final med in meds.docs) {
      await _deleteAll(med.reference.collection('Reminder'));
      await _deleteAll(med.reference.collection('Taken'));
    }
    await _deleteAll(root.collection('Medication'));
    await _deleteAll(root.collection('Checkups'));
    await _deleteAll(root.collection('Appointments'));
    await root.delete();
  }

  Future<void> _deleteAll(CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final page = await col.limit(400).get();
      if (page.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in page.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
    }
  }

  /// A sentence a person can act on, for any sign-in/up failure.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      return switch (error.code) {
        'invalid-email' => "That email address doesn't look right.",
        'user-disabled' => 'This account has been disabled.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is incorrect.',
        'email-already-in-use' => 'An account already exists for that email. Try signing in.',
        'weak-password' => 'Choose a stronger password.',
        'too-many-requests' => 'Too many attempts. Wait a moment and try again.',
        'network-request-failed' => 'No connection. Check your internet and try again.',
        'requires-recent-login' => 'Please sign in again to continue.',
        _ => error.message ?? 'Something went wrong. Please try again.',
      };
    }
    return 'Something went wrong. Please try again.';
  }
}

// ──────────────────────────────────────────────────────────── Profile ──

class ProfileRepository {
  /// Raw snapshots (with metadata) — the auth gate needs to know whether a
  /// "missing" profile came from the server or only from the offline cache.
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots(String uid) =>
      _user(uid).snapshots(includeMetadataChanges: true);

  Stream<UserProfile?> watch(String uid) =>
      _user(uid).snapshots().map((s) => s.exists ? UserProfile.fromDoc(uid, s.data()!) : null);

  Future<UserProfile?> get(String uid) async {
    final s = await _user(uid).get();
    return s.exists ? UserProfile.fromDoc(uid, s.data()!) : null;
  }

  Future<void> create(UserProfile p) =>
      _user(p.uid).set({...p.toMap(), 'createdAt': FieldValue.serverTimestamp()});

  /// Saves edits. Optional fields left empty are removed from the document,
  /// so clearing e.g. blood type actually clears it.
  Future<void> update(UserProfile p) {
    final data = p.toMap();
    return _user(p.uid).set({
      ...data,
      for (final key in const ['age', 'gender', 'blood', 'height', 'weight'])
        if (!data.containsKey(key)) key: FieldValue.delete(),
    }, SetOptions(merge: true));
  }
}

// ─────────────────────────────────────────────────────────── Check-ups ──

class CheckupRepository {
  CollectionReference<Map<String, dynamic>> _col(String uid) => _user(uid).collection('Checkups');

  Stream<List<CheckupRecord>> watch(String uid, {int limit = 60}) => _col(uid)
      .orderBy('TimeStamp', descending: true)
      .limit(limit)
      .snapshots()
      .map((q) => q.docs.map(CheckupRecord.fromDoc).toList());

  /// Saves a check-up and returns its sequence index (used to tag the
  /// medicines it recommends).
  Future<int> save(String uid, Map<String, dynamic> data) async {
    final last = await _col(uid).orderBy('Index', descending: true).limit(1).get();
    final next = last.docs.isEmpty ? 1 : ((last.docs.first.data()['Index'] as num?)?.toInt() ?? 0) + 1;
    await _col(uid).add({...data, 'Index': next, 'TimeStamp': FieldValue.serverTimestamp()});
    return next;
  }

  Future<void> delete(String uid, String id) => _col(uid).doc(id).delete();

  /// Number of saved check-ups (null if it can't be counted right now).
  Future<int?> count(String uid) async {
    try {
      return (await _col(uid).count().get()).count;
    } catch (_) {
      return null;
    }
  }
}

// ────────────────────────────────────────────────────────── Medicines ──

class MedicationRepository {
  CollectionReference<Map<String, dynamic>> _col(String uid) => _user(uid).collection('Medication');

  Stream<List<MedicationCourse>> watchCourses(String uid) => _col(uid).snapshots().map((q) {
        final list = q.docs.map(MedicationCourse.fromDoc).toList()
          ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
        return list;
      });

  Stream<List<TimeOfDay>> watchReminders(String uid, String courseId) =>
      _col(uid).doc(courseId).collection('Reminder').snapshots().map((q) {
        final times = <TimeOfDay>[];
        for (final d in q.docs) {
          final t = d.data()['time'];
          if (t is Timestamp) {
            final dt = t.toDate();
            times.add(TimeOfDay(hour: dt.hour, minute: dt.minute));
          }
        }
        times.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));
        return times;
      });

  Future<List<TimeOfDay>> reminders(String uid, String courseId) => watchReminders(uid, courseId).first;

  Stream<List<DateTime>> watchTaken(String uid, String courseId, {required DateTime since}) => _col(uid)
      .doc(courseId)
      .collection('Taken')
      .where('Time', isGreaterThanOrEqualTo: Timestamp.fromDate(since))
      .snapshots()
      .map((q) => q.docs.map((d) => d.data()['Time']).whereType<Timestamp>().map((t) => t.toDate()).toList()..sort());

  Future<void> add(
    String uid, {
    required String name,
    required int dosage,
    required String unit,
    required String foodRelation,
    required int durationDays,
    required int compartment,
    required List<TimeOfDay> times,
  }) async {
    final doc = await _col(uid).add({
      'Name': name.trim(),
      'Dosage': dosage,
      'Unit': unit,
      'Food Relation': foodRelation,
      'Duration': durationDays,
      'Compartment': compartment,
      'Index': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _writeTimes(doc, times);
  }

  Future<void> update(
    String uid,
    String courseId, {
    required String name,
    required int dosage,
    required String unit,
    required String foodRelation,
    required int durationDays,
    required int compartment,
    required List<TimeOfDay> times,
  }) async {
    final doc = _col(uid).doc(courseId);
    await doc.update({
      'Name': name.trim(),
      'Dosage': dosage,
      'Unit': unit,
      'Food Relation': foodRelation,
      'Duration': durationDays,
      'Compartment': compartment,
    });
    final existing = await doc.collection('Reminder').get();
    final batch = _db.batch();
    for (final d in existing.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
    await _writeTimes(doc, times);
  }

  Future<void> _writeTimes(DocumentReference<Map<String, dynamic>> doc, List<TimeOfDay> times) async {
    final now = DateTime.now();
    final batch = _db.batch();
    for (final t in times) {
      batch.set(doc.collection('Reminder').doc(), {
        'time': Timestamp.fromDate(DateTime(now.year, now.month, now.day, t.hour, t.minute)),
      });
    }
    await batch.commit();
  }

  Future<void> stop(String uid, String courseId) => _col(uid).doc(courseId).update({'Duration': -1});

  Future<void> recordDose(String uid, String courseId, DateTime at) =>
      _col(uid).doc(courseId).collection('Taken').add({'Time': Timestamp.fromDate(at)});

  /// Compartments held by medicines still being taken.
  Future<Set<int>> occupiedCompartments(String uid, {String? exceptId}) async {
    final q = await _col(uid).get();
    return q.docs
        .where((d) => d.id != exceptId && isMedicationActive(d.data()))
        .map((d) => (d.data()['Compartment'] as num?)?.toInt())
        .whereType<int>()
        .where((c) => c > 0)
        .toSet();
  }

  /// Names of courses still in progress.
  Future<Set<String>> activeNames(String uid) async {
    final q = await _col(uid).get();
    return q.docs.where((d) => isMedicationActive(d.data())).map((d) => '${d.data()['Name'] ?? ''}').toSet();
  }

  /// A three-day course added from a check-up recommendation.
  Future<void> addAssistantCourse(
    String uid, {
    required Medication medication,
    required DosingInfo dosing,
    required int checkupIndex,
    required String symptoms,
  }) {
    return _col(uid).add({
      'Name': medication.simpleName,
      'Dosage': 0,
      'DoseText': dosing.dose,
      'Food Relation': 'As advised',
      'Duration': 3,
      'Index': checkupIndex,
      'Compartment': medication.deviceCompartment,
      'Source': 'AI Recommendation',
      'Symptoms': symptoms,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

/// Live view of today's doses for the signed-in user: courses, their reminder
/// times and recent doses. Home and Medicines share one instance.
class DoseSchedule extends ChangeNotifier {
  DoseSchedule({required this.uid, required this.repository}) {
    _coursesSub = repository.watchCourses(uid).listen(_onCourses, onError: (Object e) {
      error = e;
      loading = false;
      notifyListeners();
    });
    // Re-evaluate "can take now / missed" windows and roll over at midnight.
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) => notifyListeners());
  }

  final String uid;
  final MedicationRepository repository;

  List<MedicationCourse> courses = const [];
  bool loading = true;
  Object? error;

  final Map<String, List<TimeOfDay>> _times = {};
  final Map<String, List<DateTime>> _taken = {};
  final Map<String, StreamSubscription<dynamic>> _subs = {};
  StreamSubscription<List<MedicationCourse>>? _coursesSub;
  Timer? _ticker;

  void _onCourses(List<MedicationCourse> list) {
    courses = list;
    loading = false;
    error = null;
    final now = DateTime.now();
    final wanted = list.where((c) => c.isActiveAt(now)).map((c) => c.id).toSet();
    for (final id in _subs.keys.where((k) => !wanted.contains(k.split('|').first)).toList()) {
      _subs.remove(id)?.cancel();
    }
    for (final id in wanted) {
      _subs.putIfAbsent('$id|times', () => repository.watchReminders(uid, id).listen((t) {
            _times[id] = t;
            notifyListeners();
          }));
      _subs.putIfAbsent('$id|taken', () {
        // Two days back covers "today" and the 24-hour dose locks.
        final since = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 1));
        return repository.watchTaken(uid, id, since: since).listen((t) {
          _taken[id] = t;
          notifyListeners();
        });
      });
    }
    notifyListeners();
  }

  List<MedicationCourse> get activeCourses => courses.where((c) => c.isActive).toList();

  List<TimeOfDay> timesFor(String courseId) => _times[courseId] ?? const [];

  /// Doses of [courseId] taken within the last 24 hours, newest first.
  List<DateTime> takenWithin24h(String courseId, {DateTime? now}) {
    final t = now ?? DateTime.now();
    return (_taken[courseId] ?? const [])
        .where((d) => t.difference(d) < const Duration(hours: 24))
        .toList()
      ..sort((a, b) => b.compareTo(a));
  }

  /// Scheduled doses today for the user's own medicines, by time.
  List<DoseSlot> todaySlots([DateTime? at]) {
    final now = at ?? DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final slots = <DoseSlot>[];
    for (final course in courses) {
      if (course.isAssistant || !course.isActiveAt(now)) continue;
      final takenToday = (_taken[course.id] ?? const []).where((d) => !d.isBefore(start));
      // A course added this afternoon has no "missed" morning dose. A pending
      // server timestamp (key present, value not yet set) means "just now".
      final added = course.createdAt ?? (course.raw.containsKey('createdAt') ? now : null);
      for (final t in timesFor(course.id)) {
        final time = DateTime(now.year, now.month, now.day, t.hour, t.minute);
        if (added != null && time.isBefore(added.subtract(const Duration(minutes: 1)))) continue;
        // A dose is recorded at its slot's scheduled time.
        final taken = takenToday.any((d) => d.hour == t.hour && d.minute == t.minute);
        slots.add(DoseSlot(course: course, time: time, taken: taken));
      }
    }
    slots.sort((a, b) => a.time.compareTo(b.time));
    return slots;
  }

  /// The next dose still to take today (current window first).
  DoseSlot? nextDose([DateTime? at]) {
    final now = at ?? DateTime.now();
    for (final s in todaySlots(now)) {
      if (!s.taken && !s.missedAt(now)) return s;
    }
    return null;
  }

  @override
  void dispose() {
    _coursesSub?.cancel();
    for (final s in _subs.values) {
      s.cancel();
    }
    _ticker?.cancel();
    super.dispose();
  }
}

// ──────────────────────────────────────────────────────── Appointments ──

class AppointmentRepository {
  CollectionReference<Map<String, dynamic>> _col(String uid) => _user(uid).collection('Appointments');

  Stream<List<Appointment>> watch(String uid) =>
      _col(uid).orderBy('Time').snapshots().map((q) => q.docs.map(Appointment.fromDoc).toList());

  Future<void> book(
    String uid, {
    required Clinic clinic,
    required DateTime time,
    String? reason,
    String? notes,
  }) {
    return _col(uid).add({
      'clinicId': clinic.id,
      'clinicName': clinic.name,
      'Time': Timestamp.fromDate(time),
      'status': 'Upcoming',
      if (clinic.address != null) 'address': clinic.address,
      if (clinic.phone != null) 'phone': clinic.phone,
      'lat': clinic.latitude,
      'lng': clinic.longitude,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> slotTaken(String uid, DateTime time) async {
    final q = await _col(uid).where('Time', isEqualTo: Timestamp.fromDate(time)).limit(1).get();
    return q.docs.isNotEmpty;
  }

  Future<void> cancel(String uid, String id) => _col(uid).doc(id).delete();
}

// ───────────────────────────────────────────────────────────── Clinics ──

class ClinicSearchException implements Exception {
  ClinicSearchException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Nearby care from OpenStreetMap (Overpass API).
///
/// Overpass rejects anonymous clients (HTTP 406) and throttles busy ones
/// (429), so requests identify the app and fall back across mirrors.
class ClinicRepository {
  ClinicRepository({http.Client? client, String? geoapifyKey})
      : _client = client ?? http.Client(),
        _geoapifyKey = geoapifyKey ?? AppConfig.geoapifyApiKey;

  final http.Client _client;
  final String _geoapifyKey;

  /// Geoapify (hosted OpenStreetMap places, needs a free key) answers first;
  /// the public Overpass servers are the fallback.
  static const _geoapifyCategories = {
    ClinicKind.hospital: 'healthcare.hospital',
    ClinicKind.clinic: 'healthcare.clinic_or_praxis',
    ClinicKind.doctors: 'healthcare.clinic_or_praxis',
    ClinicKind.dentist: 'healthcare.dentist',
    ClinicKind.pharmacy: 'healthcare.pharmacy',
  };

  static const _mirrors = [
    'https://overpass-api.de/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  /// The whole search gives up after this, however many mirrors are left:
  /// a person waiting for nearby care shouldn't wait a minute to hear "no".
  static const _deadline = Duration(seconds: 25);
  static const _userAgent = 'BaymaxHealthApp/1.0 (Flutter; nearby clinic finder)';

  static const _amenity = {
    ClinicKind.hospital: 'hospital',
    ClinicKind.clinic: 'clinic',
    ClinicKind.doctors: 'doctors',
    ClinicKind.dentist: 'dentist',
    ClinicKind.pharmacy: 'pharmacy',
  };
  static const _healthcare = {
    ClinicKind.hospital: 'hospital',
    ClinicKind.clinic: 'clinic',
    ClinicKind.doctors: 'doctor',
    ClinicKind.dentist: 'dentist',
    ClinicKind.pharmacy: 'pharmacy',
  };

  Future<List<Clinic>> nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 5,
    Set<ClinicKind> kinds = const {ClinicKind.hospital, ClinicKind.clinic, ClinicKind.doctors},
  }) async {
    final giveUpAt = DateTime.now().add(_deadline);
    if (_geoapifyKey.isNotEmpty) {
      try {
        return await _geoapify(latitude, longitude, radiusKm, kinds);
      } catch (e) {
        debugPrint('Geoapify search failed, trying Overpass: $e');
      }
    }
    return _overpass(latitude, longitude, radiusKm, kinds, giveUpAt);
  }

  Future<List<Clinic>> _geoapify(double lat, double lng, double radiusKm, Set<ClinicKind> kinds) async {
    final uri = Uri.https('api.geoapify.com', '/v2/places', {
      'categories': kinds.map((k) => _geoapifyCategories[k]!).toSet().join(','),
      'filter': 'circle:$lng,$lat,${(radiusKm * 1000).round()}',
      'bias': 'proximity:$lng,$lat',
      'limit': '60',
      'apiKey': _geoapifyKey,
    });
    final res = await _client.get(uri, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw ClinicSearchException('Geoapify returned ${res.statusCode}');
    return parseGeoapify(jsonDecode(res.body) as Map<String, dynamic>, lat, lng);
  }

  /// Geoapify GeoJSON → clinics, nearest first. Public for tests.
  static List<Clinic> parseGeoapify(Map<String, dynamic> data, double lat, double lng) {
    final seen = <String>{};
    final clinics = <Clinic>[];
    for (final f in (data['features'] as List? ?? const [])) {
      if (f is! Map) continue;
      final p = (f['properties'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final name = '${p['name'] ?? ''}'.trim();
      if (name.isEmpty) continue;
      final clat = (p['lat'] as num?)?.toDouble();
      final clng = (p['lon'] as num?)?.toDouble();
      if (clat == null || clng == null) continue;
      if (!seen.add('${name.toLowerCase()}@${clat.toStringAsFixed(3)},${clng.toStringAsFixed(3)}')) continue;

      final cats = [for (final c in (p['categories'] as List? ?? const [])) '$c'];
      final raw = ((p['datasource'] as Map?)?['raw'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final contact = (p['contact'] as Map?)?.cast<String, dynamic>() ?? const <String, dynamic>{};
      final kind = cats.contains('healthcare.hospital')
          ? ClinicKind.hospital
          : cats.contains('healthcare.dentist')
              ? ClinicKind.dentist
              : cats.contains('healthcare.pharmacy')
                  ? ClinicKind.pharmacy
                  : (raw['amenity'] == 'doctors' || raw['healthcare'] == 'doctor')
                      ? ClinicKind.doctors
                      : ClinicKind.clinic;
      String? text(Object? v) => v == null || '$v'.trim().isEmpty ? null : '$v'.trim();
      final meters = (p['distance'] as num?)?.toDouble() ?? Geolocator.distanceBetween(lat, lng, clat, clng);

      clinics.add(Clinic(
        id: 'geoapify/${p['place_id'] ?? '$clat,$clng'}',
        name: name,
        kind: kind,
        latitude: clat,
        longitude: clng,
        distanceKm: meters / 1000,
        address: text(p['address_line2']) ?? text(p['formatted']),
        phone: text(contact['phone']) ?? text(raw['phone']) ?? text(raw['contact:phone']),
        openingHours: text(p['opening_hours']) ?? text(raw['opening_hours']),
        emergency: raw['emergency'] == 'yes',
      ));
    }
    clinics.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return clinics;
  }

  Future<List<Clinic>> _overpass(
    double latitude,
    double longitude,
    double radiusKm,
    Set<ClinicKind> kinds,
    DateTime giveUpAt,
  ) async {
    final r = (radiusKm * 1000).round();
    final amen = kinds.map((k) => _amenity[k]).join('|');
    final care = kinds.map((k) => _healthcare[k]).join('|');
    final query = '[out:json][timeout:15];('
        'nwr["amenity"~"^($amen)\$"](around:$r,$latitude,$longitude);'
        'nwr["healthcare"~"^($care)\$"](around:$r,$latitude,$longitude);'
        ');out center 120;';

    String lastProblem = 'Clinic search is unavailable right now. Please try again shortly.';
    for (final mirror in _mirrors) {
      final left = giveUpAt.difference(DateTime.now());
      if (left < const Duration(seconds: 2)) break;
      try {
        final res = await _client
            .post(
              Uri.parse(mirror),
              headers: {'User-Agent': _userAgent, 'Accept': 'application/json'},
              body: {'data': query},
            )
            .timeout(left < const Duration(seconds: 12) ? left : const Duration(seconds: 12));
        if (const {429, 502, 503, 504}.contains(res.statusCode)) {
          lastProblem = 'The map service is busy. Try again in a minute.';
          continue;
        }
        if (res.statusCode != 200) {
          lastProblem = 'The map service returned an error (${res.statusCode}).';
          continue;
        }
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        return _parse(data, latitude, longitude);
      } on TimeoutException {
        lastProblem = 'The map service is taking too long right now.';
      } catch (e) {
        debugPrint('Overpass $mirror failed: $e');
        lastProblem = 'No connection to the map service. Check your internet and try again.';
      }
    }
    throw ClinicSearchException(lastProblem);
  }

  List<Clinic> _parse(Map<String, dynamic> data, double lat, double lng) {
    final seen = <String>{};
    final clinics = <Clinic>[];
    for (final e in (data['elements'] as List? ?? const [])) {
      if (e is! Map) continue;
      final tags = (e['tags'] as Map?)?.cast<String, dynamic>() ?? const {};
      final name = (tags['name'] ?? tags['operator'] ?? '').toString().trim();
      if (name.isEmpty) continue; // unnamed points aren't useful to book
      final center = e['center'] as Map?;
      final clat = (e['lat'] ?? center?['lat']) as num?;
      final clng = (e['lon'] ?? center?['lon']) as num?;
      if (clat == null || clng == null) continue;
      final key = '${name.toLowerCase()}@${clat.toStringAsFixed(3)},${clng.toStringAsFixed(3)}';
      if (!seen.add(key)) continue;

      final amenity = '${tags['amenity'] ?? ''}';
      final care = '${tags['healthcare'] ?? ''}';
      final kind = switch (amenity.isNotEmpty ? amenity : care) {
        'hospital' => ClinicKind.hospital,
        'dentist' => ClinicKind.dentist,
        'pharmacy' => ClinicKind.pharmacy,
        'doctors' || 'doctor' => ClinicKind.doctors,
        _ => ClinicKind.clinic,
      };
      final parts = [
        tags['addr:housenumber'],
        tags['addr:street'],
        tags['addr:suburb'] ?? tags['addr:district'],
        tags['addr:city'],
      ].whereType<String>().where((s) => s.trim().isNotEmpty).toList();
      final address = (tags['addr:full'] as String?) ?? (parts.isEmpty ? null : parts.join(', '));

      clinics.add(Clinic(
        id: '${e['type']}/${e['id']}',
        name: name,
        kind: kind,
        latitude: clat.toDouble(),
        longitude: clng.toDouble(),
        distanceKm: Geolocator.distanceBetween(lat, lng, clat.toDouble(), clng.toDouble()) / 1000,
        address: address,
        phone: (tags['phone'] ?? tags['contact:phone']) as String?,
        openingHours: tags['opening_hours'] as String?,
        emergency: tags['emergency'] == 'yes',
      ));
    }
    clinics.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return clinics;
  }
}
