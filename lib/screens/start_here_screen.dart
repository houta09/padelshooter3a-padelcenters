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
  int _activeButton = -1;
  bool _isPlayActive = false;

  final Map<String, TextEditingController> _controllers = {
    "Speed": TextEditingController(),
    "Spin": TextEditingController(),
    "Freq": TextEditingController(),
    "Width": TextEditingController(),
    "Height": TextEditingController(),
    "Net": TextEditingController(),
  };

  final Map<int, int> _trainingValues = {
    1: 20,
    2: 23,
    3: 24,
    4: 33,
    5: 21,
    6: 23,
    7: 25,
    8: 23,
    9: 23,
  };

  int _currentTrainingValue = 20;
  int _currentTrainingIndex = 1;
  bool _leftSelected = false;
  bool _rightSelected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings(_currentTrainingIndex);
    print('*AVH: StartHereScreen initialized with training index: $_currentTrainingIndex');
  }

  Future<void> _loadSettings(int trainingIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _controllers["Speed"]?.text = (prefs.getInt("StartHere_Speed_$trainingIndex") ?? 15).toString();
      _controllers["Spin"]?.text = (prefs.getInt("StartHere_Spin_$trainingIndex") ?? 0).toString();
      _controllers["Freq"]?.text = (prefs.getInt("StartHere_Freq_$trainingIndex") ?? 40).toString();
      _controllers["Width"]?.text = (prefs.getInt("StartHere_Width_$trainingIndex") ?? 100).toString();
      _controllers["Height"]?.text = (prefs.getInt("StartHere_Height_$trainingIndex") ?? 40).toString();
      _controllers["Net"]?.text = (prefs.getInt("StartHere_Net_$trainingIndex") ?? 0).toString();
      _leftSelected = prefs.getBool("StartHere_LeftSelected_$trainingIndex") ?? false;
      _rightSelected = prefs.getBool("StartHere_RightSelected_$trainingIndex") ?? false;
    });
    print('*AVH: Loaded settings for training index: $trainingIndex');
  }

  Future<void> _saveSettings(int trainingIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt("StartHere_Speed_$trainingIndex", int.parse(_controllers["Speed"]!.text));
    await prefs.setInt("StartHere_Spin_$trainingIndex", int.parse(_controllers["Spin"]!.text));
    await prefs.setInt("StartHere_Freq_$trainingIndex", int.parse(_controllers["Freq"]!.text));
    await prefs.setInt("StartHere_Width_$trainingIndex", int.parse(_controllers["Width"]!.text));
    await prefs.setInt("StartHere_Height_$trainingIndex", int.parse(_controllers["Height"]!.text));
    await prefs.setInt("StartHere_Net_$trainingIndex", int.parse(_controllers["Net"]!.text));
    await prefs.setBool("StartHere_LeftSelected_$trainingIndex", _leftSelected);
    await prefs.setBool("StartHere_RightSelected_$trainingIndex", _rightSelected);
    print('*AVH: Saved settings for training index: $trainingIndex');
  }

  void _updateValue(String key, int change) {
    setState(() {
      int newValue;
      if (key == "Spin") {
        newValue = (int.parse(_controllers[key]!.text) + change).clamp(-50, 50);
      } else {
        newValue = (int.parse(_controllers[key]!.text) + change).clamp(0, 100);
      }
      _controllers[key]!.text = newValue.toString();
    });
    _saveSettings(_currentTrainingIndex);
    print('*AVH: Updated $key to new value: ${_controllers[key]!.text}');
  }

  void _updateTrainingValue(int index) {
    setState(() {
      _currentTrainingValue = _trainingValues[index]!;
      _currentTrainingIndex = index;
    });
    _loadSettings(index);
    print('*AVH: Training value updated to index: $index');
  }

  void _updateValueManually(String key, String value) {
    int? newValue = int.tryParse(value);
    if (newValue != null) {
      if (key == "Spin") {
        newValue = newValue.clamp(-50, 50);
      } else {
        newValue = newValue.clamp(0, 100);
      }
      setState(() {
        _controllers[key]!.text = newValue.toString();
      });
      _saveSettings(_currentTrainingIndex);
      print('*AVH: Manually updated $key to new value: $newValue');
    }
  }

  void _updateFieldSelection(String side) {
    setState(() {
      if (side == "left") {
        _leftSelected = !_leftSelected;
      } else if (side == "right") {
        _rightSelected = !_rightSelected;
      }
    });
    _saveSettings(_currentTrainingIndex);
    print('*AVH: Field selection updated: $side');
  }

  Map<String, int> _getFieldValues() {
    int hmin, hmax;
    if (_leftSelected && _rightSelected) {
      hmin = 0;
      hmax = 100;
    } else if (_leftSelected) {
      hmin = 0;
      hmax = 50;
    } else if (_rightSelected) {
      hmin = 50;
      hmax = 100;
    } else {
      hmin = 0;
      hmax = 100;
    }
    print('*AVH: Field values calculated: hmin=$hmin, hmax=$hmax');
    return {"Hmin": hmin, "Hmax": hmax};
  }

  Future<int> _getMaxSpeed() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString('selected_mode') ?? 'Padel';
    return mode == 'Tennis' ? 250 : 100;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothManager>(
      builder: (context, bluetoothManager, child) {
        return Scaffold(
          body: Stack(
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
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            _buildCommandButtons(),
                            _buildFieldSelectionButtons(),
                            _buildValueControls(),
                            _buildControlButtons(bluetoothManager),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandButtons() {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      padding: const EdgeInsets.all(2),
      mainAxisSpacing: 10,
      crossAxisSpacing: 1,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: List.generate(9, (index) => _buildActionableButton(context, ["Fixed", "Hor movement", "2-Line", "Vert movement", "Random", "Bandeja Smash", "Volley", "Bajada", "Backglass"][index], index + 1)),
    );
  }

  Widget _buildControlButtons(BluetoothManager bluetoothManager) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildButton(context, AppLocalizations.of(context).translate('off') ?? 'Off', 0, bluetoothManager, () {
            setState(() {
              _activeButton = 0;
              _isPlayActive = false;
              bluetoothManager.sendCommandToPadelshooter(command: 0);
            });
            print('*AVH: Off button pressed');
          }),
          _buildButton(context, AppLocalizations.of(context).translate('play') ?? 'Play', 1, bluetoothManager, () async {
            setState(() {
              _isPlayActive = true;
            });
            var fieldValues = _getFieldValues();
            int maxSpeed = await _getMaxSpeed();
            bluetoothManager.sendCommandToPadelshooter(
              command: 10,
              maxSpeed: maxSpeed,
              delayLevel: 50,
              hmin: fieldValues["Hmin"]!,
              hmax: fieldValues["Hmax"]!,
              startSpeed: 100,
              speedFactor: 9,
              speed: int.parse(_controllers["Speed"]!.text),
              spin: int.parse(_controllers["Spin"]!.text),
              freq: int.parse(_controllers["Freq"]!.text),
              width: int.parse(_controllers["Width"]!.text),
              height: int.parse(_controllers["Height"]!.text),
              training: _currentTrainingValue,
              net: int.parse(_controllers["Net"]!.text),
              generalInfo: 1,
              endByte: 255,
            );
            print('*AVH: Play button pressed with maxSpeed: $maxSpeed, settings: ${_controllers["Speed"]!.text}, ${_controllers["Spin"]!.text}, ${_controllers["Freq"]!.text}');
          }),
        ],
      ),
    );
  }

  Widget _buildFieldSelectionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFieldButton(AppLocalizations.of(context).translate('left') ?? 'Left', _leftSelected, () => _updateFieldSelection("left")),
          const SizedBox(width: 6),
          Text(AppLocalizations.of(context).translate('side') ?? 'Side', style: const TextStyle(fontSize: 10, color: Colors.white)),
          const SizedBox(width: 6),
          _buildFieldButton(AppLocalizations.of(context).translate('right') ?? 'Right', _rightSelected, () => _updateFieldSelection("right")),
        ],
      ),
    );
  }

  Widget _buildFieldPercentControl(String key) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          key,
          style: const TextStyle(fontSize: 12, color: Colors.white),
        ),
        SizedBox(
          width: 50,
          height: 20,
          child: TextField(
            controller: _controllers[key],
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            decoration: const InputDecoration(
              border: InputBorder.none,
            ),
            onSubmitted: (value) => _updateValueManually(key, value),
            enabled: !_leftSelected && !_rightSelected,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldButton(String label, bool isSelected, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 20), // Adjusted padding
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: isSelected ? Colors.blue : Colors.grey[600]!,
        foregroundColor: Colors.white,
      ),
      child: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildButton(BuildContext context, String label, int index, BluetoothManager bluetoothManager, VoidCallback onPressed) {
    Color bgColor = (_isPlayActive && index == 1) || (_activeButton == index) ? Colors.blue : Colors.grey[600]!;

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

  Widget _buildActionableButton(BuildContext context, String label, int index) {
    String imageNormal = 'assets/images/Padelbaan_full_${label.toLowerCase().replaceAll(" ", "_")}.png';
    String imagePressed = 'assets/images/Padelbaan_full_${label.toLowerCase().replaceAll(" ", "_")}_green.png';

    String imageToShow = (_activeButton == index) ? imagePressed : imageNormal;

    return ElevatedButton(
      onPressed: () {
        setState(() {
          _activeButton = index;
          _updateTrainingValue(index);
        });
        print('*AVH: Actionable button pressed for label: $label');
      },
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
      child: Image.asset(
        imageToShow,
        width: 100,
        height: 61,
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildValueControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: _controllers.keys.map((key) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                AppLocalizations.of(context).translate(key.toLowerCase()) ?? key,
                style: const TextStyle(fontSize: 12, color: Colors.white),
              ),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: GestureDetector(
                  onLongPress: () => _updateValue(key, 10),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward),
                    onPressed: () => _updateValue(key, 1),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: 40,
                height: 40,
                child: TextField(
                  controller: _controllers[key],
                  keyboardType: key == "Spin" ? const TextInputType.numberWithOptions(signed: true) : TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                  ),
                  onSubmitted: (value) => _updateValueManually(key, value),
                ),
              ),
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white24,
                ),
                child: GestureDetector(
                  onLongPress: () => _updateValue(key, -10),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_downward),
                    onPressed: () => _updateValue(key, -1),
                    color: Colors.white,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 40,
                      minHeight: 40,
                    ),
                  ),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
