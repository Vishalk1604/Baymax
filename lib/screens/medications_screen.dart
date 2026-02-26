import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_medication_screen.dart';
import '../services/health_device_service.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        centerTitle: false,
        title: const Text('My Medications', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user?.uid)
            .collection('Medication')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allMedications = snapshot.data?.docs ?? [];
          final now = DateTime.now();

          // Filter out expired medications
          final activeMedications = allMedications.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
            if (createdAt == null) return true;

            final duration = data['Duration'] as int? ?? 0;
            if (duration == 0) return true;

            final expiryDate = createdAt.add(Duration(days: duration));
            return now.isBefore(expiryDate);
          }).toList();
          
          final manualMeds = activeMedications.where((doc) => (doc.get('Index') ?? 0) == 0).toList();
          final aiMeds = activeMedications.where((doc) => (doc.get('Index') ?? 0) > 0).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (aiMeds.isNotEmpty) ...[
                  _buildSectionHeader('ALGORITHM RECOMMENDATIONS', isDark),
                  const SizedBox(height: 12),
                  ...aiMeds.map((doc) => _MedicationRecommendationItem(
                    doc: doc, 
                    isDark: isDark, 
                    theme: theme,
                    userId: user!.uid,
                  )),
                  const SizedBox(height: 24),
                ],

                _buildSectionHeader('DAILY SCHEDULE', isDark),
                const SizedBox(height: 12),
                if (manualMeds.isEmpty)
                  _buildEmptyState('No scheduled medications. Tap + to add.', isDark)
                else
                  _UnifiedMedicationList(
                    medications: manualMeds,
                    userId: user!.uid,
                    isDark: isDark,
                    theme: theme,
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String msg, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Text(
          msg,
          style: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey, fontStyle: FontStyle.italic, fontSize: 13),
        ),
      ),
    );
  }
}

class _MedicationRecommendationItem extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final bool isDark;
  final ThemeData theme;
  final String userId;

  const _MedicationRecommendationItem({
    required this.doc,
    required this.isDark,
    required this.theme,
    required this.userId,
  });

  Future<void> _handleTakeMeds(BuildContext context, String medName) async {
    final healthService = HealthDeviceService();
    int signal = 0;
    final nameLower = medName.toLowerCase();
    
    if (nameLower.contains('paracetamol')) signal = 1;
    else if (nameLower.contains('cetirizine')) signal = 2;
    else if (nameLower.contains('ibuprofen')) signal = 3;
    else if (nameLower.contains('famotidine')) signal = 4;

    if (!healthService.isConnected) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          title: const Text('Device Not Connected', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Would you like to connect to the BayMax device or mark this medicine as taken manually?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Manual
              child: const Text('Mark Manual'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, false); // Connect
                await healthService.connectToBAYMAX();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white),
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    } else {
      await healthService.sendMedicationSignal(signal);
    }

    // Record in Firebase
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Medication')
        .doc(doc.id)
        .collection('Taken')
        .add({'Time': Timestamp.now()});
  }

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final medName = (data['Name'] ?? 'Unknown').toString();
    
    int hoursToWait = 24; 
    if (medName.toLowerCase().contains('paracetamol')) {
      hoursToWait = 5;
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Medication')
          .doc(doc.id)
          .collection('Taken')
          .orderBy('Time', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        bool canTake = true;
        String statusText = 'Ready';
        Duration? remaining;

        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final lastTaken = (snapshot.data!.docs.first.get('Time') as Timestamp).toDate();
          final nextAllowed = lastTaken.add(Duration(hours: hoursToWait));
          final now = DateTime.now();
          
          if (now.isBefore(nextAllowed)) {
            canTake = false;
            remaining = nextAllowed.difference(now);
            statusText = '${remaining.inHours}h ${remaining.inMinutes % 60}m';
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardTheme.color,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.rule_folder_outlined, size: 14, color: isDark ? Colors.white70 : Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'SYMPTOMS: ${data['Symptoms']?.toString().toUpperCase() ?? 'GENERAL'}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        letterSpacing: 1.0,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!canTake) Icon(Icons.timer_outlined, color: Colors.orange, size: 14),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      if (!canTake)
                        Text(
                          'Next in $statusText',
                          style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  SizedBox(
                    height: 36,
                    child: ElevatedButton(
                      onPressed: !canTake ? null : () => _handleTakeMeds(context, medName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(canTake ? 'Take Meds' : 'Locked', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _UnifiedMedicationList extends StatelessWidget {
  final List<QueryDocumentSnapshot> medications;
  final String userId;
  final bool isDark;
  final ThemeData theme;

  const _UnifiedMedicationList({
    required this.medications,
    required this.userId,
    required this.isDark,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchAllReminders(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final allSlots = snapshot.data!;
        
        allSlots.sort((a, b) {
          if (a['isTakenToday'] != b['isTakenToday']) {
            return a['isTakenToday'] ? 1 : -1;
          }
          final timeA = a['reminderTime'] as DateTime;
          final timeB = b['reminderTime'] as DateTime;
          return timeA.compareTo(timeB);
        });

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allSlots.length,
          itemBuilder: (context, index) {
            final slot = allSlots[index];
            return _MedicationTimeItem(
              userId: userId,
              medicationId: slot['medicationId'],
              reminderId: slot['reminderId'],
              medName: slot['medName'],
              dosage: slot['dosage'],
              foodRelation: slot['foodRelation'],
              reminderTime: slot['reminderTime'],
              isTakenToday: slot['isTakenToday'],
              compartment: slot['compartment'],
              isDark: isDark,
              theme: theme,
              onTap: () => _showEditSheet(context, slot['medicationId'], slot['medData']),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchAllReminders() async {
    List<Map<String, dynamic>> allSlots = [];
    final now = DateTime.now();

    for (var medDoc in medications) {
      final medData = medDoc.data() as Map<String, dynamic>;
      
      final reminders = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Medication')
          .doc(medDoc.id)
          .collection('Reminder')
          .get();

      final taken = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Medication')
          .doc(medDoc.id)
          .collection('Taken')
          .get();

      for (var remDoc in reminders.docs) {
        final remTime = (remDoc.get('time') as Timestamp).toDate();
        
        bool isTaken = taken.docs.any((tDoc) {
          final tTime = (tDoc.get('Time') as Timestamp).toDate();
          return tTime.year == now.year && tTime.month == now.month && tTime.day == now.day &&
                 tTime.hour == remTime.hour && tTime.minute == remTime.minute;
        });

        allSlots.add({
          'medicationId': medDoc.id,
          'reminderId': remDoc.id,
          'medName': medData['Name'],
          'dosage': medData['Dosage']?.toString() ?? '0',
          'foodRelation': medData['Food Relation'],
          'reminderTime': remTime,
          'isTakenToday': isTaken,
          'compartment': medData['Compartment'] ?? 0,
          'medData': medData,
        });
      }
    }
    return allSlots;
  }

  void _showEditSheet(BuildContext context, String medId, Map<String, dynamic> medData) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EditMedicationSheet(
        userId: userId,
        medicationId: medId,
        medData: medData,
        isDark: isDark,
        theme: theme,
      ),
    );
  }
}

class _MedicationTimeItem extends StatelessWidget {
  final String userId;
  final String medicationId;
  final String reminderId;
  final String medName;
  final String dosage;
  final String foodRelation;
  final DateTime reminderTime;
  final bool isTakenToday;
  final int compartment;
  final bool isDark;
  final ThemeData theme;
  final VoidCallback onTap;

  const _MedicationTimeItem({
    required this.userId,
    required this.medicationId,
    required this.reminderId,
    required this.medName,
    required this.dosage,
    required this.foodRelation,
    required this.reminderTime,
    required this.isTakenToday,
    required this.compartment,
    required this.isDark,
    required this.theme,
    required this.onTap,
  });

  Future<void> _handleTake(BuildContext context) async {
    final healthService = HealthDeviceService();
    int signal = compartment > 0 ? compartment : 0;
    
    // Fallback if compartment wasn't set (original med names)
    if (signal == 0) {
      final nameLower = medName.toLowerCase();
      if (nameLower.contains('paracetamol')) signal = 1;
      else if (nameLower.contains('cetirizine')) signal = 2;
      else if (nameLower.contains('ibuprofen')) signal = 3;
      else if (nameLower.contains('famotidine')) signal = 4;
    }

    if (!healthService.isConnected) {
      bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          title: const Text('Device Not Connected', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Connect to BayMax device to receive your medicine automatically, or mark this medicine as taken manually.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, true), // Manual
              child: const Text('Mark Manual'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context, false); // Connect
                await healthService.connectToBAYMAX();
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white),
              child: const Text('Connect'),
            ),
          ],
        ),
      );
      if (result != true) return;
    } else {
      await healthService.sendMedicationSignal(signal);
    }

    final now = DateTime.now();
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('Medication')
        .doc(medicationId)
        .collection('Taken')
        .add({
          'Time': Timestamp.fromDate(DateTime(now.year, now.month, now.day, reminderTime.hour, reminderTime.minute))
        });
  }

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat.jm().format(reminderTime);
    final now = DateTime.now();
    
    final scheduledToday = DateTime(now.year, now.month, now.day, reminderTime.hour, reminderTime.minute);
    final oneHourBefore = scheduledToday.subtract(const Duration(hours: 1));
    final oneHourAfter = scheduledToday.add(const Duration(hours: 1));
    
    bool isMissed = now.isAfter(oneHourAfter);
    bool isUpcoming = now.isBefore(oneHourBefore);
    bool canTakeNow = now.isAfter(oneHourBefore) && now.isBefore(oneHourAfter);

    String buttonText = 'Take';
    if (isTakenToday) buttonText = 'Taken';
    else if (isMissed) buttonText = 'Missed';
    else if (isUpcoming) buttonText = 'Upcoming';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: ListTile(
        onTap: onTap,
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          medName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A),
            decoration: isTakenToday ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text(
          '${dosage}mg • $timeString • $foodRelation',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600], fontSize: 11),
        ),
        trailing: SizedBox(
          height: 32,
          child: ElevatedButton(
            onPressed: (!canTakeNow || isTakenToday) ? null : () => _handleTake(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
              foregroundColor: isDark ? Colors.black : Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
              disabledForegroundColor: isMissed && !isTakenToday ? const Color(0xFFDC2626) : const Color(0xFF888888),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}

class _EditMedicationSheet extends StatefulWidget {
  final String userId;
  final String medicationId;
  final Map<String, dynamic> medData;
  final bool isDark;
  final ThemeData theme;

  const _EditMedicationSheet({
    required this.userId,
    required this.medicationId,
    required this.medData,
    required this.isDark,
    required this.theme,
  });

  @override
  State<_EditMedicationSheet> createState() => _EditMedicationSheetState();
}

class _EditMedicationSheetState extends State<_EditMedicationSheet> {
  late TextEditingController _dosageController;
  late String _selectedFood;
  late int _duration;
  late int _selectedCompartment;
  List<TimeOfDay> _reminderTimes = [];

  @override
  void initState() {
    super.initState();
    _dosageController = TextEditingController(text: widget.medData['Dosage']?.toString());
    _selectedFood = widget.medData['Food Relation'] ?? 'After Food';
    _duration = widget.medData['Duration'] ?? 0;
    _selectedCompartment = widget.medData['Compartment'] ?? 5;
    _loadReminderTimes();
  }

  Future<void> _loadReminderTimes() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('Medication')
        .doc(widget.medicationId)
        .collection('Reminder')
        .get();
    
    setState(() {
      _reminderTimes = snapshot.docs.map((doc) {
        final time = (doc.get('time') as Timestamp).toDate();
        return TimeOfDay(hour: time.hour, minute: time.minute);
      }).toList();
    });
  }

  Future<void> _updateMedication() async {
    // Validation: Check if another med is using this compartment
    final meds = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('Medication')
        .get();

    for (var doc in meds.docs) {
      if (doc.id != widget.medicationId) {
        final data = doc.data();
        // Check active medications only
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
        final duration = data['Duration'] as int? ?? 0;
        bool isActive = duration == 0 || (createdAt != null && DateTime.now().difference(createdAt).inDays < duration);
        
        if (isActive && data['Compartment'] == _selectedCompartment) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Compartment $_selectedCompartment is currently in use.')),
            );
          }
          return;
        }
      }
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('Medication')
        .doc(widget.medicationId)
        .update({
      'Dosage': int.tryParse(_dosageController.text) ?? 0,
      'Food Relation': _selectedFood,
      'Duration': _duration,
      'Compartment': _selectedCompartment,
    });

    final remindersRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('Medication')
        .doc(widget.medicationId)
        .collection('Reminder');
    
    final existingReminders = await remindersRef.get();
    for (var doc in existingReminders.docs) {
      await doc.reference.delete();
    }

    for (var time in _reminderTimes) {
      final now = DateTime.now();
      await remindersRef.add({
        'time': Timestamp.fromDate(DateTime(now.year, now.month, now.day, time.hour, time.minute))
      });
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _stopMedication() async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .collection('Medication')
        .doc(widget.medicationId)
        .update({'Duration': -1});
    if (mounted) Navigator.pop(context);
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (picked != null && !_reminderTimes.contains(picked)) {
      setState(() => _reminderTimes.add(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Edit ${widget.medData['Name']}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: widget.isDark ? Colors.white : Colors.black),
                ),
                IconButton(icon: Icon(Icons.close, color: widget.isDark ? Colors.white : const Color(0xFF1A1A1A)), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('DOSAGE (MG)'),
                      TextField(
                        controller: _dosageController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 14),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldLabel('COMPARTMENT'),
                      DropdownButtonFormField<int>(
                        value: _selectedCompartment,
                        dropdownColor: widget.isDark ? const Color(0xFF1C1C1C) : Colors.white,
                        items: [5, 6].map((v) => DropdownMenuItem(value: v, child: Text('$v', style: TextStyle(color: widget.isDark ? Colors.white : Colors.black)))).toList(),
                        onChanged: (v) => setState(() => _selectedCompartment = v!),
                        decoration: _inputDecoration(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildFieldLabel('FOOD RELATION'),
            DropdownButtonFormField<String>(
              value: _selectedFood,
              dropdownColor: widget.isDark ? const Color(0xFF1C1C1C) : Colors.white,
              style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 14),
              items: ['After Food', 'Before Food', 'With Food', 'No Preference']
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedFood = v!),
              decoration: _inputDecoration(),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildFieldLabel('REMINDER TIMES'),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add, size: 14),
                  label: const Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _reminderTimes.map((time) => Chip(
                label: Text(time.format(context), style: TextStyle(color: widget.isDark ? Colors.white : Colors.black, fontSize: 11)),
                onDeleted: () => setState(() => _reminderTimes.remove(time)),
                backgroundColor: widget.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                visualDensity: VisualDensity.compact,
              )).toList(),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _updateMedication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isDark ? Colors.white : const Color(0xFF1A1A1A),
                  foregroundColor: widget.isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: _stopMedication,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Stop Medication', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey, letterSpacing: 1.1)),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: widget.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    );
  }
}
