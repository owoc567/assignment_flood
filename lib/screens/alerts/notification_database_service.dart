import 'dart:developer';

import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'notification_model.dart';

class NotificationDatabaseService {
  static final NotificationDatabaseService _databaseService =
  NotificationDatabaseService._internal();

  factory NotificationDatabaseService() => _databaseService;

  NotificationDatabaseService._internal();

  static Database? _database;

  // Get the SQLite database
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _initializeDatabase();
    return _database!;
  }

  // Create or open the database
  Future<Database> _initializeDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/flood_notifications.db';

    log('SQLite database location: $path');

    return openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }

  // Create the Notifications table
  Future<void> _createDatabase(Database db, int version) async {
    await db.execute(
      'CREATE TABLE Notifications('
          'id INTEGER PRIMARY KEY AUTOINCREMENT, '
          'title TEXT NOT NULL, '
          'message TEXT NOT NULL, '
          'time TEXT NOT NULL, '
          'level TEXT NOT NULL, '
          'is_read INTEGER NOT NULL'
          ')',
    );
  }

  // Retrieve all notifications
  Future<List<NotificationModel>> getNotifications() async {
    final db = await database;

    final data = await db.query(
      'Notifications',
      orderBy: 'id DESC',
    );

    return List.generate(
      data.length,
          (index) => NotificationModel.fromJson(data[index]),
    );
  }

  // Insert a notification
  Future<void> insertNotification(
      NotificationModel notification,
      ) async {
    final db = await database;

    final result = await db.insert(
      'Notifications',
      notification.toMap(),
    );

    log('Inserted notification: $result');
  }

  // Mark one notification as read
  Future<void> markAsRead(int id) async {
    final db = await database;

    final result = await db.update(
      'Notifications',
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    log('Updated notification: $result');
  }

  // Mark all notifications as read
  Future<void> markAllAsRead() async {
    final db = await database;

    final result = await db.update(
      'Notifications',
      {'is_read': 1},
    );

    log('Updated notifications: $result');
  }

  // Delete one notification
  Future<void> deleteNotification(int id) async {
    final db = await database;

    final result = await db.delete(
      'Notifications',
      where: 'id = ?',
      whereArgs: [id],
    );

    log('Deleted notification: $result');
  }

  // Delete all local notifications
  Future<void> deleteAllNotifications() async {
    final db = await database;

    final result = await db.delete('Notifications');

    log('Deleted notifications: $result');
  }
}