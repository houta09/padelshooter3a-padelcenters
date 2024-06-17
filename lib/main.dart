import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'screens/main_screen.dart';
import 'screens/start_here_screen.dart';
import 'screens/trainings_screen.dart';
import 'screens/programs_screen.dart';
import 'utils/bluetooth_manager.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // Full-screen mode
    runApp(const PadelShooterApp());
  });
}

class PadelShooterApp extends StatelessWidget {
  const PadelShooterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<BluetoothManager>(
      create: (_) => BluetoothManager()..initialize(),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: const MaterialApp(
          title: 'Padelshooter',
          home: DynamicContentFrame(),
        ),
      ),
    );
  }
}

class DynamicContentFrame extends StatefulWidget {
  const DynamicContentFrame({super.key});

  @override
  _DynamicContentFrameState createState() => _DynamicContentFrameState();
}

class _DynamicContentFrameState extends State<DynamicContentFrame> {
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    var bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    bluetoothManager.addListener(_updateConnectionStatus);
  }

  @override
  void dispose() {
    var bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    bluetoothManager.removeListener(_updateConnectionStatus);
    super.dispose();
  }

  void _updateConnectionStatus() {
    setState(() {});
  }

  void changePage(int index) {
    setState(() {
      _currentPageIndex = index;
    });
  }

  String _getPageTitle() {
    switch (_currentPageIndex) {
      case 0:
        return 'Main';
      case 1:
        return 'Start Here';
      case 2:
        return 'Trainings';
      case 3:
        return 'Programs';
      default:
        return '';
    }
  }

  Widget _buildPage(Widget page) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          child: Text(
            _getPageTitle(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ),
        Expanded(child: page),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var bluetoothManager = Provider.of<BluetoothManager>(context);
    bool isConnected = bluetoothManager.isConnected;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        body: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_app.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            IndexedStack(
              index: _currentPageIndex,
              children: [
                _buildPage(MainScreen(onNavigate: changePage)),
                _buildPage(StartHereScreen(onNavigate: changePage)),
                _buildPage(TrainingsScreen(onNavigate: changePage)),
                _buildPage(ProgramsScreen(onNavigate: changePage)),
              ],
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.transparent,  // Make the background transparent
          type: BottomNavigationBarType.fixed,  // Ensure the bar doesn't move
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Main'),
            const BottomNavigationBarItem(icon: Icon(Icons.location_on), label: 'Start Here'),
            const BottomNavigationBarItem(icon: Icon(Icons.fitness_center), label: 'Trainings'),
            const BottomNavigationBarItem(icon: Icon(Icons.computer), label: 'Programs'),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.bluetooth,
                color: isConnected ? Colors.green : Colors.red,
              ),
              label: 'Bluetooth',
            ),
          ],
          currentIndex: _currentPageIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          onTap: (index) {
            if (index != 4) {
              changePage(index);
            }
          },
        ),
      ),
    );
  }
}
