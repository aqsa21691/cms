import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'data/db_helper.dart';
import 'data/initial_sync_service.dart';

class EvaluationScreen extends StatefulWidget {
  final int assessmentId;
  final String assessmentName;

  const EvaluationScreen({
    super.key,
    required this.assessmentId,
    required this.assessmentName,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  static const Color navyBlue = Color(0xFF0A1D37);
  static const double radius = 14;

  final TextEditingController evaluatedByController = TextEditingController();

  Map<String, dynamic>? selectedStudent;
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> categories = [];
  int? existingEvaluationId;

  final Map<String, TextEditingController> controllers = {};

  bool loadingStudents = true;
  bool loadingCategories = false;

  bool isReadOnly = false;
  bool _isSubmitting = false; // Prevent double taps

  @override
  void initState() {
    super.initState();
    _loadEvaluator();
    _loadStudents();
    _loadPreDefinedCategories();
  }

  Future<void> _loadPreDefinedCategories() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> catMaps = await db.query(
      'assessment_details',
      where: 'assessment_id = ?',
      whereArgs: [widget.assessmentId],
    );
    setState(() {
      categories = catMaps;
    });
  }

  // ---------------- Load Evaluator Email ----------------
  Future<void> _loadEvaluator() async {
    final prefs = await SharedPreferences.getInstance();
    final evaluator =
        prefs.getString('bgnu_id') ?? prefs.getString('email') ?? '';
    setState(() {
      evaluatedByController.text = evaluator;
    });
  }

  // ---------------- Load Students (Offline) ----------------
  // ---------------- Load Students (Offline) ----------------
  Future<void> _loadStudents() async {
    final db = await DBHelper.db;
    final List<Map<String, dynamic>> maps = await db.query(
      'users',
      where: 'designation = ?',
      whereArgs: ['Student'],
    );

    setState(() {
      students = maps;
      loadingStudents = false;
    });
  }

  // ---------------- Load Categories (Offline) ----------------
  // ---------------- Load Categories & Existing Data ----------------
  Future<void> _loadCategories() async {
    if (selectedStudent == null) return;

    print('🟢 LOAD DEBUG: Loading categories for student: ${selectedStudent!['bgnu_id']}');
    
    final db = await DBHelper.db;

    // Check for existing evaluation
    final List<Map<String, dynamic>> existingEvals = await db.query(
      'evaluations',
      where: 'assessment_id = ? AND student_roll = ?',
      whereArgs: [widget.assessmentId, selectedStudent!['bgnu_id']],
    );

    print('🟢 LOAD DEBUG: Found ${existingEvals.length} existing evaluations');

    int? foundEvalId;
    Map<int, dynamic> existingValues = {};
    bool readOnly = false;

    if (existingEvals.isNotEmpty) {
      final eval = existingEvals.first;
      foundEvalId = eval['id'];
      print('🟢 LOAD DEBUG: Existing eval ID: $foundEvalId, Synced: ${eval['synced']}');
      
      if (eval['synced'] == 1) {
        readOnly = true;
        print('🟢 LOAD DEBUG: Evaluation is synced - setting READ ONLY');
      }

      final List<Map<String, dynamic>> items = await db.query(
        'evaluation_items',
        where: 'evaluation_id = ?',
        whereArgs: [foundEvalId],
      );

      print('🟢 LOAD DEBUG: Found ${items.length} evaluation items');
      for (var item in items) {
        existingValues[item['category_id']] = item;
        print('🟢 LOAD DEBUG: Item - Category ID: ${item['category_id']}, Marks: ${item['marks']}, Comment: ${item['comment']}');
      }
    } else {
      print('🟢 LOAD DEBUG: No existing evaluation - starting fresh');
    }

    setState(() {
      existingEvaluationId = foundEvalId;
      isReadOnly = readOnly;
      _initControllers(existingValues);
    });
  }

  void _initControllers(Map<int, dynamic> existingValues) {
    controllers.clear();
    for (var c in categories) {
      final catId = c['id'];
      final catName = c['category'];
      final existingItem = existingValues[catId];

      String initialText = '';
      if (existingItem != null) {
        if (c['is_comment'] == 1) {
          initialText = existingItem['comment'] ?? '';
        } else {
          initialText = existingItem['marks'].toString();
        }
      }

      controllers[catName] = TextEditingController(text: initialText);

    }
  }

  // ---------------- Save Evaluation Locally (Update or Insert) ----------------
  Future<void> _saveLocally({bool silent = false}) async {
    if (selectedStudent == null) return;
    if (isReadOnly || _isSubmitting) return;

    setState(() => _isSubmitting = true);

    final db = await DBHelper.db;
    final bgnuId = selectedStudent!['bgnu_id'];

    print('🔵 SAVE DEBUG: Starting save for student: $bgnuId');
    print('🔵 SAVE DEBUG: Assessment ID: ${widget.assessmentId}');
    print('🔵 SAVE DEBUG: Existing Eval ID: $existingEvaluationId');

    int evalId;

    final deviceInfo = DeviceInfoPlugin();
    String deviceId = "unknown_id";
    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceId = androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceId = iosInfo.identifierForVendor ?? "unknown_ios_id";
    }

    final String now = DateTime.now().toString().split('.').first; // YYYY-MM-DD HH:MM:SS
    print('🔵 SAVE DEBUG: Device ID: $deviceId');
    print('🔵 SAVE DEBUG: Timestamp: $now');

    if (existingEvaluationId != null) {
      print('🔵 SAVE DEBUG: Updating existing evaluation ID: $existingEvaluationId');
      evalId = existingEvaluationId!;
      await db.update(
        'evaluations',
        {
          'evaluated_by': evaluatedByController.text.trim().toLowerCase(),
          'device_id': deviceId,
          'synced': 0,
        },
        where: 'id = ?',
        whereArgs: [evalId],
      );
      print('🔵 SAVE DEBUG: Updated evaluation header');

      await db.delete(
        'evaluation_items',
        where: 'evaluation_id = ?',
        whereArgs: [evalId],
      );
      print('🔵 SAVE DEBUG: Deleted old evaluation items');
    } else {
      print('🔵 SAVE DEBUG: Inserting new evaluation');
      evalId = await db.insert('evaluations', {
        'assessment_id': widget.assessmentId,
        'student_roll': bgnuId,
        'evaluated_by': evaluatedByController.text.trim().toLowerCase(),
        'device_id': deviceId,
        'created_at': now,
        'synced': 0,
      });
      print('🔵 SAVE DEBUG: Inserted new evaluation with ID: $evalId');
      setState(() {
        existingEvaluationId = evalId;
      });
    }

    print('🔵 SAVE DEBUG: Saving ${categories.length} category items');
    for (var c in categories) {
      final isComment = c['is_comment'] == 1;
      final catName = c['category'];
      final value = controllers[catName]?.text ?? '';
      
      print('🔵 SAVE DEBUG: Category: $catName, Value: $value, IsComment: $isComment');
      
      await db.insert('evaluation_items', {
        'evaluation_id': evalId,
        'category_id': c['id'] ?? 0,
        'marks': isComment
            ? 0
            : int.tryParse(controllers[c['category']]!.text) ?? 0,
        'comment': isComment ? controllers[c['category']]!.text : '',
      });
    }

    print('🔵 SAVE DEBUG: All items saved successfully');

    // Trigger immediate sync in background
    print('🔵 SAVE DEBUG: Triggering auto-sync');
    InitialSyncService.autoSync();

    if (!silent && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Evaluation Submitted Successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      // Brief delay then exit
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) Navigator.pop(context);
      });
    }
    
    if (mounted) {
       setState(() => _isSubmitting = false);
    }
    
    print('🔵 SAVE DEBUG: Save process completed');
  }

  // ---------------- Build Field Widget ----------------
  Widget _buildField(Map<String, dynamic> c) {
    final label = c['category'];
    final isComment = c['is_comment'] == 1;
    final maxMarks = c['marks'] ?? 0;

    if (isComment) {
      return TextField(
        controller: controllers[label],
        maxLines: 3,
        enabled: !isReadOnly, // Disable if read-only
        onChanged: (v) {
          final words = v.trim().split(RegExp(r'\s+'));
          if (words.length > 30) {
            controllers[label]!.text = words.take(30).join(' ');
          }
        },
        decoration: InputDecoration(
          labelText: '$label (max 30 words)',
          filled: true,
          fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: navyBlue,
          ),
        ),
      );
    } else {
      return TextField(
        controller: controllers[label],
        keyboardType: TextInputType.number,
        enabled: !isReadOnly, // Disable if read-only
        onChanged: (v) {
          int? value = int.tryParse(v);
          if (value != null && value > maxMarks && maxMarks > 0) {
            controllers[label]!.text = maxMarks.toString();
            controllers[label]!.selection = TextSelection.fromPosition(
              TextPosition(offset: controllers[label]!.text.length),
            );
          }
        },
        decoration: InputDecoration(
          labelText: '$label (out of $maxMarks)',
          filled: true,
          fillColor: isReadOnly ? Colors.grey[200] : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          labelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            color: navyBlue,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: navyBlue,
        elevation: 0,
        title: Text(widget.assessmentName),
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        automaticallyImplyLeading: true,
      ),
      body: loadingStudents
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: evaluatedByController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Evaluated By',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(radius),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Student Dropdown
                  DropdownSearch<Map<String, dynamic>>(
                    items: (filter, props) => students,
                    itemAsString: (s) => s != null ? "${s['full_name']} - ${s['bgnu_id']}" : "",
                    compareFn: (item1, item2) => item1['bgnu_id'] == item2['bgnu_id'],
                    onChanged: (v) {
                      selectedStudent = v;
                      _loadCategories();
                    },
                    popupProps: PopupProps.menu(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration: InputDecoration(
                          hintText: "Search Student...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radius),
                          ),
                        ),
                      ),
                    ),
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Select Student',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (isReadOnly)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.amberAccent.withOpacity(0.2),
                      child: const Row(
                        children: [
                          Icon(Icons.lock, color: Colors.orange),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'This evaluation has already been uploaded and cannot be edited.',
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 10),

                  ...categories.map(
                    (c) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildField(c),
                    ),
                  ),

                  const SizedBox(height: 20),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (isReadOnly || _isSubmitting)
                          ? null
                          : _saveLocally, // Disable if read only or submitting
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isReadOnly
                            ? Colors.grey
                            : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(radius),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white)
                          : Text(
                              isReadOnly ? 'Already Uploaded' : 'Submit',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
