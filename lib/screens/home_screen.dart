import 'package:flutter/material.dart';
import 'appointment_booking_screen.dart';
import 'checkup_screen.dart';
import '../services/health_device_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HealthDeviceService _healthService = HealthDeviceService();
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _isConnected = _healthService.isConnected;
    _healthService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });
  }

  void _handleConnect() async {
    if (_isConnected) {
      _healthService.disconnect();
    } else {
      bool success = await _healthService.connectToBAYMAX();
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to connect to BAYMAX. Ensure it is paired.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('Baymax', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none_outlined, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Connection Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF0F0F0)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Baymax Device',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A1A)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isConnected ? 'Connected' : 'Disconnected',
                          style: TextStyle(
                            color: _isConnected ? Colors.green : const Color(0xFF888888),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _handleConnect,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isConnected ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A),
                        foregroundColor: _isConnected ? const Color(0xFF1A1A1A) : Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        _isConnected ? 'Disconnect' : 'Connect',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              const Text('Quick Actions', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 16),

              _buildActionCard(
                'Book Appointment',
                'Schedule a visit with a specialist',
                () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AppointmentBookingScreen()));
                },
              ),
              const SizedBox(height: 12),
              _buildActionCard(
                'Health Check-Up',
                'Start a new health screening',
                () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckUpScreen()));
                },
              ),

              const SizedBox(height: 32),
              const Text('Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 16),

              // Last Check-up Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Last Check-up', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A1A))),
                          const Text('Oct 24, 2023', style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Divider(color: Color(0xFFF0F0F0), height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('98.6°F', 'Temp'),
                          _buildStatItem('72 BPM', 'Heart Rate'),
                          _buildStatItem('120/80', 'BP'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A1A))),
                  const SizedBox(height: 4),
                  Text(subtitle, style: const TextStyle(color: Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.w400)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF1A1A1A), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
