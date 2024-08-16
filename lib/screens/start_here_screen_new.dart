import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import '../utils/bluetooth_manager.dart';

class StartHereScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const StartHereScreen({super.key, required this.onNavigate});

  @override
  _StartHereScreenState createState() => _StartHereScreenState();
}

class _StartHereScreenState extends State<StartHereScreen> {
  bool _isPlayActive = false;
  bool _leftSelected = true;

  final Map<String, TextEditingController> _controllers = {
    "Speed": TextEditingController(),
    "Spin": TextEditingController(),
    "Freq": TextEditingController(),
    "Width": TextEditingController(),
    "Height": TextEditingController(),
  };

  final Map<int, String?> _programNames = {};
  int _selectedProgramIndex = -1; // No training selected initially
  int _currentShotCount = 1;
  BluetoothManager? _bluetoothManager;

  @override
  void initState() {
    super.initState();
    _bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    _loadSettings();
    _loadPrograms();
    print('*AVH: StartHereScreen initialized');
  }

  Future<void> _loadSettings() async {
    // Load settings if required
  }

  Future<void> _saveSettings() async {
    // Save settings if required
  }

  void _updateFieldSelection() {
    setState(() {
      _leftSelected = !_leftSelected;
    });
    _loadPrograms();
    print('*AVH: Field selection updated: ${_leftSelected ? "Left" : "Right"}');
  }

  Future<void> _loadPrograms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String category = _leftSelected ? "SHL" : "SHR";

    setState(() {
      for (int i = 1; i <= 9; i++) {
        _programNames[i] = null;
      }
    });

    List<String> programs = prefs.getStringList('programs_$category') ?? [];
    print("*AVH: Programs: $programs");
    for (String program in programs) {
      for (int i = 1; i <= 9; i++) {
        if (program.startsWith('$i-')) {
          setState(() {
            _programNames[i] = program;
          });
        }
      }
      print("*AVH: Programs_inloop: $_programNames");
    }
    print('*AVH: Programs loaded for category: $category');
    print("*AVH: Programs_endloop: $_programNames");
  }

  Future<void> _loadShotsForProgram(int index) async {
    final programName = _programNames[index];
    if (programName != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String category = _leftSelected ? "SHL" : "SHR";
      _currentShotCount = prefs.getInt("${category}_${programName}_ShotCount") ?? 1;

      setState(() {
        for (int i = 0; i < _currentShotCount; i++) {
          _controllers["Speed"]!.text = (prefs.getInt("${category}_${programName}_Speed_$i") ?? 0).toString();
          _controllers["Spin"]!.text = ((prefs.getInt("${category}_${programName}_Spin_$i") ?? 0)).toString();
          _controllers["Freq"]!.text = (prefs.getInt("${category}_${programName}_Freq_$i") ?? 0).toString();
          _controllers["Width"]!.text = (prefs.getInt("${category}_${programName}_Width_$i") ?? 0).toString();
          _controllers["Height"]!.text = (prefs.getInt("${category}_${programName}_Height_$i") ?? 0).toString();
        }
      });
    }
  }

  void _sendProgramToPadelshooter(int index, BluetoothManager bluetoothManager) async {
    final programName = _programNames[index];

    if (programName != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String mode = prefs.getString('selected_mode') ?? 'Padel';
      int maxSpeed = mode == 'Tennis' ? 250 : 100;

      String category = _leftSelected ? "SHL" : "SHR";
      List<List<int>> program = [];

      for (int i = 0; i < _currentShotCount; i++) {
        List<int> shot = [
          int.parse(_controllers["Speed"]!.text),
          int.parse(_controllers["Spin"]!.text),
          int.parse(_controllers["Freq"]!.text),
          int.parse(_controllers["Width"]!.text),
          int.parse(_controllers["Height"]!.text),
        ];
        if (shot.any((value) => value != 0)) {
          program.add(shot);
        }
      }

      print('*AVH: Program data being sent: $program with maxSpeed: $maxSpeed');

      try {
        await bluetoothManager.sendProgramToPadelshooter(program, maxSpeed);
        print('*AVH: Program $programName sent to Padelshooter');
      } catch (e) {
        print('*AVH: Error sending program to Padelshooter: $e');
      }
    } else {
      print('*AVH: No program found for index $index');
    }
  }

  void _handlePlayButtonPress() async {
    print('*AVH: Play button pressed');
    setState(() {
      _isPlayActive = true;
    });
    _sendProgramToPadelshooter(_selectedProgramIndex, _bluetoothManager!);
  }

  void _handleOffButtonPress() async {
    print('*AVH: Off button pressed');
    setState(() {
      _isPlayActive = false;
      _selectedProgramIndex = -1; // No training selected
    });
    try {
      await _bluetoothManager?.sendCommandToPadelshooter(command: 0);
      print('*AVH: Off command sent to Padelshooter');
    } catch (e) {
      print('*AVH: Error sending Off command: $e');
    }
  }

  void _onProgramButtonPress(int index) {
    setState(() {
      _selectedProgramIndex = index;
      _loadShotsForProgram(index);
    });
    print('*AVH: Button $index pressed, program: ${_programNames[index]}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<BluetoothManager>(
        builder: (context, bluetoothManager, child) {
          return Stack(
            children: [
              Positioned.fill(
                child: Image.asset(
                  "assets/images/background_app.jpg",
                  fit: BoxFit.cover,
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: GridView.count(
                        crossAxisCount: 3,
                        childAspectRatio: 1.8,
                        padding: const EdgeInsets.all(2),
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 1,
                        children: List.generate(
                          9,
                              (index) => _buildActionableButton(
                              context, index + 1, bluetoothManager),
                        ),
                      ),
                    ),
                    if (_selectedProgramIndex != -1) // Only show shots if a program is selected
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: _buildShotsList(),
                        ),
                      ),
                    _buildFieldSelectionButton(),
                    _buildControlButtons(bluetoothManager),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildActionableButton(
      BuildContext context, int index, BluetoothManager bluetoothManager) {
    String image = _selectedProgramIndex == index
        ? 'assets/images/Padelbaan_full_fixed_green.png'
        : 'assets/images/Padelbaan_full_fixed.png';
    String? programName = _programNames[index];

    return ElevatedButton(
      onPressed: () {
        _onProgramButtonPress(index);
        setState(() {});
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: Stack(
        children: [
          Image.asset(
            image,
            width: 100,
            height: 61,
            fit: BoxFit.cover,
          ),
          if (programName != null)
            Center(
              child: Text(
                programName.split('-')[1],
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8, // Updated font size to 8
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      blurRadius: 4.0,
                      color: Colors.black,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildShotsList() {
    return ListView.builder(
      itemCount: _currentShotCount,
      itemBuilder: (context, index) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${AppLocalizations.of(context).translate('shot') ?? 'Shot'} ${index + 1}:',
              style: const TextStyle(color: Colors.white, fontSize: 10),
            ),
            const SizedBox(width: 10),
            ..._controllers.keys.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TextField(
                    controller: _controllers[key],
                    keyboardType: key == "Spin"
                        ? const TextInputType.numberWithOptions(signed: true)
                        : TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    decoration: const InputDecoration(
                      contentPadding:
                      EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                      border: OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildFieldSelectionButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: ElevatedButton(
        onPressed: _updateFieldSelection,
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        child: Text(
          _leftSelected ? "Left" : "Right",
          style: const TextStyle(fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildControlButtons(BluetoothManager bluetoothManager) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(
            context,
            AppLocalizations.of(context).translate('off') ?? 'Off',
            !_isPlayActive,
            bluetoothManager,
            _handleOffButtonPress,
          ),
          _buildButton(
            context,
            AppLocalizations.of(context).translate('play') ?? 'Play',
            _isPlayActive,
            bluetoothManager,
            _handlePlayButtonPress,
          ),
        ],
      ),
    );
  }

  Widget _buildButton(BuildContext context, String label, bool isActive,
      BluetoothManager bluetoothManager, VoidCallback onPressed) {
    Color bgColor = isActive ? Colors.blue : Colors.grey[600]!;

    return ElevatedButton(
      onPressed: bluetoothManager.isConnected ? onPressed : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
