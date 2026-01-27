import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'signin_screen.dart';
import 'data/initial_sync_service.dart';

import 'teacher_dashboard.dart';
import 'student_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
    _checkLogin();
  }

  Future<void> _initializeApp() async {
    // Universal Device Tracking: Register this install immediately
    try {
      await InitialSyncService.registerDevice();
    } catch (e) {
      // Silent error
    }
  }

  Future<void> _checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final bgnuId = prefs.getString('bgnu_id');
    final designation = prefs.getString('designation');

    Timer(const Duration(milliseconds: 1500), () {
      if (bgnuId != null && bgnuId.isNotEmpty) {
        // Ensure OneSignal is logged in for existing sessions
        OneSignal.login(bgnuId);
        if (designation == 'Teacher') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const TeacherDashboard()),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const StudentDashboard()),
          );
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: Colors.white,
        alignment: Alignment.center,
        child: Image.asset('assets/logo.png', width: 200, height: 200),
      ),
    );
  }
}
