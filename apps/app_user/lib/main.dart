import 'package:flutter/material.dart';
import 'package:common/utils/app_logger.dart';
import 'package:common/api/api_client.dart';

import 'screens/splash_screen.dart';

// Global logger instance for app_user
final appLogger = AppLogger('USER_APP');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  appLogger.info('=== USER APP STARTING ===');
  appLogger.debug('Initializing User App...');
  
  // Auto-detect backend port on startup
  try {
    final detectedUrl = await ApiClient.detectBackendPort();
    appLogger.info('Backend URL initialized: ${ApiClient.base}');
    if (detectedUrl != ApiClient.base) {
      appLogger.warning('URL mismatch: detected=$detectedUrl, using=${ApiClient.base}');
    }
  } catch (e) {
    appLogger.debug('Port detection failed, using default: $e');
    appLogger.info('Using default backend URL: ${ApiClient.base}');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Auth Demo',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const SplashScreen(),
    );
  }
}

