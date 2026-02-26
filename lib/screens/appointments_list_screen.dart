import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/places_service.dart';
import '../models/clinic_model.dart';
import 'clinic_slots_screen.dart';

class AppointmentsListScreen extends StatefulWidget {
  const AppointmentsListScreen({super.key});

  @override
  State<AppointmentsListScreen> createState() => _AppointmentsListScreenState();
}

class _AppointmentsListScreenState extends State<AppointmentsListScreen> {
  final PlacesService _placesService = PlacesService();
  
  List<ClinicModel> _allClinics = [];
  bool _isLoadingClinics = true;
  int _visibleCount = 3;

  @override
  void initState() {
    super.initState();
    _loadClinics();
  }

  Future<void> _loadClinics() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position position = await Geolocator.getCurrentPosition();
      final clinics = await _placesService.fetchNearbyClinics(
        position.latitude,
        position.longitude,
      );
      setState(() {
        _allClinics = clinics;
        _isLoadingClinics = false;
      });
    } catch (e) {
      setState(() => _isLoadingClinics = false);
    }
  }

  void _openDirections(double lat, double lng) async {
    final url = Uri.parse("https://www.google.com/maps/dir/?api=1&destination=$lat,$lng");
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('Book Appointment', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('NEARBY CLINICS', isDark),
            const SizedBox(height: 12),
            
            if (_isLoadingClinics)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_allClinics.isEmpty)
              const Text('No clinics found nearby.', style: TextStyle(color: Colors.grey, fontSize: 13))
            else
              SizedBox(
                height: 160,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: (_allClinics.length > _visibleCount ? _visibleCount + 1 : _allClinics.length),
                  itemBuilder: (context, index) {
                    if (index == _visibleCount) return _buildLoadMoreButton(isDark);
                    return _buildClinicHorizontalCard(_allClinics[index], isDark, theme);
                  },
                ),
              ),

            const SizedBox(height: 32),
            _buildSectionHeader('UPCOMING APPOINTMENTS', isDark),
            const SizedBox(height: 12),
            
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(user?.uid)
                  .collection('Appointments')
                  .orderBy('Time')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox.shrink();
                
                final now = DateTime.now();
                final allDocs = snapshot.data!.docs;
                
                final upcomingDocs = allDocs.where((doc) {
                  final time = (doc.get('Time') as Timestamp).toDate();
                  return time.isAfter(now);
                }).toList();

                if (upcomingDocs.isEmpty) {
                  return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('No upcoming appointments', style: TextStyle(color: Colors.grey, fontSize: 13))));
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: upcomingDocs.length,
                  itemBuilder: (context, index) {
                    final data = upcomingDocs[index].data() as Map<String, dynamic>;
                    final time = (data['Time'] as Timestamp).toDate();
                    return _buildAppointmentTile(data, time, isDark, theme, upcomingDocs[index].id, user!.uid);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(title, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[500], letterSpacing: 1.2));
  }

  Widget _buildClinicHorizontalCard(ClinicModel clinic, bool isDark, ThemeData theme) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(clinic.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(clinic.address, style: TextStyle(fontSize: 11, color: Colors.grey[600]), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text('${clinic.distance?.toStringAsFixed(1)} km away', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ClinicSlotsScreen(clinic: clinic))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF009688),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Book', style: TextStyle(fontSize: 11)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.near_me_outlined, size: 18, color: Colors.blue),
                onPressed: () => _openDirections(clinic.latitude, clinic.longitude),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadMoreButton(bool isDark) {
    return Container(
      width: 60,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(20)),
      child: IconButton(
        icon: const Icon(Icons.add_circle_outline, color: Colors.grey, size: 28),
        onPressed: () => setState(() => _visibleCount += 5),
      ),
    );
  }

  Widget _buildAppointmentTile(Map<String, dynamic> data, DateTime time, bool isDark, ThemeData theme, String docId, String userId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5), borderRadius: BorderRadius.circular(12)),
            child: Column(
              children: [
                Text(DateFormat('dd').format(time), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Text(DateFormat('MMM').format(time).toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data['clinicName'] ?? data['DoctorName'] ?? 'Clinic Visit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(DateFormat('hh:mm a').format(time), style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFDC2626), size: 16),
            onPressed: () async => await FirebaseFirestore.instance.collection('users').doc(userId).collection('Appointments').doc(docId).delete(),
          ),
        ],
      ),
    );
  }
}
