import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/bluetooth_manager.dart';
import '../utils/app_localizations.dart';

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
                  'assets/images/PS3A-black_transp.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                if (bluetoothManager.isConnected) ...[
                  Text(
                    AppLocalizations.of(context).translate('connected_to_padelshooter') ?? "Connected to Padelshooter",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ] else ...[
                  const CircularProgressIndicator(),
                  const SizedBox(height: 20),
                  Text(
                    AppLocalizations.of(context).translate('trying_to_connect_to_padelshooter') ?? "Trying to connect to Padelshooter...",
                    style: const TextStyle(fontSize: 18, color: Colors.white),
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
