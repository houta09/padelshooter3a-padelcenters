import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:convert';
import '../main.dart';
import '../utils/app_localizations.dart';
import '../utils/bluetooth_manager.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int) onNavigate;
  final bool developer; // Add developer flag

  const SettingsScreen({Key? key, required this.onNavigate, this.developer = false}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedLanguage;
  late BluetoothManager _bluetoothManager;
  String _selectedMode = 'Padel'; // Default mode

  @override
  void initState() {
    super.initState();
    _bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language_code') ?? 'en';
      _selectedMode = prefs.getString('selected_mode') ?? 'Padel';
      if (widget.developer) {
        _bluetoothManager.startSpeed = prefs.getInt('startSpeed') ?? 50;
        _bluetoothManager.speedFactor = prefs.getInt('speedFactor') ?? 5;
      }
    });
    print('*AVH-lang-s: Loaded language preference: $_selectedLanguage');
    print('*AVH-mode: Loaded mode preference: $_selectedMode');
    if (widget.developer) {
      print('*AVH-settings: Loaded startSpeed: ${_bluetoothManager.startSpeed}');
      print('*AVH-settings: Loaded speedFactor: ${_bluetoothManager.speedFactor}');
    }
  }

  Future<void> _setLanguagePreference(String languageCode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
    setState(() {
      _selectedLanguage = languageCode;
    });
    _setLocale(languageCode);
  }

  void _setLocale(String languageCode) {
    Locale locale = Locale(languageCode);
    PadelShooterApp.setLocale(context, locale);
    print('*AVH-lang-s: Setting locale to: $languageCode');
  }

  Future<void> _setModePreference(String mode) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_mode', mode);
    setState(() {
      _selectedMode = mode;
    });
    print('*AVH-mode: Mode preference set to: $mode');
  }

  Future<void> _setStartSpeed(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('startSpeed', value);
    setState(() {
      _bluetoothManager.startSpeed = value;
    });
    print('*AVH-settings: Start speed set to: $value');
  }

  Future<void> _setSpeedFactor(int value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt('speedFactor', value);
    setState(() {
      _bluetoothManager.speedFactor = value;
    });
    print('*AVH-settings: Speed factor set to: $value');
  }

  Future<bool> _requestPermissions() async {
    print('*AVH-Export: Requesting storage permission');

    if (Platform.isAndroid) {
      var status = await Permission.manageExternalStorage.status;
      if (!status.isGranted) {
        status = await Permission.manageExternalStorage.request();
        print('*AVH-Export: Storage permission requested. New status: $status');
      }
      if (status.isGranted) {
        print('*AVH-Export: Storage permission granted.');
        return true;
      } else {
        print('*AVH-Export: Storage permission not granted.');
        return false;
      }
    } else {
      return true;
    }
  }

  Future<bool> _requestStoragePermission() async {
    if (Platform.isIOS) {
      return true; // No need for permissions on iOS
    }

    var status = await Permission.storage.status;
    print('*AVH-Import: Initial storage permission status: $status');

    if (status.isDenied || status.isRestricted || status.isPermanentlyDenied) {
      print('*AVH-Import: Requesting storage permission.');
      status = await Permission.storage.request();
      print('*AVH-Import: Requested storage permission status: $status');
    }

    if (status.isPermanentlyDenied) {
      print('*AVH-Import: Storage permission is permanently denied.');
      await _showPermissionDeniedDialog();
      return false;
    }

    if (!status.isGranted) {
      print('*AVH-Import: Storage permission not granted.');
      await _showPermissionDeniedDialog();
    }

    print('*AVH-Import: Storage permission granted.');
    return true;
  }

  Future<void> _showPermissionDeniedDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use your file manager for import of file'),
        content: const Text('Locate your programs file on your phone'),
        actions: [
          TextButton(
            child: const Text('Open file manager'),
            onPressed: () async {
              Navigator.of(context).pop();
              await openAppSettings();
            },
          ),
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<bool> _showReplaceOrAddDialog(BuildContext context) async {
    bool replace = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Programs'),
        content: const Text('Do you want to replace existing programs or add to them?'),
        actions: [
          TextButton(
            child: const Text('Replace'),
            onPressed: () {
              replace = true;
              Navigator.of(context).pop();
            },
          ),
          TextButton(
            child: const Text('Add'),
            onPressed: () {
              replace = false;
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
    return replace;
  }

  Future<void> _importPrograms(BuildContext context) async {
    print('*AVH-Import: Import Programs button pressed');

    bool permissionGranted = await _requestPermissions();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!permissionGranted) {
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        print('*AVH-Import: File path: ${file.path}');

        if (await file.exists()) {
          String content = await file.readAsString();
          print('*AVH-Import: File content: $content');
          Map<String, dynamic> allPrograms = json.decode(content);
          SharedPreferences prefs = await SharedPreferences.getInstance();

          // Ask the user whether to replace or add programs
          bool replace = await _showReplaceOrAddDialog(context);

          if (replace) {
            // Clear existing programs
            for (String key in prefs.getKeys()) {
              if (key.startsWith('programs_') || key.contains('_ShotCount') || key.contains('_Speed') || key.contains('_Spin') || key.contains('_Freq') || key.contains('_Width') || key.contains('_Height')) {
                await prefs.remove(key);
              }
            }
          }

          List<String> categories = prefs.getStringList('categories') ?? [];
          for (String category in allPrograms.keys) {
            if (!categories.contains(category)) {
              categories.add(category); // Add new category
            }
            List<String> programs = prefs.getStringList('programs_$category') ?? [];
            for (String program in allPrograms[category].keys) {
              if (!programs.contains(program)) {
                programs.add(program);
              }
              Map<String, dynamic> programData = allPrograms[category][program];
              int shotCount = programData["shotCount"];
              prefs.setInt('${category}_${program}_ShotCount', shotCount);

              for (int i = 0; i < shotCount; i++) {
                Map<String, int> shot = Map<String, int>.from(programData["shots"][i]);
                prefs.setInt('${category}_${program}_Speed_$i', shot["Speed"]!);
                prefs.setInt('${category}_${program}_Spin_$i', shot["Spin"]!);
                prefs.setInt('${category}_${program}_Freq_$i', shot["Freq"]!);
                prefs.setInt('${category}_${program}_Width_$i', shot["Width"]!);
                prefs.setInt('${category}_${program}_Height_$i', shot["Height"]!);
              }
            }
            prefs.setStringList('programs_$category', programs);
          }
          prefs.setStringList('categories', categories); // Save categories
          print('*AVH-Import: Programs and categories imported successfully');
        } else {
          print('*AVH-Import: File not found');
        }
      }
    } catch (e) {
      print('*AVH-Import: Error importing programs: $e');
    }
  }

  Future<void> _importSettings(BuildContext context) async {
    print('*AVH-Import: Import Settings button pressed');

    bool permissionGranted = await _requestPermissions();
    await Future.delayed(const Duration(milliseconds: 500));
    if (!permissionGranted) {
      return;
    }

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null) {
        File file = File(result.files.single.path!);
        print('*AVH-Import: File path: ${file.path}');

        if (await file.exists()) {
          String content = await file.readAsString();
          print('*AVH-Import: File content: $content');
          Map<String, dynamic> allSettings = json.decode(content);

          for (int i = 1; i <= 9; i++) {
            await _setTrainingSettings('StartHere', i, allSettings['StartHere_training_$i']);
            await _setTrainingSettings('Trainings', i, allSettings['Trainings_training_$i']);
          }

          print('*AVH-Import: Settings imported successfully');
        } else {
          print('*AVH-Import: File not found');
        }
      }
    } catch (e) {
      print('*AVH-Import: Error importing settings: $e');
    }
  }

  Future<Map<String, dynamic>> _getTrainingSettings(String prefix, int trainingIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      "Speed": prefs.getInt("${prefix}_Speed_$trainingIndex") ?? 15,
      "Spin": prefs.getInt("${prefix}_Spin_$trainingIndex") ?? 0,
      "Freq": prefs.getInt("${prefix}_Freq_$trainingIndex") ?? 40,
      "Width": prefs.getInt("${prefix}_Width_$trainingIndex") ?? 100,
      "Height": prefs.getInt("${prefix}_Height_$trainingIndex") ?? 40,
      "Net": prefs.getInt("${prefix}_Net_$trainingIndex") ?? 0,
      "Delay": prefs.getInt("${prefix}_Delay_$trainingIndex") ?? 50,
      "LeftSelected": prefs.getBool("${prefix}_LeftSelected_$trainingIndex") ?? false,
      "RightSelected": prefs.getBool("${prefix}_RightSelected_$trainingIndex") ?? false,
    };
  }

  Future<void> _setTrainingSettings(String prefix, int trainingIndex, Map<String, dynamic> settings) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt("${prefix}_Speed_$trainingIndex", settings["Speed"] as int);
    await prefs.setInt("${prefix}_Spin_$trainingIndex", settings["Spin"] as int);
    await prefs.setInt("${prefix}_Freq_$trainingIndex", settings["Freq"] as int);
    await prefs.setInt("${prefix}_Width_$trainingIndex", settings["Width"] as int);
    await prefs.setInt("${prefix}_Height_$trainingIndex", settings["Height"] as int);
    await prefs.setInt("${prefix}_Net_$trainingIndex", settings["Net"] as int);
    await prefs.setInt("${prefix}_Delay_$trainingIndex", settings["Delay"] as int);
    await prefs.setBool("${prefix}_LeftSelected_$trainingIndex", settings["LeftSelected"] as bool);
    await prefs.setBool("${prefix}_RightSelected_$trainingIndex", settings["RightSelected"] as bool);

    print('*AVH-SetTraining: Saved training settings for $prefix training $trainingIndex: $settings');
  }

  Future<void> _exportSettings() async {
    print('*AVH-Export: Export button pressed');
    if (Platform.isAndroid) {
      bool permissionGranted = await _requestPermissions();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!permissionGranted) {
        print('*AVH-Export: Storage permission not granted. Cannot export settings.');
        return;
      } else {
        print('*AVH-Export: Storage permission is granted. Haleluja.');
      }
    }

    Map<String, dynamic> allSettings = {};
    for (int i = 1; i <= 9; i++) {
      allSettings['StartHere_training_$i'] = await _getTrainingSettings('StartHere', i);
      allSettings['Trainings_training_$i'] = await _getTrainingSettings('Trainings', i);
    }
    print('*AVH-Export: Settings to export: $allSettings');

    try {
      final directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      print('*AVH-Export: Directory: ${directory.path}');
      if (directory == null) {
        print('*AVH-Export: Directory is null');
        return;
      }

      final file = File('${directory.path}/training_settings_PS3A.json');
      print('*AVH-Export: File path: ${file.path}');

      await file.create(recursive: true);
      await file.writeAsString(json.encode(allSettings));

      if (await file.exists()) {
        print('*AVH-Export: File exists: ${file.path}');
        String content = await file.readAsString();
        print('*AVH-Export: File content: $content');

        await Share.shareXFiles(
            [XFile(file.path)], text: 'Here are my PadelShooter settings.');
        print('*AVH-Export: Share dialog opened');
      } else {
        print('*AVH-Export: File not found');
      }
    } catch (e) {
      print('*AVH-Export: Error exporting settings: $e');
    }
  }

  Future<void> _importSettingsFromWeb() async {
    print('*AVH-Import: Import Settings from Web button pressed');
    try {
      final response = await http.get(Uri.parse('https://padelshooter.com/wp-content/uploads/2024/07/training_settings.json'));

      if (response.statusCode == 200) {
        print('*AVH-Import: Successfully fetched settings from web');
        Map<String, dynamic> settings = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        for (int i = 1; i <= 9; i++) {
          await prefs.setInt('StartHere_Speed_$i', settings['StartHere_training_$i']['Speed'] as int);
          await prefs.setInt('StartHere_Spin_$i', settings['StartHere_training_$i']['Spin'] as int);
          await prefs.setInt('StartHere_Freq_$i', settings['StartHere_training_$i']['Freq'] as int);
          await prefs.setInt('StartHere_Width_$i', settings['StartHere_training_$i']['Width'] as int);
          await prefs.setInt('StartHere_Height_$i', settings['StartHere_training_$i']['Height'] as int);
          await prefs.setInt('StartHere_Net_$i', settings['StartHere_training_$i']['Net'] as int);
          await prefs.setInt('StartHere_Delay_$i', settings['StartHere_training_$i']['Delay'] as int);
          await prefs.setBool('StartHere_LeftSelected_$i', settings['StartHere_training_$i']['LeftSelected'] as bool);
          await prefs.setBool('StartHere_RightSelected_$i', settings['StartHere_training_$i']['RightSelected'] as bool);

          await prefs.setInt('Trainings_Speed_$i', settings['Trainings_training_$i']['Speed'] as int);
          await prefs.setInt('Trainings_Spin_$i', settings['Trainings_training_$i']['Spin'] as int);
          await prefs.setInt('Trainings_Freq_$i', settings['Trainings_training_$i']['Freq'] as int);
          await prefs.setInt('Trainings_Width_$i', settings['Trainings_training_$i']['Width'] as int);
          await prefs.setInt('Trainings_Height_$i', settings['Trainings_training_$i']['Height'] as int);
          await prefs.setInt('Trainings_Net_$i', settings['Trainings_training_$i']['Net'] as int);
          await prefs.setInt('Trainings_Delay_$i', settings['Trainings_training_$i']['Delay'] as int);
          await prefs.setBool('Trainings_LeftSelected_$i', settings['Trainings_training_$i']['LeftSelected'] as bool);
          await prefs.setBool('Trainings_RightSelected_$i', settings['Trainings_training_$i']['RightSelected'] as bool);
        }

        print('*AVH-Import: Settings imported successfully from web');
      } else {
        print('*AVH-Import: Error fetching settings from web. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('*AVH-Import: Error importing settings from web: $e');
    }
  }

  Future<void> _exportPrograms() async {
    print('*AVH-Export: Export Programs button pressed');
    if (Platform.isAndroid) {
      bool permissionGranted = await _requestPermissions();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!permissionGranted) {
        print('*AVH-Export: Storage permission not granted. Cannot export settings.');
        return;
      } else {
        print('*AVH-Export: Storage permission is granted. Haleluja.');
      }
    }

    SharedPreferences prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> allPrograms = {};
    Set<String> categories = prefs.getKeys().where((key) => key.startsWith('programs_')).map((key) => key.split('_')[1]).toSet();

    for (String category in categories) {
      List<String> programs = prefs.getStringList('programs_$category') ?? [];
      allPrograms[category] = {};

      for (String program in programs) {
        int shotCount = prefs.getInt('${category}_${program}_ShotCount') ?? 0;
        allPrograms[category][program] = {"shotCount": shotCount, "shots": []};

        for (int i = 0; i < shotCount; i++) {
          Map<String, int> shot = {
            "Speed": prefs.getInt('${category}_${program}_Speed_$i') ?? 0,
            "Spin": prefs.getInt('${category}_${program}_Spin_$i') ?? 0,
            "Freq": prefs.getInt('${category}_${program}_Freq_$i') ?? 0,
            "Width": prefs.getInt('${category}_${program}_Width_$i') ?? 0,
            "Height": prefs.getInt('${category}_${program}_Height_$i') ?? 0,
          };
          allPrograms[category][program]["shots"].add(shot);
        }
      }
    }
    print('*AVH-Export: Programs to export: $allPrograms');

    try {
      final directory = Platform.isAndroid
          ? Directory('/storage/emulated/0/Download')
          : await getApplicationDocumentsDirectory();

      print('*AVH-Export: Directory: ${directory.path}');
      if (directory == null) {
        print('*AVH-Export: Directory is null');
        return;
      }

      final file = File('${directory.path}/programs_PS3A.json');
      print('*AVH-Export: File path: ${file.path}');

      await file.create(recursive: true);
      await file.writeAsString(json.encode(allPrograms));

      if (await file.exists()) {
        print('*AVH-Export: File exists: ${file.path}');
        String content = await file.readAsString();
        print('*AVH-Export: File content: $content');

        await Share.shareXFiles(
            [XFile(file.path)], text: 'Here are my PadelShooter programs.');
        print('*AVH-Export: Share dialog opened');
      } else {
        print('*AVH-Export: File not found');
      }
    } catch (e) {
      print('*AVH-Export: Error exporting programs: $e');
    }
  }

  Future<void> _importProgramsFromWeb() async {
    print('*AVH-Import: Import Programs from Web button pressed');
    try {
      final response = await http.get(Uri.parse('https://padelshooter.com/wp-content/uploads/programs_PS3A.json'));

      if (response.statusCode == 200) {
        print('*AVH-Import: Successfully fetched programs from web');
        Map<String, dynamic> programs = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        List<String> categories = [];
        for (String category in programs.keys) {
          categories.add(category); // Add category to the list
          List<String> programNames = [];
          for (String program in programs[category].keys) {
            programNames.add(program);
            Map<String, dynamic> programData = programs[category][program];
            int shotCount = programData["shotCount"];
            prefs.setInt('${category}_${program}_ShotCount', shotCount);

            for (int i = 0; i < shotCount; i++) {
              Map<String, int> shot = Map<String, int>.from(programData["shots"][i]);
              prefs.setInt('${category}_${program}_Speed_$i', shot["Speed"]!);
              prefs.setInt('${category}_${program}_Spin_$i', shot["Spin"]!);
              prefs.setInt('${category}_${program}_Freq_$i', shot["Freq"]!);
              prefs.setInt('${category}_${program}_Width_$i', shot["Width"]!);
              prefs.setInt('${category}_${program}_Height_$i', shot["Height"]!);
            }
          }
          prefs.setStringList('programs_$category', programNames);
        }
        prefs.setStringList('categories', categories); // Save categories
        print('*AVH-Import: Programs and categories imported successfully from web');
      } else {
        print('*AVH-Import: Error fetching programs from web. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('*AVH-Import: Error importing programs from web: $e');
    }
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
    }
  }

  void _sendPositioningCommand(int width) async {
    try {
      await _bluetoothManager.sendCommandToPadelshooter(
        command: 10,
        speed: 14,
        spin: 0,
        freq: 40,
        width: width,
        height: 40,
        net: 0,
        generalInfo: 1,
        endByte: 255,
        training: 20,
        maxSpeed: _selectedMode == 'Tennis' ? 250 : 100,
      );
      await Future.delayed(Duration(seconds: 10));
      await _bluetoothManager.sendCommandToPadelshooter(command: 0);
    } catch (e) {
      print('Error sending positioning command: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    print('*AVH-lang-s: Building SettingsScreen with selected language: $_selectedLanguage');

    final Map<String, String> languages = {
      'en': AppLocalizations.of(context)?.translate('english') ?? 'English',
      'es': AppLocalizations.of(context)?.translate('spanish') ?? 'Spanish',
      'fr': AppLocalizations.of(context)?.translate('french') ?? 'French',
      'zh': AppLocalizations.of(context)?.translate('chinese') ?? 'Chinese',
      'pt': AppLocalizations.of(context)?.translate('portuguese') ?? 'Portuguese',
      'pl': AppLocalizations.of(context)?.translate('polish') ?? 'Polish',
      'sv': AppLocalizations.of(context)?.translate('swedish') ?? 'Swedish',
      'fi': AppLocalizations.of(context)?.translate('finnish') ?? 'Finnish',
      'it': AppLocalizations.of(context)?.translate('italian') ?? 'Italian',
      'de': AppLocalizations.of(context)?.translate('german') ?? 'German',
      'ja': AppLocalizations.of(context)?.translate('japanese') ?? 'Japanese',
      'ar': AppLocalizations.of(context)?.translate('arabic') ?? 'Arabic',
      'lv': AppLocalizations.of(context)?.translate('latvian') ?? 'Latvian',
    };

    final Map<String, String> modes = {
      'Padel': AppLocalizations.of(context)?.translate('padel') ?? 'Padel',
      'Tennis': AppLocalizations.of(context)?.translate('tennis') ?? 'Tennis',
    };

    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)?.translate('choose_lang') ?? 'Choose Language',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              DropdownButton<String>(
                value: _selectedLanguage,
                isExpanded: true,
                hint: Text(AppLocalizations.of(context)?.translate('select_language') ?? 'Select Language'),
                items: languages.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _setLanguagePreference(value);
                    print('*AVH-lang-s: Language preference set to: $value');
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.translate('choose_padeltennis') ?? 'Choose Padel / Tennis',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              DropdownButton<String>(
                value: _selectedMode,
                isExpanded: true,
                hint: Text(AppLocalizations.of(context)?.translate('choose_padeltennis') ?? 'Select Mode'),
                items: modes.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    _setModePreference(value);
                    print('*AVH-mode: Mode preference set to: $value');
                  }
                },
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.translate('htu_ps') ?? 'How to use Padelshooter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              RichText(
                text: TextSpan(
                  text: AppLocalizations.of(context)?.translate('help-info'),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.translate('export_import_settings') ?? 'Export / Import of app settings',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)?.translate('imex_text') ??
                    'Export your app settings to document (in Downloads map) or Import others settings from document (in Downloads map) or Import the perfect app settings from Web.',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ButtonTheme(
                minWidth: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _exportSettings,
                      child: Text(AppLocalizations.of(context)?.translate('export_settings') ?? 'Export Settings'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _importSettings(context),
                      child: Text(AppLocalizations.of(context)?.translate('import_settings') ?? 'Import Settings'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _importSettingsFromWeb,
                      child: Text(AppLocalizations.of(context)?.translate('import_settings_web') ?? 'Import Settings from Web'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.translate('export_import_programs') ?? 'Export / Import of programs',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)?.translate('imex_text') ??
                    'Export your programs to document (in Downloads map) or Import others programs from document (in Downloads map).',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ButtonTheme(
                minWidth: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _exportPrograms,
                      child: Text(AppLocalizations.of(context)?.translate('export_programs') ?? 'Export Programs'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: () => _importPrograms(context),
                      child: Text(AppLocalizations.of(context)?.translate('import_programs') ?? 'Import Programs'),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _importProgramsFromWeb,
                      child: Text(AppLocalizations.of(context)?.translate('import_programs_web') ?? 'Import Programs from Web'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                AppLocalizations.of(context)?.translate('pos_ps') ?? 'Positioning of Padelshooter',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)?.translate('pos_ps_text') ??
                    "The Padelshooter can't reach the whole padelcourt width. If you want to play more wide, you can reposition the Padelshooter for reaching a bigger part of that side. Also you can use the Middle button to position the Padelshooter exact in middle of the court. Press the side you want to play, then position the Padelshooter so that the machine is shooting exact in the middle line.",
                style: const TextStyle(color: Colors.black, fontSize: 16),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _sendPositioningCommand(100),
                      child: Text(AppLocalizations.of(context)?.translate('left') ?? 'Left'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _sendPositioningCommand(50),
                      child: Text(AppLocalizations.of(context)?.translate('middle') ?? 'Middle'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _sendPositioningCommand(0),
                      child: Text(AppLocalizations.of(context)?.translate('right') ?? 'Right'),
                    ),
                  ),
                ],
              ),
              if (widget.developer) ...[
                const SizedBox(height: 20),
                Text(
                  'Start Speed',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                Slider(
                  value: _bluetoothManager.startSpeed.toDouble(),
                  min: 0,
                  max: 250,
                  divisions: 250,
                  label: _bluetoothManager.startSpeed.toString(),
                  onChanged: (value) {
                    _setStartSpeed(value.toInt());
                  },
                ),
                Text(
                  'Speed Factor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                ),
                Slider(
                  value: _bluetoothManager.speedFactor.toDouble(),
                  min: 0,
                  max: 30,
                  divisions: 30,
                  label: _bluetoothManager.speedFactor.toString(),
                  onChanged: (value) {
                    _setSpeedFactor(value.toInt());
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
