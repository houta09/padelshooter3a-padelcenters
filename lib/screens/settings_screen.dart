import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_localizations.dart';
import '../main.dart';

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
  }

  Future<void> _loadLanguagePreference() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _selectedLanguage = prefs.getString('language_code') ?? 'es'; // Default to Spanish if not set
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
    };

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)?.translate('settings') ?? 'Settings'),
      ),
      body: Padding(
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
          ],
        ),
      ),
    );
  }
}
