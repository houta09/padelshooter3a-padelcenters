import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:collection/collection.dart';
import 'package:permission_handler/permission_handler.dart';

class BluetoothManager extends ChangeNotifier {
  static final BluetoothManager _singleton = BluetoothManager._internal();
  factory BluetoothManager() => _singleton;

  BluetoothManager._internal() {
    initialize();
  }

  late BluetoothDevice device;
  List<BluetoothService> services = [];
  bool isConnected = false;
  bool isScanning = false;
  late StreamSubscription<BluetoothConnectionState> _deviceStateSubscription;
  Timer? _reconnectionTimer;
  static const String serviceUUID = "fff0";
  static const String characteristicUUID = "fff2";

  int _startSpeed = 60;
  int _speedFactor = 6;

  int get startSpeed => _startSpeed;
  int get speedFactor => _speedFactor;

  set startSpeed(int value) {
    _startSpeed = value;
    notifyListeners();
  }

  set speedFactor(int value) {
    _speedFactor = value;
    notifyListeners();
  }

  // Add developer mode flags
  bool _isDeveloperMode = false;
  bool _isExtraMode = false;

  bool get isDeveloperMode => _isDeveloperMode;
  bool get isExtraMode => _isExtraMode;

  void setDeveloperMode(bool isEnabled, {bool isExtraMode = false}) {
    _isDeveloperMode = isEnabled;
    _isExtraMode = isExtraMode;
    notifyListeners();
  }

  Future<void> initialize() async {
    await requestPermissions();
    await initializeBluetooth();
  }

  Future<void> requestPermissions() async {
    if (await Permission.locationWhenInUse.isDenied) {
      await Permission.locationWhenInUse.request();
    }

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
    FlutterBluePlus.adapterState.listen((state) async {
      if (state == BluetoothAdapterState.on) {
        await scanForDevices();
      }
    });
  }

  Future<void> scanForDevices() async {
    if (isScanning) {
      return;
    }
    isScanning = true;
    var completer = Completer<void>();
    StreamSubscription<List<ScanResult>>? scanSubscription;

    scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      var foundDevice = results.firstWhereOrNull((result) => result.device.name.toLowerCase().contains( "padelshooter"));
      if (foundDevice != null) {
        FlutterBluePlus.stopScan();
        isScanning = false;
        connect(foundDevice.device).then((_) => completer.complete()).catchError((error) => completer.completeError(error))
            .whenComplete(() => scanSubscription?.cancel());
      }
    });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    await completer.future.catchError((_) {});
    FlutterBluePlus.stopScan();
    isScanning = false;
    scanSubscription.cancel();

    if (!isConnected) {
      _startReconnectionLoop();
    }
  }

  void _startReconnectionLoop() {
    _reconnectionTimer?.cancel();
    _reconnectionTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (!isConnected) {
        await scanForDevices();
      }
    });
  }

  Future<void> connect(BluetoothDevice device) async {
    this.device = device;
    _deviceStateSubscription = this.device.connectionState.listen((state) {
      isConnected = state == BluetoothConnectionState.connected;
      notifyListeners();
      if (isConnected) {
        _reconnectionTimer?.cancel();
      } else {
        _startReconnectionLoop();
      }
    });

    try {
      await this.device.connect();
      services = await this.device.discoverServices();
      notifyListeners();
    } catch (e) {
      notifyListeners();
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
    int speed = 15,
    int spin = 0,
    int freq = 40,
    int width = 100,
    int height = 30,
    int training = 30,
    int net = 0,
    int generalInfo = 69,
    int endByte = 255,
  }) async {
    List<int> intData = [
      command, maxSpeed, delayLevel, hmin, hmax, _startSpeed, _speedFactor,
      speed, convertSpinValue(spin), freq, width, height, training, net, generalInfo, endByte
    ];
    if (!isConnected) await connect(device);
    await sendData(intData, serviceUUID, characteristicUUID);
  }

  Future<void> sendProgramToPadelshooter(List<List<int>> program, int maxSpeed) async {
    List<int> intData = [11, maxSpeed, 0, 0, 100, _startSpeed, _speedFactor, 69];

    print('*AVH: Initial data: $intData');

    for (var shot in program) {
      if (shot.any((value) => value != 0)) {
        shot[1] = convertSpinValue(shot[1]); // Convert spin value
        intData.addAll(shot);
        intData.add(254);
        print('*AVH: Adding shot: $shot');
      }
    }

    intData.add(255);
    print('*AVH: Final data to send: $intData');

    try {
      await sendData(intData, serviceUUID, characteristicUUID);
      print('*AVH: Data sent successfully');
    } catch (e) {
      print('*AVH: Error sending data: $e');
    }
  }

  @override
  void dispose() {
    _deviceStateSubscription.cancel();
    _reconnectionTimer?.cancel();
    super.dispose();
  }
}

int convertSpinValue(int spin) {
  return ((-1 * spin) + 50); // Convert spin from -50..50 to 0..100
}
