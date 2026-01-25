import 'package:flutter/material.dart';

class AppointmentsListScreen extends StatelessWidget {
  const AppointmentsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Appointments'),
          actions: [
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: () {},
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildUpcomingTab(context),
            _buildPastTab(context),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAppointmentCard(
          context,
          'Oct 28, 2023',
          '10:30 AM',
          'Dr. Sarah Wilson',
          'Cardiologist',
          'https://i.pravatar.cc/150?u=sarah',
          isVirtual: true,
        ),
        _buildAppointmentCard(
          context,
          'Nov 05, 2023',
          '02:00 PM',
          'Dr. John Miller',
          'General Practitioner',
          'https://i.pravatar.cc/150?u=john',
          isVirtual: false,
        ),
      ],
    );
  }

  Widget _buildPastTab(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildAppointmentCard(
          context,
          'Sep 15, 2023',
          '11:00 AM',
          'Dr. Sarah Wilson',
          'Cardiologist',
          'https://i.pravatar.cc/150?u=sarah',
          isVirtual: false,
          isPast: true,
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(
    BuildContext context,
    String date,
    String time,
    String doctorName,
    String specialty,
    String imageUrl, {
    bool isVirtual = false,
    bool isPast = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(date.split(',')[0], style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(time, style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(specialty, style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                ),
                CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Icon(isVirtual ? Icons.videocam_outlined : Icons.location_on_outlined, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(isVirtual ? 'Virtual Consultation' : 'In-Person Visit', style: const TextStyle(fontSize: 12)),
                const Spacer(),
                if (!isPast) ...[
                  TextButton(onPressed: () {}, child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isVirtual ? Colors.teal : null,
                      foregroundColor: isVirtual ? Colors.white : null,
                    ),
                    child: Text(isVirtual ? 'Start Call' : 'Details'),
                  ),
                ] else
                  TextButton(onPressed: () {}, child: const Text('Rebook')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
