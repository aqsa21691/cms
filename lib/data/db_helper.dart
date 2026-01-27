import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static Database? _db;

  static const _dbName = 'cms_offline.db'; // Updated name
  static const _dbVersion = 3; // Incremented version

  static Future<Database> get db async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add columns for assessments if upgrading
          try {
            await db.execute(
              'ALTER TABLE assessments ADD COLUMN synced INTEGER DEFAULT 1',
            );
            await db.execute('ALTER TABLE assessments ADD COLUMN ucode TEXT');
            await db.execute(
              'ALTER TABLE assessments ADD COLUMN description TEXT',
            );
            await db.execute(
              'ALTER TABLE assessments ADD COLUMN created_by TEXT',
            );
          } catch (e) {
            // Ignore upgrade errors for existing columns
          }
        }
        if (oldVersion < 3) {
           try {
            await db.execute(
              'ALTER TABLE assessments ADD COLUMN teacher_name TEXT',
            );
           } catch (e) {
             // Ignore
           }
        }
      },
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE users (
        bgnu_id TEXT PRIMARY KEY,
        full_name TEXT,
        designation TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE assessments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        description TEXT,
        ucode TEXT,
        created_by TEXT,
        teacher_name TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE assessment_details (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER,
        category TEXT,
        marks INTEGER,
        is_comment INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE evaluations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        assessment_id INTEGER,
        student_roll TEXT,
        evaluated_by TEXT,
        device_id TEXT,
        created_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE evaluation_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        evaluation_id INTEGER,
        category_id INTEGER,
        marks INTEGER,
        comment TEXT
      )
    ''');
  }

  static Future<void> clearAllData() async {
    final db = await DBHelper.db;
    await db.delete('users');
    await db.delete('assessments');
    await db.delete('assessment_details');
    await db.delete('evaluations');
    await db.delete('evaluation_items');
  }
}
