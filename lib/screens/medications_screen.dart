import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'add_medication_screen.dart';

class MedicationsScreen extends StatelessWidget {
  const MedicationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Medications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
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
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final medications = snapshot.data?.docs ?? [];

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Ongoing Medications Section (Shows each medicine once)
                if (medications.isNotEmpty) ...[
                  const Text('Ongoing Medications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...medications.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
                    final durationDays = data['Duration'] ?? 0;
                    
                    // Calculate days remaining
                    final daysPassed = DateTime.now().difference(createdAt).inDays;
                    final daysRemaining = (durationDays - daysPassed).clamp(0, durationDays);

                    if (daysRemaining <= 0 && durationDays != 0) return const SizedBox.shrink();

                    return Card(
                      color: Colors.teal.withAlpha(10),
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const Icon(Icons.hourglass_bottom, color: Colors.teal),
                        title: Text(data['Name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(durationDays == 0 ? 'Permanent' : '$daysRemaining days remaining of $durationDays days'),
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 24),
                ],

                // 2. Daily Schedule Section
                const Text('Today\'s Schedule', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (medications.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Text('No medications added yet.'),
                    ),
                  )
                else
                  // For each medication, we need to show its reminder times
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: medications.length,
                    itemBuilder: (context, index) {
                      final medDoc = medications[index];
                      final medData = medDoc.data() as Map<String, dynamic>;
                      
                      return _MedicationScheduleGroup(
                        userId: user!.uid,
                        medicationId: medDoc.id,
                        medData: medData,
                      );
                    },
                  ),
                const SizedBox(height: 80),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MedicationScheduleGroup extends StatelessWidget {
  final String userId;
  final String medicationId;
  final Map<String, dynamic> medData;

  const _MedicationScheduleGroup({
    required this.userId,
    required this.medicationId,
    required this.medData,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      // Listen to the Reminder sub-collection for this specific medication
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Medication')
          .doc(medicationId)
          .collection('Reminder')
          .orderBy('time')
          .snapshots(),
      builder: (context, reminderSnapshot) {
        if (!reminderSnapshot.hasData) return const SizedBox.shrink();

        final reminders = reminderSnapshot.data!.docs;

        return Column(
          children: reminders.map((reminderDoc) {
            final reminderData = reminderDoc.data() as Map<String, dynamic>;
            final reminderTime = (reminderData['time'] as Timestamp).toDate();
            
            return _MedicationTimeItem(
              userId: userId,
              medicationId: medicationId,
              medName: medData['Name'] ?? 'Unknown',
              dosage: medData['Dosage']?.toString() ?? '0',
              foodRelation: medData['Food Relation'] ?? '',
              reminderTime: reminderTime,
            );
          }).toList(),
        );
      },
    );
  }
}

class _MedicationTimeItem extends StatelessWidget {
  final String userId;
  final String medicationId;
  final String medName;
  final String dosage;
  final String foodRelation;
  final DateTime reminderTime;

  const _MedicationTimeItem({
    required this.userId,
    required this.medicationId,
    required this.medName,
    required this.dosage,
    required this.foodRelation,
    required this.reminderTime,
  });

  @override
  Widget build(BuildContext context) {
    final timeString = DateFormat.jm().format(reminderTime);

    return StreamBuilder<QuerySnapshot>(
      // Listen to the Taken sub-collection for this medication
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('Medication')
          .doc(medicationId)
          .collection('Taken')
          .snapshots(),
      builder: (context, takenSnapshot) {
        final takenDocs = takenSnapshot.data?.docs ?? [];
        
        // Logic to check if *this specific reminder slot* was taken today.
        // Since we store all "Taken" events in one sub-collection, we match by time proximity 
        // or just count. A robust way is to check if any "Taken" timestamp is within 
        // a reasonable window of the reminder time today.
        bool isTakenToday = false;
        final now = DateTime.now();
        
        for (var doc in takenDocs) {
          final takenTime = (doc.get('Time') as Timestamp).toDate();
          if (takenTime.year == now.year && takenTime.month == now.month && takenTime.day == now.day) {
            // Match the taken event to this reminder slot based on hour/minute proximity
            if (takenTime.hour == reminderTime.hour && takenTime.minute == reminderTime.minute) {
              isTakenToday = true;
              break;
            }
          }
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: Checkbox(
              value: isTakenToday,
              onChanged: isTakenToday ? null : (val) async {
                if (val == true) {
                  // Mark as taken: Save to the Taken sub-collection
                  // We save the specific reminder time to help matching logic
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
              },
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            title: Text(
              medName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                decoration: isTakenToday ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text('${dosage}mg • $timeString • $foodRelation'),
            trailing: Icon(
              Icons.medication_liquid_sharp,
              color: isTakenToday ? Colors.grey : Colors.blue,
            ),
          ),
        );
      },
    );
  }
}
