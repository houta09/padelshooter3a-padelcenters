/*
Difference to set between Smart and 3A
- String model = '3a';
- android/local.properties: isSmartVersion=false (3A)
=
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'screens/main_screen.dart';
import 'screens/start_here_screen.dart';
import 'screens/trainings_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/bluetooth_manager.dart';
import 'utils/app_localizations.dart';
import 'dart:convert';

late String settingsFileLink;
late String programsFileLink;
late String appTitle;

Future<void> loadConfig(String model) async {
  print('*AVH-Config: Loading configuration for model: $model');
  try {
    final configData = await rootBundle.loadString('assets/configurations/config_$model.json');
    final config = json.decode(configData);

    appTitle = config['appTitle'];
    settingsFileLink = config['settingsFileLink'];
    programsFileLink = config['programsFileLink'];

    print('*AVH-Config: Configuration loaded successfully');
  } catch (e) {
    print('*AVH-Config: Error loading configuration: $e');
  }
}

Future<void> _importSettingsFromWeb() async {
  print('*AVH-Import: Import from Web function called');
  try {
    final response = await http.get(Uri.parse(settingsFileLink));

    if (response.statusCode == 200) {
      print('*AVH-Import: Successfully fetched settings from web');
      Map<String, dynamic> settings = json.decode(response.body);
      SharedPreferences prefs = await SharedPreferences.getInstance();

      for (int i = 1; i <= 9; i++) {
        await prefs.setInt("StartHere_Speed_$i", settings['StartHere_training_$i']["Speed"] as int);
        await prefs.setInt("StartHere_Spin_$i", settings['StartHere_training_$i']["Spin"] as int);
        await prefs.setInt("StartHere_Freq_$i", settings['StartHere_training_$i']["Freq"] as int);
        await prefs.setInt("StartHere_Width_$i", settings['StartHere_training_$i']["Width"] as int);
        await prefs.setInt("StartHere_Height_$i", settings['StartHere_training_$i']["Height"] as int);
        await prefs.setInt("StartHere_Net_$i", settings['StartHere_training_$i']["Net"] as int);
        await prefs.setInt("StartHere_Delay_$i", settings['StartHere_training_$i']["Delay"] as int);
        await prefs.setBool("StartHere_LeftSelected_$i", settings['StartHere_training_$i']["LeftSelected"] as bool);
        await prefs.setBool("StartHere_RightSelected_$i", settings['StartHere_training_$i']["RightSelected"] as bool);

        await prefs.setInt("Trainings_Speed_$i", settings['Trainings_training_$i']["Speed"] as int);
        await prefs.setInt("Trainings_Spin_$i", settings['Trainings_training_$i']["Spin"] as int);
        await prefs.setInt("Trainings_Freq_$i", settings['Trainings_training_$i']["Freq"] as int);
        await prefs.setInt("Trainings_Width_$i", settings['Trainings_training_$i']["Width"] as int);
        await prefs.setInt("Trainings_Height_$i", settings['Trainings_training_$i']["Height"] as int);
        await prefs.setInt("Trainings_Net_$i", settings['Trainings_training_$i']["Net"] as int);
        await prefs.setInt("Trainings_Delay_$i", settings['Trainings_training_$i']["Delay"] as int);
        await prefs.setBool("Trainings_LeftSelected_$i", settings['Trainings_training_$i']["LeftSelected"] as bool);
        await prefs.setBool("Trainings_RightSelected_$i", settings['Trainings_training_$i']["RightSelected"] as bool);
      }

      print('*AVH-Import: Settings imported successfully from web');
      await prefs.setBool('settings_imported', true);
    } else {
      print('*AVH-Import: Error fetching settings from web. Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('*AVH-Import: Error importing settings from web: $e');
  }
}

void main() async {
  print('*AVH-main: App starting...');
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration based on the model
  String model = '3a'; // Change this to '3a' for PadelShooter 3A
  await loadConfig(model);

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // Full-screen mode
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('language_code');

    // Set default to English if not set or not supported
    if (languageCode == null || ![
      'en', 'es', 'fr', 'zh', 'pt', 'pl', 'fi', 'lv','nl', 'sv', 'it', 'de', 'ja', 'ar'
    ].contains(languageCode)) {
      languageCode = 'en';
    }

    print('*AVH-lang-m: Initial language code from preferences: $languageCode');
    // Check if settings have already been imported
    bool settingsImported = prefs.getBool('settings_imported') ?? false;
    print('*AVH-main: Settings imported: $settingsImported');
    if (!settingsImported) {
      await _importSettingsFromWeb();
      print('*AVH-import: Settings imported from Web');
    }

    runApp(PadelShooterApp(initialLocale: Locale(languageCode)));
    print('*AVH-main: runApp called');
  });
}

class PadelShooterApp extends StatefulWidget {
  final Locale initialLocale;

  const PadelShooterApp({super.key, required this.initialLocale});

  @override
  _PadelShooterAppState createState() => _PadelShooterAppState();

  static void setLocale(BuildContext context, Locale newLocale) {
    final _PadelShooterAppState? state = context.findAncestorStateOfType<_PadelShooterAppState>();
    state?.setLocale(newLocale);
  }
}

class _PadelShooterAppState extends State<PadelShooterApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    print('*AVH-main: Initial locale set to: ${_locale.languageCode}');
  }

  void setLocale(Locale locale) async {
    setState(() {
      _locale = locale;
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
    print('*AVH-lang-m: Locale set to: ${locale.languageCode}');
  }

  @override
  Widget build(BuildContext context) {
    print('*AVH-lang-m: Building app with locale: ${_locale.languageCode}');
    return ChangeNotifierProvider<BluetoothManager>(
      create: (_) => BluetoothManager()..initialize(),
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: MaterialApp(
          title: appTitle, // Use the app title from the configuration
          home: const DynamicContentFrame(),
          locale: _locale,
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('es', ''), // Spanish
            Locale('fr', ''), // French
            Locale('zh', ''), // Chinese
            Locale('de', ''), // German
            Locale('pt', ''), // Portuguese
            Locale('lv', ''), // Latvia
            Locale('nl', ''), // Netherlands
            Locale('it', ''), // Italian
            Locale('sv', ''), // Swedish
            Locale('fi', ''), // Finnish
            Locale('pl', ''), // Polish
            Locale('ja', ''), // Japanese
            Locale('ar', ''), // Arabic
          ],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          localeResolutionCallback: (locale, supportedLocales) {
            print('*AVH-lang-m: localeResolutionCallback: device locale=${locale?.languageCode}');
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == _locale.languageCode &&
                  supportedLocale.countryCode == _locale.countryCode) {
                return supportedLocale;
              }
            }
            return _locale;
          },
          builder: (context, child) {
            return Directionality(
              textDirection: _locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
              child: child!,
            );
          },
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
    print('*AVH-DynamicContentFrame: Initializing with page index: $_currentPageIndex');
    final bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    bluetoothManager.addListener(_updateConnectionStatus);
  }

  @override
  void dispose() {
    final bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    bluetoothManager.removeListener(_updateConnectionStatus);
    print('*AVH-DynamicContentFrame: Disposing DynamicContentFrame');
    super.dispose();
  }

  void _updateConnectionStatus() {
    print('*AVH-DynamicContentFrame: Bluetooth connection status changed');
    setState(() {});
  }

  void changePage(int index) {
    setState(() {
      _currentPageIndex = index;
    });
    print('*AVH: Page changed to index: $index');
  }

  String _getPageTitle() {
    switch (_currentPageIndex) {
      case 0:
        return appTitle ?? "PadelShooter 3A";
      case 1:
        return AppLocalizations.of(context).translate('start_here') ?? 'Start Here';
      case 2:
        return AppLocalizations.of(context).translate('trainings') ?? 'Trainings';
      case 3:
        return AppLocalizations.of(context).translate('programs') ?? 'Programs';
      case 4:
        return AppLocalizations.of(context).translate('settings') ?? 'Settings';
      default:
        return '';
    }
  }

  Widget _buildPage(Widget page) {
    print('*AVH-DynamicContentFrame: Building page with title: ${_getPageTitle()}');
    return Column(
      children: [
        SafeArea(
          child: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: AppBar(
              title: Text(
                _getPageTitle(),
                style: const TextStyle(color: Colors.white),
              ),
              centerTitle: true,
              backgroundColor: Colors.transparent,
              elevation: 0,
            ),
          ),
        ),
        Expanded(
          child: Container(
            padding: EdgeInsets.zero,
            margin: EdgeInsets.zero,
            child: page,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothManager>(context);
    final bool isConnected = bluetoothManager.isConnected;

    print('*AVH-DynamicContentFrame: Building DynamicContentFrame with page index: $_currentPageIndex');
    print('*AVH-DynamicContentFrame: Bluetooth connection status: ${isConnected ? 'Connected' : 'Disconnected'}');

    final String mainLabel = AppLocalizations.of(context).translate('main') ?? 'Main';
    final String startHereLabel = AppLocalizations.of(context).translate('start_here') ?? 'Start Here';
    final String trainingsLabel = AppLocalizations.of(context).translate('trainings') ?? 'Trainings';
    final String programsLabel = AppLocalizations.of(context).translate('programs') ?? 'Programs';
    final String settingsLabel = AppLocalizations.of(context).translate('settings') ?? 'Settings';

    print('*AVH-DynamicContentFrame: Translations - Main: $mainLabel, Start Here: $startHereLabel, Trainings: $trainingsLabel, Programs: $programsLabel, Settings: $settingsLabel');

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
                _buildPage(SettingsScreen(onNavigate: changePage)),
              ],
            ),
          ],
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(Icons.home, size: 25),
              label: mainLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.location_on, size: 25),
              label: startHereLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.fitness_center, size: 25),
              label: trainingsLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.computer, size: 25),
              label: programsLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(Icons.settings, size: 25),
              label: settingsLabel,
            ),
            BottomNavigationBarItem(
              icon: Icon(
                Icons.bluetooth,
                color: isConnected ? Colors.green : Colors.red,
                size: 25,
              ),
              label: 'BT',
            ),
          ],
          currentIndex: _currentPageIndex,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white60,
          selectedLabelStyle: const TextStyle(fontSize: 13),
          unselectedLabelStyle: const TextStyle(fontSize: 12),
          onTap: (index) {
            changePage(index);
          },
        ),
      ),
    );
  }
}
