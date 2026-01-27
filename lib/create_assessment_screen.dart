import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'data/db_helper.dart';
import 'data/initial_sync_service.dart';

class CreateAssessmentScreen extends StatefulWidget {
  const CreateAssessmentScreen({super.key});

  @override
  State<CreateAssessmentScreen> createState() => _CreateAssessmentScreenState();
}

class _CreateAssessmentScreenState extends State<CreateAssessmentScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _ucodeController = TextEditingController();

  String teacherName = '';
  bool _isNextClicked = false;

  final List<Map<String, TextEditingController>> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherName();
  }

  Future<void> _loadTeacherName() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      teacherName = prefs.getString('full_name') ?? '';
    });
  }

  void _addCategory() {
    setState(() {
      _categories.add({
        'category': TextEditingController(),
        'marks': TextEditingController(),
      });
    });
  }

  Future<void> _submitAssessment() async {
    if (_titleController.text.isEmpty || _ucodeController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Title and Ucode are mandatory")),
      );
      return;
    }

    final db = await DBHelper.db;
    final prefs = await SharedPreferences.getInstance();
    final bgnuId = prefs.getString('bgnu_id');

    if (bgnuId == null || bgnuId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: User ID not found. Please re-login.")),
      );
      return;
    }

    // 1. SAVE LOCALLY FIRST (Offline-First Approach)
    final assessmentId = await db.insert('assessments', {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'ucode': _ucodeController.text.trim(),
      'created_by': bgnuId,
      'teacher_name': teacherName, // Save for local display
      'synced': 0, // Not synced yet
    });

    for (var cat in _categories) {
      final catName = cat['category']!.text.trim();
      final marksText = cat['marks']!.text.trim();

      int marks = 0;
      int isComment = 1;

      if (marksText.isNotEmpty && int.tryParse(marksText) != null) {
        marks = int.parse(marksText);
        isComment = 0;
      }

      await db.insert('assessment_details', {
        'assessment_id': assessmentId,
        'category': catName,
        'marks': marks,
        'is_comment': isComment,
      });
    }

    // 2. TRIGGER SYNC IMMEDIATELY
    // We don't await this to block UI, we let it run in background/or await shortly
    // But for better UX, we'll fire and forget or quick await.
    // Given requirements say "jesy e net aye upload ho jaye", the auto-sync handles that.
    // We trigger it here just in case net is ALREADY available.
    InitialSyncService.autoSyncAssessments().then((_) {
      // Optional: Refresh local dashboard count if needed, but we rely on dashboard auto-refresh
    });

    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Assessment saved! Uploading in background..."),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Create Assessment"),
        backgroundColor: const Color(0xFF0A1D37),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: TextEditingController(text: teacherName),
              enabled: false,
              decoration: const InputDecoration(
                labelText: "Assessment by",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: "Title",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              decoration: const InputDecoration(
                labelText: "Description",
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ucodeController,
              maxLength: 4,
              decoration: const InputDecoration(
                labelText: "Ucode (Max 4 alphanumeric)",
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            if (!_isNextClicked)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_titleController.text.isNotEmpty &&
                        _ucodeController.text.isNotEmpty) {
                      setState(() => _isNextClicked = true);
                      _addCategory();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Please fill mandatory fields"),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A1D37),
                  ),
                  child: const Text(
                    "Next",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            if (_isNextClicked) ...[
              const Divider(height: 40),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Add categories",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 10),
              ..._categories.map(
                (cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: cat['category'],
                          decoration: const InputDecoration(
                            labelText: "Category",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: cat['marks'],
                          decoration: const InputDecoration(
                            labelText: "Marks/Comment",
                            border: OutlineInputBorder(),
                            hintText: "Mark or 'Comment'",
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: _addCategory,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueGrey,
                    ),
                    child: const Text(
                      "Add",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _submitAssessment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text(
                      "Submit",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
