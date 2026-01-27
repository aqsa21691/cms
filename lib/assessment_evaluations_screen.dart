import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AssessmentEvaluationsScreen extends StatefulWidget {
  final int assessmentId;
  final String assessmentTitle;

  const AssessmentEvaluationsScreen({
    super.key,
    required this.assessmentId,
    required this.assessmentTitle,
  });

  @override
  State<AssessmentEvaluationsScreen> createState() =>
      _AssessmentEvaluationsScreenState();
}

class _AssessmentEvaluationsScreenState
    extends State<AssessmentEvaluationsScreen> {
  bool isLoading = true;
  Map<String, dynamic>? assessmentData;
  List<dynamic> evaluations = [];
  List<dynamic> categories = [];

  @override
  void initState() {
    super.initState();
    _loadEvaluations();
  }

  Future<void> _loadEvaluations() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://devntec.com/apias/get_assessment_evaluations.php?assessment_id=${widget.assessmentId}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success') {
          setState(() {
            assessmentData = data['assessment'];
            categories = data['categories'] ?? [];
            evaluations = data['evaluations'] ?? [];
            isLoading = false;
          });
        } else {
          _showError(data['message'] ?? 'Failed to load evaluations');
        }
      } else {
        _showError('Network error occurred');
      }
    } catch (e) {
      _showError('Error: $e');
    }
  }

  void _showError(String message) {
    setState(() => isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Widget _buildEvaluationCard(Map<String, dynamic> evaluation) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          evaluation['student_name'] ?? 'Unknown Student',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Student ID: ${evaluation['student_id'] ?? 'N/A'}'),
            Text('Evaluated by: ${evaluation['evaluated_by'] ?? 'N/A'}'),
            Text('Date: ${evaluation['created_at'] ?? 'N/A'}'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Evaluation Details:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...((evaluation['details'] as List<dynamic>?) ?? []).map((
                  detail,
                ) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${detail['category']}:',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            detail['is_comment'] == 1
                                ? (detail['value'] ?? 'No comment')
                                : '${detail['value'] ?? 0} marks',
                            style: TextStyle(
                              color: detail['is_comment'] == 1
                                  ? Colors.blue
                                  : Colors.green,
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
        title: Text(
          'Evaluations: ${widget.assessmentTitle}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Assessment Info Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            assessmentData?['title'] ?? 'Assessment',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0A1D37),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('Code: ${assessmentData?['ucode'] ?? 'N/A'}'),
                          Text(
                            'Description: ${assessmentData?['description'] ?? 'No description'}',
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Total Evaluations: ${evaluations.length}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Evaluations List
                  const Text(
                    'Student Evaluations:',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0A1D37),
                    ),
                  ),
                  const SizedBox(height: 10),

                  Expanded(
                    child: evaluations.isEmpty
                        ? const Center(
                            child: Text(
                              'No evaluations found for this assessment',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : ListView.builder(
                            itemCount: evaluations.length,
                            itemBuilder: (context, index) {
                              return _buildEvaluationCard(evaluations[index]);
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
