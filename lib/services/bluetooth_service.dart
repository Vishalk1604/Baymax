import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Bluetooth Classic (SPP) link to the Baymax device.
///
/// Bluetooth delivers bytes in arbitrary chunks: one chunk can hold half a
/// message or several messages. [messages] therefore emits complete,
/// newline-terminated lines only (the firmware ends every message with
/// `println`).
class AppBluetoothService {
  static final AppBluetoothService _instance = AppBluetoothService._internal();
  factory AppBluetoothService() => _instance;
  AppBluetoothService._internal();

  BluetoothConnection? _connection;
  StreamSubscription<Uint8List>? _inputSubscription;
  String _lineBuffer = '';

  bool get isConnected => _connection != null && _connection!.isConnected;

  final StreamController<String> _messagesController = StreamController<String>.broadcast();

  /// Complete lines received from the device, without the line terminator.
  Stream<String> get messages => _messagesController.stream;

  final StreamController<void> _disconnectedController = StreamController<void>.broadcast();

  /// Fires when the link drops (device switched off, out of range, or
  /// [disconnect] called).
  Stream<void> get disconnected => _disconnectedController.stream;

  /// The app talks to the already-paired BAYMAX and never scans, so Android
  /// 12+ only needs "Nearby devices" (BLUETOOTH_CONNECT). Before Android 12
  /// Bluetooth is granted at install (permission_handler reports it granted).
  /// Location isn't needed: asking for it, and failing when it was refused,
  /// used to block the connection for no reason.
  Future<bool> requestPermissions() async {
    final status = await Permission.bluetoothConnect.request();
    return status.isGranted || status.isLimited;
  }

  /// Bluetooth on? If not, asks the system to turn it on (Android dialog).
  Future<bool> ensureEnabled() async {
    try {
      if (await FlutterBluetoothSerial.instance.isEnabled ?? false) return true;
      return await FlutterBluetoothSerial.instance.requestEnable() ?? false;
    } catch (e) {
      debugPrint('Could not check or enable Bluetooth: $e');
      return false;
    }
  }

  Future<List<BluetoothDevice>> getAvailableDevices() async {
    try {
      // The class name is FlutterBluetoothSerial even in the 'plus' package
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      debugPrint('Error getting bonded devices: $e');
      return [];
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (isConnected) {
      await disconnect();
    }

    try {
      final connection = await BluetoothConnection.toAddress(device.address);
      _connection = connection;
      _lineBuffer = '';
      debugPrint('Connected to ${device.name}');

      _inputSubscription = connection.input?.listen(
        _onData,
        onDone: _handleLinkLost,
        onError: (Object e) {
          debugPrint('Bluetooth input error: $e');
          _handleLinkLost();
        },
        cancelOnError: true,
      );

      return true;
    } catch (e) {
      debugPrint('Cannot connect, exception occurred: $e');
      _connection = null;
      return false;
    }
  }

  void _onData(Uint8List data) {
    _lineBuffer += utf8.decode(data, allowMalformed: true);

    // Emit every complete line; keep any trailing partial line for later.
    int newline;
    while ((newline = _lineBuffer.indexOf('\n')) != -1) {
      final line = _lineBuffer.substring(0, newline).trim(); // also drops '\r'
      _lineBuffer = _lineBuffer.substring(newline + 1);
      if (line.isNotEmpty) _messagesController.add(line);
    }

    // A device that never sends '\n' must not grow the buffer forever.
    if (_lineBuffer.length > 1024) _lineBuffer = '';
  }

  void _handleLinkLost() {
    final wasConnected = _connection != null;
    _inputSubscription = null;
    _connection = null;
    _lineBuffer = '';
    if (wasConnected) _disconnectedController.add(null);
  }

  Future<bool> sendCommand(String command) async {
    if (!isConnected) return false;
    try {
      _connection!.output.add(utf8.encode(command));
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      debugPrint('Error sending command: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _inputSubscription?.cancel();
    final connection = _connection;
    if (connection != null) {
      try {
        await connection.close();
      } catch (e) {
        debugPrint('Error closing connection: $e');
      }
    }
    _handleLinkLost();
  }

  void dispose() {
    _inputSubscription?.cancel();
    _connection?.dispose();
    _messagesController.close();
    _disconnectedController.close();
  }
}
