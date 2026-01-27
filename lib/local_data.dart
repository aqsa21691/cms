import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'data/db_helper.dart';
import 'data/initial_sync_service.dart';

class LocalDataScreen extends StatefulWidget {
  final String? userEmail;

  const LocalDataScreen({super.key, this.userEmail});

  @override
  State<LocalDataScreen> createState() => _LocalDataScreenState();
}

class _LocalDataScreenState extends State<LocalDataScreen> {
  List<Map<String, dynamic>> pendingEvaluations = [];

  bool loading = true;
  static const Color navyBlue = Color(0xFF0A1D37);
  String? currentUserEmail;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    currentUserEmail = widget.userEmail;
    _loadAllSavedData();
    _setupConnectivityListener();

    // Trigger immediate sync when screen opens
    Future.delayed(Duration(milliseconds: 500), () {
      _triggerFullAutoSync();
    });
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
      bool isConnected =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (isConnected) {
        _triggerFullAutoSync();
      }
    });
  }

  Future<void> _triggerFullAutoSync() async {
    try {
      await InitialSyncService.autoSyncEvaluations();
      await InitialSyncService.autoSyncAssessments();
      await _loadAllSavedData();

      // Silent success - do not annoy user with "Sync completed" on every screen load
      if (mounted) {
         // Optional: Only show if debug mode or if specifically requested
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadAllSavedData() async {
    final db = await DBHelper.db;

    // Load only PENDING (synced = 0) evaluations
    final List<Map<String, dynamic>> allEvals = await db.query(
      'evaluations',
      where: 'synced = ?',
      whereArgs: [0],
    );

    // Get item details
    final List<Map<String, dynamic>> itemsWithNames = await db.rawQuery('''
      SELECT ei.*, ad.category as category_name
      FROM evaluation_items ei
      LEFT JOIN assessment_details ad ON ei.category_id = ad.id
    ''');

    final Map<int, List<Map<String, dynamic>>> itemsGrouped = {};
    for (var item in itemsWithNames) {
      final evalId = item['evaluation_id'] as int;
      itemsGrouped.putIfAbsent(evalId, () => []).add(item);
    }

    final List<Map<String, dynamic>> allAssess = await db.query('assessments');
    final Map<int, String> assessMap = {
      for (var a in allAssess) a['id'] as int: a['title'] as String,
    };

    List<Map<String, dynamic>> tempPending = [];

    for (var e in allEvals) {
      final id = e['id'] as int;
      final assessId = e['assessment_id'] as int;

      final fullEval = {
        ...e,
        'assessment_name': assessMap[assessId] ?? 'Unknown Assessment',
        'data': itemsGrouped[id] ?? [],
      };
      tempPending.add(fullEval);
    }

    if (mounted) {
      setState(() {
        pendingEvaluations = tempPending;
        loading = false;
      });
    }
  }

  Future<void> _triggerAssessmentSync() async {
     // No-op or keep for internal logic if needed
  }

  Future<void> _uploadData(int id, Map<String, dynamic> data) async {
    final payload = {
      'assessment_id': data['assessment_id'],
      'student_roll': data['student_roll'],
      'evaluated_by': data['evaluated_by'],
      'device_id': data['device_id'],
      'data': (data['data'] as List)
          .map(
            (d) => {
              'category_id': d['category_id'],
              'marks': d['marks'],
              'comment': d['comment'],
            },
          )
          .toList(),
    };

    try {
      final response = await http
          .post(
            Uri.parse('https://devntec.com/apias/create_evaluation.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['status'] == 'success') {
          final db = await DBHelper.db;
          await db.update(
            'evaluations',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (_) {
      // Handle all errors silently
    }
  }

  Future<void> _uploadAll() async {
    setState(() => loading = true);

    final list = List<Map<String, dynamic>>.from(pendingEvaluations);
    int success = 0;
    int failed = 0;

    for (var item in list) {
      await _uploadData(item['id'], item);
      final db = await DBHelper.db;
      final check = await db.query(
        'evaluations',
        where: 'id = ? AND synced = 1',
        whereArgs: [item['id']],
      );
      if (check.isNotEmpty) {
        success++;
      } else {
        failed++;
      }
    }

    await _loadAllSavedData();
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pending Evaluations"),
        backgroundColor: navyBlue,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          if (pendingEvaluations.isNotEmpty)
            TextButton(
              onPressed: loading ? null : _uploadAll,
              child: const Text("Upload All", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : pendingEvaluations.isEmpty
              ? const Center(child: Text("No pending uploads"))
              : ListView.builder(
                  itemCount: pendingEvaluations.length,
                  itemBuilder: (context, index) {
                    final item = pendingEvaluations[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: navyBlue,
                          child: Text(
                            "${index + 1}",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(
                          item['assessment_name'],
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'Student: ${item['student_roll']}\nEvaluator: ${item['evaluated_by']}',
                        ),
                        trailing: const Icon(Icons.cloud_off, color: Colors.grey),
                      ),
                    );
                  },
                ),
    );
  }
}
