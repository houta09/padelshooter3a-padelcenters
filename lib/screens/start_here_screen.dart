import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    6: 20,
    7: 25,
    8: 20,
    9: 20,
  };

  int _currentTrainingValue = 20;
  int _currentTrainingIndex = 1;
  bool _leftSelected = false;
  bool _rightSelected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings(_currentTrainingIndex);
  }

  Future<void> _loadSettings(int trainingIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _controllers["Speed"]?.text = (prefs.getInt("Speed_$trainingIndex") ?? 15).toString();
      _controllers["Spin"]?.text = (50 - (prefs.getInt("Spin_$trainingIndex") ?? 50)).toString();
      _controllers["Freq"]?.text = (prefs.getInt("Freq_$trainingIndex") ?? 40).toString();
      _controllers["Width"]?.text = (prefs.getInt("Width_$trainingIndex") ?? 100).toString();
      _controllers["Height"]?.text = (prefs.getInt("Height_$trainingIndex") ?? 40).toString();
      _controllers["Net"]?.text = (prefs.getInt("Net_$trainingIndex") ?? 0).toString();
      _leftSelected = prefs.getBool("LeftSelected_$trainingIndex") ?? false;
      _rightSelected = prefs.getBool("RightSelected_$trainingIndex") ?? false;
    });
  }

  Future<void> _saveSettings(int trainingIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt("Speed_$trainingIndex", int.parse(_controllers["Speed"]!.text));
    await prefs.setInt("Spin_$trainingIndex", 50 - int.parse(_controllers["Spin"]!.text));
    await prefs.setInt("Freq_$trainingIndex", int.parse(_controllers["Freq"]!.text));
    await prefs.setInt("Width_$trainingIndex", int.parse(_controllers["Width"]!.text));
    await prefs.setInt("Height_$trainingIndex", int.parse(_controllers["Height"]!.text));
    await prefs.setInt("Net_$trainingIndex", int.parse(_controllers["Net"]!.text));
    await prefs.setBool("LeftSelected_$trainingIndex", _leftSelected);
    await prefs.setBool("RightSelected_$trainingIndex", _rightSelected);
  }

  void _updateValue(String key, int change) {
    setState(() {
      int newValue = (int.parse(_controllers[key]!.text) + change).clamp(-50, 50);
      _controllers[key]!.text = newValue.toString();
    });
    _saveSettings(_currentTrainingIndex);
  }

  void _updateTrainingValue(int index) {
    setState(() {
      _currentTrainingValue = _trainingValues[index]!;
      _currentTrainingIndex = index;
    });
    _loadSettings(index);
  }

  void _updateValueManually(String key, String value) {
    int? newValue = int.tryParse(value);
    if (newValue != null && newValue >= -50 && newValue <= 50) {
      setState(() {
        _controllers[key]!.text = newValue.toString();
      });
      _saveSettings(_currentTrainingIndex);
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
    return {"Hmin": hmin, "Hmax": hmax};
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BluetoothManager>(
      builder: (context, bluetoothManager, child) {
        return Scaffold(
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
              SingleChildScrollView(
                child: Visibility(
                  visible: bluetoothManager.isConnected,
                  replacement: const Center(child: CircularProgressIndicator()),
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
        );
      },
    );
  }

  Widget _buildCommandButtons() {
    return GridView.count(
      crossAxisCount: 3,
      childAspectRatio: 2.2,
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
          _buildButton(context, "Off", 0, bluetoothManager, () {
            setState(() {
              _activeButton = 0;
              _isPlayActive = false;
              bluetoothManager.sendCommandToPadelshooter(command: 0);
            });
          }),
          _buildButton(context, "Play", 1, bluetoothManager, () {
            setState(() {
              _isPlayActive = true;
            });
            var fieldValues = _getFieldValues();
            bluetoothManager.sendCommandToPadelshooter(
              command: 10,
              maxSpeed: 100,
              delayLevel: 50,
              hmin: fieldValues["Hmin"]!,
              hmax: fieldValues["Hmax"]!,
              startSpeed: 100,
              speedFactor: 9,
              speed: int.parse(_controllers["Speed"]!.text),
              spin: 50 - int.parse(_controllers["Spin"]!.text),
              freq: int.parse(_controllers["Freq"]!.text),
              width: int.parse(_controllers["Width"]!.text),
              height: int.parse(_controllers["Height"]!.text),
              training: _currentTrainingValue,
              net: int.parse(_controllers["Net"]!.text),
              generalInfo: 1,
              endByte: 255,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFieldSelectionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildFieldButton("Left", _leftSelected, () => _updateFieldSelection("left")),
          const SizedBox(width: 6),
          const Text("Side", style: TextStyle(fontSize: 14, color: Colors.white)),
          const SizedBox(width: 6),
          _buildFieldButton("Right", _rightSelected, () => _updateFieldSelection("right")),
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
            keyboardType: TextInputType.numberWithOptions(signed: true),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: bgColor,
        foregroundColor: Colors.white,
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(label, style: const TextStyle(fontSize: 16)),
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
                key,
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
                  keyboardType: key == "Spin" ? TextInputType.numberWithOptions(signed: true) : TextInputType.number,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
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
