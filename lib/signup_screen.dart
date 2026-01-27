import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'signin_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _bgnuIdController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _designation = 'Student';
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _signup() async {
    if (_fullNameController.text.isEmpty ||
        _bgnuIdController.text.isEmpty ||
        _passwordController.text.isEmpty) {
      setState(() => _errorMessage = 'All fields are mandatory');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.post(
        Uri.parse('https://devntec.com/apias/signup.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': _fullNameController.text.trim(),
          'bgnu_id': _bgnuIdController.text.trim(),
          'password': _passwordController.text.trim(),
          'designation': _designation,
        }),
      );

      final data = json.decode(response.body);

      if (data['status'] == 'success') {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account created successfully! Please Sign In.')),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        setState(() => _errorMessage = data['message']);
      }
    } catch (e) {
      setState(() => _errorMessage = 'Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Course Management System",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          children: [
            const SizedBox(height: 20),
            Image.asset('assets/logo.png', height: 120),
            const SizedBox(height: 20),
            const Text(
              "Sign Up",
              style: TextStyle(
                color: Color(0xFF0A1D37),
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _fullNameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bgnuIdController,
              decoration: InputDecoration(
                labelText: "BGNU ID",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: "Password",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Designation",
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0A1D37)),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _designation = 'Teacher'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _designation == 'Teacher' ? const Color(0xFF0A1D37) : Colors.white,
                      foregroundColor: _designation == 'Teacher' ? Colors.white : const Color(0xFF0A1D37),
                    ),
                    child: const Text("Teacher"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _designation = 'Student'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: _designation == 'Student' ? const Color(0xFF0A1D37) : Colors.white,
                      foregroundColor: _designation == 'Student' ? Colors.white : const Color(0xFF0A1D37),
                    ),
                    child: const Text("Student"),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _signup,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1D37),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Sign Up",
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginScreen()),
              ),
              child: const Text(
                "Already have an account? Sign In",
                style: TextStyle(color: Color(0xFF0A1D37)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
