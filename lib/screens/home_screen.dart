import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'checkup_screen.dart';
import 'checkup_details_screen.dart';
import '../services/health_device_service.dart';
import '../services/settings_service.dart';

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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;
    final settings = Provider.of<SettingsService>(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text('Baymax', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: false,
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
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Baymax Device',
                          style: TextStyle(
                            fontWeight: FontWeight.w700, 
                            fontSize: 16, 
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                          ),
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
                        backgroundColor: _isConnected 
                            ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5))
                            : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                        foregroundColor: _isConnected 
                            ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
                            : (isDark ? Colors.black : Colors.white),
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
              
              Text(
                'Quick Actions', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w700, 
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                )
              ),
              const SizedBox(height: 16),

              _buildActionCard(
                'Health Check-Up',
                'Start a new health screening',
                isDark,
                () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckUpScreen()));
                },
              ),

              const SizedBox(height: 32),
              Text(
                'Overview', 
                style: TextStyle(
                  fontSize: 18, 
                  fontWeight: FontWeight.w700, 
                  color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                )
              ),
              const SizedBox(height: 16),

              // Live Overview Section linked to Firestore
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .doc(user?.uid)
                    .collection('Checkups')
                    .orderBy('TimeStamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Card(
                      color: theme.cardTheme.color,
                      child: const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(
                          child: Text(
                            'No check-up data yet. Start your first one!',
                            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ),
                    );
                  }

                  final lastCheckup = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                  final timestamp = lastCheckup['TimeStamp'] as dynamic;
                  String dateStr = 'Recent';
                  if (timestamp != null) {
                    dateStr = DateFormat('MMM dd, yyyy').format(timestamp.toDate());
                  }

                  return Column(
                    children: [
                      // Last Check-up Card
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => CheckupDetailsScreen(checkup: lastCheckup)),
                          );
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Card(
                          color: theme.cardTheme.color,
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Last Check-up', 
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700, 
                                        fontSize: 16, 
                                        color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                                      )
                                    ),
                                    Text(dateStr, style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  child: Divider(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0), height: 1),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(settings.formatTemp((lastCheckup['Temp'] as num).toDouble()), 'Temp', isDark),
                                    _buildStatItem('${lastCheckup['HeartRate']} BPM', 'Heart Rate', isDark),
                                    _buildStatItem('${lastCheckup['SpO2']}%', 'SpO2', isDark),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      if (snapshot.data!.docs.length > 1) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'PAST CHECK-UPS', 
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.bold, 
                              color: isDark ? Colors.grey[400] : const Color(0xFF888888),
                              letterSpacing: 1.2,
                            )
                          ),
                        ),
                        const SizedBox(height: 12),
                        // List other checkups
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: snapshot.data!.docs.length - 1,
                          itemBuilder: (context, index) {
                            final checkup = snapshot.data!.docs[index + 1].data() as Map<String, dynamic>;
                            final ts = checkup['TimeStamp'] as dynamic;
                            String d = 'Unknown Date';
                            String t = '';
                            if (ts != null) {
                              d = DateFormat('MMM dd, yyyy').format(ts.toDate());
                              t = DateFormat('hh:mm a').format(ts.toDate());
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => CheckupDetailsScreen(checkup: checkup)),
                                  );
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.cardTheme.color,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              d, 
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700, 
                                                fontSize: 15, 
                                                color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                                              )
                                            ),
                                            Text(t, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            settings.formatTemp((checkup['Temp'] as num).toDouble()), 
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600, 
                                              fontSize: 14, 
                                              color: isDark ? Colors.grey[300] : const Color(0xFF1A1A1A)
                                            )
                                          ),
                                          Text(
                                            '${checkup['HeartRate']} BPM', 
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500, 
                                              fontSize: 12, 
                                              color: Color(0xFF888888)
                                            )
                                          ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      const Icon(Icons.chevron_right, color: Color(0xFF888888), size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(String title, String subtitle, bool isDark, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C1C1C) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title, 
                    style: TextStyle(
                      fontWeight: FontWeight.w700, 
                      fontSize: 16, 
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                    )
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle, 
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.w400)
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: isDark ? Colors.white : const Color(0xFF1A1A1A), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, bool isDark) {
    return Column(
      children: [
        Text(
          value, 
          style: TextStyle(
            fontWeight: FontWeight.w700, 
            fontSize: 18, 
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)
          )
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
