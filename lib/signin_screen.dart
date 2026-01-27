import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'signup_screen.dart';
import 'teacher_dashboard.dart';
import 'student_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _bgnuIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> login() async {
    if (_bgnuIdController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'All fields are mandatory');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('https://devntec.com/apias/signin.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'bgnu_id': _bgnuIdController.text.trim(),
          'password': _passwordController.text.trim(),
        }),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        final bgnuId = data['user']['bgnu_id'];
        final designation = data['user']['designation'];

        await prefs.setString("bgnu_id", bgnuId);
        await prefs.setString("full_name", data['user']['full_name']);
        await prefs.setString("designation", designation);
        await prefs.setString("token", "cms_token");

        // OneSignal: Identify user and tag by role for targeted notifications
        print('🔔 NOTIFICATION DEBUG: Logging in user to OneSignal: $bgnuId');
        
        // CRITICAL FIX: Wait a bit for OneSignal to initialize fully
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Set External User ID
        await OneSignal.login(bgnuId);
        print('🔔 NOTIFICATION DEBUG: OneSignal login completed');
        
        // Wait for login to register
        await Future.delayed(const Duration(milliseconds: 300));
        
        print('🔔 NOTIFICATION DEBUG: User designation: $designation');
        if (designation == 'Teacher') {
          print('🔔 NOTIFICATION DEBUG: Setting teacher tags for: $bgnuId');
          OneSignal.User.addTags({"role": "teacher", "teacher_id": bgnuId});
          print('🔔 NOTIFICATION DEBUG: Teacher tags set successfully');
        } else {
          print('🔔 NOTIFICATION DEBUG: Setting student tags for: $bgnuId');
          OneSignal.User.addTags({"role": "student", "student_id": bgnuId});
          print('🔔 NOTIFICATION DEBUG: Student tags set successfully');
        }
        
        // Request notification permission again to ensure it's enabled
        print('🔔 NOTIFICATION DEBUG: Requesting notification permissions...');
        final permissionGranted = await OneSignal.Notifications.requestPermission(true);
        print('🔔 NOTIFICATION DEBUG: Permission granted: $permissionGranted');
        
        // Log the External User ID to verify
        print('🔔 NOTIFICATION DEBUG: External User ID should be: $bgnuId');
        print('🔔 NOTIFICATION DEBUG: This user will receive notifications sent to External ID: $bgnuId');

        if (!mounted) return;
        _redirect(designation);
      } else {
        setState(() => _errorMessage = data['message']);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _redirect(String designation) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1D37),
        elevation: 0,
        automaticallyImplyLeading: false,
        centerTitle: false,
        title: const Text(
          "Course Management System",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            Image.asset('assets/logo.png', height: 150),
            const SizedBox(height: 20),
            const Text(
              "Sign In",
              style: TextStyle(
                color: Color(0xFF0A1D37),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _bgnuIdController,
              decoration: InputDecoration(
                labelText: "BGNU ID",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const SizedBox(height: 30),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1D37),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Sign In",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SignupScreen()),
              ),
              child: const Text(
                "Don't have an account? Sign Up",
                style: TextStyle(color: Color(0xFF0A1D37)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
