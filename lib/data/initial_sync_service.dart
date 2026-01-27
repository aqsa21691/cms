import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:device_info_plus/device_info_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'db_helper.dart';

class InitialSyncService {
  static Future<void> registerDevice([String? email]) async {
    final deviceInfo = DeviceInfoPlugin();
    String deviceName = "Unknown Device";
    String deviceId = "unknown_id";

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      deviceName = "${androidInfo.manufacturer} ${androidInfo.model}";
      deviceId = androidInfo.id; // Unique Android ID
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      deviceName = iosInfo.name;
      deviceId = iosInfo.identifierForVendor ?? "unknown_ios_id";
    }

    final networkInfo = NetworkInfo();
    String? ipAddress = await networkInfo.getWifiIP() ?? "0.0.0.0";
    String finalEmail = email ?? "Guest/New Install";

    // Update local DB
    final db = await DBHelper.db;
    await db.insert('devices', {
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'last_seen': DateTime.now().toString(),
      'email': finalEmail,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Send to Server (Placeholder API call)
    try {
      await http.post(
        Uri.parse('https://devntec.com/apias/register_device.php'),
        body: jsonEncode({
          'device_id': deviceId,
          'email': finalEmail,
          'device_name': deviceName,
          'ip_address': ipAddress,
        }),
      );
    } catch (e) {
      // Ignore network errors for device registration
    }

    // Repair historical data (lowercase all evaluated_by emails and anchor to device)
    await repairEvaluatorEmails(deviceId);
  }

  static Future<void> repairEvaluatorEmails(String currentDeviceId) async {
    final db = await DBHelper.db;
    try {
      // 1. Fetch ALL evaluations to perform comprehensive repair
      final List<Map<String, dynamic>> records = await db.query('evaluations');

      if (records.isNotEmpty) {
        await db.transaction((txn) async {
          for (var r in records) {
            String originalEmail = (r['evaluated_by'] as String? ?? '').trim();
            String lowerEmail = originalEmail.toLowerCase();
            String? existingDeviceId = r['device_id'] as String?;

            bool needsUpdate = false;
            Map<String, dynamic> updates = {};

            // Fix Email: Normalize (Trim + Lowercase)
            if (originalEmail != lowerEmail ||
                (r['evaluated_by'] as String) != lowerEmail) {
              updates['evaluated_by'] = lowerEmail;
              needsUpdate = true;
            }

            // Fix Device ID: If missing, anchor to this device
            if (existingDeviceId == null ||
                existingDeviceId.isEmpty ||
                existingDeviceId == 'unknown_id') {
              updates['device_id'] = currentDeviceId;
              needsUpdate = true;
            }

            if (needsUpdate) {
              await txn.update(
                'evaluations',
                updates,
                where: 'id = ?',
                whereArgs: [r['id']],
              );
            }
          }
        });
      }
    } catch (e) {
      // Silent error for repair
    }
  }

  static Future<void> fetchDevices(String token) async {
    try {
      final res = await http.get(
        Uri.parse('https://devntec.com/apias/get_devices.php'),
      );
      final body = jsonDecode(res.body);

      final db = await DBHelper.db;
      await db.transaction((txn) async {
        await txn.delete('devices');
        for (var d in body['data']) {
          await txn.insert('devices', {
            'device_id':
                d['device_id'] ??
                d['id'].toString(), // Fallback if server uses id
            'device_name': d['device_name'],
            'ip_address': d['ip_address'],
            'last_seen': d['last_seen'],
            'email': d['email'],
          });
        }
      });
    } catch (e) {
      // Handle offline
    }
  }

  static Future<void> syncRecords(String token, [String? teacherId]) async {
    try {
      // 1. Fetch Assessments
      String url = 'https://devntec.com/apias/get_assessments.php';
      if (teacherId != null && teacherId.isNotEmpty) {
        url += '?teacher_id=$teacherId';
      }

      final resAssessments = await http.get(Uri.parse(url));
      final bodyAssessments = jsonDecode(resAssessments.body);

      // 2. Fetch All Categories
      final resCategories = await http.post(
        Uri.parse('https://devntec.com/apias/get_assessment_categories.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'assessment_id': 0}),
      );
      final bodyCategories = jsonDecode(resCategories.body);

      final db = await DBHelper.db;
      await db.transaction((txn) async {
        // Only clear if we actually got data to replace it with
        bool gotAssessments =
            bodyAssessments['status'] == 'success' ||
            bodyAssessments['status'] == true;
        bool gotCategories =
            bodyCategories['status'] == 'success' ||
            bodyCategories['status'] == true;

        if (gotAssessments) {
          // Restore delete: Sync means "match server state". If server deletes, we delete.
          await txn.delete('assessments', where: 'synced = 1');

          for (var a in bodyAssessments['data']) {
            // CRITICAL FIX: If server doesn't return created_by (old API), use the teacherId we verified against.
            final ownerId = a['created_by'] ?? teacherId;

            await txn.insert('assessments', {
              'id': a['id'],
              'title': a['title'],
              'description': a['description'],
              'ucode': a['ucode'],
              'created_by': ownerId, 
              'teacher_name': a['teacher_name'],
              'synced': 1,
            });
          }
        }

        if (gotCategories) {
          await txn.delete('assessment_details');
          for (var c in bodyCategories['data']) {
            await txn.insert('assessment_details', {
              'id': c['id'],
              'assessment_id': c['assessment_id'],
              'category': c['category'],
              'marks': c['marks'],
              'is_comment': c['is_comment'],
            });
          }
        }
      });
    } catch (e) {
      // Sync failed silently
    }
  }

  static Future<void> syncUsers(String token) async {
    final res = await http.get(
      Uri.parse('https://devntec.com/apias/get_students.php'),
    );
    final body = jsonDecode(res.body);

    final db = await DBHelper.db;
    await db.transaction((txn) async {
      await txn.delete(
        'users',
        where: 'designation = ?',
        whereArgs: ['Student'],
      );
      for (var s in body['data']) {
        await txn.insert('users', {
          'bgnu_id': s['bgnu_id'],
          'full_name': s['full_name'],
          'designation': 'Student',
        });
      }
    });
  }

  static Future<void> autoSync() async {
    await autoSyncAssessments();
    await autoSyncEvaluations();
  }

  static bool _isSyncingAssessments = false;

  static Future<void> autoSyncAssessments() async {
    if (_isSyncingAssessments) return;
    _isSyncingAssessments = true;

    try {
      final db = await DBHelper.db;
      final List<Map<String, dynamic>> assessments = await db.query(
        'assessments',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (assessments.isEmpty) return;

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
            final int newId = data['id'];
            final int oldId = assessment['id'];

            if (newId != oldId) {
              await db.transaction((txn) async {
                // 1. Migrate Assessment ID references
                await txn.rawUpdate(
                  'UPDATE assessment_details SET assessment_id = ? WHERE assessment_id = ?',
                  [newId, oldId],
                );
                await txn.rawUpdate(
                  'UPDATE evaluations SET assessment_id = ? WHERE assessment_id = ?',
                  [newId, oldId],
                );
                // 2. Migrate Assessment itself
                await txn.rawUpdate(
                  'UPDATE assessments SET id = ?, synced = 1 WHERE id = ?',
                  [newId, oldId],
                );
              });

              // 3. Fetch NEW category IDs from server to migrate evaluation_items
              try {
                final resCats = await http.post(
                  Uri.parse(
                    'https://devntec.com/apias/get_assessment_categories.php',
                  ),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({'assessment_id': newId}),
                );
                final bodyCats = jsonDecode(resCats.body);
                if (bodyCats['status'] == 'success' ||
                    bodyCats['status'] == true) {
                  final serverCats = bodyCats['data'];
                  await db.transaction((txn) async {
                    for (var sCat in serverCats) {
                      final String catName = sCat['category'];
                      final int newCatId = sCat['id'];

                      // Update items that reference this assessment and have this category name
                      // Join with assessment_details to find by name
                      await txn.rawUpdate('''
                        UPDATE evaluation_items 
                        SET category_id = ? 
                        WHERE category_id IN (
                          SELECT ad.id FROM assessment_details ad 
                          WHERE ad.assessment_id = ? AND ad.category = ?
                        )
                      ''', [newCatId, newId, catName]);
                    }
                  });
                }
              } catch (_) {}
            } else {
              await db.update(
                'assessments',
                {'synced': 1},
                where: 'id = ?',
                whereArgs: [oldId],
              );
            }
          }
        } catch (e) {
          // Auto-sync failed for assessment silently
        }
      }
    } catch (e) {
      // Handle errors silently
    } finally {
      _isSyncingAssessments = false;
    }
  }

  static bool _isSyncingEvaluations = false;

  static Future<void> autoSyncEvaluations() async {
    if (_isSyncingEvaluations) return;
    _isSyncingEvaluations = true;

    try {
      final db = await DBHelper.db;
      final List<Map<String, dynamic>> evaluations = await db.query(
        'evaluations',
        where: 'synced = ?',
        whereArgs: [0],
      );

      if (evaluations.isEmpty) {
        return;
      }

      for (var eval in evaluations) {
        final items = await db.query(
          'evaluation_items',
          where: 'evaluation_id = ?',
          whereArgs: [eval['id']],
        );

        final payload = {
          'assessment_id': eval['assessment_id'],
          'student_roll': eval['student_roll'],
          'evaluated_by': eval['evaluated_by'],
          'device_id': eval['device_id'],
          'created_at': eval['created_at'], // Exact phone timestamp for idempotency
          'data': items
              .map(
                (i) => {
                  'category_id': i['category_id'],
                  'marks': i['marks'],
                  'comment': i['comment'],
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
              final dynamic serverIdRaw = body['id'];
              final int? serverId = int.tryParse(serverIdRaw.toString());
              final int localId = eval['id'];

              if (serverId != null && serverId != localId) {
                await db.transaction((txn) async {
                  // Update references in items
                  await txn.rawUpdate(
                    'UPDATE evaluation_items SET evaluation_id = ? WHERE evaluation_id = ?',
                    [serverId, localId],
                  );
                  // Update header itself (ID and synced status)
                  await txn.rawUpdate(
                    'UPDATE evaluations SET id = ?, synced = 1 WHERE id = ?',
                    [serverId, localId],
                  );
                });
              } else {
                await db.update(
                  'evaluations',
                  {'synced': 1},
                  where: 'id = ?',
                  whereArgs: [localId],
                );
              }
            }
          }
        } catch (_) {
          // Handle all errors silently
        }
      }
    } catch (e) {
      // Handle errors silently
    } finally {
      _isSyncingEvaluations = false;
    }
  }

  static Future<void> syncStudentHistory(String studentRoll) async {
    try {
      final response = await http.post(
        Uri.parse('https://devntec.com/apias/get_student_history.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'student_roll': studentRoll}),
      );

      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        final db = await DBHelper.db;
        final List history = body['data'];
        final List<int> serverIds = history.map((e) => int.tryParse(e['id'].toString()) ?? 0).where((id) => id != 0).toList();

        await db.transaction((txn) async {
          // Sync-Purge: Delete synced local evaluations that are NOT in the server's history for this student
          if (serverIds.isNotEmpty) {
             final idList = serverIds.join(',');
             await txn.delete('evaluations', 
               where: 'student_roll = ? AND synced = 1 AND id NOT IN ($idList)', 
               whereArgs: [studentRoll]
             );
          } else {
             // If server reports ZERO history, wipe all synced local evaluations for this student
             await txn.delete('evaluations', 
               where: 'student_roll = ? AND synced = 1', 
               whereArgs: [studentRoll]
             );
          }

          for (var item in history) {
            // Check if exists
            final existing = await txn.query(
              'evaluations',
              where: 'id = ?',
              whereArgs: [item['id']],
            );

            if (existing.isEmpty) {
              // Insert header only (details lazy loaded)
              await txn.insert('evaluations', {
                'id': item['id'],
                'assessment_id': item['assessment_id'],
                'student_roll': item['evaluation_of'] ?? item['student_roll'],
                'evaluated_by': item['evaluated_by'],
                'synced': 1,
              });
            }
          }
        });
      }
    } catch (e) {
      // Failed to sync student history silently
    }
  }

  static Future<void> syncTeacherHistory(String teacherId) async {
    try {
      final response = await http.post(
        Uri.parse('https://devntec.com/apias/get_teacher_history.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'teacher_id': teacherId}),
      );

      final body = jsonDecode(response.body);
      if (body['success'] == true) {
        final db = await DBHelper.db;
        final List history = body['data'];
        final List<int> serverIds = history.map((e) => int.tryParse(e['id'].toString()) ?? 0).where((id) => id != 0).toList();

        await db.transaction((txn) async {
          // Sync-Purge for Teacher: 
          // We only purge records that belong to assessments THIS teacher created.
          // Otherwise, we might delete evaluations synced by other means.
          if (serverIds.isNotEmpty) {
             final idList = serverIds.join(',');
             await txn.delete('evaluations', 
               where: 'synced = 1 AND assessment_id IN (SELECT id FROM assessments WHERE created_by = ?) AND id NOT IN ($idList)', 
               whereArgs: [teacherId]
             );
          } else {
             await txn.delete('evaluations', 
               where: 'synced = 1 AND assessment_id IN (SELECT id FROM assessments WHERE created_by = ?)', 
               whereArgs: [teacherId]
             );
          }

          for (var item in history) {
            // Check if exists
            final existing = await txn.query(
              'evaluations',
              where: 'id = ?',
              whereArgs: [item['id']],
            );

            if (existing.isEmpty) {
              // Insert header only (details lazy loaded)
              await txn.insert('evaluations', {
                'id': item['id'],
                'assessment_id': item['assessment_id'],
                'student_roll': item['evaluation_of'] ?? item['student_roll'],
                'evaluated_by': item['evaluated_by'],
                'synced': 1,
              });
            }
          }
        });
      }
    } catch (e) {
      // Failed to sync teacher history silently
    }
  }
}
