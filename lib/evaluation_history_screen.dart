import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data/db_helper.dart';

class EvaluationHistoryScreen extends StatefulWidget {
  final int? assessmentId;
  const EvaluationHistoryScreen({super.key, this.assessmentId});

  @override
  State<EvaluationHistoryScreen> createState() =>
      _EvaluationHistoryScreenState();
}

class _EvaluationHistoryScreenState extends State<EvaluationHistoryScreen> {
  List history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('designation') ?? '';
    final userId = prefs.getString('bgnu_id') ?? '';

    final db = await DBHelper.db;
    // Using LEFT JOIN to ensure evaluations are visible even if local assessment or user data is missing
    String query = '''
      SELECT 
        e.*, 
        a.title as assessment_title, 
        u.full_name as student_name,
        a.created_by as assessment_owner
      FROM evaluations e
      LEFT JOIN assessments a ON e.assessment_id = a.id
      LEFT JOIN users u ON e.student_roll = u.bgnu_id
    ''';

    List<dynamic> args = [];
    List<String> conditions = [];

    if (widget.assessmentId != null) {
      conditions.add('e.assessment_id = ?');
      args.add(widget.assessmentId);
    }

    // Role-based filtering
    if (role == 'Student') {
      conditions.add('e.student_roll = ?');
      args.add(userId);
    } else if (role == 'Teacher') {
      // Teachers see evaluations for assessments THEY created
      // Note: This relies on local assessments table being synced/populated
      conditions.add('a.created_by = ?');
      args.add(userId);
    }

    // Show all evaluations (synced and offline)
    // conditions.add('e.synced = 1');

    if (conditions.isNotEmpty) {
      query += ' WHERE ${conditions.join(' AND ')}';
    }

    query += ' ORDER BY e.id DESC';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, args);

    setState(() {
      history = maps
          .map(
            (e) => {
              ...e,
              'student_name': e['student_name'] ?? e['student_roll'] ?? 'N/A',
              'assessment_title':
                  e['assessment_title'] ??
                  'Unknown (ID: ${e['assessment_id']})',
            },
          )
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.assessmentId == null ? "History" : "Assessment History",
        ),
        backgroundColor: const Color(0xFF0A1D37),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: history.isEmpty
          ? const Center(child: Text("No evaluations found"))
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final item = history[index];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  elevation: 2,
                  child: ListTile(
                    title: Text(
                      "To: ${item['student_name']}",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Assessment: ${item['assessment_title']}"),
                        Text(
                          "By: ${item['evaluated_by']}",
                          style: const TextStyle(
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          "Eval ID: ${item['id']}",
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.blueGrey,
                          ),
                        ),
                      ],
                    ),
                    trailing: Icon(
                      item['synced'] == 1 ? Icons.cloud_done : Icons.cloud_off,
                      color: item['synced'] == 1 ? Colors.green : Colors.grey,
                    ),
                    onTap: () => _showDetails(item),
                  ),
                );
              },
            ),
    );
  }

  void _showDetails(dynamic item) async {
    final db = await DBHelper.db;

    // 1. Try Local Fetch
    // Find all IDs for this student & assessment to handle duplicate headers
    final idsResult = await db.query(
      'evaluations',
      columns: ['id'],
      where: 'assessment_id = ? AND student_roll = ?',
      whereArgs: [
        item['assessment_id'],
        item['student_roll'] ?? item['evaluation_of']
      ],
    );

    final ids = idsResult.map((e) => e['id']).toList();
    if (ids.isEmpty && item['id'] != null) {
      ids.add(item['id']);
    }

    List<Map<String, dynamic>> details = [];
    if (ids.isNotEmpty) {
      final placeholders = List.filled(ids.length, '?').join(',');
      details = await db.rawQuery(
        '''
      SELECT ei.*, ad.category as category_name, ad.marks as total_marks
      FROM evaluation_items ei
      LEFT JOIN assessment_details ad ON ei.category_id = ad.id
      WHERE ei.evaluation_id IN ($placeholders)
    ''',
        ids,
      );
    }

    bool isFromServer = false;

    // 2. Try Server Fallback if local is empty
    if (details.isEmpty) {
      final sRoll = (item['student_roll']?.toString() ?? '').trim();
      final aId = item['assessment_id'];

      if (sRoll.isNotEmpty && aId != null) {
        try {
          final response = await http.post(
            Uri.parse('https://devntec.com/apias/get_report.php'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'assessment_id': aId,
              'student_roll': sRoll,
              'evaluation_id': item['id']
            }),
          );

          final body = jsonDecode(response.body);
          if (body['success'] == true && body['report'] != null) {
            final List serverCats = body['report']['categories'] ?? [];
            details = serverCats
                .map(
                  (c) => {
                    'category_name': c['category_name'],
                    'marks': c['marks_obtained'],
                    'total_marks': c['total_marks'],
                    'comment': c['comment'] ?? '',
                  },
                )
                .toList();
            isFromServer = true;

            // 3. Save to local DB for future use
            if (details.isNotEmpty) {
              try {
                await db.transaction((txn) async {
                  final evalId = item['id'];
                  if (evalId != null) {
                    await txn.delete('evaluation_items',
                        where: 'evaluation_id = ?', whereArgs: [evalId]);

                    for (var d in details) {
                      final catMaps = await txn.query('assessment_details',
                          where: 'assessment_id = ? AND category = ?',
                          whereArgs: [aId, d['category_name']]);

                      int catId = 0;
                      if (catMaps.isNotEmpty) {
                        catId = catMaps.first['id'] as int;
                      }

                      await txn.insert('evaluation_items', {
                        'evaluation_id': evalId,
                        'category_id': catId,
                        'marks': d['marks'] ?? 0,
                        'comment': d['comment'] ?? '',
                      });
                    }
                  }
                });
              } catch (e) {
                debugPrint("Error saving details locally: $e");
              }
            }
          } else {
            debugPrint("Server report fetch failed: ${body['message']}");
          }
        } catch (e) {
          debugPrint("Server fallback error: $e");
        }
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Evaluation Details",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0A1D37),
                        ),
                      ),
                      if (isFromServer)
                        const Text(
                          "Fetched from Server",
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Text(
                "Student: ${item['student_name']}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                "Evaluator ID: ${item['evaluated_by']}",
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 15),
              Expanded(
                child: details.isEmpty
                    ? const Center(
                        child: Text(
                          "No data details found for this evaluation.",
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: details.length,
                        itemBuilder: (context, idx) {
                          final d = details[idx];
                          final catName =
                              d['category_name'] ?? "Unknown Category";
                          final tMarks = d['total_marks'] ?? 0;
                          final isComment =
                              catName.toString().toLowerCase().contains(
                                'comment',
                              ) ||
                              tMarks == 0;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  catName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0A1D37),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (isComment)
                                  Text(
                                    d['comment']?.toString().isNotEmpty == true
                                        ? d['comment']
                                        : "No comment provided",
                                    style: const TextStyle(
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        "Score: ${d['marks']} / $tMarks",
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      if (d['comment']?.toString().isNotEmpty ==
                                          true)
                                        const Icon(
                                          Icons.comment,
                                          size: 16,
                                          color: Colors.grey,
                                        ),
                                    ],
                                  ),
                                if (!isComment &&
                                    d['comment']?.toString().isNotEmpty == true)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(
                                      "Note: ${d['comment']}",
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
