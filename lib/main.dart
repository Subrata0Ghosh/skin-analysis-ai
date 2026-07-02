import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/storage_service.dart';
import 'views/splash/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  bool firebaseInitialized = false;
  try {
    // Attempt to initialize Firebase Core.
    // Wrapped in a try-catch to guarantee the app compiles and launches successfully
    // even if the user hasn't run 'flutterfire configure' or added config json files yet.
    await Firebase.initializeApp();
    firebaseInitialized = true;
    AuthService.isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase initialization skipped (Running in local offline Demo Mode): $e");
    AuthService.isFirebaseInitialized = false;
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(
          create: (_) => AuthService(),
        ),
        ProxyProvider<AuthService, StorageService>(
          update: (context, auth, previousStorage) => StorageService(firebaseInitialized && !auth.isDemoMode),
        ),
      ],
      child: const AuraSkinApp(),
    ),
  );
}

class AuraSkinApp extends StatelessWidget {
  const AuraSkinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AuraSkin AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark, // Standard dark mode skincare theme
      home: const SplashScreen(),
    );
  }
}
