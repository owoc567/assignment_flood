import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class OfflineSosDatabase {
  OfflineSosDatabase._internal();

  static final OfflineSosDatabase instance =
  OfflineSosDatabase._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _createDatabase();
    return _database!;
  }

  Future<Database> _createDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      'myflood_offline.db',
    );

    return openDatabase(
      path,
      version: 1,
      onCreate: (database, version) async {
        await database.execute(
          '''
          CREATE TABLE offline_sos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            full_name TEXT NOT NULL,
            phone_number TEXT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            message TEXT,
            created_at TEXT NOT NULL,
            sync_status TEXT NOT NULL DEFAULT 'pending_sync'
          )
          ''',
        );
      },
    );
  }

  Future<int> saveOfflineSos({
    required String userId,
    required String fullName,
    String? phoneNumber,
    required double latitude,
    required double longitude,
    String? message,
  }) async {
    final database = await instance.database;

    return database.insert(
      'offline_sos',
      {
        'user_id': userId,
        'full_name': fullName,
        'phone_number': phoneNumber,
        'latitude': latitude,
        'longitude': longitude,
        'message': message,
        'created_at':
        DateTime.now().toUtc().toIso8601String(),
        'sync_status': 'pending_sync',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>>
  getPendingSos() async {
    final database = await instance.database;

    return database.query(
      'offline_sos',
      where: 'sync_status = ?',
      whereArgs: ['pending_sync'],
      orderBy: 'created_at ASC',
    );
  }

  Future<List<Map<String, dynamic>>>
  getAllOfflineSos() async {
    final database = await instance.database;

    return database.query(
      'offline_sos',
      orderBy: 'created_at DESC',
    );
  }

  Future<void> markAsSynced(int id) async {
    final database = await instance.database;

    await database.update(
      'offline_sos',
      {
        'sync_status': 'synced',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markAsPending(int id) async {
    final database = await instance.database;

    await database.update(
      'offline_sos',
      {
        'sync_status': 'pending_sync',
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteSos(int id) async {
    final database = await instance.database;

    await database.delete(
      'offline_sos',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}