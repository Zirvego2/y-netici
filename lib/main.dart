import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'package:zirvego_main_app/services/auth_service.dart';
import 'package:zirvego_main_app/services/notification_service.dart';
import 'package:zirvego_main_app/services/fcm_service.dart';
import 'package:zirvego_main_app/providers/order_provider.dart';
import 'package:zirvego_main_app/screens/login_screen.dart';
import 'package:zirvego_main_app/screens/home_screen.dart';
import 'package:zirvego_main_app/utils/firebase_config.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:zirvego_main_app/services/fcm_service.dart' show fcmBackgroundMessageHandler;

// Background message handler'ı main()'den ÖNCE kaydet (Flutter gereksinimi)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await fcmBackgroundMessageHandler(message);
}

void main() async {
  // Global error handler - uygulama crash'lerini yakala
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('❌ Flutter Error: ${details.exception}');
    debugPrint('Stack trace: ${details.stack}');
  };

  // Platform exception handler
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('❌ Platform Error: $error');
    debugPrint('Stack trace: $stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  
  // Firebase'i başlat - eğer zaten başlatılmamışsa
  try {
    // Firebase'in zaten başlatılmış olup olmadığını kontrol et
    Firebase.app();
    debugPrint('Firebase already initialized');
  } catch (e) {
    // Firebase başlatılmamışsa, başlat
    try {
      await Firebase.initializeApp(
        options: FirebaseConfig.getFirebaseOptions(),
      );
      debugPrint('Firebase initialized successfully');
    } catch (initError) {
      debugPrint('Firebase initialization error: $initError');
      // Hata olsa bile uygulamayı başlat (test için)
    }
  }
  
  // Background message handler'ı kaydet (main() içinde, FCM initialize'den önce)
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('FCM background handler kayıt hatası: $e');
  }
  
  // Bildirim servisini başlat (hata olsa bile devam et)
  try {
    await NotificationService().initialize();
  } catch (e) {
    debugPrint('NotificationService başlatma hatası: $e');
  }
  
  // FCM servisini başlat (hata olsa bile devam et)
  try {
    await FCMService().initialize();
  } catch (e) {
    debugPrint('FCMService başlatma hatası: $e');
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => OrderProvider()),
      ],
      child: MaterialApp(
        title: 'ZirveGo Yönetici',
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('tr', 'TR'),
          Locale('en', 'US'),
        ],
        locale: const Locale('tr', 'TR'),
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB), // ZirveGo mavi
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          fontFamily: 'Inter',
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
          ),
        ),
        home: const AuthWrapper(),
        builder: (context, widget) {
          // Widget hatalarını yakala
          ErrorWidget.builder = (FlutterErrorDetails details) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Bir hata oluştu',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        details.exception.toString(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Uygulamayı yeniden başlat
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const AuthWrapper()),
                          (route) => false,
                        );
                      },
                      child: const Text('Yeniden Dene'),
                    ),
                  ],
                ),
              ),
            );
          };
          return widget ?? const SizedBox();
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        // Auth durumunu kontrol et
        if (authService.isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Eğer kullanıcı giriş yapmışsa Home, yoksa Login
        if (authService.isAuthenticated) {
          return const HomeScreen();
        }
        
        return const LoginScreen();
      },
    );
  }
}
