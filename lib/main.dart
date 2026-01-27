import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (kIsWeb) {
    // Initialize for Web
    databaseFactory = databaseFactoryFfiWeb;
  } else if (Platform.isWindows || Platform.isLinux) {
    // Initialize for Desktop
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Firebase (Required for Android notifications)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Firebase initialization failed silently
  }

  // OneSignal Initialization
  print('🔔 Initializing OneSignal with App ID: 384836b5-5495-4b82-8543-44c89468f73a');
  OneSignal.initialize("384836b5-5495-4b82-8543-44c89468f73a");

  // Request notification permissions (important for iOS, good for Android)
  print('🔔 Requesting notification permissions...');
  OneSignal.Notifications.requestPermission(true);

  // Optional: Log event when notification is received
  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print('🔔 NOTIFICATION RECEIVED: ${event.notification.title}');
    print('🔔 NOTIFICATION BODY: ${event.notification.body}');
    print('🔔 NOTIFICATION DATA: ${event.notification.additionalData}');
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: const SplashScreen(),
    );
  }
}
