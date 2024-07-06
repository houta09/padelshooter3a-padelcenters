import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/main_screen.dart';
import 'screens/start_here_screen.dart';
import 'screens/trainings_screen.dart';
import 'screens/programs_screen.dart';
import 'screens/settings_screen.dart';
import 'utils/bluetooth_manager.dart';
import 'utils/app_localizations.dart';

Future<void> clearArabicLanguagePreference() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  if (prefs.getString('language_code') == 'ar') {
    await prefs.remove('language_code');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await clearArabicLanguagePreference();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp])
      .then((_) async {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky); // Full-screen mode
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? languageCode = prefs.getString('language_code');

    // Set default to English if not set or not supported
    if (languageCode == null || ![
      'en', 'es', 'fr', 'zh', 'pt', 'pl', 'fi', 'sv', 'it', 'de', 'ja', 'ar'
    ].contains(languageCode)) {
      languageCode = 'en';
    }

    print('*AVH-lang-m: Initial language code from preferences: $languageCode');
    runApp(PadelShooterApp(initialLocale: Locale(languageCode)));
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
          title: 'Padelshooter',
          home: const DynamicContentFrame(),
          locale: _locale,
          supportedLocales: const [
            Locale('en', ''), // English
            Locale('es', ''), // Spanish
            Locale('fr', ''), // French
            Locale('zh', ''), // Chinese
            Locale('de', ''), // German
            Locale('pt', ''), // Portuguese
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
    final bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
    bluetoothManager.addListener(_updateConnectionStatus);
  }

  @override
  void dispose() {
    final bluetoothManager = Provider.of<BluetoothManager>(context, listen: false);
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
    print('*AVH: Page changed to index: $index');
  }

  String _getPageTitle() {
    switch (_currentPageIndex) {
      case 0:
        return AppLocalizations.of(context)?.translate('main') ?? 'Main';
      case 1:
        return AppLocalizations.of(context)?.translate('start_here') ?? 'Start Here';
      case 2:
        return AppLocalizations.of(context)?.translate('trainings') ?? 'Trainings';
      case 3:
        return AppLocalizations.of(context)?.translate('programs') ?? 'Programs';
      case 4:
        return AppLocalizations.of(context)?.translate('settings') ?? 'Settings';
      default:
        return '';
    }
  }

  Widget _buildPage(Widget page) {
    return Column(
      children: [
        SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            alignment: Alignment.center,
            child: Text(
              _getPageTitle(),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        Expanded(child: page),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bluetoothManager = Provider.of<BluetoothManager>(context);
    final bool isConnected = bluetoothManager.isConnected;

    print('*AVH-lang-m: Building DynamicContentFrame with page index: $_currentPageIndex');

    final String mainLabel = AppLocalizations.of(context)?.translate('main') ?? 'Main';
    final String startHereLabel = AppLocalizations.of(context)?.translate('start_here') ?? 'Start Here';
    final String trainingsLabel = AppLocalizations.of(context)?.translate('trainings') ?? 'Trainings';
    final String programsLabel = AppLocalizations.of(context)?.translate('programs') ?? 'Programs';
    final String settingsLabel = AppLocalizations.of(context)?.translate('settings') ?? 'Settings';

    print('*AVH-lang-m: Translations - Main: $mainLabel, Start Here: $startHereLabel, Trainings: $trainingsLabel, Programs: $programsLabel, Settings: $settingsLabel');

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
