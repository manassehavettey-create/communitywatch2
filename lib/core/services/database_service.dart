import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  // Web Simulation Storage
  static final List<Map<String, dynamic>> _webIncidents = [];
  static final List<Map<String, dynamic>> _webUsers = [
    {
      'id': 1, 
      'username': 'Admin_Master', 
      'email': 'admin@communitywatch.gh', 
      'reputation_score': 100, 
      'is_verified': 1, 
      'joined_date': 'Oct 2023',
      'is_frozen': 0,
      'lat': 5.6037,
      'lng': -0.1870
    }
  ];
  static final List<Map<String, dynamic>> _webMessages = [];
  static final List<Map<String, dynamic>> _webAdminLogs = [];

  DatabaseService._init();

  Future<Database?> get database async {
    if (kIsWeb) return null; 
    if (_database != null) return _database!;
    
    try {
      _database = await _initDB('community_watch_pro_v5.db');
      return _database!;
    } catch (e) {
      return null;
    }
  }

  Future<Database?> _initDB(String filePath) async {
    if (kIsWeb) return null;
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB,
      );
    } catch (e) {
      return null;
    }
  }

  Future _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const boolType = 'BOOLEAN NOT NULL';
    const integerType = 'INTEGER NOT NULL';
    const doubleType = 'REAL NOT NULL';

    await db.execute('''
CREATE TABLE incidents (
  id $idType,
  type $textType,
  description $textType,
  location $textType,
  timestamp $textType,
  severity $textType,
  is_resolved $boolType,
  lat $doubleType,
  lng $doubleType,
  reporter_name TEXT
)
''');

    await db.execute('''
CREATE TABLE users (
  id $idType,
  username $textType,
  email $textType,
  reputation_score $integerType,
  is_verified $boolType,
  joined_date $textType,
  is_frozen INTEGER DEFAULT 0,
  lat REAL,
  lng REAL
)
''');

    await db.execute('''
CREATE TABLE messages (
  id $idType,
  sender $textType,
  recipient $textType,
  content $textType,
  timestamp $textType,
  is_admin_reply $integerType
)
''');

    await db.execute('''
CREATE TABLE admin_logs (
  id $idType,
  admin_id $textType,
  action $textType,
  timestamp $textType,
  details $textType
)
''');
  }

  // --- Incident Operations ---
  Future<int> createIncident(Map<String, dynamic> incident) async {
    if (kIsWeb) {
      final newIncident = Map<String, dynamic>.from(incident);
      newIncident['id'] = _webIncidents.length + 1;
      _webIncidents.add(newIncident);
      return newIncident['id'];
    }
    final db = await database;
    return await db?.insert('incidents', incident) ?? 0;
  }

  Future<List<Map<String, dynamic>>> readAllIncidents() async {
    if (kIsWeb) return List.from(_webIncidents.reversed);
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query('incidents', orderBy: 'timestamp DESC');
    } catch (e) {
      return [];
    }
  }

  // --- User Operations ---
  Future<int> createUser(Map<String, dynamic> user) async {
    if (kIsWeb) {
      final newUser = Map<String, dynamic>.from(user);
      newUser['id'] = _webUsers.length + 1;
      newUser['is_frozen'] = 0;
      _webUsers.add(newUser);
      return newUser['id'];
    }
    final db = await database;
    return await db?.insert('users', user) ?? 0;
  }

  Future<List<Map<String, dynamic>>> readAllUsers() async {
    if (kIsWeb) return List.from(_webUsers);
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query('users');
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    if (kIsWeb) {
      try {
        return _webUsers.firstWhere((u) => u['email'] == email);
      } catch (e) {
        return null;
      }
    }
    final db = await database;
    if (db == null) return null;
    final maps = await db.query('users', where: 'email = ?', whereArgs: [email]);
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<int> updateUserStatus(int id, int isFrozen) async {
    if (kIsWeb) {
      final index = _webUsers.indexWhere((u) => u['id'] == id);
      if (index != -1) {
        final updatedUser = Map<String, dynamic>.from(_webUsers[index]);
        updatedUser['is_frozen'] = isFrozen;
        _webUsers[index] = updatedUser;
        return 1;
      }
      return 0;
    }
    final db = await database;
    return await db?.update('users', {'is_frozen': isFrozen}, where: 'id = ?', whereArgs: [id]) ?? 0;
  }

  Future<int> updateUserLocation(String email, double lat, double lng) async {
    if (kIsWeb) {
      final index = _webUsers.indexWhere((u) => u['email'] == email);
      if (index != -1) {
        final updatedUser = Map<String, dynamic>.from(_webUsers[index]);
        updatedUser['lat'] = lat;
        updatedUser['lng'] = lng;
        _webUsers[index] = updatedUser;
        return 1;
      }
      return 0;
    }
    final db = await database;
    return await db?.update('users', {'lat': lat, 'lng': lng}, where: 'email = ?', whereArgs: [email]) ?? 0;
  }

  Future<int> deleteUser(int id) async {
    if (kIsWeb) {
      _webUsers.removeWhere((u) => u['id'] == id);
      return 1;
    }
    final db = await database;
    return await db?.delete('users', where: 'id = ?', whereArgs: [id]) ?? 0;
  }

  // --- Message Operations ---
  Future<int> createMessage(Map<String, dynamic> message) async {
    if (kIsWeb) {
      final newMessage = Map<String, dynamic>.from(message);
      newMessage['id'] = _webMessages.length + 1;
      _webMessages.add(newMessage);
      return newMessage['id'];
    }
    final db = await database;
    return await db?.insert('messages', message) ?? 0;
  }

  Future<List<Map<String, dynamic>>> readMessagesForUser(String username) async {
    if (kIsWeb) {
      return _webMessages.where((m) => m['sender'] == username || m['recipient'] == username).toList();
    }
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query(
        'messages', 
        where: 'sender = ? OR recipient = ?', 
        whereArgs: [username, username],
        orderBy: 'timestamp ASC'
      );
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> readAllAdminMessages() async {
    if (kIsWeb) return List.from(_webMessages.reversed);
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query('messages', orderBy: 'timestamp DESC');
    } catch (e) {
      return [];
    }
  }

  // --- Admin Log Operations ---
  Future<int> createAdminLog(Map<String, dynamic> log) async {
    if (kIsWeb) {
      final newLog = Map<String, dynamic>.from(log);
      newLog['id'] = _webAdminLogs.length + 1;
      _webAdminLogs.add(newLog);
      return newLog['id'];
    }
    final db = await database;
    return await db?.insert('admin_logs', log) ?? 0;
  }

  Future<List<Map<String, dynamic>>> readAllAdminLogs() async {
    if (kIsWeb) return List.from(_webAdminLogs.reversed);
    try {
      final db = await database;
      if (db == null) return [];
      return await db.query('admin_logs', orderBy: 'timestamp DESC');
    } catch (e) {
      return [];
    }
  }

  Future close() async {
    if (kIsWeb) return;
    final db = await database;
    db?.close();
  }
}
