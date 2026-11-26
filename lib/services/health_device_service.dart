import 'dart:async';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import '../baymax/core/vital_thresholds.dart';
import 'bluetooth_service.dart';

class HealthReading {
  final int heartRate;
  final int spo2;

  /// Estimated BODY temperature in °C — what every threshold and screen uses.
  final double temperature;

  /// The raw forehead reading the device sent, kept so stored history can be
  /// recalibrated later. Null for manual / test-mode readings.
  final double? rawSensorTemperature;

  HealthReading({
    required this.heartRate,
    required this.spo2,
    required this.temperature,
    this.rawSensorTemperature,
  });

  @override
  String toString() => 'HR: $heartRate bpm, SpO2: $spo2%, Temp: ${temperature.toStringAsFixed(2)}°C';
}

/// Protocol (see docs/firmware/FLUTTER_INTEGRATION_GUIDE.md):
///   app → device: `start\n` (measure), `1`..`6\n` (dispense compartment)
///   device → app: `ACK`, `STATUS:<step>`, `DATA:HR=..,SPO2=..,TEMP=..`,
///                 `SUCCESS:<msg>`, `ERROR:<msg>`, `DISPENSED:<n>`
class HealthDeviceService {
  static final HealthDeviceService _instance = HealthDeviceService._internal();
  factory HealthDeviceService() => _instance;
  HealthDeviceService._internal() {
    _bluetoothService.messages.listen(_handleMessage);
    _bluetoothService.disconnected.listen((_) => _onLinkLost());
  }

  /// The device gives up after 60 s; allow a little extra for Bluetooth lag.
  static const Duration measurementTimeout = Duration(seconds: 75);

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
  bool _gotReadingThisRun = false;
  Timer? _measurementTimer;

  bool get isConnected => _bluetoothService.isConnected;

  Future<bool> connectToBAYMAX() async {
    try {
      if (!await _bluetoothService.requestPermissions()) {
        _setStatus('Baymax needs the “Nearby devices” permission. Allow it in Settings → Apps → Baymax → Permissions.');
        return false;
      }
      if (!await _bluetoothService.ensureEnabled()) {
        _setStatus('Turn on Bluetooth to connect to your Baymax.');
        return false;
      }
      final devices = await _bluetoothService.getAvailableDevices();

      BluetoothDevice? baymaxDevice;
      for (var device in devices) {
        String? name = device.name;
        if (name == 'BAYMAX') {
          baymaxDevice = device;
          break;
        }
      }

      if (baymaxDevice == null) {
        _setStatus('BAYMAX isn’t paired yet. Pair it in your phone’s Bluetooth settings, then tap Connect.');
        return false;
      }

      bool connected = await _bluetoothService.connectToDevice(baymaxDevice);
      _connectionController.add(connected);
      if (connected) {
        _setStatus('Connected to BAYMAX');
      }
      return connected;
    } catch (e) {
      _setStatus('Connection error: $e');
      return false;
    }
  }

  Future<bool> startMeasurement() async {
    if (!_bluetoothService.isConnected) {
      _setStatus('Not connected to device');
      return false;
    }

    isMeasuring = true;
    _gotReadingThisRun = false;
    _setStatus('Starting measurement...');

    final sent = await _bluetoothService.sendCommand('start\n');
    if (!sent) {
      _finishMeasurement('Could not reach the device. Try reconnecting.');
      return false;
    }

    _measurementTimer?.cancel();
    _measurementTimer = Timer(measurementTimeout, () {
      if (isMeasuring) _finishMeasurement('Measurement timed out. Please try again.');
    });
    return true;
  }

  /// Sends a dispense command for compartment 1–6. Returns false (and sends
  /// nothing) for any other value — compartment 0 means "no compartment".
  Future<bool> sendMedicationSignal(int compartment) async {
    if (compartment < 1 || compartment > 6) return false;
    if (!_bluetoothService.isConnected) return false;
    return await _bluetoothService.sendCommand('$compartment\n');
  }

  void _handleMessage(String message) {
    message = message.trim();
    if (message.isEmpty) return;

    if (message == 'ACK') {
      _setStatus('Place your finger on the sensor');
    } else if (message.startsWith('STATUS:')) {
      final status = message.substring('STATUS:'.length);
      if (status == 'HR_SPO2_MEASURING') {
        _setStatus('Measuring heart rate & SpO₂ — keep your finger still');
      } else if (status == 'TEMP_MEASURING') {
        _setStatus('Measuring temperature — hold your forehead near the sensor');
      }
    } else if (message.startsWith('DATA:')) {
      _parseData(message);
    } else if (message.startsWith('SUCCESS:')) {
      // Older firmware also answers dispense commands with SUCCESS:, so only
      // treat it as the end of a measurement while one is running.
      if (isMeasuring) {
        _finishMeasurement(_gotReadingThisRun ? 'Measurement complete' : 'Measurement finished without a valid reading');
      }
    } else if (message.startsWith('DISPENSED:')) {
      _setStatus('Medicine dispensed');
    } else if (message.startsWith('ERROR:')) {
      final error = message.substring('ERROR:'.length);
      if (isMeasuring) {
        _finishMeasurement('Error: $error');
      } else {
        _setStatus('Error: $error');
      }
    }
  }

  void _parseData(String message) {
    final values = <String, String>{};
    for (final pair in message.substring('DATA:'.length).split(',')) {
      final kv = pair.split('=');
      if (kv.length == 2) values[kv[0].trim().toUpperCase()] = kv[1].trim();
    }

    final hr = int.tryParse(values['HR'] ?? '');
    final spo2 = int.tryParse(values['SPO2'] ?? '');
    final rawTemp = double.tryParse(values['TEMP'] ?? '');

    if (hr == null || spo2 == null || rawTemp == null) {
      _finishMeasurement('The device sent an incomplete reading. Please measure again.');
      return;
    }

    // The device measures forehead skin; convert to body temperature once,
    // here, so everything downstream works in one scale.
    final bodyTemp = TemperatureCalibration.bodyFromForehead(rawTemp);

    if (!VitalThresholds.isPlausibleHeartRate(hr) ||
        !VitalThresholds.isPlausibleSpo2(spo2) ||
        !VitalThresholds.isPlausibleBodyTemp(bodyTemp)) {
      _finishMeasurement(
        'Reading looks wrong (HR $hr, SpO₂ $spo2%, temp ${bodyTemp.toStringAsFixed(1)}°C). '
        'Check sensor contact and measure again.',
      );
      return;
    }

    lastReading = HealthReading(
      heartRate: hr,
      spo2: spo2,
      temperature: bodyTemp,
      rawSensorTemperature: rawTemp,
    );
    _gotReadingThisRun = true;
    _readingController.add(lastReading);
  }

  void _finishMeasurement(String status) {
    _measurementTimer?.cancel();
    _measurementTimer = null;
    isMeasuring = false;
    _setStatus(status);
  }

  void _setStatus(String status) {
    measurementStatus = status;
    _statusController.add(status);
  }

  void _onLinkLost() {
    _measurementTimer?.cancel();
    _measurementTimer = null;
    isMeasuring = false;
    _setStatus('Device disconnected');
    _connectionController.add(false);
  }

  Future<void> disconnect() async {
    // The Bluetooth layer's `disconnected` stream drives _onLinkLost().
    await _bluetoothService.disconnect();
  }

  void dispose() {
    _measurementTimer?.cancel();
    _readingController.close();
    _statusController.close();
    _connectionController.close();
  }
}
