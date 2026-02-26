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
  int _selectedCompartment = 5; // Default to 5
  
  final List<String> _durations = ['Once', 'One Week', 'One Month', 'Custom'];
  final List<String> _foodRelations = ['After Food', 'Before Food', 'With Food', 'No Preference'];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _autoAssignCompartment();
  }

  Future<void> _autoAssignCompartment() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final meds = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Medication')
        .get();

    Set<int> occupied = {};
    for (var doc in meds.docs) {
      int? comp = doc.data()['Compartment'];
      if (comp != null) occupied.add(comp);
    }

    if (occupied.contains(5) && !occupied.contains(6)) {
      setState(() => _selectedCompartment = 6);
    } else {
      setState(() => _selectedCompartment = 5);
    }
  }

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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Validation: Check if compartment is already in use by another ACTIVE med
    final medsQuery = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('Medication')
        .where('Compartment', isEqualTo: _selectedCompartment)
        .get();

    if (medsQuery.docs.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Compartment $_selectedCompartment is already assigned to another medication.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      int durationDays = 0;
      switch (_selectedDuration) {
        case 'Once': durationDays = 1; break;
        case 'One Week': durationDays = 7; break;
        case 'One Month': durationDays = 30; break;
        case 'Custom': 
          durationDays = int.tryParse(_customDurationController.text) ?? 0;
          break;
      }

      final medicationDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('Medication')
          .add({
        'Name': _nameController.text.trim(),
        'Dosage': int.tryParse(_dosageController.text) ?? 0,
        'Food Relation': _selectedFoodRelation,
        'Duration': durationDays,
        'Compartment': _selectedCompartment,
        'Index': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      for (var time in _selectedTimes) {
        final now = DateTime.now();
        final reminderDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);

        await medicationDoc.collection('Reminder').add({
          'time': Timestamp.fromDate(reminderDateTime),
        });

        await NotificationService().scheduleNotification(
          id: (medicationDoc.id + time.toString()).hashCode,
          title: 'Medication Reminder',
          body: 'Take ${_nameController.text.trim()} from Compartment $_selectedCompartment',
          scheduledDate: reminderDateTime,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white, fontSize: 15)),
            ),
            const Text('Add Medication', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
            _isLoading 
              ? const SizedBox(width: 60, height: 20, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
              : TextButton(
                  onPressed: _saveMedication,
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 15)),
                ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildLabel('MEDICATION NAME', isDark),
            _buildTextField(_nameController, 'e.g. Paracetamol', isDark, Icons.medication),
            const SizedBox(height: 32),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('DOSAGE', isDark),
                      _buildTextField(_dosageController, '10', isDark, null, keyboardType: TextInputType.number),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('DEVICE COMPARTMENT', isDark),
                      _buildCompartmentSelector(isDark),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _buildLabel('FOOD RELATION', isDark),
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
                  selectedColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  labelStyle: TextStyle(
                    color: isSelected ? (isDark ? Colors.black : Colors.white) : (isDark ? Colors.white : Colors.black87),
                    fontSize: 13,
                    fontWeight: FontWeight.w600
                  ),
                  backgroundColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
                  showCheckmark: false,
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildLabel('REMINDER TIMES', isDark),
                TextButton.icon(
                  onPressed: () => _selectTime(context),
                  icon: Icon(Icons.add, size: 18, color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                  label: Text('Add Time', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A1A1A), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedTimes.map((time) {
                return Chip(
                  label: Text(time.format(context), style: TextStyle(color: isDark ? Colors.white : Colors.black87)),
                  onDeleted: _selectedTimes.length > 1 ? () {
                    setState(() => _selectedTimes.remove(time));
                  } : null,
                  deleteIconColor: const Color(0xFFDC2626),
                  backgroundColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                  side: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            _buildLabel('DURATION', isDark),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDuration,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                  items: _durations.map((d) => DropdownMenuItem(value: d, child: Text(d, style: TextStyle(color: isDark ? Colors.white : Colors.black87)))).toList(),
                  onChanged: (val) => setState(() => _selectedDuration = val!),
                ),
              ),
            ),
            if (_selectedDuration == 'Custom') ...[
              const SizedBox(height: 16),
              _buildTextField(_customDurationController, 'Number of days', isDark, null, keyboardType: TextInputType.number),
            ],

            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveMedication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Save Medication', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.grey[400] : const Color(0xFF888888), letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, IconData? icon, {TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
        prefixIcon: icon != null ? Icon(icon, color: isDark ? Colors.white : const Color(0xFF1A1A1A)) : null,
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.white : const Color(0xFF1A1A1A))),
      ),
    );
  }

  Widget _buildCompartmentSelector(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: _selectedCompartment,
          isExpanded: true,
          dropdownColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          items: [5, 6].map((int val) => DropdownMenuItem(value: val, child: Text('Comp. $val', style: TextStyle(color: isDark ? Colors.white : Colors.black87)))).toList(),
          onChanged: (val) => setState(() => _selectedCompartment = val!),
        ),
      ),
    );
  }
}
