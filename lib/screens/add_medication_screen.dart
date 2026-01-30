import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/notification_service.dart';

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _customDurationController = TextEditingController();
  
  final List<TimeOfDay> _selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
  String _selectedDuration = 'One Week';
  String _selectedFoodRelation = 'After Food';
  final List<String> _durations = ['Once', 'One Week', 'One Month', 'Custom'];
  final List<String> _foodRelations = ['After Food', 'Before Food', 'With Food', 'No Preference'];
  bool _isLoading = false;

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null && !_selectedTimes.contains(picked)) {
      setState(() {
        _selectedTimes.add(picked);
        _selectedTimes.sort((a, b) => a.hour.compareTo(b.hour) != 0 
            ? a.hour.compareTo(b.hour) 
            : a.minute.compareTo(b.minute));
      });
    }
  }

  Future<void> _saveMedication() async {
    if (_nameController.text.isEmpty || _dosageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in name and dosage')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      int durationDays = 0;
      switch (_selectedDuration) {
        case 'Once': durationDays = 1; break;
        case 'One Week': durationDays = 7; break;
        case 'One Month': durationDays = 30; break;
        case 'Custom': 
          durationDays = int.tryParse(_customDurationController.text) ?? 0;
          break;
      }

      // 1. Save the Medication document once
      final medicationDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Medication')
          .add({
        'Name': _nameController.text.trim(),
        'Dosage': int.tryParse(_dosageController.text) ?? 0,
        'Food Relation': _selectedFoodRelation,
        'Duration': durationDays,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. Save each reminder time in the sub-collection "Reminder"
      for (var time in _selectedTimes) {
        final now = DateTime.now();
        final reminderDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);

        await medicationDoc.collection('Reminder').add({
          'time': Timestamp.fromDate(reminderDateTime),
        });

        // Schedule Notification 30 mins before
        await NotificationService().scheduleNotification(
          id: (medicationDoc.id + time.toString()).hashCode,
          title: 'Medication Reminder',
          body: 'Take ${_nameController.text.trim()} in 30 mins ($_selectedFoodRelation)',
          scheduledDate: reminderDateTime,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        title: const Text('Add Medication'),
        actions: [
          _isLoading 
            ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
            : TextButton(
                onPressed: _saveMedication,
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Medication Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g. Paracetamol',
                prefixIcon: const Icon(Icons.medication),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dosage', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _dosageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '10',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Form', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        initialValue: 'Tablet',
                        items: ['Tablet', 'Capsule', 'Syrup', 'Injection'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) {},
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const Text('Food Relation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: _foodRelations.map((relation) {
                final isSelected = _selectedFoodRelation == relation;
                return ChoiceChip(
                  label: Text(relation),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedFoodRelation = relation);
                  },
                  selectedColor: Theme.of(context).colorScheme.primaryContainer,
                  labelStyle: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.black),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Reminder Times', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                TextButton.icon(
                  onPressed: () => _selectTime(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Time'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTimes.map((time) {
                return Chip(
                  label: Text(time.format(context)),
                  onDeleted: _selectedTimes.length > 1 ? () {
                    setState(() => _selectedTimes.remove(time));
                  } : null,
                  deleteIconColor: Colors.red[400],
                  backgroundColor: Colors.blue.withAlpha(20),
                  side: BorderSide.none,
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            const Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDuration,
                  isExpanded: true,
                  items: _durations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (val) => setState(() => _selectedDuration = val!),
                ),
              ),
            ),
            if (_selectedDuration == 'Custom') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customDurationController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Number of days',
                  labelText: 'Custom Duration (Days)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveMedication,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Save Medication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
