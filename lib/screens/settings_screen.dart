import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import '../main.dart';
import 'package:share_plus/share_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  final Function(int) onNavigate;

  const SettingsScreen({Key? key, required this.onNavigate}) : super(key: key);

  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _loadLanguagePreference();
    _requestPermissions();
  }

  Future<void> _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language_code') ?? 'en';
    });
    print('*AVH-lang-s: Loaded language preference: $_selectedLanguage');
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

  Future<void> _requestPermissions() async {
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      status = await Permission.manageExternalStorage.request();
      print('*AVH-Export: Storage permission requested. New status: $status');
    }
    if (status.isGranted) {
      print('*AVH-Export: Storage permission granted.');
    } else {
      print('*AVH-Export: Storage permission not granted.');
    }
  }

  Future<Map<String, dynamic>> _getTrainingSettings(String prefix, int trainingIndex) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return {
      "Speed": prefs.getInt("${prefix}_Speed_$trainingIndex") ?? 15,
      "Spin": 50 - (prefs.getInt("${prefix}_Spin_$trainingIndex") ?? 50),
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
    await prefs.setInt("${prefix}_Spin_$trainingIndex", 50 - (settings["Spin"] as int));
    await prefs.setInt("${prefix}_Freq_$trainingIndex", settings["Freq"] as int);
    await prefs.setInt("${prefix}_Width_$trainingIndex", settings["Width"] as int);
    await prefs.setInt("${prefix}_Height_$trainingIndex", settings["Height"] as int);
    await prefs.setInt("${prefix}_Net_$trainingIndex", settings["Net"] as int);
    await prefs.setInt("${prefix}_Delay_$trainingIndex", settings["Delay"] as int);
    await prefs.setBool("${prefix}_LeftSelected_$trainingIndex", settings["LeftSelected"] as bool);
    await prefs.setBool("${prefix}_RightSelected_$trainingIndex", settings["RightSelected"] as bool);
  }

  Future<void> _exportSettings() async {
    print('*AVH-Export: Export button pressed');

    // Check storage permission again
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      print('*AVH-Export: Storage permission not granted. Cannot export settings.');
      await _requestPermissions();
      return;
    }

    // Gather settings for all trainings
    Map<String, dynamic> allSettings = {};
    for (int i = 1; i <= 9; i++) {
      allSettings['StartHere_training_$i'] = await _getTrainingSettings('StartHere', i);
      allSettings['Trainings_training_$i'] = await _getTrainingSettings('Trainings', i);
    }
    print('*AVH-Export: Settings to export: $allSettings');

    try {
      // Save to Downloads directory for easier access
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      print('*AVH-Export: Downloads directory: ${downloadsDirectory.path}');
      if (downloadsDirectory == null) {
        print('*AVH-Export: Downloads directory is null');
        return;
      }

      final file = File('${downloadsDirectory.path}/training_settings.json');
      print('*AVH-Export: File path: ${file.path}');

      await file.create(recursive: true);
      await file.writeAsString(json.encode(allSettings));

      if (await file.exists()) {
        print('*AVH-Export: File exists: ${file.path}');
        String content = await file.readAsString();
        print('*AVH-Export: File content: $content');

        Share.shareFiles([file.path], text: 'Here are my PadelShooter settings.');
        print('*AVH-Export: Share dialog opened');
      } else {
        print('*AVH-Export: File not found');
      }
    } catch (e) {
      print('*AVH-Export: Error exporting settings: $e');
    }
  }

  Future<void> _importSettings() async {
    print('*AVH-Import: Import button pressed');

    // Check storage permission again
    var status = await Permission.manageExternalStorage.status;
    if (!status.isGranted) {
      print('*AVH-Import: Storage permission not granted. Cannot import settings.');
      await _requestPermissions();
      return;
    }

    try {
      // Read from Downloads directory
      final downloadsDirectory = Directory('/storage/emulated/0/Download');
      print('*AVH-Import: Downloads directory: ${downloadsDirectory.path}');
      if (downloadsDirectory == null) {
        print('*AVH-Import: Downloads directory is null');
        return;
      }

      final file = File('${downloadsDirectory.path}/training_settings.json');
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
    } catch (e) {
      print('*AVH-Import: Error importing settings: $e');
    }
  }

  Future<void> _importSettingsFromWeb() async {
    print('*AVH-Import: Import from Web button pressed');

    try {
      final response = await http.get(Uri.parse('https://padelshooter.com/wp-content/uploads/2024/07/training_settings.json'));

      if (response.statusCode == 200) {
        Map<String, dynamic> settings = json.decode(response.body);
        SharedPreferences prefs = await SharedPreferences.getInstance();

        for (int i = 1; i <= 9; i++) {
          await prefs.setInt("StartHere_Speed_$i", settings['StartHere_training_$i']["Speed"] as int);
          await prefs.setInt("StartHere_Spin_$i", 50 - (settings['StartHere_training_$i']["Spin"] as int));
          await prefs.setInt("StartHere_Freq_$i", settings['StartHere_training_$i']["Freq"] as int);
          await prefs.setInt("StartHere_Width_$i", settings['StartHere_training_$i']["Width"] as int);
          await prefs.setInt("StartHere_Height_$i", settings['StartHere_training_$i']["Height"] as int);
          await prefs.setInt("StartHere_Net_$i", settings['StartHere_training_$i']["Net"] as int);
          await prefs.setInt("StartHere_Delay_$i", settings['StartHere_training_$i']["Delay"] as int);
          await prefs.setBool("StartHere_LeftSelected_$i", settings['StartHere_training_$i']["LeftSelected"] as bool);
          await prefs.setBool("StartHere_RightSelected_$i", settings['StartHere_training_$i']["RightSelected"] as bool);

          await prefs.setInt("Trainings_Speed_$i", settings['Trainings_training_$i']["Speed"] as int);
          await prefs.setInt("Trainings_Spin_$i", 50 - (settings['Trainings_training_$i']["Spin"] as int));
          await prefs.setInt("Trainings_Freq_$i", settings['Trainings_training_$i']["Freq"] as int);
          await prefs.setInt("Trainings_Width_$i", settings['Trainings_training_$i']["Width"] as int);
          await prefs.setInt("Trainings_Height_$i", settings['Trainings_training_$i']["Height"] as int);
          await prefs.setInt("Trainings_Net_$i", settings['Trainings_training_$i']["Net"] as int);
          await prefs.setInt("Trainings_Delay_$i", settings['Trainings_training_$i']["Delay"] as int);
          await prefs.setBool("Trainings_LeftSelected_$i", settings['Trainings_training_$i']["LeftSelected"] as bool);
          await prefs.setBool("Trainings_RightSelected_$i", settings['Trainings_training_$i']["RightSelected"] as bool);
        }

        print('*AVH-Import: Settings imported successfully from web');
      } else {
        print('*AVH-Import: Error fetching settings from web. Status code: ${response.statusCode}');
      }
    } catch (e) {
      print('*AVH-Import: Error importing settings from web: $e');
    }
  }

  void _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      print('Could not launch $url');
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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('settings') ?? 'Settings'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
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
              RichText(
                text: TextSpan(
                  text: AppLocalizations.of(context)?.translate('help-info'),
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _exportSettings,
                child: Text(AppLocalizations.of(context)?.translate('export') ?? 'Export'),
              ),
              ElevatedButton(
                onPressed: _importSettings,
                child: Text(AppLocalizations.of(context)?.translate('import') ?? 'Import'),
              ),
              ElevatedButton(
                onPressed: _importSettingsFromWeb,
                child: Text(AppLocalizations.of(context)?.translate('import_from_web') ?? 'Import from Web'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
