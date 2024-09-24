import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import '../utils/bluetooth_manager.dart';

class TrainingsScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final bool isDeveloperMode;

  const TrainingsScreen({super.key, required this.onNavigate, this.isDeveloperMode = false});

  @override
  _TrainingsScreenState createState() => _TrainingsScreenState();
}

class _TrainingsScreenState extends State<TrainingsScreen> with WidgetsBindingObserver {
  bool _isPlayActive = false;
  bool _isPauseActive = false;
  bool _leftSelected = true;

  List<Map<String, TextEditingController>> _shots = [];
  final Map<int, String?> _programNames = {};
  int _selectedProgramIndex = -1;
  int _currentShotCount = 1;
  BluetoothManager? _bluetoothManager;

  // Temporary session-based settings
  Map<String, dynamic> sessionTrainingSettings = {};

  @override
  void initState() {
    super.initState();
    _bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    WidgetsBinding.instance.addObserver(this);
    _loadPrograms();
    print('*AVH: TrainingsScreen initialized');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadPrograms();
    }
  }

  @override
  void didUpdateWidget(TrainingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadPrograms();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sessionTrainingSettings.clear(); // Clear session settings on exit
    super.dispose();
  }

  Future<void> _loadPrograms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String category = _leftSelected ? "TRL" : "TRR";

    setState(() {
      for (int i = 1; i <= 9; i++) {
        _programNames[i] = null;
      }
    });

    List<String> programs = prefs.getStringList('programs_$category') ?? [];

    for (String program in programs) {
      for (int i = 1; i <= 9; i++) {
        if (program.startsWith('$i-')) {
          setState(() {
            _programNames[i] = program;
          });
        }
      }
    }
  }

  Future<void> _loadShotsForProgram(int index) async {
    final programName = _programNames[index];
    if (programName != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String category = _leftSelected ? "TRL" : "TRR";
      _currentShotCount = prefs.getInt("${category}_${programName}_ShotCount") ?? 1;

      setState(() {
        _shots = List.generate(
          _currentShotCount,
              (i) => {
            "Speed": TextEditingController(
                text: (sessionTrainingSettings["${category}_${programName}_Speed_$i"] ??
                    prefs.getInt("${category}_${programName}_Speed_$i") ??
                    0)
                    .toString()),
            "Spin": TextEditingController(
                text: (sessionTrainingSettings["${category}_${programName}_Spin_$i"] ??
                    prefs.getInt("${category}_${programName}_Spin_$i") ??
                    0)
                    .toString()),
            "Freq": TextEditingController(
                text: (sessionTrainingSettings["${category}_${programName}_Freq_$i"] ??
                    prefs.getInt("${category}_${programName}_Freq_$i") ??
                    0)
                    .toString()),
            "Width": TextEditingController(
                text: (sessionTrainingSettings["${category}_${programName}_Width_$i"] ??
                    prefs.getInt("${category}_${programName}_Width_$i") ??
                    0)
                    .toString()),
            "Height": TextEditingController(
                text: (sessionTrainingSettings["${category}_${programName}_Height_$i"] ??
                    prefs.getInt("${category}_${programName}_Height_$i") ??
                    0)
                    .toString()),
          },
        );
      });
    }
  }

  Future<void> _saveShotSettings(int index) async {
    if (_selectedProgramIndex == -1) return;
    final programName = _programNames[_selectedProgramIndex];
    if (programName == null) return;

    String category = _leftSelected ? "TRL" : "TRR";

    // Store the settings in the session map instead of SharedPreferences
    sessionTrainingSettings["${category}_${programName}_Speed_$index"] = int.parse(_shots[index]["Speed"]!.text);
    sessionTrainingSettings["${category}_${programName}_Spin_$index"] = int.parse(_shots[index]["Spin"]!.text);
    sessionTrainingSettings["${category}_${programName}_Freq_$index"] = int.parse(_shots[index]["Freq"]!.text);
    sessionTrainingSettings["${category}_${programName}_Width_$index"] = int.parse(_shots[index]["Width"]!.text);
    sessionTrainingSettings["${category}_${programName}_Height_$index"] = int.parse(_shots[index]["Height"]!.text);

    print('*Temporary*: Settings for shot $index of program $programName saved temporarily.');
  }

  void _updateShotSettings(int index, String key, String value) {
    setState(() {
      _shots[index][key]!.text = value;
    });
    _saveShotSettings(index);
  }

  // This method is only for saving program data in developer mode
  Future<void> _saveProgram() async {
    if (_selectedProgramIndex == -1) return;
    final programName = _programNames[_selectedProgramIndex];
    if (programName == null) return;

    SharedPreferences prefs = await SharedPreferences.getInstance();
    String category = _leftSelected ? "TRL" : "TRR";

    for (int i = 0; i < _currentShotCount; i++) {
      await prefs.setInt("${category}_${programName}_Speed_$i", int.parse(_shots[i]["Speed"]!.text));
      await prefs.setInt("${category}_${programName}_Spin_$i", int.parse(_shots[i]["Spin"]!.text));
      await prefs.setInt("${category}_${programName}_Freq_$i", int.parse(_shots[i]["Freq"]!.text));
      await prefs.setInt("${category}_${programName}_Width_$i", int.parse(_shots[i]["Width"]!.text));
      await prefs.setInt("${category}_${programName}_Height_$i", int.parse(_shots[i]["Height"]!.text));
    }
    await prefs.setInt("${category}_${programName}_ShotCount", _currentShotCount);

    print('*AVH: Program $programName saved successfully by developer.');
  }

  void _sendProgramToPadelshooter(int index, BluetoothManager bluetoothManager) async {
    final programName = _programNames[index];

    if (programName != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String mode = prefs.getString('selected_mode') ?? 'Padel';
      int maxSpeed = mode == 'Tennis' ? 250 : 100;

      String category = _leftSelected ? "TRL" : "TRR";
      List<List<int>> program = [];

      for (int i = 0; i < _currentShotCount; i++) {
        List<int> shot = [
          int.parse(_shots[i]["Speed"]!.text),
          int.parse(_shots[i]["Spin"]!.text),
          int.parse(_shots[i]["Freq"]!.text),
          int.parse(_shots[i]["Width"]!.text),
          int.parse(_shots[i]["Height"]!.text),
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
      _isPauseActive = false;
    });
    _sendProgramToPadelshooter(_selectedProgramIndex, _bluetoothManager!);
  }

  void _handlePauseButtonPress() {
    print('*AVH: Pause button pressed');
    setState(() {
      _isPlayActive = false;
      _isPauseActive = true;
    });
    _bluetoothManager?.sendCommandToPadelshooter(command: 0); // Stop the shooter
  }

  void _handleOffButtonPress() async {
    print('*AVH: Off button pressed');
    setState(() {
      _isPlayActive = false;
      _isPauseActive = false;
      _selectedProgramIndex = -1;
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

  void _updateFieldSelection() {
    setState(() {
      _leftSelected = !_leftSelected;
      _loadPrograms().then((_) {
        if (_selectedProgramIndex != -1) {
          _loadShotsForProgram(_selectedProgramIndex);
        }
      });
    });
    print('*AVH: Field selection updated: ${_leftSelected ? "Left" : "Right"}');
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
                    if (_selectedProgramIndex != -1)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            children: [
                              _buildShotsHeader(),
                              _buildShotsList(),
                            ],
                          ),
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.isDeveloperMode)
                          ElevatedButton(
                            onPressed: _saveProgram, // Developer can save the program
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 10, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8)),
                              backgroundColor: Colors.cyan,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text(
                              'Save',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        _buildFieldSelectionButton(),
                      ],
                    ),
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
        ? 'assets/images/Padelbaan_full_green.png'
        : 'assets/images/Padelbaan_full.png';
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
                programName.split('-')[1].replaceAll('+', '\n'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
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

  Widget _buildShotsHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(width: 40),
        Expanded(
          child: Text(
            'Speed',
            style: const TextStyle(color: Colors.white, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            'Spin',
            style: const TextStyle(color: Colors.white, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            'Freq',
            style: const TextStyle(color: Colors.white, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            'Width',
            style: const TextStyle(color: Colors.white, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Text(
            'Height',
            style: const TextStyle(color: Colors.white, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildShotsList() {
    return ListView.builder(
      shrinkWrap: true,
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
            ..._shots[index].keys.map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: TextField(
                    controller: _shots[index][key],
                    keyboardType: key == "Spin"
                        ? const TextInputType.numberWithOptions(signed: true)
                        : TextInputType.number,
                    style: const TextStyle(color: Colors.white, fontSize: 10),
                    textAlign: TextAlign.center,
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
                    onChanged: (value) => _updateShotSettings(index, key, value),
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
            !_isPlayActive && !_isPauseActive,
            bluetoothManager,
            _handleOffButtonPress,
          ),
          _buildButton(
            context,
            AppLocalizations.of(context).translate('pause') ?? 'Pause',
            _isPauseActive,
            bluetoothManager,
            _handlePauseButtonPress,
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
