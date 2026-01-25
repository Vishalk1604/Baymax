import 'dart:async';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'bluetooth_service.dart';

class HealthReading {
  final int heartRate;
  final int spo2;
  final double temperature;

  HealthReading({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
  });

  @override
  String toString() => 'HR: $heartRate bpm, SpO2: $spo2%, Temp: ${temperature.toStringAsFixed(2)}°C';
}

class HealthDeviceService {
  static final HealthDeviceService _instance = HealthDeviceService._internal();
  factory HealthDeviceService() => _instance;
  HealthDeviceService._internal() {
    _bluetoothService.messages.listen(_handleMessage);
  }

  final AppBluetoothService _bluetoothService = AppBluetoothService();
  
  final StreamController<HealthReading?> _readingController = StreamController<HealthReading?>.broadcast();
  Stream<HealthReading?> get readingStream => _readingController.stream;

  final StreamController<String> _statusController = StreamController<String>.broadcast();
  Stream<String> get statusStream => _statusController.stream;

  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStream => _connectionController.stream;

  HealthReading? lastReading;
  String measurementStatus = 'Idle';
  bool isMeasuring = false;

  bool get isConnected => _bluetoothService.isConnected;

  Future<bool> connectToBAYMAX() async {
    try {
      await _bluetoothService.requestPermissions();
      final devices = await _bluetoothService.getAvailableDevices();

      BluetoothDevice? baymaxDevice;
      for (var device in devices) {
        // Classic Bluetooth uses .name
        String? name = device.name;
        if (name == 'BAYMAX') {
          baymaxDevice = device;
          break;
        }
      }

      if (baymaxDevice == null) {
        _statusController.add('BAYMAX device not found. Please ensure it is paired in system settings.');
        return false;
      }

      bool connected = await _bluetoothService.connectToDevice(baymaxDevice);
      _connectionController.add(connected);
      if (connected) {
        _statusController.add('Connected to BAYMAX');
      }
      return connected;
    } catch (e) {
      _statusController.add('Connection error: $e');
      return false;
    }
  }

  Future<bool> startMeasurement() async {
    if (!_bluetoothService.isConnected) {
      _statusController.add('Not connected to device');
      return false;
    }

    isMeasuring = true;
    measurementStatus = 'Waiting...';
    _statusController.add(measurementStatus);

    bool sent = await _bluetoothService.sendCommand('start\n');
    return sent;
  }

  void _handleMessage(String message) {
    message = message.trim();
    if (message.isEmpty) return;

    if (message == 'ACK') {
      measurementStatus = 'Acknowledged, place finger on sensor';
    } else if (message.startsWith('STATUS:')) {
      String status = message.replaceFirst('STATUS:', '');
      if (status == 'HR_SPO2_MEASURING') {
        measurementStatus = 'Measuring Heart Rate & SpO2...';
      } else if (status == 'TEMP_MEASURING') {
        measurementStatus = 'Measuring Temperature...';
      }
    } else if (message.startsWith('DATA:')) {
      _parseData(message);
    } else if (message.startsWith('SUCCESS:')) {
      measurementStatus = 'Measurement Complete';
      isMeasuring = false;
    } else if (message.startsWith('ERROR:')) {
      String error = message.replaceFirst('ERROR:', '');
      measurementStatus = 'Error: $error';
      isMeasuring = false;
    }
    _statusController.add(measurementStatus);
  }

  void _parseData(String message) {
    try {
      String data = message.replaceFirst('DATA:', '');
      Map<String, String> values = {};
      List<String> pairs = data.split(',');

      for (String pair in pairs) {
        List<String> kv = pair.split('=');
        if (kv.length == 2) {
          values[kv[0].trim()] = kv[1].trim();
        }
      }

      if (values.containsKey('HR') && values.containsKey('SPO2') && values.containsKey('TEMP')) {
        lastReading = HealthReading(
          heartRate: int.parse(values['HR']!),
          spo2: int.parse(values['SPO2']!),
          temperature: double.parse(values['TEMP']!),
        );
        _readingController.add(lastReading);
      }
    } catch (e) {
      print('Error parsing data: $e');
    }
  }

  void disconnect() {
    _bluetoothService.disconnect();
    isMeasuring = false;
    measurementStatus = 'Disconnected';
    _statusController.add(measurementStatus);
    _connectionController.add(false);
  }

  void dispose() {
    _readingController.close();
    _statusController.close();
    _connectionController.close();
  }
}
