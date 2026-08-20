import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/layanan_model.dart';
import '../models/jadwal_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  static const _databaseName = 'rs_prima_insan.db';
  static const _databaseVersion = 5;

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
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE chat_history ADD COLUMN tts_text TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS chat_sessions (
          id TEXT PRIMARY KEY,
          title TEXT NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      // Migrate existing chat_history into a default session
      final existing = await db.query('chat_history', limit: 1);
      if (existing.isNotEmpty) {
        final sessionId = existing.first['session_id'] as String;
        final now = DateTime.now().toIso8601String();
        await db.insert('chat_sessions', {
          'id': sessionId,
          'title': 'Chat Lama',
          'created_at': now,
          'updated_at': now,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    }
    if (oldVersion < 5) {
      await db.execute(
        'ALTER TABLE chat_sessions '
        'ADD COLUMN title_generated INTEGER NOT NULL DEFAULT 0',
      );
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
        tts_text TEXT,
        is_bot INTEGER NOT NULL,
        timestamp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE chat_sessions (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        title_generated INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ===== SESSION METHODS =====

  Future<void> insertSessionWithFirstMessage(
    String id,
    String title,
    String message,
  ) async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    await db.transaction((transaction) async {
      await transaction.insert('chat_sessions', {
        'id': id,
        'title': title,
        'created_at': now,
        'updated_at': now,
        'title_generated': 0,
      });
      await transaction.insert('chat_history', {
        'session_id': id,
        'text': message,
        'tts_text': null,
        'is_bot': 0,
        'timestamp': now,
      });
    });
  }

  Future<void> deleteSessionsWithoutUserMessages() async {
    final db = await instance.database;

    await db.transaction((transaction) async {
      final emptySessions = await transaction.rawQuery('''
        SELECT sessions.id
        FROM chat_sessions AS sessions
        WHERE NOT EXISTS (
          SELECT 1
          FROM chat_history AS history
          WHERE history.session_id = sessions.id
            AND history.is_bot = 0
        )
      ''');

      for (final session in emptySessions) {
        final sessionId = session['id'] as String;
        await transaction.delete(
          'chat_history',
          where: 'session_id = ?',
          whereArgs: [sessionId],
        );
        await transaction.delete(
          'chat_sessions',
          where: 'id = ?',
          whereArgs: [sessionId],
        );
      }
    });
  }

  Future<List<Map<String, dynamic>>> getAllSessions() async {
    final db = await instance.database;
    return await db.query('chat_sessions', orderBy: 'updated_at DESC');
  }

  Future<int> updateSessionTitle(
    String id,
    String title,
  ) async {
    final db = await instance.database;
    return await db.update(
      'chat_sessions',
      {'title': title},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Memperbaiki judul sesi lama yang rusak atau bernilai generic/bahasa inggris
  /// berdasarkan pesan pertama pengguna pada sesi tersebut.
  Future<void> sanitizeSessionTitles(String Function(String) titleFormatter) async {
    final db = await instance.database;
    final sessions = await db.query('chat_sessions');

    for (final session in sessions) {
      final sessionId = session['id'] as String;
      final currentTitle = (session['title'] as String?) ?? '';

      // Cek apakah judul perlu diperbaiki (misal: "The user wants...", "Chat Baru", "Chat Lama", dll)
      final isProblematic = currentTitle.toLowerCase().contains('the user') ||
          currentTitle.toLowerCase().contains('user wants') ||
          currentTitle.toLowerCase().contains('tit...') ||
          currentTitle == 'Chat Baru' ||
          currentTitle == 'Chat Lama';

      if (isProblematic || currentTitle.isEmpty) {
        // Ambil pesan user pertama dari sesi ini
        final userMessages = await db.query(
          'chat_history',
          where: 'session_id = ? AND is_bot = 0',
          orderBy: 'timestamp ASC',
          limit: 1,
        );

        if (userMessages.isNotEmpty) {
          final firstUserText = userMessages.first['text'] as String;
          final cleanTitle = titleFormatter(firstUserText);
          await db.update(
            'chat_sessions',
            {'title': cleanTitle},
            where: 'id = ?',
            whereArgs: [sessionId],
          );
        }
      }
    }
  }

  Future<void> deleteSession(String id) async {
    final db = await instance.database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'chat_history',
        where: 'session_id = ?',
        whereArgs: [id],
      );
      await transaction.delete(
        'chat_sessions',
        where: 'id = ?',
        whereArgs: [id],
      );
    });
  }

  Future<void> deleteAllSessions() async {
    final db = await instance.database;
    await db.transaction((transaction) async {
      await transaction.delete('chat_history');
      await transaction.delete('chat_sessions');
    });
  }

  // ===== CHAT HISTORY METHODS =====

  Future<bool> insertChatIfSessionExists(
    String sessionId,
    String text,
    bool isBot, {
    String? ttsText,
  }) async {
    final db = await instance.database;

    return db.transaction((transaction) async {
      final sessions = await transaction.query(
        'chat_sessions',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [sessionId],
        limit: 1,
      );
      if (sessions.isEmpty) return false;

      final now = DateTime.now().toIso8601String();
      await transaction.update(
        'chat_sessions',
        {'updated_at': now},
        where: 'id = ?',
        whereArgs: [sessionId],
      );
      await transaction.insert('chat_history', {
        'session_id': sessionId,
        'text': text,
        'tts_text': ttsText,
        'is_bot': isBot ? 1 : 0,
        'timestamp': now,
      });
      return true;
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

  Future<void> replaceChatHistory(
    String sessionId,
    List<Map<String, dynamic>> messages,
  ) async {
    final db = await instance.database;
    await db.transaction((transaction) async {
      await transaction.delete(
        'chat_history',
        where: 'session_id = ?',
        whereArgs: [sessionId],
      );
      for (final msg in messages) {
        await transaction.insert('chat_history', {
          'session_id': sessionId,
          'text': msg['text'],
          'tts_text': msg['tts_text'],
          'is_bot': msg['is_bot'] == 1 ? 1 : 0,
          'timestamp': msg['timestamp'] ?? DateTime.now().toIso8601String(),
        });
      }
    });
  }

  Future<int> deleteChatHistory(String sessionId) async {
    final db = await instance.database;
    return await db.delete(
      'chat_history',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // ===== LAYANAN & JADWAL METHODS =====

  Future<int> insertLayanan(LayananModel layanan) async {
    final db = await instance.database;
    return await db.insert('layanan', layanan.toMap());
  }

  Future<int> insertJadwal(JadwalModel jadwal) async {
    final db = await instance.database;
    return await db.insert('jadwal_dokter', jadwal.toMap());
  }

  Future<List<LayananModel>> queryLayanan(String query) async {
    final db = await instance.database;
    final result = await db.query(
      'layanan',
      where: 'nama_layanan LIKE ? OR deskripsi LIKE ?',
      whereArgs: ['%\$query%', '%\$query%'],
    );
    return result.map((json) => LayananModel.fromMap(json)).toList();
  }

  Future<List<JadwalModel>> queryJadwal(
    String spesialisasi,
    String? hari,
  ) async {
    final db = await instance.database;
    String whereClause = 'spesialisasi LIKE ?';
    List<dynamic> whereArgs = ['%\$spesialisasi%'];

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
