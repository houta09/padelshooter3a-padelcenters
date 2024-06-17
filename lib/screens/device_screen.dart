/*
import 'dart:async';

import 'dart:typed_data';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../widgets/service_tile.dart';
import '../widgets/characteristic_tile.dart';
import '../widgets/descriptor_tile.dart';
import '../utils/snackbar.dart';

class DeviceScreen extends StatefulWidget {
  final BluetoothDevice device;

  const DeviceScreen({super.key, required this.device});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  int? _rssi;
  int? _mtuSize;
  BluetoothDeviceState _connectionState = BluetoothDeviceState.disconnected;
  List<BluetoothService> _services = [];
  bool _isDiscoveringServices = false;
  bool _isConnecting = false;
  bool _isDisconnecting = false;
  final bool _isSendingData = false;

  late StreamSubscription<BluetoothDeviceState> _connectionStateSubscription;
  late StreamSubscription<bool> _isConnectingSubscription;
  late StreamSubscription<bool> _isDisconnectingSubscription;
  late StreamSubscription<int> _mtuSubscription;

  static const String serviceUUID = "fff0";
  static const String characteristicUUID = "fff2";

  @override
  void initState() {
    super.initState();

    _connectionStateSubscription = widget.device.connectionState.listen((state) async {
      _connectionState = state;
      if (state == BluetoothDeviceState.connected) {
        _services = []; // must rediscover services
      }
      if (state == BluetoothDeviceState.connected && _rssi == null) {
        _rssi = await widget.device.readRssi();
      }
      if (mounted) {
        setState(() {});
      }
    });

    _mtuSubscription = widget.device.mtu.listen((value) {
      _mtuSize = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isConnectingSubscription = widget.device.isConnecting.listen((value) {
      _isConnecting = value;
      if (mounted) {
        setState(() {});
      }
    });

    _isDisconnectingSubscription = widget.device.isDisconnecting.listen((value) {
      _isDisconnecting = value;
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _connectionStateSubscription.cancel();
    _mtuSubscription.cancel();
    _isConnectingSubscription.cancel();
    _isDisconnectingSubscription.cancel();
    super.dispose();
  }

  bool get isConnected {
    return _connectionState == BluetoothDeviceState.connected;
  }

  Future onConnectPressed() async {
    try {
      await widget.device.connectAndUpdateStream();
      Snackbar.show(ABC.c, "Connect: Success", success: true);
    } catch (e) {
      if (e is FlutterBluePlusException && e.code == FbpErrorCode.connectionCanceled.index) {
        // ignore connections canceled by the user
      } else {
        Snackbar.show(ABC.c, prettyException("Connect Error:", e), success: false);
      }
    }
  }

  Future onCancelPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream(queue: false);
      Snackbar.show(ABC.c, "Cancel: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Cancel Error:", e), success: false);
    }
  }

  Future onDisconnectPressed() async {
    try {
      await widget.device.disconnectAndUpdateStream();
      Snackbar.show(ABC.c, "Disconnect: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Disconnect Error:", e), success: false);
    }
  }

  Future onDiscoverServicesPressed() async {
    if (mounted) {
      setState(() {
        _isDiscoveringServices = true;
      });
    }
    try {
      _services = await widget.device.discoverServices();
      Snackbar.show(ABC.c, "Discover Services: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Discover Services Error:", e), success: false);
    }
    if (mounted) {
      setState(() {
        _isDiscoveringServices = false;
      });
    }
  }

  Future onRequestMtuPressed() async {
    try {
      await widget.device.requestMtu(223, predelay: 0);
      Snackbar.show(ABC.c, "Request Mtu: Success", success: true);
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Change Mtu Error:", e), success: false);
    }
  }

  Future<void> sendCommandToPadelshooter({
    // Default values
    int Command = 10,
    int MaxSpeed = 100,
    int DelayLevel = 50,
    int Hmin = 0,
    int Hmax = 100,
    int StartSpeed = 100,
    int SpeedFactor = 9,
    int Speed = 15,
    int Spin = 50,
    int Freq = 40,
    int Width = 100,
    int Height = 30,
    int Training = 30,
    int Net = 0,
    int GeneralInfo = 0,
    int EndByte = 255,
  }) async {
    // Confirm the device is connected before proceeding
    if (_connectionState != BluetoothDeviceState.connected) {
      Snackbar.show(ABC.c, "Device is not connected", success: false);
      return;
    }

    // Discover all available services
    _services = await widget.device.discoverServices();
    for (var service in _services) {
      print('Discovered service: ${service.uuid}');
      for (var characteristic in service.characteristics) {
        print('Characteristic in service ${service.uuid}: ${characteristic.uuid}');
      }
    }

    // Find the specific service (using the full UUID)
    print("Attempting to find the specific service...");

    BluetoothService? service = _services.firstWhereOrNull(
          (s) => s.uuid.toString() == serviceUUID,
    );

    // Check if the service is found
    if (service == null) {
      print("Service not found with UUID: $serviceUUID");
      Snackbar.show(ABC.c, "Service not found", success: false);
      return;
    } else {
      print("Service found: ${service.uuid}");
    }

    // Find the specific characteristic within the service
    BluetoothCharacteristic? characteristic = service.characteristics.firstWhereOrNull(
          (c) => c.uuid.toString() == characteristicUUID,
    );

    // Check if the characteristic is found
    if (characteristic == null) {
      print("Characteristic not found in service ${service.uuid} with UUID: $characteristicUUID");
      Snackbar.show(ABC.c, "Characteristic not found", success: false);
      return;
    } else {
      print("Characteristic found: ${characteristic.uuid}");
    }

    // Create the data list using named parameters
    List<int> intData = [Command, MaxSpeed, DelayLevel, Hmin, Hmax, StartSpeed, SpeedFactor, Speed, Spin, Freq, Width, Height, Training, Net, GeneralInfo, EndByte];

    // Convert to Uint8List (unsigned 8-bit integers)
    Uint8List data = Uint8List.fromList(intData.map((value) => value & 0xFF).toList());

    // Write data to the characteristic
    try {
      await characteristic.write(data, withoutResponse: true);
      print("Data sent successfully!");
      Snackbar.show(ABC.c, "Data sent successfully!", success: true);
    } catch (e) {
      print("Error writing data: $e");
      Snackbar.show(ABC.c, prettyException("Error writing data:", e), success: false);
    }
  }




  List<Widget> _buildServiceTiles(BuildContext context, BluetoothDevice d) {
    return _services
        .map(
          (s) => ServiceTile(
        service: s,
        characteristicTiles: s.characteristics.map((c) => _buildCharacteristicTile(c)).toList(),
      ),
    )
        .toList();
  }

  CharacteristicTile _buildCharacteristicTile(BluetoothCharacteristic c) {
    return CharacteristicTile(
      characteristic: c,
      descriptorTiles: c.descriptors.map((d) => DescriptorTile(descriptor: d)).toList(),
    );
  }

  Widget buildSpinner(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(14.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: CircularProgressIndicator(
          backgroundColor: Colors.black12,
          color: Colors.black26,
        ),
      ),
    );
  }

  Widget buildRemoteId(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text('${widget.device.remoteId}'),
    );
  }

  Widget buildRssiTile(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        isConnected ? const Icon(Icons.bluetooth_connected) : const Icon(Icons.bluetooth_disabled),
        Text(((isConnected && _rssi != null) ? '${_rssi!} dBm' : ''), style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget buildGetServices(BuildContext context) {
    return IndexedStack(
      index: (_isDiscoveringServices) ? 1 : 0,
      children: <Widget>[
        TextButton(
          onPressed: onDiscoverServicesPressed,
          child: const Text("Get Services"),
        ),
        const IconButton(
          icon: SizedBox(
            width: 18.0,
            height: 18.0,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(Colors.grey),
            ),
          ),
          onPressed: null,
        )
      ],
    );
  }

  Widget buildMtuTile(BuildContext context) {
    return ListTile(
      title: const Text('MTU Size'),
      subtitle: Text('$_mtuSize bytes'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: onRequestMtuPressed,
      ),
    );
  }

  Widget buildConnectButton(BuildContext context) {
    return Row(children: [
      if (_isConnecting || _isDisconnecting) buildSpinner(context),
      TextButton(
        onPressed: _isConnecting ? onCancelPressed : (isConnected ? onDisconnectPressed : onConnectPressed),
        child: Text(
          _isConnecting ? "CANCEL" : (isConnected ? "DISCONNECT" : "CONNECT"),
          style: Theme.of(context).primaryTextTheme.labelLarge?.copyWith(color: Colors.white),
        ),
      ),
    ]);
  }

  Widget buildSendDataButton(BuildContext context) {
    return ElevatedButton(
      onPressed: _isSendingData ? null : sendCommandToPadelshooter,
      child: Text(_isSendingData ? "Sending..." : "Send Data to Padelshooter"),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyC,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.device.platformName),
          actions: [buildConnectButton(context)],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              buildRemoteId(context),
              ListTile(
                leading: buildRssiTile(context),
                title: Text('Device is ${_connectionState.toString().split('.')[1]}.'),
                trailing: buildGetServices(context),
              ),
              buildMtuTile(context),
              buildSendDataButton(context), // Added the Send Data Button
              ..._buildServiceTiles(context, widget.device),
            ],
          ),
        ),
      ),
    );
  }
  */