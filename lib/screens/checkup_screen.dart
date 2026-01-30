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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Health Check-Up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Device Connection Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardTheme.color,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                          size: 48,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _isConnected ? 'Baymax Device Connected' : 'Baymax Device Not Connected',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.w700, 
                            fontSize: 18, 
                            color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isConnected ? _statusMessage : 'Connect your device to start check-up',
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _handleConnect,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isConnected 
                                  ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5)) 
                                  : (isDark ? Colors.white : const Color(0xFF1A1A1A)),
                              foregroundColor: _isConnected 
                                  ? (isDark ? Colors.white : const Color(0xFF1A1A1A)) 
                                  : (isDark ? Colors.black : Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text(
                              _isConnected ? 'Disconnect' : 'Connect Device',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  Text(
                    'Measurements', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w700, 
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                    )
                  ),
                  const SizedBox(height: 16),
                  
                  // Real-time Data Display (3-column row)
                  Row(
                    children: [
                      Expanded(
                        child: _buildDataCard(
                          'Temp',
                          _lastReading != null ? '${_lastReading!.temperature.toStringAsFixed(1)}°F' : '--',
                          isDark,
                          theme
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataCard(
                          'HR',
                          _lastReading != null ? '${_lastReading!.heartRate} BPM' : '--',
                          isDark,
                          theme
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildDataCard(
                          'SpO2',
                          _lastReading != null ? '${_lastReading!.spo2}%' : '--',
                          isDark,
                          theme
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  // Take Readings button - Modern Style
                  if (!_isMeasuring)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _startMeasurement,
                        icon: Icon(_hasTakenReading ? Icons.refresh : Icons.play_arrow, size: 20),
                        label: Text(_hasTakenReading ? 'Retake Readings' : 'Take Readings'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                          foregroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 32),
                  Text(
                    'Observations', 
                    style: TextStyle(
                      fontSize: 16, 
                      fontWeight: FontWeight.w700, 
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A)
                    )
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    maxLines: 4,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: 'Describe how you feel...',
                      hintStyle: const TextStyle(color: Color(0xFF888888)),
                      filled: true,
                      fillColor: isDark ? const Color(0xFF1C1C1C) : Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          
          // Action Buttons - Sticky at bottom
          Container(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              border: Border(top: BorderSide(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_isMeasuring) ...[
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _hasTakenReading ? () {} : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        disabledBackgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
                        disabledForegroundColor: const Color(0xFF888888),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('Evaluate Health', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ] else ...[
                  LinearProgressIndicator(
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A), 
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5)
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => setState(() => _isMeasuring = false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildDataCard(String label, String value, bool isDark, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF888888), fontWeight: FontWeight.w600, letterSpacing: 1.1),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20, 
                fontWeight: FontWeight.w700, 
                color: isDark ? Colors.white : const Color(0xFF1A1A1A)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
