import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fbp;
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';

class PomodoroBluetoothService {
  static final PomodoroBluetoothService _instance = PomodoroBluetoothService._internal();
  factory PomodoroBluetoothService() => _instance;
  PomodoroBluetoothService._internal();

  // Bluetooth variables
  fbp.BluetoothDevice? connectedDevice;
  fbp.BluetoothCharacteristic? commandCharacteristic;
  fbp.BluetoothCharacteristic? statusCharacteristic;
  fbp.BluetoothCharacteristic? sensorCharacteristic;
  bool isConnected = false;
  bool isScanning = false;
  List<fbp.BluetoothDevice> foundDevices = [];

  // Stream controllers
  final StreamController<Map<String, String>> _statusController = 
      StreamController<Map<String, String>>.broadcast();
  final StreamController<Map<String, String>> _sensorController = 
      StreamController<Map<String, String>>.broadcast();
  final StreamController<bool> _connectionController = 
      StreamController<bool>.broadcast();

  // Timers
  Timer? statusTimer;
  StreamSubscription<List<fbp.ScanResult>>? _scanSubscription;

  // Getters for streams
  Stream<Map<String, String>> get statusStream => _statusController.stream;
  Stream<Map<String, String>> get sensorStream => _sensorController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  Future<void> requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> startScan() async {
    if (isScanning) return;

    print("Starting scan...");
    isScanning = true;
    foundDevices.clear();

    try {
      // 先停止任何正在进行的扫描
      await fbp.FlutterBluePlus.stopScan();
      
      if (await fbp.FlutterBluePlus.isSupported == false) {
        throw Exception("Bluetooth not supported");
      }

      if (await fbp.FlutterBluePlus.isOn == false) {
        throw Exception("Please turn on Bluetooth");
      }

      // 添加小延迟确保蓝牙准备就绪
      await Future.delayed(Duration(milliseconds: 500));

      // 取消之前的监听
      _scanSubscription?.cancel();

      // 设置扫描监听
      _scanSubscription = fbp.FlutterBluePlus.scanResults.listen((results) {
        print("Scan results: ${results.length} devices found");
        for (fbp.ScanResult result in results) {
          String deviceName = result.device.platformName;
          print("Found device: '$deviceName' - ${result.device.remoteId}");
          
          if (deviceName.isNotEmpty && 
              (deviceName.contains("Pomodoro Robot") || 
               deviceName.contains("ESP32") ||
               deviceName.contains("Pomodoro") ||
               deviceName.contains("PomoBot"))) {
            if (!foundDevices.contains(result.device)) {
              foundDevices.add(result.device);
              print("Added Pomodoro device: $deviceName");
            }
          }
        }
      });

      // 开始扫描，设置15秒超时
      await fbp.FlutterBluePlus.startScan(
        timeout: Duration(seconds: 15),
      );
      
      print("Scan started successfully");
      
    } catch (e) {
      print("Scan error: $e");
      isScanning = false;
      throw e;
    } finally {
      // 15秒后自动停止
      Future.delayed(Duration(seconds: 15), () {
        if (isScanning) {
          isScanning = false;
        }
      });
    }
  }

  Future<void> stopScan() async {
    print("Stopping scan...");
    try {
      await fbp.FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
    } catch (e) {
      print("Error stopping scan: $e");
    }
    isScanning = false;
    print("Scan stopped");
  }

  Future<void> connectToDevice(fbp.BluetoothDevice device) async {
    try {
      // 连接前先停止扫描
      await stopScan();
      
      print("Connecting to device: ${device.platformName}");
      await device.connect();
      
      List<fbp.BluetoothService> services = await device.discoverServices();
      
      for (fbp.BluetoothService service in services) {
        if (service.uuid.toString().contains("12345678-1234-1234-1234-123456789abc")) {
          for (fbp.BluetoothCharacteristic characteristic in service.characteristics) {
            String uuid = characteristic.uuid.toString();
            
            if (uuid.contains("87654321-4321-4321-4321-cba987654321")) {
              commandCharacteristic = characteristic;
            } else if (uuid.contains("11111111-2222-3333-4444-555555555555")) {
              statusCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen(_onStatusReceived);
            } else if (uuid.contains("22222222-3333-4444-5555-666666666666")) {
              sensorCharacteristic = characteristic;
              await characteristic.setNotifyValue(true);
              characteristic.lastValueStream.listen(_onSensorReceived);
            }
          }
        }
      }

      connectedDevice = device;
      isConnected = true;
      
      // 通知UI连接状态已更改
      _connectionController.add(true);

      // 定期获取状态和传感器数据
      statusTimer = Timer.periodic(Duration(seconds: 3), (timer) {
        sendCommand("GET_STATUS");
        sendCommand("GET_SENSORS");
      });

      print("Connected successfully!");
    } catch (e) {
      print("Connection failed: $e");
      isConnected = false;
      // 确保连接失败时也发送状态
      _connectionController.add(false);
      throw e;
    }
  }

  Future<void> disconnect() async {
    print("Disconnecting...");
    
    // 停止定时器
    statusTimer?.cancel();
    statusTimer = null;
    
    // 断开设备连接
    if (connectedDevice != null) {
      try {
        await connectedDevice!.disconnect();
      } catch (e) {
        print("Disconnect error: $e");
      }
    }
    
    // 清理状态
    connectedDevice = null;
    isConnected = false;
    commandCharacteristic = null;
    statusCharacteristic = null;
    sensorCharacteristic = null;
    
    // 通知UI连接状态已更改
    _connectionController.add(false);
    
    print("Disconnected successfully");
  }

  Future<void> sendCommand(String command) async {
    if (commandCharacteristic != null && isConnected) {
      try {
        await commandCharacteristic!.write(command.codeUnits);
      } catch (e) {
        print("Command failed: $e");
      }
    }
  }

  void _onStatusReceived(List<int> value) {
    String statusString = String.fromCharCodes(value);
    Map<String, String> statusMap = {};
    List<String> pairs = statusString.split(',');
    for (String pair in pairs) {
      List<String> keyValue = pair.split(':');
      if (keyValue.length == 2) {
        statusMap[keyValue[0].trim()] = keyValue[1].trim();
      }
    }
    _statusController.add(statusMap);
  }

  void _onSensorReceived(List<int> value) {
    String sensorString = String.fromCharCodes(value);
    Map<String, String> sensorMap = {};
    List<String> pairs = sensorString.split(',');
    for (String pair in pairs) {
      List<String> keyValue = pair.split(':');
      if (keyValue.length == 2) {
        sensorMap[keyValue[0].trim()] = keyValue[1].trim();
      }
    }
    _sensorController.add(sensorMap);
  }

  void dispose() {
    disconnect();
    _scanSubscription?.cancel();
    _statusController.close();
    _sensorController.close();
    _connectionController.close();
  }
}