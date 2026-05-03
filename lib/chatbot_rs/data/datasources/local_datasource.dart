import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/layanan_model.dart';
import '../models/jadwal_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _databaseName = 'rs_prima_insan.db';
  static const _databaseVersion = 2;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE chat_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          session_id TEXT NOT NULL,
          text TEXT NOT NULL,
          is_bot INTEGER NOT NULL,
          timestamp TEXT NOT NULL
        )
      ''');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE layanan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_layanan TEXT NOT NULL,
        deskripsi TEXT NOT NULL,
        lokasi_gedung TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE jadwal_dokter (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nama_dokter TEXT NOT NULL,
        spesialisasi TEXT NOT NULL,
        hari TEXT NOT NULL,
        jam_mulai TEXT NOT NULL,
        jam_selesai TEXT NOT NULL,
        id_layanan INTEGER,
        FOREIGN KEY (id_layanan) REFERENCES layanan (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id TEXT NOT NULL,
        text TEXT NOT NULL,
        is_bot INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');
  }

  Future<int> insertLayanan(LayananModel layanan) async {
    final db = await instance.database;
    return await db.insert('layanan', layanan.toMap());
  }

  Future<int> insertJadwal(JadwalModel jadwal) async {
    final db = await instance.database;
    return await db.insert('jadwal_dokter', jadwal.toMap());
  }

  Future<int> insertChat(String sessionId, String text, bool isBot) async {
    final db = await instance.database;
    return await db.insert('chat_history', {
      'session_id': sessionId,
      'text': text,
      'is_bot': isBot ? 1 : 0,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getChatHistory(String sessionId) async {
    final db = await instance.database;
    return await db.query(
      'chat_history',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<int> deleteChatHistory(String sessionId) async {
    final db = await instance.database;
    return await db.delete(
      'chat_history',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<LayananModel>> queryLayanan(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'layanan',
      where: 'nama_layanan LIKE ? OR deskripsi LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
    );
    return result.map((json) => LayananModel.fromMap(json)).toList();
  }

  Future<List<JadwalModel>> queryJadwal(String spesialisasi, String? hari) async {
    final db = await instance.database;
    String whereClause = 'spesialisasi LIKE ?';
    List<dynamic> whereArgs = ['%$spesialisasi%'];
    
    if (hari != null) {
      whereClause += ' AND hari = ?';
      whereArgs.add(hari);
    }
    
    final result = await db.query(
      'jadwal_dokter',
      where: whereClause,
      whereArgs: whereArgs,
    );
    return result.map((json) => JadwalModel.fromMap(json)).toList();
  }

  Future<void> clearAll() async {
    final db = await instance.database;
    await db.delete('layanan');
    await db.delete('jadwal_dokter');
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
