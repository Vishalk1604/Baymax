import 'package:flutter/material.dart';

class AppointmentBookingScreen extends StatelessWidget {
  const AppointmentBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Book Appointment'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Doctor Selection
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Doctor', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search doctors...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.grey[100],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDoctorItem(context, 'Dr. Sarah Wilson', 'Cardiologist', '4.9', 'https://i.pravatar.cc/150?u=sarah'),
                  _buildDoctorItem(context, 'Dr. John Miller', 'General Practitioner', '4.8', 'https://i.pravatar.cc/150?u=john'),
                ],
              ),
            ),

            // Section 2: Date & Time Picker
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Date & Time', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  // Placeholder for Calendar
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Text('Calendar View Placeholder')),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: [
                      _buildTimeChip('9:00 AM'),
                      _buildTimeChip('10:30 AM', isSelected: true),
                      _buildTimeChip('1:00 PM'),
                      _buildTimeChip('3:30 PM'),
                    ],
                  ),
                ],
              ),
            ),

            // Section 3: Reason for Visit
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Reason for Visit', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(label: const Text('Routine Checkup'), selected: true, onSelected: (b) {}),
                      ChoiceChip(label: const Text('Follow-up'), selected: false, onSelected: (b) {}),
                      ChoiceChip(label: const Text('Consultation'), selected: false, onSelected: (b) {}),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Additional notes (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100), // Space for bottom button
          ],
        ),
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, spreadRadius: 1)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: \$50.00', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('Oct 28, 10:30 AM', style: TextStyle(color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Confirm Appointment'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorItem(BuildContext context, String name, String specialty, String rating, String imageUrl) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Row(
          children: [
            Text(specialty),
            const SizedBox(width: 8),
            const Icon(Icons.star, size: 14, color: Colors.amber),
            Text(rating, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: ElevatedButton(
          onPressed: () {},
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          child: const Text('Select'),
        ),
      ),
    );
  }

  Widget _buildTimeChip(String time, {bool isSelected = false}) {
    return Chip(
      label: Text(time),
      backgroundColor: isSelected ? Colors.teal : Colors.grey[200],
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
    );
  }
}
