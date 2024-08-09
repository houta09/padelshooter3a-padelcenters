import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import '../utils/bluetooth_manager.dart';

class ProgramsScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const ProgramsScreen({super.key, required this.onNavigate});

  @override
  _ProgramsScreenState createState() => _ProgramsScreenState();
}

class _ProgramsScreenState extends State<ProgramsScreen> {
  final List<Map<String, TextEditingController>> _shots = List.generate(
    20,
        (_) => {
      "Speed": TextEditingController(),
      "Spin": TextEditingController(),
      "Freq": TextEditingController(),
      "Width": TextEditingController(),
      "Height": TextEditingController(),
    },
  );

  final TextEditingController _programNameController = TextEditingController();
  final TextEditingController _newCategoryController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  int _currentShotCount = 1;
  int _selectedShotIndex = -1;
  String? _selectedCategory;
  List<String> _categories = [];
  List<Map<String, String>> _filteredPrograms = [];
  BluetoothManager? _bluetoothManager;

  bool _isButtonPressed = false;
  bool _isPlayButtonPressed = false;
  int _maxSpeed = 100;

  @override
  void initState() {
    super.initState();
    _bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString('selected_mode') ?? 'Padel';
    setState(() {
      _maxSpeed = mode == 'Tennis' ? 250 : 100;
      _categories = prefs.getStringList('categories') ?? [];
    });
  }

  Future<void> _saveProgram() async {
    if (_programNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('Please enter a name for the program.') ?? 'Please enter a name for the program.')),
      );
      return;
    }

    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('Please select a category.') ?? 'Please select a category.')),
      );
      return;
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> programs = prefs.getStringList('programs_${_selectedCategory!}') ?? [];

    if (!programs.contains(_programNameController.text)) {
      programs.add(_programNameController.text);
      await prefs.setStringList('programs_${_selectedCategory!}', programs);
    }

    for (int i = 0; i < _currentShotCount; i++) {
      prefs.setInt("${_selectedCategory!}_${_programNameController.text}_Speed_$i", int.parse(_shots[i]["Speed"]!.text));
      prefs.setInt("${_selectedCategory!}_${_programNameController.text}_Spin_$i", int.parse(_shots[i]["Spin"]!.text));
      prefs.setInt("${_selectedCategory!}_${_programNameController.text}_Freq_$i", int.parse(_shots[i]["Freq"]!.text));
      prefs.setInt("${_selectedCategory!}_${_programNameController.text}_Width_$i", int.parse(_shots[i]["Width"]!.text));
      prefs.setInt("${_selectedCategory!}_${_programNameController.text}_Height_$i", int.parse(_shots[i]["Height"]!.text));
    }
    prefs.setInt("${_selectedCategory!}_${_programNameController.text}_ShotCount", _currentShotCount);
    print('*AVH: Program saved: ${_programNameController.text}');
  }

  Future<void> _loadProgram(String category, String programName) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int shotCount = prefs.getInt("${category}_${programName}_ShotCount") ?? 1;
    setState(() {
      _selectedCategory = category;
      _currentShotCount = shotCount;
      _programNameController.text = programName;
    });
    for (int i = 0; i < _currentShotCount; i++) {
      _shots[i]["Speed"]!.text = (prefs.getInt("${category}_${programName}_Speed_$i") ?? 0).toString();
      _shots[i]["Spin"]!.text = ((prefs.getInt("${category}_${programName}_Spin_$i") ?? 0)).toString();
      _shots[i]["Freq"]!.text = (prefs.getInt("${category}_${programName}_Freq_$i") ?? 0).toString();
      _shots[i]["Width"]!.text = (prefs.getInt("${category}_${programName}_Width_$i") ?? 0).toString();
      _shots[i]["Height"]!.text = (prefs.getInt("${category}_${programName}_Height_$i") ?? 0).toString();
    }
    print('*AVH: Program loaded: $programName');
  }

  Future<void> _deleteProgram(String programName) async {
    if (_selectedCategory == null) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> programs = prefs.getStringList('programs_${_selectedCategory!}') ?? [];
    programs.remove(programName);
    await prefs.setStringList('programs_${_selectedCategory!}', programs);

    for (int i = 0; i < _currentShotCount; i++) {
      await prefs.remove("${_selectedCategory!}_${programName}_Speed_$i");
      await prefs.remove("${_selectedCategory!}_${programName}_Spin_$i");
      await prefs.remove("${_selectedCategory!}_${programName}_Freq_$i");
      await prefs.remove("${_selectedCategory!}_${programName}_Width_$i");
      await prefs.remove("${_selectedCategory!}_${programName}_Height_$i");
    }
    await prefs.remove("${_selectedCategory!}_${programName}_ShotCount");
    print('*AVH: Program deleted: $programName');
  }

  Future<void> _playProgram() async {
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
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String mode = prefs.getString('selected_mode') ?? 'Padel';
    int maxSpeed = mode == 'Tennis' ? 250 : 100;

    await _bluetoothManager?.sendProgramToPadelshooter(program, maxSpeed);
    print('*AVH: Program played: ${_programNameController.text}');
  }

  void _addShot() {
    bool allFilled = true;

    for (int i = 0; i < _currentShotCount; i++) {
      _shots[i].forEach((key, controller) {
        if (controller.text.isEmpty) {
          allFilled = false;
        }
      });
    }

    if (allFilled) {
      if (_currentShotCount < 20) {
        setState(() {
          _currentShotCount++;
        });
        print('*AVH: Shot added');
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('Please fill in all fields for existing shots before adding a new one.') ?? 'Please fill in all fields for existing shots before adding a new one.')),
      );
    }
  }

  void _deleteShot() {
    if (_selectedShotIndex != -1 && _selectedShotIndex < _currentShotCount) {
      setState(() {
        _shots.removeAt(_selectedShotIndex);
        _currentShotCount--;
        _selectedShotIndex = -1;
      });
      print('*AVH: Shot deleted at index: $_selectedShotIndex');
    }
  }

  void _copyShot() {
    if (_selectedShotIndex != -1 && _selectedShotIndex < _currentShotCount && _currentShotCount < 20) {
      setState(() {
        _shots.insert(_selectedShotIndex + 1, {
          "Speed": TextEditingController(text: _shots[_selectedShotIndex]["Speed"]!.text),
          "Spin": TextEditingController(text: _shots[_selectedShotIndex]["Spin"]!.text),
          "Freq": TextEditingController(text: _shots[_selectedShotIndex]["Freq"]!.text),
          "Width": TextEditingController(text: _shots[_selectedShotIndex]["Width"]!.text),
          "Height": TextEditingController(text: _shots[_selectedShotIndex]["Height"]!.text),
        });
        _currentShotCount++;
      });
      print('*AVH: Shot copied at index: $_selectedShotIndex');
    }
  }

  void _moveShotUp() {
    if (_selectedShotIndex > 0) {
      setState(() {
        final shot = _shots.removeAt(_selectedShotIndex);
        _shots.insert(_selectedShotIndex - 1, shot);
        _selectedShotIndex--;
      });
      print('*AVH: Shot moved up at index: $_selectedShotIndex');
    }
  }

  void _moveShotDown() {
    if (_selectedShotIndex != -1 && _selectedShotIndex < _currentShotCount - 1) {
      setState(() {
        final shot = _shots.removeAt(_selectedShotIndex);
        _shots.insert(_selectedShotIndex + 1, shot);
        _selectedShotIndex++;
      });
      print('*AVH: Shot moved down at index: $_selectedShotIndex');
    }
  }

  Future<void> _showCategoryList(BuildContext context) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> categories = prefs.getStringList('categories') ?? [];

    final category = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('Select Category') ?? 'Select Category'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(categories[index]),
                  onTap: () {
                    Navigator.of(context).pop(categories[index]);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      categories.removeAt(index);
                      await prefs.setStringList('categories', categories);
                      Navigator.of(context).pop();
                      _showCategoryList(context);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextField(
              controller: _newCategoryController,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context).translate('New Category') ?? 'New Category',
              ),
            ),
            TextButton(
              onPressed: () async {
                if (_newCategoryController.text.isNotEmpty) {
                  categories.add(_newCategoryController.text);
                  await prefs.setStringList('categories', categories);
                  _newCategoryController.clear();
                  Navigator.of(context).pop();
                  _showCategoryList(context);
                }
              },
              child: Text(AppLocalizations.of(context).translate('Add') ?? 'Add'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).translate('Cancel') ?? 'Cancel'),
            ),
          ],
        );
      },
    );

    if (category != null) {
      setState(() {
        _selectedCategory = category;
        _searchPrograms();
      });
      print('*AVH: Category selected: $_selectedCategory');
    }
  }

  Future<void> _showProgramList(BuildContext context) async {
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('Please select a category first.') ?? 'Please select a category first.')),
      );
      return;
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> programs = prefs.getStringList('programs_${_selectedCategory!}') ?? [];

    final programName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(AppLocalizations.of(context).translate('Load Program') ?? 'Load Program'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: programs.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(programs[index]),
                  onTap: () {
                    Navigator.of(context).pop(programs[index]);
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      _deleteProgram(programs[index]);
                      programs.removeAt(index);
                      await prefs.setStringList('programs_${_selectedCategory!}', programs);
                      Navigator.of(context).pop();
                      _showProgramList(context);
                    },
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(AppLocalizations.of(context).translate('Cancel') ?? 'Cancel'),
            ),
          ],
        );
      },
    );

    if (programName != null) {
      _loadProgram(_selectedCategory!, programName);
    }
  }

  void _resetButtonStates() {
    setState(() {
      _isButtonPressed = false;
      _isPlayButtonPressed = false;
    });
  }

  Future<void> _searchPrograms() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> allFilteredPrograms = [];

    if (_selectedCategory == null) {
      for (String category in _categories) {
        List<String> programs = prefs.getStringList('programs_$category') ?? [];
        if (_searchController.text.isEmpty) {
          allFilteredPrograms.addAll(programs.map((program) => {'category': category, 'program': program}));
        } else {
          allFilteredPrograms.addAll(programs.where((program) => program.toLowerCase().contains(_searchController.text.toLowerCase())).map((program) => {'category': category, 'program': program}));
        }
      }
    } else {
      List<String> programs = prefs.getStringList('programs_${_selectedCategory!}') ?? [];
      if (_searchController.text.isEmpty) {
        allFilteredPrograms = programs.map((program) => {'category': _selectedCategory!, 'program': program}).toList();
      } else {
        allFilteredPrograms = programs.where((program) => program.toLowerCase().contains(_searchController.text.toLowerCase())).map((program) => {'category': _selectedCategory!, 'program': program}).toList();
      }
    }

    setState(() {
      _filteredPrograms = allFilteredPrograms;
      _programNameController.clear();
      _clearShots();
    });

    print('Programs filtered: $_filteredPrograms');
  }

  void _resetFilters() {
    setState(() {
      _selectedCategory = null;
      _programNameController.clear();
      _searchController.clear();
      _filteredPrograms = [];
      _clearShots();
    });
  }

  void _clearShots() {
    setState(() {
      _currentShotCount = 0;
      for (var shot in _shots) {
        shot.forEach((key, controller) {
          controller.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage("assets/images/background_app.jpg"),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListView(
                children: [
                  TextField(
                    controller: _programNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).translate('pn') ?? 'Program Name',
                      labelStyle: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    onPressed: () {
                      _resetButtonStates();
                      setState(() {
                        _isButtonPressed = true;
                      });
                      _showCategoryList(context);
                    },
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: _isButtonPressed ? Colors.blue : Colors.grey[700],
                      fixedSize: const Size(150, 40),
                    ),
                    child: Text(_selectedCategory ?? (AppLocalizations.of(context).translate('cat') ?? 'Category')),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context).translate('search_programs') ?? 'Search Programs',
                      labelStyle: const TextStyle(color: Colors.white),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white),
                        onPressed: _searchPrograms,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _searchPrograms,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.blue,
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('search') ?? 'Search'),
                      ),
                      ElevatedButton(
                        onPressed: _resetFilters,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('reset') ?? 'Reset'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  ..._filteredPrograms.map((program) {
                    return ListTile(
                      title: Text(program['program']!, style: const TextStyle(color: Colors.white)),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () async {
                          _selectedCategory = program['category'];
                          _deleteProgram(program['program']!);
                          _searchPrograms();
                        },
                      ),
                      onTap: () {
                        _loadProgram(program['category']!, program['program']!);
                      },
                    );
                  }).toList(),
                  const SizedBox(height: 20),
                  ...List.generate(_currentShotCount, (index) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Theme(
                              data: ThemeData(unselectedWidgetColor: Colors.white),
                              child: Checkbox(
                                value: _selectedShotIndex == index,
                                onChanged: (bool? value) {
                                  setState(() {
                                    _selectedShotIndex = value! ? index : -1;
                                  });
                                },
                              ),
                            ),
                            Text('${AppLocalizations.of(context).translate('shot') ?? 'Shot'} ${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 14)),
                            const SizedBox(width: 10),
                            ..._shots[index].keys.map((key) {
                              return Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                  child: Column(
                                    children: [
                                      Text(AppLocalizations.of(context).translate(key.toLowerCase()) ?? key, style: const TextStyle(color: Colors.white, fontSize: 10)),
                                      SizedBox(
                                        width: 50,
                                        height: 30,
                                        child: TextField(
                                          controller: _shots[index][key],
                                          keyboardType: key == "Spin" ? const TextInputType.numberWithOptions(signed: true) : TextInputType.number,
                                          style: const TextStyle(color: Colors.white, fontSize: 10),
                                          decoration: const InputDecoration(
                                            contentPadding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                            border: OutlineInputBorder(),
                                            enabledBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderSide: BorderSide(color: Colors.white),
                                            ),
                                          ),
                                          onSubmitted: (value) {
                                            if (key == "Spin") {
                                              int? newValue = int.tryParse(value);
                                              if (newValue != null) {
                                                newValue = newValue.clamp(-50, 50);
                                                setState(() {
                                                  _shots[index][key]!.text = newValue.toString();
                                                });
                                              }
                                            }
                                            print('*AVH: Shot value updated for $key: $value');
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                        const Divider(color: Colors.white),
                      ],
                    );
                  }),
                  if (_currentShotCount < 20)
                    Center(
                      child: ElevatedButton(
                        onPressed: _addShot,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('as') ?? 'Add Shot'),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _saveProgram();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('savep') ?? 'Save Program', style: const TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _showProgramList(context);
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('loadp') ?? 'Load Program', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () {
                          _resetButtonStates();
                          setState(() {
                            _isPlayButtonPressed = true;
                          });
                          _playProgram();
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _isPlayButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('playprog') ?? 'Play Program', style: const TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _bluetoothManager?.sendCommandToPadelshooter(command: 0);
                          print('*AVH: Bluetooth command sent: Off');
                        },
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('off') ?? 'Off', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _selectedShotIndex != -1 ? () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _deleteShot();
                        } : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _selectedShotIndex != -1 && _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('delshot') ?? 'Delete Shot', style: const TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: _selectedShotIndex != -1 ? () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _copyShot();
                        } : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _selectedShotIndex != -1 && _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('copyshot') ?? 'Copy Shot', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _selectedShotIndex > 0 ? () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _moveShotUp();
                        } : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _selectedShotIndex > 0 && _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('mu') ?? 'Move Up', style: const TextStyle(fontSize: 12)),
                      ),
                      ElevatedButton(
                        onPressed: _selectedShotIndex != -1 && _selectedShotIndex < _currentShotCount - 1 ? () {
                          _resetButtonStates();
                          setState(() {
                            _isButtonPressed = true;
                          });
                          _moveShotDown();
                        } : null,
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: _selectedShotIndex != -1 && _selectedShotIndex < _currentShotCount - 1 && _isButtonPressed ? Colors.blue : Colors.grey[700],
                          fixedSize: const Size(150, 40),
                        ),
                        child: Text(AppLocalizations.of(context).translate('md') ?? 'Move Down', style: const TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
