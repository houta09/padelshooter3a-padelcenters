import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:collection/collection.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager extends ChangeNotifier {
  static final BluetoothManager _singleton = BluetoothManager._internal();
  factory BluetoothManager() => _singleton;

  BluetoothManager._internal() {
    print("*AVH: Before initialize BT Manager");
    initialize();
    print("*AVH: After initialize BT Manager");
  }

  late BluetoothDevice device;
  List<BluetoothService> services = [];
  bool isConnected = false;
  bool isScanning = false;
  late StreamSubscription<BluetoothConnectionState> _deviceStateSubscription;
  Timer? _reconnectionTimer;
  static const String serviceUUID = "fff0";
  static const String characteristicUUID = "fff2";

  Future<void> initialize() async {
    print("*AVH: Before Request Permissions");
    await requestPermissions();
    print("*AVH: After Request Permissions");
    await initializeBluetooth();
    print("*AVH: After Initialize Bluetooth");
  }

  Future<void> requestPermissions() async {
    // Request location permission for both Android and iOS
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }

    // Request Bluetooth permissions specifically for iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      if (await Permission.bluetooth.isDenied) {
        await Permission.bluetooth.request();
      }

      if (await Permission.bluetoothScan.isDenied) {
        await Permission.bluetoothScan.request();
      }

      if (await Permission.bluetoothConnect.isDenied) {
        await Permission.bluetoothConnect.request();
      }
    }
  }

  Future<void> initializeBluetooth() async {
    print("Initializing Bluetooth...");
    FlutterBluePlus.adapterState.listen((state) async {
      if (state == BluetoothAdapterState.on) {
        print("Bluetooth is ON");
        await scanForDevices();
      } else {
        print("Bluetooth is OFF or not ready");
      }
    });
  }

  Future<void> scanForDevices() async {
    if (isScanning) {
      print("Already scanning for devices...");
      return;
    }
    print("Scanning for devices...");
    isScanning = true;
    var completer = Completer<void>();
    StreamSubscription<List<ScanResult>>? scanSubscription;

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      var foundDevice = results.firstWhereOrNull((result) => result.device.name.toLowerCase() == "padelshooter");
      if (foundDevice != null) {
        print("Device found: ${foundDevice.device.name}");
        FlutterBluePlus.stopScan();
        isScanning = false;
        connect(foundDevice.device).then((_) => completer.complete()).catchError((error) => completer.completeError(error))
            .whenComplete(() => scanSubscription?.cancel());
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 20));
    await completer.future.catchError((_) {});
    FlutterBluePlus.stopScan();
    isScanning = false;
    scanSubscription.cancel();

    if (!isConnected) {
      print("Device not found, starting reconnection loop...");
      _startReconnectionLoop();
    }
  }

  void _startReconnectionLoop() {
    print("Starting reconnection loop...");
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!isConnected) {
        print("Reconnection attempt...");
        await scanForDevices();
      }
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    this.device = device;
    print("Connecting to device: ${device.name}");
    _deviceStateSubscription = this.device.connectionState.listen((state) {
      isConnected = state == BluetoothConnectionState.connected;
      notifyListeners();  // Notify listeners about the connection status change
      print("Connection state changed: $state");
      if (isConnected) {
        _reconnectionTimer?.cancel();
        print("Connected to device.");
      } else {
        _startReconnectionLoop();
      }
    });

    try {
      await this.device.connect();
      services = await this.device.discoverServices();
      notifyListeners();  // Notify listeners after services are discovered
    } catch (e) {
      print('Error connecting to device: $e');
      notifyListeners();  // Notify listeners about the error
      _startReconnectionLoop();
    }
  }

  Future<void> sendData(List<int> data, String serviceUUID, String characteristicUUID) async {
    if (!isConnected) {
      throw Exception("Device not connected");
    }
    var service = services.firstWhereOrNull((s) => s.uuid.toString() == serviceUUID);
    var characteristic = service?.characteristics.firstWhereOrNull((c) => c.uuid.toString() == characteristicUUID);
    if (service == null || characteristic == null) {
      throw Exception("Service or Characteristic not found");
    }
    await characteristic.write(Uint8List.fromList(data), withoutResponse: false);
  }

  Future<void> sendCommandToPadelshooter({
    int command = 10,
    int maxSpeed = 100,
    int delayLevel = 50,
    int hmin = 0,
    int hmax = 100,
    int startSpeed = 100,
    int speedFactor = 9,
    int speed = 15,
    int spin = 50,
    int freq = 40,
    int width = 100,
    int height = 30,
    int training = 30,
    int net = 0,
    int generalInfo = 1,
    int endByte = 255,
  }) async {
    List<int> intData = [
      command, maxSpeed, delayLevel, hmin, hmax, startSpeed, speedFactor,
      speed, spin, freq, width, height, training, net, generalInfo, endByte
    ];
    if (!isConnected) await connect(device);
    await sendData(intData, serviceUUID, characteristicUUID);
  }

  Future<void> sendProgramToPadelshooter(List<List<int>> program) async {
    List<int> intData = [11, 100, 0, 0, 100, 100, 9, 0]; // Command, maxSpeed, delayLevel, hmin, hmax, startSpeed, speedFactor, generalInfo
    for (var shot in program) {
      if (shot.any((value) => value != 0)) { // Only send shots with non-zero values
        intData.addAll(shot);
        intData.add(254); // End of shot
      }
    }
    intData.add(255); // End of program
    await sendData(intData, serviceUUID, characteristicUUID);
  }

  @override
  void dispose() {
    _deviceStateSubscription.cancel();
    _reconnectionTimer?.cancel();
    super.dispose();
  }
}
