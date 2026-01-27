import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'signin_screen.dart';
import 'evaluation.dart';
import 'local_data.dart';
import 'evaluation_history_screen.dart';
import 'data/db_helper.dart';
import 'data/initial_sync_service.dart';
import 'student_my_evaluations_screen.dart';

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  String fullName = '';
  String bgnuId = '';
  List<Map<String, dynamic>> assessments = [];
  int localCount = 0;
  bool isLoading = true;
  StreamSubscription<dynamic>? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadLocalAssessments();
    _loadLocalCount();
    _triggerSync();
    _setupConnectivityListener();
    _syncTimer = Stream.periodic(
      const Duration(seconds: 30),
    ).listen((_) => _triggerSync());
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      bool isConnected =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (isConnected) {
        _triggerSync();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLocalCount() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'evaluations',
      where: 'synced = ?',
      whereArgs: [0],
    );
    setState(() {
      localCount = maps.length;
    });
  }

  Future<void> _triggerSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // First sync evaluations (most important for students)
      await InitialSyncService.autoSyncEvaluations();

      // Then sync other data
      await InitialSyncService.syncRecords(token);
      await InitialSyncService.syncUsers(token);
      await InitialSyncService.syncStudentHistory(bgnuId);

      _loadLocalAssessments();
      _loadLocalCount();
    } catch (e) {
      // Silent sync failure
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _loadLocalAssessments() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'assessments',
      where: 'synced = ?',
      whereArgs: [1],
    );
    setState(() {
      assessments = maps;
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fullName = prefs.getString('full_name') ?? 'Student';
      bgnuId = prefs.getString('bgnu_id') ?? '';
    });
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await DBHelper.clearAllData();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _showCodeDialog(Map assessment) async {
    final TextEditingController codeController = TextEditingController();
    final String correctCode = assessment['ucode']?.toString() ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Enter Code"),
        content: TextField(
          controller: codeController,
          maxLength: 4,
          decoration: const InputDecoration(hintText: "Enter 4-digit code"),
          autofocus: true,
          onChanged: (value) {
            if (value.length == 4) {
              if (value == correctCode) {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EvaluationScreen(
                      assessmentId:
                          int.tryParse(assessment['id'].toString()) ?? 0,
                      assessmentName: assessment['title'].toString(),
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Incorrect Code")));
                codeController.clear();
              }
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A1D37),
        elevation: 0,
        title: const Text(
          'CMS',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LocalDataScreen(userEmail: bgnuId),
                    ),
                  ).then((_) => _loadLocalCount());
                },
              ),
              if (localCount > 0)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      '$localCount',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Color(0xFF0A1D37),
                    child: Icon(Icons.person, color: Colors.white, size: 35),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Color(0xFF0A1D37),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          bgnuId,
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Active",
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              "Assessments",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0A1D37),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : assessments.isEmpty
                      ? const Center(child: Text("No assessments available"))
                      : ListView.builder(
                          itemCount: assessments.length,
                          itemBuilder: (context, index) {
                            final item = assessments[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(item['title'] ?? ''),
                                subtitle: Text(
                                  "${item['description']}\nBy: ${item['teacher_name'] ?? item['created_by']}",
                                ),
                                trailing: ElevatedButton(
                                  onPressed: () => _showCodeDialog(item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  child: const Text(
                                    "Start",
                                    style: TextStyle(color: Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
