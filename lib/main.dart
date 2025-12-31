import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/quran_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_layout.dart';
import 'services/hadith_service.dart';
import 'services/azkar_service.dart';
import 'services/background_athan_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize background athan service
  await BackgroundAthanService.instance.initialize();
  
  // Initialize services
  await HadithService.instance.initialize();
  await AzkarService.instance.initialize();
  
  // Schedule background athan notifications
  await BackgroundAthanService.instance.scheduleAthanNotifications();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
        ChangeNotifierProvider.value(value: HadithService.instance),
        ChangeNotifierProvider(create: (_) => QuranProvider()),
      ],
      child: MaterialApp(
        title: 'إمساكية',
        debugShowCheckedModeBanner: false,
        home: const SplashScreen(),
        routes: {
          '/settings': (context) => const SettingsScreen(),
          '/main': (context) => const MainLayout(),
        },
      ),
    );
  }
}
