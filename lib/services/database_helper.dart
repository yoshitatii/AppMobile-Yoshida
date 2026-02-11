import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'pos_umkm.db');
    
    return await openDatabase(
      path,
      version: 2, // Tingkatkan versi untuk migration
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabel Barang
    await db.execute('''
      CREATE TABLE barang (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        kode TEXT NOT NULL UNIQUE,
        nama TEXT NOT NULL,
        harga_beli REAL NOT NULL,
        harga_jual REAL NOT NULL,
        stok INTEGER NOT NULL,
        satuan TEXT,
        kategori TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    // Tabel Transaksi
    await db.execute('''
      CREATE TABLE transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nomor_transaksi TEXT NOT NULL UNIQUE,
        tanggal TEXT NOT NULL,
        total_harga REAL NOT NULL,
        bayar REAL NOT NULL,
        kembalian REAL NOT NULL,
        catatan TEXT
      )
    ''');

    // Tabel Item Transaksi
    await db.execute('''
      CREATE TABLE item_transaksi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaksi_id INTEGER NOT NULL,
        barang_id INTEGER NOT NULL,
        nama_barang TEXT NOT NULL,
        jumlah INTEGER NOT NULL,
        harga REAL NOT NULL,
        subtotal REAL NOT NULL,
        FOREIGN KEY (transaksi_id) REFERENCES transaksi (id) ON DELETE CASCADE,
        FOREIGN KEY (barang_id) REFERENCES barang (id)
      )
    ''');

    // Tabel Pembukuan
    await db.execute('''
      CREATE TABLE pembukuan (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        jenis TEXT NOT NULL,
        tanggal TEXT NOT NULL,
        nominal REAL NOT NULL,
        kategori TEXT NOT NULL,
        keterangan TEXT NOT NULL
      )
    ''');

    // Index untuk optimalisasi query
    await db.execute('CREATE INDEX idx_barang_kode ON barang(kode)');
    await db.execute('CREATE INDEX idx_transaksi_tanggal ON transaksi(tanggal)');
    await db.execute('CREATE INDEX idx_pembukuan_tanggal ON pembukuan(tanggal)');
    await db.execute('CREATE INDEX idx_pembukuan_jenis ON pembukuan(jenis)');
  }

  // Migration untuk versi 2: Normalisasi data jenis yang sudah ada
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Normalisasi semua jenis pembukuan ke lowercase
      await db.execute('''
        UPDATE pembukuan 
        SET jenis = LOWER(jenis)
        WHERE jenis IS NOT NULL
      ''');
      
      // Update 'masuk' menjadi 'pemasukan' dan 'keluar' menjadi 'pengeluaran'
      await db.execute('''
        UPDATE pembukuan 
        SET jenis = 'pemasukan'
        WHERE LOWER(jenis) IN ('masuk', 'pemasukan', 'income')
      ''');
      
      await db.execute('''
        UPDATE pembukuan 
        SET jenis = 'pengeluaran'
        WHERE LOWER(jenis) IN ('keluar', 'pengeluaran', 'expense')
      ''');
    }
  }

  // ===========================================================
  // METODE GENERIC UNTUK QUERY
  // ===========================================================

  Future<List<Map<String, dynamic>>> query(String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(table, data);
  }

  Future<int> update(String table, Map<String, dynamic> data, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.update(table, data, where: where, whereArgs: whereArgs);
  }

  Future<int> delete(String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    return await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<List<Map<String, dynamic>>> rawQuery(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawQuery(sql, arguments);
  }

  Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return await db.rawUpdate(sql, arguments);
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Helper untuk debug - melihat semua data pembukuan
  Future<void> debugPembukuan() async {
    final db = await database;
    final result = await db.query('pembukuan', orderBy: 'tanggal DESC', limit: 10);
    print('=== DEBUG PEMBUKUAN (10 terakhir) ===');
    for (var row in result) {
      print('ID: ${row['id']}, Jenis: ${row['jenis']}, Nominal: ${row['nominal']}, Kategori: ${row['kategori']}');
    }
    print('=====================================');
  }

  // Helper untuk mendapatkan ringkasan pembukuan hari ini
  Future<Map<String, double>> getTodaySummary() async {
    final db = await database;
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
    
    final result = await db.rawQuery('''
      SELECT 
        COALESCE(SUM(CASE WHEN jenis = 'pemasukan' THEN nominal ELSE 0 END), 0) as pemasukan,
        COALESCE(SUM(CASE WHEN jenis = 'pengeluaran' THEN nominal ELSE 0 END), 0) as pengeluaran
      FROM pembukuan 
      WHERE tanggal >= ? AND tanggal <= ?
    ''', [startOfDay.toIso8601String(), endOfDay.toIso8601String()]);
    
    if (result.isNotEmpty) {
      final pemasukan = (result[0]['pemasukan'] as num?)?.toDouble() ?? 0.0;
      final pengeluaran = (result[0]['pengeluaran'] as num?)?.toDouble() ?? 0.0;
      
      return {
        'pemasukan': pemasukan,
        'pengeluaran': pengeluaran,
        'saldo': pemasukan - pengeluaran,
      };
    }
    
    return {
      'pemasukan': 0.0,
      'pengeluaran': 0.0,
      'saldo': 0.0,
    };
  }
}