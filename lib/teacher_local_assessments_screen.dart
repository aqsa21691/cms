import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'data/db_helper.dart';

class TeacherLocalAssessmentsScreen extends StatefulWidget {
  const TeacherLocalAssessmentsScreen({super.key});

  @override
  State<TeacherLocalAssessmentsScreen> createState() =>
      _TeacherLocalAssessmentsScreenState();
}

class _TeacherLocalAssessmentsScreenState
    extends State<TeacherLocalAssessmentsScreen> {
  List assessments = [];
  bool _isUploading = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _loadLocalAssessments();
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
      bool isConnected =
          results.contains(ConnectivityResult.mobile) ||
          results.contains(ConnectivityResult.wifi);
      if (isConnected) {
        _uploadAll();
      }
    });
  }

  Future<void> _loadLocalAssessments() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'assessments',
      where: 'synced = ?',
      whereArgs: [0],
    );
    setState(() {
      assessments = maps;
    });
  }

  Future<void> _uploadAll() async {
    if (assessments.isEmpty) return;

    setState(() => _isUploading = true);

    final db = await DBHelper.db;

    for (var assessment in assessments) {
      final details = await db.query(
        'assessment_details',
        where: 'assessment_id = ?',
        whereArgs: [assessment['id']],
      );

      final body = {
        'title': assessment['title'],
        'description': assessment['description'],
        'ucode': assessment['ucode'],
        'created_by': assessment['created_by'],
        'categories': details
            .map(
              (d) => {
                'name': d['category'],
                'marks': d['marks'],
                'is_comment': d['is_comment'],
              },
            )
            .toList(),
      };

      try {
        final response = await http.post(
          Uri.parse('https://devntec.com/apias/create_assessment.php'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        );

        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          await db.update(
            'assessments',
            {'synced': 1},
            where: 'id = ?',
            whereArgs: [assessment['id']],
          );
        }
      } catch (e) {
        // Upload failed silently
      }
    }

    setState(() => _isUploading = false);
    _loadLocalAssessments();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Sync completed"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Local Assessments"),
        backgroundColor: const Color(0xFF0A1D37),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        actions: [
          if (assessments.isNotEmpty)
            _isUploading
                ? const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : TextButton(
                    onPressed: _uploadAll,
                    child: const Text(
                      "Upload All",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
        ],
      ),
      body: assessments.isEmpty
          ? const Center(child: Text("No local assessments to show"))
          : ListView.builder(
              itemCount: assessments.length,
              itemBuilder: (context, index) {
                final item = assessments[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF0A1D37),
                      child: Text(
                        "${index + 1}",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(item['title'] ?? ''),
                    subtitle: Text("Code: ${item['ucode']}"),
                    trailing: const Icon(Icons.cloud_off, color: Colors.grey),
                  ),
                );
              },
            ),
    );
  }
}
