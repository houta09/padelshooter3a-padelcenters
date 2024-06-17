import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/bluetooth_manager.dart';

class MainScreen extends StatelessWidget {
  final Function(int) onNavigate;

  const MainScreen({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothManager>(
      builder: (context, bluetoothManager, child) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const SizedBox(height: 16),
                Image.asset(
                  'assets/images/PS3A-black-right.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                if (bluetoothManager.isConnected) ...[
                  const Text(
                    "Connected to Padelshooter",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  const Text(
                    "Trying to connect to Padelshooter...",
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}