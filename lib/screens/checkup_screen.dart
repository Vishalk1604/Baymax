import 'package:flutter/material.dart';
import '../services/health_device_service.dart';

class CheckUpScreen extends StatefulWidget {
  const CheckUpScreen({super.key});

  @override
  State<CheckUpScreen> createState() => _CheckUpScreenState();
}

class _CheckUpScreenState extends State<CheckUpScreen> {
  final HealthDeviceService _healthService = HealthDeviceService();
  bool _isConnected = false;
  bool _isMeasuring = false;
  String _statusMessage = 'Ready to start';
  HealthReading? _lastReading;
  bool _hasTakenReading = false;

  @override
  void initState() {
    super.initState();
    _isConnected = _healthService.isConnected;
    _isMeasuring = _healthService.isMeasuring;
    _statusMessage = _healthService.measurementStatus;
    _lastReading = _healthService.lastReading;
    if (_lastReading != null) _hasTakenReading = true;

    _healthService.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
        });
      }
    });

    _healthService.statusStream.listen((status) {
      if (mounted) {
        setState(() {
          _statusMessage = status;
          _isMeasuring = _healthService.isMeasuring;
        });
      }
    });

    _healthService.readingStream.listen((reading) {
      if (mounted) {
        setState(() {
          _lastReading = reading;
          _hasTakenReading = true;
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

  void _startMeasurement() async {
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please connect the device first')),
      );
      return;
    }
    bool success = await _healthService.startMeasurement();
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send start command')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Health Check-Up'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  // Device Connection Rectangle
                  Center(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: _isConnected ? Colors.teal.withAlpha(50) : Colors.red.withAlpha(50)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(5),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                            size: 40,
                            color: _isConnected ? Colors.teal[300] : Colors.red[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isConnected ? 'Baymax Device Connected' : 'Baymax Device Not Connected',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isConnected ? _statusMessage : 'Connect your device to start check-up',
                            style: TextStyle(color: Colors.grey[600], fontSize: 13),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _handleConnect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected ? Colors.grey[200] : Colors.teal,
                              foregroundColor: _isConnected ? Colors.black87 : Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: Text(_isConnected ? 'Disconnect' : 'Connect Device'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Real-time Data Display (3-column row)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDataCard(
                          context,
                          'Temp',
                          _lastReading != null ? '${_lastReading!.temperature.toStringAsFixed(1)}°F' : '--',
                          Icons.thermostat,
                          _lastReading != null ? 'Normal' : 'Waiting',
                          _lastReading != null ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDataCard(
                          context,
                          'Heart Rate',
                          _lastReading != null ? '${_lastReading!.heartRate} BPM' : '--',
                          Icons.favorite,
                          _lastReading != null ? 'Normal' : 'Waiting',
                          _lastReading != null ? Colors.green : Colors.grey,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildDataCard(
                          context,
                          'SpO2',
                          _lastReading != null ? '${_lastReading!.spo2}%' : '--',
                          Icons.water_drop,
                          _lastReading != null ? 'Normal' : 'Waiting',
                          _lastReading != null ? Colors.green : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Take Readings button
                  if (!_isMeasuring)
                    Center(
                      child: TextButton.icon(
                        onPressed: _startMeasurement,
                        icon: Icon(_hasTakenReading ? Icons.refresh : Icons.play_arrow, size: 18),
                        label: Text(_hasTakenReading ? 'Retake Readings' : 'Take Readings'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.teal,
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  // "How are you feeling" text box
                  const Text(
                    'How are you feeling?',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Type your symptoms or mood here...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[200]!),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Action Buttons - Sticky at bottom
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isMeasuring) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _hasTakenReading ? () {} : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Evaluate Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _hasTakenReading ? () {} : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Save Results'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _hasTakenReading ? () {} : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Share'),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        // For simplicity, we just stop the UI state if needed, 
                        // though the device might continue until it finishes or is disconnected.
                        setState(() {
                          _isMeasuring = false;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red[400],
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Stop Check-Up', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCard(BuildContext context, String title, String value, IconData icon, String status, Color statusColor) {
    return Container(
      padding: const EdgeInsets.all(10.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 4),
              Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 4),
              Text(status, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
