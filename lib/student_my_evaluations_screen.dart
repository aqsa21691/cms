import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data/db_helper.dart';

class StudentMyEvaluationsScreen extends StatefulWidget {
  final int assessmentId;
  final String assessmentName;
  final String studentRoll;

  const StudentMyEvaluationsScreen({
    super.key,
    required this.assessmentId,
    required this.assessmentName,
    required this.studentRoll,
  });

  @override
  State<StudentMyEvaluationsScreen> createState() =>
      _StudentMyEvaluationsScreenState();
}

class _StudentMyEvaluationsScreenState
    extends State<StudentMyEvaluationsScreen> {
  bool isLoading = true;
  List<Map<String, dynamic>> myEvaluations = [];

  @override
  void initState() {
    super.initState();
    _loadMySpecificEvaluations();
  }

  Future<void> _loadMySpecificEvaluations() async {
    final db = await DBHelper.db;

    // Load from LOCAL DB first
    // Query: Matches if I am the subject (student_roll) OR if I am the evaluator (evaluated_by)
    final List<Map<String, dynamic>> evals = await db.query(
      'evaluations',
      where: 'assessment_id = ? AND (student_roll = ? OR evaluated_by = ?)',
      whereArgs: [
        widget.assessmentId,
        widget.studentRoll,
        widget.studentRoll
      ],
      orderBy: 'id DESC',
    );

    List<Map<String, dynamic>> fullList = [];
    for (var eval in evals) {
      final int evalId = eval['id'];

      // Try local items first
      List<Map<String, dynamic>> items = await db.rawQuery('''
        SELECT ei.*, ad.category as category_name, ad.marks as total_marks
        FROM evaluation_items ei
        LEFT JOIN assessment_details ad ON ei.category_id = ad.id
        WHERE ei.evaluation_id = ?
      ''', [evalId]);

      // Server Fallback: If no items found locally, try fetching from server
      if (items.isEmpty) {
        final String sRoll = (eval['student_roll']?.toString() ?? '').trim();
        final int aId = eval['assessment_id'];

        if (sRoll.isNotEmpty && aId != 0) {
          try {
            final response = await http.post(
              Uri.parse('https://devntec.com/apias/get_report.php'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'assessment_id': aId,
                'student_roll': sRoll,
                'evaluation_id': evalId
              }),
            );

            final body = jsonDecode(response.body);
            if (body['success'] == true && body['report'] != null) {
              final List serverCats = body['report']['categories'] ?? [];
              items = serverCats
                  .map(
                    (c) => {
                      'category_name': c['category_name'],
                      'marks': c['marks_obtained'],
                      'total_marks': c['total_marks'],
                      'comment': c['comment'] ?? '',
                    },
                  )
                  .toList();

              // Save to local DB
              if (items.isNotEmpty) {
                await db.transaction((txn) async {
                  await txn.delete('evaluation_items',
                      where: 'evaluation_id = ?', whereArgs: [evalId]);

                  for (var d in items) {
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
                });
              }
            }
          } catch (e) {
            debugPrint("Server fallback error in StudentMyEvaluationsScreen: $e");
          }
        }
      }

      fullList.add({
        ...eval,
        'data': items,
      });
    }

    setState(() {
      myEvaluations = fullList;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.assessmentName),
        backgroundColor: const Color(0xFF0A1D37),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : myEvaluations.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_late, size: 50, color: Colors.grey),
                      SizedBox(height: 10),
                      Text("No evaluations found for you yet."),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: myEvaluations.length,
                  itemBuilder: (context, index) {
                    final item = myEvaluations[index];
                    final details = item['data'] as List;

                    // Determine relationship
                    final isMyEvaluation =
                        item['evaluated_by'] == widget.studentRoll;
                    final isAboutMe = item['student_roll'] == widget.studentRoll;

                    String headerText = "";
                    Color headerColor = Colors.black;

                    if (isMyEvaluation) {
                      headerText = "You evaluated this student";
                      headerColor = const Color(0xFF0A1D37); // Navy
                    } else if (isAboutMe) {
                      headerText = "Evaluated by: ${item['evaluated_by']}";
                      headerColor = Colors.green[800]!;
                    } else {
                      // Should not happen with strict filtering, but fallback
                      headerText = "Evaluation";
                    }

                    int totalMarks = 0;
                    for (var d in details) {
                      totalMarks += (d['marks'] as int? ?? 0);
                    }

                    return Card(
                      elevation: 3,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isMyEvaluation
                              ? const Color(0xFF0A1D37).withValues(alpha: 0.3)
                              : Colors.green.withValues(alpha: 0.3),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        headerText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: headerColor,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        "ID: ${item['id']}",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMyEvaluation
                                        ? const Color(0xFF0A1D37)
                                        : Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    "Total: $totalMarks",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(),
                            if (details.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text("No details available"),
                              ),
                            ...details.map<Widget>((d) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        d['category_name'] ?? 'Category',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        d['comment'] != null &&
                                                d['comment'].toString().isNotEmpty
                                            ? d['comment']
                                            : "${d['marks']} marks",
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
