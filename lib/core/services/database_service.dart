import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:path/path.dart' as p;
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static dynamic _database; 
  static Completer<dynamic>? _dbOpenCompleter;

  DatabaseService._init();

  Future<dynamic> get database async {
    if (kIsWeb) return null; 
    if (_database != null) return _database;
    
    // Lock pattern to prevent multiple simultaneous initializations
    if (_dbOpenCompleter != null) return _dbOpenCompleter!.future;
    
    _dbOpenCompleter = Completer<dynamic>();
    try {
      _database = await _initDB('community_watch_final_v20.db');
      _dbOpenCompleter!.complete(_database);
    } catch (e) {
      _dbOpenCompleter!.completeError(e);
      _dbOpenCompleter = null;
      rethrow;
    }
    return _database;
  }

  Future<dynamic> _initDB(String filePath) async {
    final dbPath = await sqlite.getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await sqlite.openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE incidents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            type TEXT, description TEXT, location TEXT, timestamp TEXT, severity TEXT,
            is_resolved INTEGER DEFAULT 0, lat REAL, lng REAL, reporter_name TEXT, 
            reporter_id TEXT, attachments TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE users (
            id INTEGER PRIMARY KEY AUTOINCREMENT, username TEXT, email TEXT UNIQUE,
            password TEXT, phone TEXT UNIQUE, region TEXT, is_admin INTEGER DEFAULT 0, 
            reputation_score INTEGER DEFAULT 100, lat REAL, lng REAL, 
            face_image TEXT, face_up TEXT, face_center TEXT, face_left TEXT, face_right TEXT,
            blood_group TEXT, id_type TEXT, joined_date TEXT, session_token TEXT, is_verified INTEGER DEFAULT 0, is_frozen INTEGER DEFAULT 0
          )
        ''');
        await db.execute('''
          CREATE TABLE messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT, recipient TEXT, content TEXT, timestamp TEXT, is_admin_reply INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE admin_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            admin_id TEXT, action TEXT, timestamp TEXT, details TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE regional_risk (
            region TEXT PRIMARY KEY, level TEXT
          )
        ''');
      },
    );
  }

  DateTime? _lastSync;

  // --- CORE SYNC ---
  Future<void> syncIntelFromServer() async {
    if (AuthService.instance.sessionToken == null) return;
    
    // THROTTLE: Only sync every 60 seconds automatically
    if (_lastSync != null && DateTime.now().difference(_lastSync!).inSeconds < 60) return;

    try {
      final res = await http.get(
        Uri.parse('${AuthService.instance.getBaseUrl()}/incidents'), 
        headers: AuthService.instance.getSecureHeaders()
      ).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final List data = jsonDecode(res.body)['incidents'];
        final db = await database;
        if (db == null) return;

        await db.transaction((txn) async {
          if (AuthService.instance.isAdmin) {
            await txn.delete('incidents');
          } else {
            await txn.delete('incidents', where: 'reporter_id = ?', whereArgs: [AuthService.instance.currentUserEmail]);
          }
          
          final batch = txn.batch();
          for (var i in data) {
            batch.insert('incidents', i, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
          }
          await batch.commit(noResult: true);
        });
        _lastSync = DateTime.now();
      }
    } catch (e) {
      print("SYNC_ERROR: $e");
    }
  }

  // FORCE SYNC for manual refresh
  Future<void> forceSyncIntel() async {
    _lastSync = null;
    await syncIntelFromServer();
  }

  // --- USER OPERATIONS ---
  Future<int> saveSession(Map<String, dynamic> user, String? token) async {
    final db = await database;
    if (db == null) return 0;
    return await db.insert('users', {
      'username': user['username'],
      'email': user['email'],
      'is_admin': (user['is_admin'] == 1 || user['is_admin'] == true) ? 1 : 0,
      'reputation_score': user['reputation_score'],
      'session_token': token
    }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
  }

  Future<int> createUser(Map<String, dynamic> user) async {
    final db = await database;
    if (db == null) return 0;
    const localUserColumns = {
      'username',
      'email',
      'password',
      'phone',
      'region',
      'is_admin',
      'reputation_score',
      'lat',
      'lng',
      'face_image',
      'face_up',
      'face_center',
      'face_left',
      'face_right',
      'blood_group',
      'id_type',
      'joined_date',
      'is_verified',
      'is_frozen',
    };
    final localUser = Map<String, dynamic>.fromEntries(
      user.entries.where((entry) => localUserColumns.contains(entry.key)),
    );
    return await db.insert('users', localUser, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getActiveSession() async {
    final db = await database;
    if (db == null) return null;
    final maps = await db.query('users', where: 'session_token IS NOT NULL', limit: 1, orderBy: 'id DESC');
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>?> getMyProfile() async {
    final db = await database;
    if (db == null) return null;
    final maps = await db.query('users', where: 'email = ?', whereArgs: [AuthService.instance.currentUserEmail]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    if (db == null) return null;
    final maps = await db.query('users', where: 'email = ?', whereArgs: [email]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<Map<String, dynamic>?> getUserByAdminId(String adminId) async {
    final db = await database;
    if (db == null) return null;
    final maps = await db.query('users', where: 'email = ? AND is_admin = 1', whereArgs: [adminId]);
    return maps.isNotEmpty ? maps.first : null;
  }

  Future<List<Map<String, dynamic>>> readAllUsers() async {
    final db = await database;
    return db != null ? await db.query('users') : [];
  }

  Future<int> updateUser(Map<String, dynamic> user) async {
    final db = await database;
    if (db == null) return 0;
    return await db.update('users', user, where: 'email = ?', whereArgs: [user['email']]);
  }

  Future<int> updateUserStatus(int id, int isFrozen) async {
    final db = await database;
    return db != null ? await db.update('users', {'is_frozen': isFrozen}, where: 'id = ?', whereArgs: [id]) : 0;
  }

  Future<int> verifyUser(String email) async {
    final db = await database;
    if (db == null) return 0;
    return await db.update('users', {'is_verified': 1}, where: 'email = ?', whereArgs: [email]);
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db != null ? await db.delete('users', where: 'id = ?', whereArgs: [id]) : 0;
  }

  // --- INCIDENT OPERATIONS ---
  Future<void> createIncident(Map<String, dynamic> incident) async {
    final db = await database;
    final data = Map<String, dynamic>.from(incident);
    data['reporter_id'] = AuthService.instance.currentUserEmail;
    if (db != null) await db.insert('incidents', data);
    try {
      await http.post(Uri.parse('${AuthService.instance.getBaseUrl()}/incidents'), 
          headers: AuthService.instance.getSecureHeaders(), body: jsonEncode(data));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> readMyIncidents() async {
    if (kIsWeb) {
      if (AuthService.instance.sessionToken == null) return [];
      try {
        final res = await http.get(
          Uri.parse('${AuthService.instance.getBaseUrl()}/incidents'),
          headers: AuthService.instance.getSecureHeaders(),
        );
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body)['incidents'];
          return data.cast<Map<String, dynamic>>().where((i) => i['reporter_id'] == AuthService.instance.currentUserEmail).toList();
        }
      } catch (e) {
        print("WEB_INCIDENTS_ERROR: $e");
      }
      return [];
    }

    // Don't call syncIntelFromServer here directly to avoid nested awaits on every read
    final db = await database;
    if (db == null) return [];
    return await db.query('incidents', where: 'reporter_id = ?', whereArgs: [AuthService.instance.currentUserEmail], orderBy: 'timestamp DESC');
  }

  Future<List<Map<String, dynamic>>> readAllIncidents() async {
    if (kIsWeb) {
      if (AuthService.instance.sessionToken == null) return [];
      try {
        final res = await http.get(
          Uri.parse('${AuthService.instance.getBaseUrl()}/incidents'),
          headers: AuthService.instance.getSecureHeaders(),
        );
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body)['incidents'];
          final all = data.cast<Map<String, dynamic>>();
          if (AuthService.instance.isAdmin) return all;
          return all.where((i) => i['reporter_id'] == AuthService.instance.currentUserEmail).toList();
        }
      } catch (_) {}
      return [];
    }

    final db = await database;
    if (db == null) return [];
    if (AuthService.instance.isAdmin) {
      return await db.query('incidents', orderBy: 'timestamp DESC');
    }
    return await readMyIncidents();
  }

  Future<int> deleteIncident(int id) async {
    final db = await database;
    if (db != null) {
      await db.delete('incidents', where: 'id = ?', whereArgs: [id]);
    }
    try {
      await http.delete(
        Uri.parse('${AuthService.instance.getBaseUrl()}/incidents/$id'),
        headers: AuthService.instance.getSecureHeaders(),
      );
    } catch (_) {}
    return 1;
  }

  Future<void> resolveIncident(int id) async {
    final db = await database;
    if (db != null) {
      await db.update('incidents', {'is_resolved': 1}, where: 'id = ?', whereArgs: [id]);
    }
    try {
      await http.post(
        Uri.parse('${AuthService.instance.getBaseUrl()}/incidents/resolve'),
        headers: AuthService.instance.getSecureHeaders(),
        body: jsonEncode({'id': id}),
      );
    } catch (_) {}
  }

  // --- LOGS & RISK ---
  Future<int> createAdminLog(Map<String, dynamic> log) async {
    final db = await database;
    return db != null ? await db.insert('admin_logs', log) : 0;
  }

  Future<List<Map<String, dynamic>>> readAllAdminLogs() async {
    final db = await database;
    return db != null ? await db.query('admin_logs', orderBy: 'id DESC') : [];
  }

  Future<void> updateRegionalRisk(String region, String level) async {
    final db = await database;
    if (db != null) await db.insert('regional_risk', {'region': region, 'level': level}, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
  }

  Future<Map<String, String>> getAllRegionalRisks() async {
    if (kIsWeb) {
      return {
        'Greater Accra': 'High',
        'Ashanti': 'Med',
        'Northern': 'Low',
      };
    }
    final db = await database;
    if (db == null) return {};
    try {
      final maps = await db.query('regional_risk');
      return { for (var e in maps) (e['region']?.toString() ?? 'Unknown') : (e['level']?.toString() ?? 'Low') };
    } catch (_) { return {}; }
  }

  // --- MESSAGES ---
  Future<int> createMessage(Map<String, dynamic> message) async {
    final db = await database;
    // Always use email as the link internally
    final data = Map<String, dynamic>.from(message);
    if (db != null) await db.insert('messages', data);
    try {
      await http.post(Uri.parse('${AuthService.instance.getBaseUrl()}/messages'), 
          headers: AuthService.instance.getSecureHeaders(), body: jsonEncode(data));
    } catch (_) {}
    return 1;
  }

  Future<void> editMessage(int id, String newContent) async {
    final db = await database;
    if (db != null) {
      await db.update('messages', {'content': newContent, 'is_edited': 1}, where: 'id = ?', whereArgs: [id]);
    }
    try {
      await http.post(
        Uri.parse('${AuthService.instance.getBaseUrl()}/messages/edit'),
        headers: AuthService.instance.getSecureHeaders(),
        body: jsonEncode({'id': id, 'content': newContent}),
      );
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> readMessagesForUser(String email) async {
    if (kIsWeb) {
      try {
        final res = await http.get(
          Uri.parse('${AuthService.instance.getBaseUrl()}/messages?unit=$email'),
          headers: AuthService.instance.getSecureHeaders(),
        );
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body)['messages'];
          return data.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
      return [];
    }
    final db = await database;
    if (db == null) return [];
    return await db.query('messages', 
      where: 'sender = ? OR recipient = ?', 
      whereArgs: [email, email],
      orderBy: 'timestamp ASC'
    );
  }

  Future<List<Map<String, dynamic>>> readAllAdminMessages() async {
    if (kIsWeb) {
      try {
        final res = await http.get(
          Uri.parse('${AuthService.instance.getBaseUrl()}/messages'),
          headers: AuthService.instance.getSecureHeaders(),
        );
        if (res.statusCode == 200) {
          final List data = jsonDecode(res.body)['messages'];
          return data.cast<Map<String, dynamic>>();
        }
      } catch (_) {}
      return [];
    }
    final db = await database;
    return db != null ? await db.query('messages', orderBy: 'timestamp DESC') : [];
  }

  Future close() async {
    final db = await database;
    if (db != null) await db.close();
  }

  // --- ALIASES ---
  Future<Map<String, dynamic>?> getAuthenticatedUser() async => await getMyProfile();
}
