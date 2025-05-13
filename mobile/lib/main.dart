import 'package:flutter/material.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'screens/sensors_screen.dart';
import 'screens/settings_screen.dart';
import 'services/auth_service.dart';
import 'services/data_service.dart';
import 'services/notification_service.dart';
import 'services/user_settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Add this to your main.dart to help diagnose network issues
import 'dart:io';

void printNetworkInfo() {
  debugPrint('=== Network Debug Info ===');
  debugPrint('Platform: ${Platform.operatingSystem}');
  debugPrint('Is Android: ${Platform.isAndroid}');
  debugPrint('Is iOS: ${Platform.isIOS}');

  // For Android emulator, localhost should be 10.0.2.2
  // For iOS simulator, localhost works as expected
  final suggestedUrl =
      Platform.isAndroid ? 'http://10.0.2.2:8000' : 'http://localhost:8000';
  debugPrint('Suggested backend URL: $suggestedUrl');
  debugPrint('========================');
}

// Add this call in your main() function
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print network debugging info
  printNetworkInfo();

  // Initialize services with timeout
  try {
    await Future.wait([
      UserSettingsService().init(),
      NotificationService().init(),
      // DataService().init(), // Initialize DataService after navigating to main page
    ]).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('Error initializing services: $e');
    // Continue anyway with cached data
  }

  // Check remember me and authentication
  final prefs = await SharedPreferences.getInstance();
  final rememberMe = prefs.getBool('remember_me') ?? false;
  final isAuthenticated = await AuthService().isAuthenticated();
  String initialRoute = '/';
  if (rememberMe && isAuthenticated) {
    initialRoute = '/main';
  }

  runApp(AirQualityApp(initialRoute: initialRoute));
}

class AirQualityApp extends StatelessWidget {
  final String initialRoute;
  const AirQualityApp({Key? key, this.initialRoute = '/'}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Air Quality Monitor',
      navigatorKey: navigatorKey, // Use the global navigator key
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.purple, width: 2.0),
          ),
        ),
      ),
      initialRoute: initialRoute,
      routes: {
        '/': (context) => const LoginScreen(),
        '/main': (context) => const MainScreen(),
        '/sensors': (context) => const SensorsScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
    );
  }
}
