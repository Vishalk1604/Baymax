import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class AppBluetoothService {
  static final AppBluetoothService _instance = AppBluetoothService._internal();
  factory AppBluetoothService() => _instance;
  AppBluetoothService._internal();

  BluetoothConnection? _connection;
  bool get isConnected => _connection != null && _connection!.isConnected;

  final StreamController<String> _messagesController = StreamController<String>.broadcast();
  Stream<String> get messages => _messagesController.stream;

  Future<bool> requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
    
    return statuses.values.every((status) => status.isGranted);
  }

  Future<List<BluetoothDevice>> getAvailableDevices() async {
    try {
      // The class name is FlutterBluetoothSerial even in the 'plus' package
      return await FlutterBluetoothSerial.instance.getBondedDevices();
    } catch (e) {
      print("Error getting bonded devices: $e");
      return [];
    }
  }

  Future<bool> connectToDevice(BluetoothDevice device) async {
    if (isConnected) {
      await disconnect();
    }

    try {
      _connection = await BluetoothConnection.toAddress(device.address);
      print('Connected to ${device.name}');

      _connection!.input!.listen((Uint8List data) {
        String message = utf8.decode(data);
        _messagesController.add(message);
      }).onDone(() {
        _connection = null;
      });

      return true;
    } catch (e) {
      print('Cannot connect, exception occurred: $e');
      _connection = null;
      return false;
    }
  }

  Future<bool> sendCommand(String command) async {
    if (!isConnected) return false;
    try {
      _connection!.output.add(utf8.encode(command));
      await _connection!.output.allSent;
      return true;
    } catch (e) {
      print('Error sending command: $e');
      return false;
    }
  }

  Future<void> disconnect() async {
    await _connection?.close();
    _connection = null;
  }

  void dispose() {
    _messagesController.close();
    _connection?.dispose();
  }
}
