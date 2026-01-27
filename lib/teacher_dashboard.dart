import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'signin_screen.dart';
import 'create_assessment_screen.dart';
import 'teacher_local_assessments_screen.dart';
import 'evaluation_history_screen.dart';
import 'assessment_evaluations_screen.dart';
import 'data/db_helper.dart';
import 'data/initial_sync_service.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key});

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  String fullName = '';
  String bgnuId = '';
  int localCount = 0;
  List<Map<String, dynamic>> myAssessments = [];
  StreamSubscription<dynamic>? _syncTimer;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo().then((_) {
      _loadMyAssessments();
      _triggerAutoSync();
    });
    _loadLocalCount();
    _setupConnectivityListener();
    _syncTimer = Stream.periodic(
      const Duration(seconds: 30),
    ).listen((_) => _triggerAutoSync());
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      bool isConnected =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (isConnected) {
        _triggerAutoSync();
      }
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _triggerAutoSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // If we have no assessments, force a full record sync
      final normalizedId = bgnuId.trim();
      if (myAssessments.isEmpty) {
        await InitialSyncService.syncRecords(token, normalizedId);
      }
      await InitialSyncService.autoSync();
      await InitialSyncService.syncTeacherHistory(normalizedId);

      _loadLocalCount();
      _loadMyAssessments();
    } catch (e) {
      // Auto-sync failed silently
    }
  }

  Future<void> _loadMyAssessments() async {
    if (bgnuId.isEmpty) return; // Wait for ID to load

    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'assessments',
      where: 'created_by = ?', // STRICT PRIVACY FILTER
      whereArgs: [bgnuId.trim()],
      orderBy: 'id DESC',
    );
    setState(() {
      myAssessments = maps;
    });
  }

  Future<void> _loadLocalCount() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'assessments',
      where: 'synced = ?',
      whereArgs: [0],
    );
    setState(() {
      localCount = maps.length;
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      fullName = prefs.getString('full_name') ?? 'Teacher';
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
                      builder: (_) => const TeacherLocalAssessmentsScreen(),
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
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CreateAssessmentScreen(),
                    ),
                  ).then((_) => _loadMyAssessments());
                },
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  "Create Assessment",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A1D37),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "My Assessments",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A1D37),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: myAssessments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("No assessments created yet"),
                          IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: _triggerAutoSync,
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _triggerAutoSync,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: myAssessments.length,
                        itemBuilder: (context, index) {
                          final item = myAssessments[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              title: Text(
                                item['title'] ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text("Code: ${item['ucode']}"),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.analytics,
                                      color: Color(0xFF0A1D37),
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EvaluationHistoryScreen(
                                            assessmentId: item['id'],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
