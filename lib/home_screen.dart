import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'data/db_helper.dart';

import 'evaluation.dart';
import 'local_data.dart';
import 'signin_screen.dart';
import 'data/initial_sync_service.dart';
import 'admin_devices_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color navyBlue = Color(0xFF0A1D37);
  static const double radius = 14;

  final String apiUrl = 'https://devntec.com/apias/get_assessments.php';

  List<dynamic> assessments = [];
  bool hasLocalData = false;
  bool isLoading = true;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadAssessments(showLoading: true);
    _checkLocalData();
    _startBackgroundSync(); // Silent Auto-Sync on load
    _setupConnectivityListener();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  void _setupConnectivityListener() {
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      // specific check for mobile or wifi
      bool isConnected =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (isConnected) {
        _startBackgroundSync();
      }
    });
  }

  // ---------------- Silent Background Sync ----------------
  Future<void> _startBackgroundSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      // Run syncs in parallel or sequence, doesn't matter much for background
      // Using Future.wait to do both
      await Future.wait([
        InitialSyncService.syncRecords(token),
        InitialSyncService.syncUsers(token),
        InitialSyncService.autoSync(),
      ]);

      if (mounted) {
        // Refresh UI with new data
        _loadAssessments(showLoading: false);
      }
    } catch (e) {
      // Background Sync Failed (Offline?)
    }
  }

  // ---------------- Load Assessments from API or Local ----------------
  // ---------------- Load Assessments from Local DB ----------------
  // ---------------- Load Assessments from Local DB ----------------
  Future<void> _loadAssessments({bool showLoading = false}) async {
    if (showLoading) setState(() => isLoading = true);
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query('assessments');

    if (!mounted) return;
    setState(() {
      assessments = maps;
      isLoading = false;
    });
  }

  // ---------------- Check Local Saved Data ----------------
  Future<void> _checkLocalData() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> unsynced = await db.query(
      'evaluations',
      where: 'synced = ?',
      whereArgs: [0],
    );
    setState(() {
      hasLocalData = unsynced.isNotEmpty;
    });
  }

  // ---------------- Sign Out ----------------
  // ---------------- Sign Out ----------------
  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    // Only remove auth details, keep 'is_synced'
    await prefs.remove('email');
    await prefs.remove('token');

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen()),
    );
  }

  // ---------------- Show Code Dialog ----------------
  Future<void> _showCodeDialog(Map<String, dynamic> assessment) async {
    final TextEditingController codeController = TextEditingController();
    final String correctCode = assessment['code']?.toString() ?? '';
    int attempts = 0;
    bool locked = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: const Text("Enter Assessment Code"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                maxLength: 4,
                decoration: const InputDecoration(
                  hintText: "Enter 4-letter code",
                ),
                textCapitalization: TextCapitalization.characters,
              ),
              if (locked)
                const Text(
                  "Too many wrong attempts! Wait 10 seconds.",
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: locked
                  ? null
                  : () {
                      final enteredCode = codeController.text
                          .trim()
                          .toUpperCase();

                      if (enteredCode == correctCode.toUpperCase()) {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EvaluationScreen(
                              assessmentId:
                                  int.tryParse(assessment['id'].toString()) ??
                                  0,
                              assessmentName: assessment['title'].toString(),
                            ),
                          ),
                        ).then((_) => _checkLocalData());
                      } else {
                        attempts++;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Incorrect code")),
                        );

                        if (attempts >= 5) {
                          locked = true;
                          setStateDialog(() {});
                          Future.delayed(const Duration(seconds: 10), () {
                            locked = false;
                            attempts = 0;
                            setStateDialog(() {});
                          });
                        }
                        setStateDialog(() {});
                      }
                    },
              child: const Text("Confirm"),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- Build ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: const Text(
          'Content Management System',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          // Upload Icon
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.cloud_upload, color: Colors.white),
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  final email = prefs.getString('email');
                  if (!mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          LocalDataScreen(userEmail: email?.toLowerCase()),
                    ),
                  );
                  if (mounted) _checkLocalData();
                },
              ),
              if (hasLocalData)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: CircleAvatar(radius: 5, backgroundColor: Colors.red),
                ),
            ],
          ),
          // Logout Icon
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.redAccent),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(radius),
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
                    backgroundColor: navyBlue,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FutureBuilder<String>(
                      future: SharedPreferences.getInstance().then(
                        (prefs) => prefs.getString('email') ?? 'User',
                      ),
                      builder: (context, snapshot) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              snapshot.data ?? 'Loading...',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: navyBlue,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  "Active",
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                if (snapshot.data == 'nabel.akram@gmail.com')
                                  IconButton(
                                    icon: const Icon(
                                      Icons.devices,
                                      color: navyBlue,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AdminDevicesScreen(),
                                        ),
                                      );
                                    },
                                    tooltip: 'Tracked Devices',
                                  ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Assessment List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _startBackgroundSync,
                child: assessments.isEmpty && isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : assessments.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 100),
                          Center(child: Text('No assessments found')),
                        ],
                      )
                    : ListView.builder(
                        itemCount: assessments.length,
                        itemBuilder: (context, index) {
                          final item = assessments[index];

                          return Card(
                            margin: const EdgeInsets.only(bottom: 14),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['title'] ?? '',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: navyBlue,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          item['description'] ?? '',
                                          style: TextStyle(color: navyBlue),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          radius,
                                        ),
                                      ),
                                    ),
                                    onPressed: () {
                                      _showCodeDialog(item);
                                    },
                                    child: const Text(
                                      'Start',
                                      style: TextStyle(color: Colors.white),
                                    ),
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
